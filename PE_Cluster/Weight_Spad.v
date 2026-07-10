module weight_spad #(
    parameter WEIGHT_WIDTH  = 8,
    parameter CLUSTER_ROWS  = 9     // physical rows (max)
)(
    input                               clock,
    input                               reset,

    // Write port — driven by Zero_Recovery, once per column pass
    // Writes are sequential: slot 0, 1, 2, ... FILTER_SIZE-1 (no address needed)
    input                               write_en,
    input        signed [WEIGHT_WIDTH-1:0]       data_in,        // {is_zero, weight_val}
    input                               data_in_valid,
    output                              data_in_ready,
    output reg                          write_fin,      // pulses when last active row written
    input [$clog2(WEIGHT_WIDTH):0] read_address,
    input [$clog2(WEIGHT_WIDTH):0] filter_size,
    // Read port — combinatorial, addressed by pe_row index
    output       signed [WEIGHT_WIDTH-1:0]       data_out        // {is_zero, weight_val}
);

// ============================================================================
// Local parameters
// ============================================================================
wire [$clog2(CLUSTER_ROWS)-1:0] last_row;
assign  last_row = filter_size - 1'b1;

// ============================================================================
// Register file — CLUSTER_ROWS slots (only FILTER_SIZE slots are active)
// ============================================================================
reg signed [WEIGHT_WIDTH-1:0] mem [0:CLUSTER_ROWS-1];

// ============================================================================
// Internal sequential write pointer
// ============================================================================
reg [$clog2(CLUSTER_ROWS)-1:0] write_ptr;
wire data_in_shake;
wire last_write;
assign data_in_shake = data_in_ready & data_in_valid & write_en;
assign last_write    =  (write_ptr == last_row);
integer i;
//
// Write pointer: increments on each accepted write, resets after last slot

always @(posedge clock) begin
    if (reset)
        write_ptr <= {$clog2(CLUSTER_ROWS){1'b0}};  
    else if (last_write)
        write_ptr <= {$clog2(CLUSTER_ROWS){1'b0}};
    else if (data_in_shake)
        write_ptr <= write_ptr + 1'b1;
end

// write_fin: pulses the cycle after the last active slot is written
always @(posedge clock) begin
    if (reset)
        write_fin <= 1'b0;
    else
        write_fin <= last_write;
end

// Sequential write using the internal pointer
always @(posedge clock) begin
    if (reset) begin
        for (i = 0; i < CLUSTER_ROWS; i = i + 1)
            mem[i] <= {WEIGHT_WIDTH{1'b0}};
    end
    else if (data_in_shake) begin
        mem[write_ptr] <= data_in;
    end
end

// Read — purely combinatorial
// Inactive rows (>= FILTER_SIZE) return is_zero=1, val=0 automatically
// because they are never written and initialized to 0
assign data_out      = mem[read_address];
assign data_in_ready = 1'b1;

endmodule