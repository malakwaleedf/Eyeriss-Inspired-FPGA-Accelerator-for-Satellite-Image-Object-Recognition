// =============================================================================
// Testbench: tb_TOP_Group.v
//
// DUT: CONV_TOP
//
// Memory configuration:
//   - Weight DRAM : 9×9, loaded row-major from weight_dram_stream_rowmajor.txt
//   - Iact DRAM   : 1024×1024, loaded column-major from iact_dram_stream_colmajor.txt
//                   (1,048,576 × 1 flat file; first 1024 values → column 0, etc.)
//
// DRAM interface:
//   Both DRAMs are address-indexed by the DUT. The TB loads the memories from
//   file and responds to DUT-driven addresses combinationally — no TB-side
//   address arithmetic is performed.
//
//   For the GLB push paths the TB simply:
//     - Waits for the DUT ready signal
//     - Asserts valid and presents data (combinationally from the DRAM array)
//     - Holds valid until the DUT's corresponding done signal arrives
//     - Deasserts valid
//
// Flow (repeated 1024 times, one per output column):
//   1. Reset for 4 cycles
//   2. Assert turn_on for 1 cycle
//   3. Wait for weight_DRAM_data_in_ready, hold weight valid until weight done
//   4. Wait for IACT_data_in_ready, hold iact valid until iact column done
//   5. Wait for rearrange_col_done_from_rearrange_to_top
//   6. Snapshot rearrange_inst internal memory → store as one output column
//   7. Wait 8 cycles, then repeat
//
// Output: rearrange_output_matrix.txt  (1024×1024, one decimal value per line,
//         row-major, no headers or extra text)
// =============================================================================

`timescale 1ns/1ns

module tb_TOP_Group;

// ============================================================
// Parameters
// ============================================================
parameter PE_NUM                    = 36;
parameter ROW_NUM                   = 9;
parameter IACT_WIDTH                = 8;
parameter WEIGHT_WIDTH              = 8;
parameter PSUM_WIDTH                = 20;
parameter IACT_SPAD_DEPTH           = 16;
parameter PSUM_SPAD_DEPTH           = 16;
parameter WEIGHT_SPAD_DEPTH         = 9;
parameter CLUSTER_ROWS              = 9;

parameter IACT_SRAM_DEPTH           = 256;
parameter IACT_SRAM_ADDRESS_SIZE    = 8;
parameter WEIGHT_SRAM_DEPTH         = 256;
parameter WEIGHT_SRAM_ADDRESS_SIZE  = 7;
parameter ADDRESS_SIZE              = 5;
parameter PSUM_SRAM_DEPTH           = 32;
parameter PSUM_WRITE_COUNT_SIZE     = 5;

// Convolution config
parameter CYCLES_PER_IACT_COL                 = 5'd16;
parameter UNIQUE_VALUES_PER_CLUSTER_PER_CYCLE = 5'd12;
parameter UNIQUE_VALUES_PER_CLUSTER           = 8'd192;
parameter WEIGHT_VALUES_PER_FILTER            = 7'd81;
parameter WEIGHT_COLUMNS                      = 4'd9;

// DRAM sizes
parameter WEIGHT_DRAM_DEPTH  = 81;       // 9×9
parameter IACT_DRAM_TOTAL    = 1032*1032;  // 1024×1024
parameter WEIGHT_ADDR_SIZE   = 7;
parameter IACT_ADDR_SIZE     = 21;

// Rearrange / output dimensions
parameter REARRANGE_DEPTH = 1024;
parameter NUM_COLUMNS     = 1024;

// ============================================================
// Clock
// ============================================================
reg clk;
initial clk = 0;
always #5 clk = ~clk;  // 100 MHz

task wait_clk; begin @(posedge clk); #1; end endtask

// ============================================================
// Weight DRAM
// Loaded row-major from file; DUT drives the read address.
// ============================================================
reg signed [WEIGHT_WIDTH-1:0] weight_dram [0:WEIGHT_DRAM_DEPTH-1];

wire [WEIGHT_ADDR_SIZE-1:0] weight_addr_from_dut;
reg  signed [WEIGHT_WIDTH-1:0]     weight_data_to_dut;

// ============================================================
// Iact DRAM
// Loaded column-major from file; DUT drives the read address.
// ============================================================
reg signed [IACT_WIDTH-1:0]  iact_dram [0:IACT_DRAM_TOTAL-1];

wire [IACT_ADDR_SIZE-1:0] iact_addr_from_dut;
reg  signed [IACT_WIDTH-1:0]      iact_data_to_dut;

always @(*) begin
    iact_data_to_dut = iact_dram[iact_addr_from_dut];
end

// ============================================================
// DUT port signals
// ============================================================
reg  rst;
reg  turn_on;

// Iact GLB push interface
wire                  IACT_data_in_ready_from_glb_to_dram;
reg                   IACT_data_in_valid_from_dram_to_glb;
wire                  IACT_column_done_flag_from_ctrl_to_top;

// Weight GLB push interface
reg                   weight_DRAM_data_in_valid;
wire                  weight_DRAM_data_in_ready;
wire                  weight_load_done;   // DUT signals weight load complete
reg     [6:0]              weight_rom_idx;

// Controller config
reg [2:0] top_filter_mode;
reg [2:0] top_input_mode;
reg [4:0] cycles_per_iact_col;
reg [4:0] unique_values_per_cluster_per_cycle;
reg [7:0] unique_values_per_cluster;
reg [6:0] weight_values_per_filter;
reg [3:0] weight_columns;
reg       iact_next_ofmap_col_from_ctrl_to_top;

wire top_done_iact_column;

// ============================================================
// DUT instantiation
// ============================================================
CONV_TOP #(
    .PE_NUM                  (PE_NUM),
    .ROW_NUM                 (ROW_NUM),
    .IACT_WIDTH              (IACT_WIDTH),
    .WEIGHT_WIDTH            (WEIGHT_WIDTH),
    .PSUM_WIDTH              (PSUM_WIDTH),
    .IACT_SPAD_DEPTH         (IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH         (PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH       (WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS            (CLUSTER_ROWS),
    .IACT_SRAM_DEPTH         (IACT_SRAM_DEPTH),
    .IACT_SRAM_ADDRESS_SIZE  (IACT_SRAM_ADDRESS_SIZE),
    .WEIGHT_SRAM_DEPTH       (WEIGHT_SRAM_DEPTH),
    .WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
    .ADDRESS_SIZE            (ADDRESS_SIZE),
    .PSUM_SRAM_DEPTH         (PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE   (PSUM_WRITE_COUNT_SIZE)
) dut (
    .clock                                    (clk),
    .global_reset                             (rst),
    .turn_on                                  (turn_on),
    .top_filter_mode                          (top_filter_mode),
    .cycles_per_iact_col                      (cycles_per_iact_col),
    .weight_columns                           (weight_columns),
    .top_input_mode                           (top_input_mode),
    .unique_values_per_cluster_per_cycle      (unique_values_per_cluster_per_cycle),
    .unique_values_per_cluster                (unique_values_per_cluster),
    .weight_values_per_filter                 (weight_values_per_filter),
    // Iact DRAM — DUT drives address, TB responds combinationally
    .iact_data_in_addr_from_iact_dist_to_dram (iact_addr_from_dut),
    .iact_data_in_from_dram_to_iact_dist      (iact_data_to_dut),
    // Iact GLB push path
    .IACT_data_in_from_dram_to_glb            (iact_data_to_dut),
    //.IACT_data_in_valid_from_dram_to_glb      (IACT_data_in_valid_from_dram_to_glb),
    .IACT_data_in_ready_from_glb_to_dram      (IACT_data_in_ready_from_glb_to_dram),
    .IACT_column_done_flag_from_ctrl_to_top   (IACT_column_done_flag_from_ctrl_to_top),
    // Weight DRAM — DUT drives address, TB responds combinationally
    //.weight_addr_from_glb_to_dram             (weight_addr_from_dut),
    .weight_data_in_from_dram_to_glb          (weight_data_to_dut),
    // Weight GLB push path
    .weight_data_in_valid_from_dram_to_glb    (weight_DRAM_data_in_valid),
    .weight_data_in_ready_from_glb_to_dram    (weight_DRAM_data_in_ready),
    .top_done_iact_column                     (top_done_iact_column)
);

// ============================================================
// Task: reset for 4 clock cycles
// ============================================================
task do_reset;
    begin
        rst = 1'b1;
        repeat(4) wait_clk;
        rst = 1'b0;
    end
endtask

// ============================================================
// Output matrix accumulated over 1024 column iterations
// ============================================================
reg signed [PSUM_WIDTH-1:0] output_matrix [0:REARRANGE_DEPTH-1][0:NUM_COLUMNS-1];

integer col_iter, row_idx, timeout_cnt;
integer out_file;


task load_weight_dram;
    integer i, val, fd;
    begin
        fd = $fopen("weight_dram_stream_rowmajor.txt", "r");
        for (i = 0; i < WEIGHT_DRAM_DEPTH; i = i + 1) begin
            if ($fscanf(fd, "%d", val) == 1) begin
                weight_dram[i] = val[WEIGHT_WIDTH-1:0];
            end
        end
        $fclose(fd);
    end
endtask

task load_iact_dram;
    integer i, val, fd;
    begin
        fd = $fopen("iact_dram_stream_colmajor.txt", "r");
        for (i = 0; i < IACT_DRAM_TOTAL; i = i + 1) begin
            if ($fscanf(fd, "%d", val) == 1) begin
                iact_dram[i] = val[IACT_WIDTH-1:0];
            end
        end
        $fclose(fd);
    end
endtask

// ============================================================
// Main test flow
// ============================================================
initial begin

    // Load weight DRAM (row-major: lines 0-8 → row 0, ..., lines 72-80 → row 8)
    //$readmemh("weight_dram_stream_rowmajor.txt", weight_dram);

    load_weight_dram;

    // Load iact DRAM (column-major: lines 0-1023 → col 0, lines 1024-2047 → col 1, ...)
    // $readmemh("iact_dram_stream_colmajor.txt", iact_dram);
    load_iact_dram;

    // Initialise all DUT inputs
    do_reset;
    turn_on                              = 1'b0;
    wait_clk;
    top_filter_mode                      = 3'b011;
    top_input_mode                       = 3'b000;
    cycles_per_iact_col                  = CYCLES_PER_IACT_COL;
    unique_values_per_cluster_per_cycle  = UNIQUE_VALUES_PER_CLUSTER_PER_CYCLE;
    unique_values_per_cluster            = UNIQUE_VALUES_PER_CLUSTER;
    weight_values_per_filter             = WEIGHT_VALUES_PER_FILTER;
    weight_columns                       = WEIGHT_COLUMNS;
    iact_next_ofmap_col_from_ctrl_to_top = 1'b0;
    IACT_data_in_valid_from_dram_to_glb  = 1'b0;
    weight_DRAM_data_in_valid            = 1'b0;

    // ----------------------------------------------------------
    // Main loop: 1024 output columns
    // ----------------------------------------------------------
    out_file = $fopen("rearrange_output_matrix.txt", "w");

    for (col_iter = 0; col_iter < NUM_COLUMNS; col_iter = col_iter + 1) begin

        // Step 1: reset for 4 cycles
        //do_reset;

        // Step 2: assert turn_on for exactly 1 cycle
        turn_on = 1'b1;
        wait_clk;
        turn_on = 1'b0;

  
        
        // Step 3: weight GLB push
        //   Wait for DUT ready, then loop through ROM entries 0-80,
        //   presenting each value for one clock cycle with valid asserted.
        wait (weight_DRAM_data_in_ready === 1'b1);
        for (weight_rom_idx = 0; weight_rom_idx < WEIGHT_DRAM_DEPTH; weight_rom_idx = weight_rom_idx + 1) begin
            weight_data_to_dut        = weight_dram[weight_rom_idx];
            weight_DRAM_data_in_valid = 1'b1;
            wait_clk;
        end
        weight_DRAM_data_in_valid = 1'b0;
        $display("******************* Done weight glb loading *******************");
        // Step 4: iact GLB push
        //   Wait for DUT ready, assert valid, hold until column done
        //wait (IACT_data_in_ready_from_glb_to_dram === 1'b1);
        IACT_data_in_valid_from_dram_to_glb = 1'b1;

    
        //wait (IACT_column_done_flag_from_ctrl_to_top === 1'b1);
        //wait_clk;
        $display("******************* Done iact glb loading *******************");
        //IACT_data_in_valid_from_dram_to_glb = 1'b0;

        // Step 5: wait for rearrange column done
        timeout_cnt = 0;
        @(posedge dut.rearrange_col_done_from_rearrange_to_top)
        //wait_clk;
            

        /*if (timeout_cnt >= 10_000_000) begin
            $display("[ERROR] col %0d: timeout waiting for rearrange_col_done", col_iter);
            $finish;
        end*/

        // Step 6: snapshot rearrange internal memory — one output column
        for (row_idx = 0; row_idx < REARRANGE_DEPTH; row_idx = row_idx + 1) begin
            output_matrix[row_idx][col_iter] =
                dut.rearrange_inst.mem[row_idx];
        end

        // Write this column to file immediately
        for (row_idx = 0; row_idx < REARRANGE_DEPTH; row_idx = row_idx + 1) begin
            $fdisplay(out_file, "%0d", output_matrix[row_idx][col_iter]);
        end

        // Step 7: idle a few cycles before the next column
        repeat(8) wait_clk;
        $display("******************* End of for Loop *******************");
       // $stop;

    end // for col_iter

    $fclose(out_file);
    $display("[INFO] Done. Output written to rearrange_output_matrix.txt");
    $stop;
end

// ============================================================
// Timeout watchdog
// ============================================================
initial begin
    #2_000_000_000;
    $display("[TIMEOUT] Simulation exceeded time limit.");
    $finish;
end

endmodule