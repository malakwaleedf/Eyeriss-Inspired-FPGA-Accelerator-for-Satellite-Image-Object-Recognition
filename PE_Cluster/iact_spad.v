
module iact_spad #(
    parameter IACT_WIDTH  = 8,
    parameter SPAD_DEPTH = 16
)(
    input                           clock,
    input                           reset,

    // Write port
    input                           write_en,
    input        signed [IACT_WIDTH-1:0]     data_in,       // {is_zero, iact_val}
    input                           data_in_valid,
    output                          data_in_ready,
    output reg                      write_fin,     // pulses 1 cycle after slot 15 written

    // Read port — purely combinatorial, addressed by cycle_counter
    input                                   read_ptr_inc,
    output           signed [IACT_WIDTH-1:0]       data_out,      // combinatorial: mem[read_addr]
    
    input        [4:0]                      cycles_per_iact_col
);

// ============================================================================
// Register file
// ============================================================================
reg signed [IACT_WIDTH-1:0] mem [0:SPAD_DEPTH-1];

// ============================================================================
// Write pointer (circular, wraps at SPAD_DEPTH)
// ============================================================================
// reg [$clog2(SPAD_DEPTH)-1:0] write_ptr;
reg [$clog2(SPAD_DEPTH):0] write_ptr;
reg [$clog2(SPAD_DEPTH)-1:0] read_ptr;
wire data_in_shake = data_in_valid & write_en;

always @(posedge clock) begin
    if (reset)
        write_ptr <= 'd0;
    // else if (data_in_shake) begin
    else if (data_in_shake || write_ptr == cycles_per_iact_col) begin
        // if(write_ptr == cycles_per_iact_col - 1'b1)
        if(write_ptr == cycles_per_iact_col)
            write_ptr <= 'd0;
        else
            write_ptr <= write_ptr + 5'd1;
    end
    else
        write_ptr <= write_ptr;
end


integer i;
always @(posedge clock) begin
    if (reset)
	for (i = 0; i < SPAD_DEPTH; i = i + 1)
            mem[i] <= {IACT_WIDTH{1'b0}};
    else if (data_in_shake)
        mem[write_ptr] <= data_in;
end


always @(posedge clock) begin
    if (reset)
        write_fin <= 1'b0;
    else
    // if(write_ptr == cycles_per_iact_col - 1'b1)begin
    if(write_ptr == cycles_per_iact_col)begin
        write_fin <= 1'b1;
    end
    else
        write_fin <= 1'b0;
end

// ============================================================================
// READ OPERATION 
// ============================================================================
always @(posedge clock) begin
    if (reset) begin
        read_ptr <= 'd0;
    end
    else if (read_ptr_inc) begin
         if(read_ptr == cycles_per_iact_col - 1'b1)
            read_ptr <= 'd0;
         else
            read_ptr <= read_ptr + 'd1;
    end
end

assign data_in_ready = 1'b1;
assign data_out = mem[read_ptr];
endmodule
