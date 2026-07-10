module rearrange #(
    parameter PSUM_WIDTH = 20,  // accumulator / psum chain bitwidth
	// for largest conv (filter size = 9) #iacts/clsuter = 16 * 12 = 192 -> 256
	parameter IACT_SRAM_ADDRESS_SIZE = 8,
	parameter ADDRESS_SIZE = 5,
	parameter PSUM_SRAM_DEPTH = 32, // This must be equal to 2^(ADDRESS_SIZE)
    parameter PSUM_WRITE_COUNT_SIZE = 5,
	parameter REARANGE_MEM_DEPTH = 1024,
	parameter CLUSTER_GROUPS = 16,
	parameter PE_COL = 4 
)
(input clock,
input reset,
input [4:0] cycles_per_iact_col,

input glb_write_done_cluster_0,
input glb_write_done_cluster_1,
input glb_write_done_cluster_2,
input glb_write_done_cluster_3,
input glb_write_done_cluster_4,
input glb_write_done_cluster_5,
input glb_write_done_cluster_6,
input glb_write_done_cluster_7,
input glb_write_done_cluster_8,
input glb_write_done_cluster_9,
input glb_write_done_cluster_10,
input glb_write_done_cluster_11,
input glb_write_done_cluster_12,
input glb_write_done_cluster_13,
input glb_write_done_cluster_14,
input glb_write_done_cluster_15,

output reg [2:0] glb_counter,
output reg [4:0] cluster_counter,
output reg [4:0] glb_read_idx_counter,

input pixel_in_valid,
input signed [PSUM_WIDTH-1:0] pixel_in_data,
output pixel_in_ready,

output reg output_pixel_valid,
output reg signed [PSUM_WIDTH-1 : 0] output_pixel_data,
input output_pixel_ready,


output [ADDRESS_SIZE-1:0] psum_glb_read_address,
output reg psum_read_address_initial,

input read_done_from_dram, 
output reg rearrange_col_done
);

reg signed [PSUM_WIDTH-1:0] mem [0:REARANGE_MEM_DEPTH-1];

reg [10:0] internal_write_address;
reg [10:0] internal_read_address; 

wire write_shake;
wire read_shake;

reg cluster_inc;
reg glb_read_idx_inc;

reg glb_write_done_cluster_0_reg;
reg glb_write_done_cluster_1_reg;
reg glb_write_done_cluster_2_reg;
reg glb_write_done_cluster_3_reg;
reg glb_write_done_cluster_4_reg;
reg glb_write_done_cluster_5_reg;
reg glb_write_done_cluster_6_reg;
reg glb_write_done_cluster_7_reg;
reg glb_write_done_cluster_8_reg;
reg glb_write_done_cluster_9_reg;
reg glb_write_done_cluster_10_reg;
reg glb_write_done_cluster_11_reg;
reg glb_write_done_cluster_12_reg;
reg glb_write_done_cluster_13_reg;
reg glb_write_done_cluster_14_reg;
reg glb_write_done_cluster_15_reg;


assign psum_glb_read_address = glb_read_idx_counter;
assign glb_write_done_all = glb_write_done_cluster_15_reg;

assign write_shake = pixel_in_ready & pixel_in_valid; // write in rearrange
assign read_shake = output_pixel_ready & output_pixel_valid; // read from rearrange
assign pixel_in_ready = glb_write_done_all ? 1:0;

always @ (posedge clock) begin 
	if (reset) begin
		glb_write_done_cluster_0_reg<= 0;
		glb_write_done_cluster_1_reg<= 0;
		glb_write_done_cluster_2_reg<= 0;
		glb_write_done_cluster_3_reg<= 0;
		glb_write_done_cluster_4_reg<= 0;
		glb_write_done_cluster_5_reg<= 0;
		glb_write_done_cluster_6_reg<= 0;
		glb_write_done_cluster_7_reg<= 0;
		glb_write_done_cluster_8_reg<= 0;
		glb_write_done_cluster_9_reg<= 0;
		glb_write_done_cluster_10_reg<= 0;
		glb_write_done_cluster_11_reg<= 0;
		glb_write_done_cluster_12_reg<= 0;
		glb_write_done_cluster_13_reg<= 0;
		glb_write_done_cluster_14_reg<= 0;
		glb_write_done_cluster_15_reg<= 0;
	end 
	else begin 
		if (glb_write_done_cluster_0 == 1) begin
			glb_write_done_cluster_0_reg <= 1;
		end 
		if (glb_write_done_cluster_1 == 1) begin
			glb_write_done_cluster_1_reg<= 1;
		end 		
		if (glb_write_done_cluster_2 == 1) begin
			glb_write_done_cluster_2_reg<= 1;
		end 
		if (glb_write_done_cluster_3 == 1) begin
			glb_write_done_cluster_3_reg<= 1;
		end 
		if (glb_write_done_cluster_4_reg == 1) begin
			glb_write_done_cluster_4_reg<= 1;
		end 
		if (glb_write_done_cluster_5 == 1) begin
			glb_write_done_cluster_5_reg<= 1;
		end 
		if (glb_write_done_cluster_6 == 1) begin
			glb_write_done_cluster_6_reg<= 1;
		end 
		if (glb_write_done_cluster_7 == 1) begin
			glb_write_done_cluster_7_reg<= 1;
		end 
		if (glb_write_done_cluster_8 == 1) begin
			glb_write_done_cluster_8_reg<= 1;
		end 
		if (glb_write_done_cluster_9 == 1) begin
			glb_write_done_cluster_9_reg<= 1;
		end 
		if (glb_write_done_cluster_10 == 1) begin
			glb_write_done_cluster_10_reg<= 1;
		end 
		if (glb_write_done_cluster_11 == 1) begin
			glb_write_done_cluster_11_reg<= 1;
		end 
		if (glb_write_done_cluster_12 == 1) begin
			glb_write_done_cluster_12_reg<= 1;
		end 
		if (glb_write_done_cluster_13 == 1) begin
			glb_write_done_cluster_13_reg<= 1;
		end 
		if (glb_write_done_cluster_14 == 1) begin
			glb_write_done_cluster_14_reg<= 1;
		end 
		if (glb_write_done_cluster_15 == 1) begin
			glb_write_done_cluster_15_reg<= 1;
		end 
	end 
end 

// psum slot counter
always @(posedge clock) begin
	if (reset) begin
		glb_read_idx_counter <= 0;
	end 
	else if (glb_read_idx_counter == cycles_per_iact_col) begin
		glb_read_idx_counter <= 0;
	end	
	else if (glb_read_idx_inc && glb_write_done_all) begin
		glb_read_idx_counter <= glb_read_idx_counter+1;
	end
end

// GLB counter
always @(posedge clock) begin
	if (reset) begin
		glb_counter <= 0;
	end 
	else if (glb_counter == PE_COL) begin
		glb_counter <= 0;
	end
	else if (write_shake && glb_write_done_all) begin
		glb_counter <= glb_counter + 1;
	end 
end

always @(posedge clock) begin
	if (reset) begin 
		cluster_inc <= 0;
	end 
	else if (cluster_inc) begin
		cluster_inc <= 0;
	end 
	else if (glb_counter == PE_COL -'d1) begin
		cluster_inc <= 1;
	end
end

// cluster groupt counter
always @(posedge clock) begin
	if (reset) begin
		cluster_counter <= 0;
	end 
	else if (cluster_counter == CLUSTER_GROUPS) begin
		cluster_counter <= 0;
	end
	else if (cluster_inc && glb_write_done_all) begin
		cluster_counter <= cluster_counter + 1;
	end 
end

always @(posedge clock) begin
	if (reset) begin 
		glb_read_idx_inc <= 0;
	end 
	else if (glb_read_idx_inc) begin 
		glb_read_idx_inc <= 0;
	end 
	else if (cluster_inc && (cluster_counter == CLUSTER_GROUPS -'d1)) begin
		glb_read_idx_inc <= 1;
	end 
	else if (cluster_inc && glb_write_done_all) begin
		glb_read_idx_inc <= 0;
	end
end


always @(posedge clock) begin
	if (reset) begin 
		internal_write_address <= 0;
	end 
	else if (internal_write_address == REARANGE_MEM_DEPTH) begin
		internal_write_address <= 0;
	end 
	else if (write_shake && !(glb_counter == PE_COL)) begin
		internal_write_address <= internal_write_address + 1;
	end 
	else internal_write_address <= internal_write_address;
end

integer i;
always @(posedge clock) begin
	if (reset) begin 
		for (i= 0; i < REARANGE_MEM_DEPTH; i = i+1 ) begin 
			mem[i] <= 'd0;
		end
	end 
	else if (write_shake) begin
		mem [internal_write_address] <= pixel_in_data;
	end
end 

always @(posedge clock) begin 
	if (reset) begin 
		psum_read_address_initial <=0;
	end
	else if (read_done_from_dram) begin 
		psum_read_address_initial <= 1;
	end 
	else begin
		psum_read_address_initial <= psum_read_address_initial;
	end 
end 

always @(posedge clock) begin 
	if (reset) begin 
		output_pixel_data <=0;
		output_pixel_valid <=0;
		internal_read_address <=0;
	end
	else if (output_pixel_ready) begin 
		output_pixel_valid <= 1;
		output_pixel_data <= mem [internal_read_address];
	end 
end 

always @(posedge clock) begin
	if (reset) begin 
		internal_read_address <= 0;
	end 
	else if (internal_read_address == REARANGE_MEM_DEPTH-1 ) begin
		internal_read_address <= 0;
	end 
	else if (read_shake) begin
		internal_read_address <= internal_read_address+1;
	end 
	else internal_read_address <= internal_read_address;
end

always @(posedge clock) begin 
	if (reset) begin 
		rearrange_col_done <= 0;
	end 
	else if (internal_write_address == 'd1024) begin
		rearrange_col_done <= 1;
		glb_write_done_cluster_15_reg <= 0;
	end
	else if (rearrange_col_done) begin
		rearrange_col_done <= 'd0;
	end
end 

endmodule