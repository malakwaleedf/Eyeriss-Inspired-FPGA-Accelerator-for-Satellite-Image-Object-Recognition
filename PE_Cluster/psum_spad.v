module psum_spad #(
    parameter PSUM_WIDTH = 20,
    parameter SPAD_DEPTH = 16
)(
    input                           clock,
    input                           reset,
    // data signals
    input  signed [PSUM_WIDTH-1:0]  psum_data_in, // from PE core
    output signed [PSUM_WIDTH-1:0]  psum_data_out,
    // control signals
    input         [$clog2(SPAD_DEPTH) - 1:0]             write_idx,
    input                           pe_mode,
    input                           write_en,
    input                           read_inc, // increments read_idx when high
    input                           read_restart, // resets read_idx to 0 when high
    input [4:0]                     cycles_per_iact_col
);

reg signed [PSUM_WIDTH-1:0] spad_mem [0:SPAD_DEPTH-1]; // spad register file
reg [4:0] read_idx_counter; // read index counter for the spad (5-bit, matches cycles_per_iact_col)
reg  [$clog2(SPAD_DEPTH) - 1:0] stream_write_idx;

// assign stream_write_idx = write_restart ? 0 : write_idx;
integer i;
// Write operations (sequential)
always @(posedge clock) begin
    if(reset) begin
        for (i = 0; i < SPAD_DEPTH; i = i + 1)
            spad_mem[i] <= {PSUM_WIDTH{1'b0}};
    end
    else if (write_en & !pe_mode) begin
        spad_mem[write_idx] <= psum_data_in; // write to spad at write_idx
    end
    else if (write_en & pe_mode) begin
        spad_mem[stream_write_idx] <= psum_data_in; // write to spad at write_idx
    end
    else 
        spad_mem[write_idx] <= spad_mem[write_idx];
end

// Read counter, to compute read idex, increments read_inc is high
always @(posedge clock) begin
    if(reset) begin
        read_idx_counter <= 5'b0;
    end
    else if (read_restart) begin
        read_idx_counter <= 5'b0; // explicit restart takes priority
    end
    else if (read_inc) begin
        // wrap at cycles_per_iact_col so we never read an unwritten slot
        if (read_idx_counter == cycles_per_iact_col - 1'b1)
            read_idx_counter <= 5'b0;
        else
            read_idx_counter <= read_idx_counter + 1'b1;
    end
    else 
        read_idx_counter <= read_idx_counter;
end

always @(posedge clock) begin
    if(reset) begin
        stream_write_idx <= 5'b0;
    end
    else if (pe_mode & write_en) begin
        stream_write_idx <= stream_write_idx + 1'b1; // increment read index counter
    end
    else if ((stream_write_idx == cycles_per_iact_col)) begin
        stream_write_idx <= 5'b0; // wrap around to 0 after reaching max depth or if read_restart is high
    end
    else 
        stream_write_idx <= stream_write_idx;
end


// Read operations (combinatorial)
assign psum_data_out = spad_mem[read_idx_counter]; // read from spad at read_idx_counter

endmodule
