module Psum_Router #(
	parameter PSUM_SIZE = 20
) (
	// source ports
	output       						PE_data_in_ready,
	input         						PE_data_in_valid,
	input	signed 	[PSUM_SIZE-1:0] 	PE_data_in,
	
	// destination ports
	input          						GLB_out_ready,
	output        					GLB_out_valid,
	output 	signed 	[PSUM_SIZE-1:0]		GLB_out
);

// output in_ready signals
assign PE_data_in_ready = GLB_out_ready;
assign GLB_out_valid = PE_data_in_valid;
assign GLB_out = PE_data_in;

endmodule