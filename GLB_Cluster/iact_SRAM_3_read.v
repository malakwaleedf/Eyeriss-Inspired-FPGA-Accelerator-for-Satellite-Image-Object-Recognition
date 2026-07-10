module iact_SRAM #(
	parameter IACT_SIZE = 8, // iact precision (from DOTA dataset)

	parameter IACT_SRAM_DEPTH = 256, // iact GLB depth 
	// for largest conv (filter size = 9) #iacts/clsuter = 16 * 12 = 192 -> 256
	parameter IACT_SRAM_ADDRESS_SIZE = 8	
) (
	input									clock,
	input									reset,
	// data signals
	output									data_in_ready,
	input	reg								data_in_valid,
	input		signed [IACT_SIZE-1 : 0]			data_in,

	// router 0 ports
	input									data_out_ready_0,
	output	reg								data_out_valid_0,
	output	reg	signed [IACT_SIZE-1 : 0]			data_out_0,
	// router 1 ports
	input									data_out_ready_1,
	output	reg								data_out_valid_1,
	output	reg	signed [IACT_SIZE-1 : 0]			data_out_1,
	// rounter 2 ports
	input									data_out_ready_2,
	output	reg								data_out_valid_2,
	output	reg	signed [IACT_SIZE-1 : 0]			data_out_2,
	
	// control signals
	input										write_en, // enables write
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	write_addr, // initial write address
	output	reg									write_done, // flags the end of write operation
	output  reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]  write_address,

	// router 0 controls
	input										read_en_0, // enables read from port 0
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	read_addr_0, // initial read address
	output	reg									read_done_0, // flags the end of read operation
	// router 1 controls
	input										read_en_1, // enables read from port 1
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	read_addr_1, // initial read address
	output	reg									read_done_1, // flags the end of read operation
	// router 2 controls
	input										read_en_2, // enables read from port 2
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	read_addr_2, // initial read address
	output	reg									read_done_2 // flags the end of read operation
);

// ====================================================	//
//				Signals & Buses							//
// ====================================================	//
wire read_shake_0;
wire read_shake_1;
wire read_shake_2;

wire write_shake;
reg	write_shake_reg; // needed to calculate write_done

reg [IACT_SRAM_ADDRESS_SIZE-1 : 0] read_address_0;
reg [IACT_SRAM_ADDRESS_SIZE-1 : 0] read_address_1;
reg [IACT_SRAM_ADDRESS_SIZE-1 : 0] read_address_2;

reg signed [IACT_SIZE-1 : 0] mem [0 : IACT_SRAM_DEPTH-1];

// ====================================================	//
//				Read Operation for rounter 0			//
// ====================================================	//
assign read_shake_0 = read_en_0 & data_out_ready_0;
// read data valid
always @(posedge clock) begin
	if (reset) begin 
		data_out_valid_0 <= 1'd0; 
	end 
	else begin
		data_out_valid_0 <= read_shake_0; 
	end
end
// read from memory
always @(posedge clock) begin
	if (read_shake_0) begin
		data_out_0 <= mem [read_address_0];
	end
end
// read address
always @(posedge clock) begin
	if(reset) begin
		read_address_0 <= 'd0; // reset read address 
	end
	else if (read_shake_0) begin
		read_address_0 <= read_address_0 + 1'b1; // inc read address 
	end
	else if (!read_en_0) begin
		read_address_0 <= read_addr_0; // set to initial read address 
	end
end
// read done logic
always @(posedge clock) begin
	if (reset) begin
		read_done_0 <= 1'b0;
	end
	else if(data_out_valid_0 & !read_en_0) begin
		// high for 1 clock cycle when read operation finishes 
		read_done_0 <= 1'b1;
	end
	else begin
		read_done_0 <= 1'b0;
	end
end

// ====================================================	//
//				Read Operation for rounter 1			//
// ====================================================	//
assign read_shake_1 = read_en_1 & data_out_ready_1; // BRAM read enable 
// read data valid
always @(posedge clock) begin
	if (reset) begin 
		data_out_valid_1 <= 1'd0; 
	end 
	else begin
		data_out_valid_1 <= read_shake_1; // 1 clock cycle later read data is ready 
	end
end
// read from memory
always @(posedge clock) begin
	if (read_shake_1) begin
		data_out_1 <= mem [read_address_1];
	end
end
// read address
always @(posedge clock) begin
	if(reset) begin
		read_address_1 <= 'd0; // reset read address 
	end
	else if (read_shake_1) begin
		read_address_1 <= read_address_1 + 1'b1; // inc read address 
	end
	else if (!read_en_1) begin
		read_address_1 <= read_addr_1; // set to initial read address 
	end
end
// read done logic
always @(posedge clock) begin
	if (reset) begin
		read_done_1 <= 1'b0;
	end
	else if(data_out_valid_1 & !read_en_1) begin
		// high for 1 clock cycle when read operation finishes 
		read_done_1 <= 1'b1;
	end
	else begin
		read_done_1 <= 1'b0;
	end
end

// ====================================================	//
//				Read Operation for rounter 2			//
// ====================================================	//
assign read_shake_2 = read_en_2 & data_out_ready_2; // BRAM read enable 
// read data valid
always @(posedge clock) begin
	if (reset) begin 
		data_out_valid_2 <= 1'd0; 
	end 
	else begin
		data_out_valid_2 <= read_shake_2; // 1 clock cycle later read data is ready 
	end
end
// read from memory
always @(posedge clock) begin
	if (read_shake_2) begin
		data_out_2 <= mem [read_address_2];
	end
end
// read address
always @(posedge clock) begin
	if(reset) begin
		read_address_2 <= 'd0; // reset read address 
	end
	else if (read_shake_2) begin
		read_address_2 <= read_address_2 + 1'b1; // inc read address 
	end
	else if (!read_en_2) begin
		read_address_2 <= read_addr_2; // set to initial read address 
	end
end
// read done logic
always @(posedge clock) begin
	if (reset) begin
		read_done_2 <= 1'b0;
	end
	else if(data_out_valid_2 & !read_en_2) begin
		// high for 1 clock cycle when read operation finishes 
		read_done_2 <= 1'b1;
	end
	else begin
		read_done_2 <= 1'b0;
	end
end

// ====================================================	//
//				Write Operation		 					//
// ====================================================	//
assign write_shake = write_en & data_in_valid; 
assign data_in_ready = write_en;
// write address
always @(posedge clock) begin 
	if(reset) begin
		write_address <= 0; // reset write address 
	end
	else if (write_shake) begin
		write_address <= write_address + 1'b1; // inc write address 
	end
	else if (!write_en) begin
		write_address <= write_addr; // set to initial write address 
	end
end
// write in memory
always @(posedge clock) begin
	if (write_shake) begin
		mem [write_address] <= data_in;
	end
end
// write done logic
always @(posedge clock) begin
	if (reset) begin
		write_shake_reg <= 1'b0;
	end
	else begin
		write_shake_reg <= write_shake; // to check write signals history
	end
end
always @(posedge clock) begin
	if (reset) begin
		write_done <= 1'b0;
	end
	else if(write_shake_reg & !write_en) begin 
		// high for 1 clock cycle when write operation finishes 
		write_done <= 1'b1;
	end
	else begin
		write_done <= 1'b0;
	end
end

endmodule
