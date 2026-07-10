module local_reset(
input clock,
input global_reset,
input rearrange_col_done,

output reg local_reset
);


always @(posedge clock) begin
    if (global_reset) begin
        local_reset <= 'd1;
    end
    else if (rearrange_col_done) begin
        local_reset <= 'd1;
    end
    else begin
        local_reset <= 'd0;
    end
end
endmodule