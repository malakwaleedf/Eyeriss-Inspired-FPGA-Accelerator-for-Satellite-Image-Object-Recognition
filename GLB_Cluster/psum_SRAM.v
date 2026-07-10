
module psum_SRAM_Bank #(
	parameter PSUM_SIZE = 20,
	parameter ADDRESS_SIZE = 5,
	parameter PSUM_SRAM_DEPTH = 16, // This must be equal to 2^(ADDRESS_SIZE)
	parameter WRITE_COUNT_SIZE = 5
) (
	input         								clock,
	input         								reset,
	input 										psum_read_address_initial,
	// data signals
	output        								psum_data_in_ready,
	input         								psum_data_in_valid,
	input 		signed 	[PSUM_SIZE-1:0] 		psum_data_in,
	
	input         								psum_data_out_ready,
	output	reg       							psum_data_out_valid,
	output	reg		signed 	[PSUM_SIZE-1:0] 	psum_data_out,
	
	// control signals
	input         								psum_write_en,
	input  				[ADDRESS_SIZE-1:0]  	psum_write_addr,
	output        								psum_write_done,
	
	input         								psum_read_en,
	input  				[ADDRESS_SIZE-1:0]  	psum_read_addr,
	output	reg									psum_read_done,
	
	input				[WRITE_COUNT_SIZE-1:0]	PSUM_DEPTH
);

// ===============================================================	//
// 					Signals & Buses 								//
// ================================================================	//
reg [WRITE_COUNT_SIZE-1:0] write_count; 

wire read_shake;
wire write_shake;
reg write_shake_reg; // needed to calculate write_done

reg [ADDRESS_SIZE-1:0] psum_read_address;
reg [ADDRESS_SIZE-1:0] psum_write_address;

reg signed [PSUM_SIZE-1:0] mem [0:PSUM_SRAM_DEPTH-1];

// ====================================================	//
//					Read Operation 						//
// ====================================================	//
assign read_shake = psum_read_en & psum_data_out_ready;
always @(posedge clock) begin
	if (reset) begin 
		psum_data_out_valid <= 1'd0; 
	end 
	else begin
		psum_data_out_valid <= read_shake; // 1 clock cycle later read data is ready 
	end
end
// read from memory
always @(posedge clock) begin
	if (read_shake) begin
		psum_data_out <= mem[psum_read_addr];
	end
end

// read done logic
always @(posedge clock) begin
	if (reset) begin
		psum_read_done <= 1'b0;
	end
	else if(psum_data_out_valid & !psum_read_en) begin
		// high for 1 clock cycle when read operation finishes 
		psum_read_done <= 1'b1;
	end
	else begin
		psum_read_done <= 1'b0;
	end
end

// ====================================================	//
//					Write Operation		 				//
// ====================================================	//
assign write_shake = psum_write_en & psum_data_in_valid; // BRAM write enable
assign psum_data_in_ready = psum_write_en;
// write address
always @(posedge clock) begin // // i am not sure if it needs fixing
	if(reset) begin
		psum_write_address <= 0;
	end
	else if (write_shake & !psum_write_done) begin // // write_done done included 
		psum_write_address <= psum_write_address + 1'b1; // inc write address 
	end
	
end
// write in memory
always @(posedge clock) begin
	if (write_shake) begin
		mem [psum_write_address] <= psum_data_in;
	end
end

assign psum_write_done = (write_count == PSUM_DEPTH); // // diff logic for write_done
always @(posedge clock) begin
	if (reset) begin 
		write_count <= 'd0; 
	end 
	else if (psum_write_done) begin 
		write_count <= 'd0;
	end 
	else if (write_shake) begin 
		write_count <= write_count + 'd1;
	end
end

endmodule

