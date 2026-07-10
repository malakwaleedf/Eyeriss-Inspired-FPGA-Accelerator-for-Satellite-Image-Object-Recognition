module GLB_CLUSTER#(
	parameter IACT_SIZE = 8, // iact precision (from DOTA dataset)

	parameter IACT_SRAM_DEPTH = 256, // iact GLB depth 
	// for largest conv (filter size = 9) #iacts/clsuter = 16 * 12 = 192 -> 256
	parameter IACT_SRAM_ADDRESS_SIZE = 8,	
	parameter WEIGHT_SIZE = 8, // weight precision
	parameter WEIGHT_SRAM_DEPTH = 256, // weight GLB depth
	parameter WEIGHT_SRAM_ADDRESS_SIZE = 8,
	parameter PSUM_SIZE = 20,
	parameter ADDRESS_SIZE = 5,
	parameter PSUM_SRAM_DEPTH = 16, // This must be equal to 2^(ADDRESS_SIZE)
    parameter PSUM_WRITE_COUNT_SIZE = 5
) (
    input wire clk,
    input wire rst,

    //##################################################################
    //                    IACT SRAM ports
    //##################################################################
    // data signals
	output									IACT_data_in_ready,
	input	 								IACT_data_in_valid,
	input		signed [IACT_SIZE-1 : 0]			IACT_data_in,

	// router 0 ports
	input									IACT_data_out_ready_0,
	output	 								IACT_data_out_valid_0,
	output	 	signed [IACT_SIZE-1 : 0]			IACT_data_out_0,
	// router 1 ports
	input									IACT_data_out_ready_1,
	output	 								IACT_data_out_valid_1,
	output	 	signed [IACT_SIZE-1 : 0]			IACT_data_out_1,
	// rounter 2 ports
	input									IACT_data_out_ready_2,
	output	 								IACT_data_out_valid_2,
	output	 	signed [IACT_SIZE-1 : 0]			IACT_data_out_2,
	
	// control signals
    output      [IACT_SRAM_ADDRESS_SIZE-1 : 0]  IACT_write_address,
	input										IACT_write_en, // enables write
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	IACT_write_addr, // initial write address
	output	 									IACT_write_done, // flags the end of write operation

	// router 0 controls
	input										IACT_read_en_0, // enables read from port 0
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	IACT_read_addr_0, // initial read address
	output	 									IACT_read_done_0, // flags the end of read operation
	// router 1 controls
	input										IACT_read_en_1, // enables read from port 1
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	IACT_read_addr_1, // initial read address
	output	 									IACT_read_done_1, // flags the end of read operation
	// router 2 controls
	input										IACT_read_en_2, // enables read from port 2
	input		[IACT_SRAM_ADDRESS_SIZE-1 : 0]	IACT_read_addr_2, // initial read address
	output	 									IACT_read_done_2, // flags the end of read operation

    //#################################################################
    //                    PSUM COLUMN 0 SRAM ports
    //#################################################################
    // data signals
    input                                       psum0_read_address_initial,
	output         							    psum0_data_in_ready,
	input         								psum0_data_in_valid,
	input 		signed 	[PSUM_SIZE - 1:0] 		psum0_data_in,
	
	input         								psum0_data_out_ready,
	output         							    psum0_data_out_valid,
	output 	 	signed 	[PSUM_SIZE - 1:0] 		psum0_data_out,
	
	// control signals
	input         								psum0_write_en,
	input  				[ADDRESS_SIZE - 1:0]  	psum0_write_addr,
	output         							psum0_write_done,
	
	output 	                                        psum0_read_done,
	input         								      psum0_read_en,
	input  				[ADDRESS_SIZE - 1:0]  	      psum0_read_addr,
	input				[PSUM_WRITE_COUNT_SIZE - 1:0] psum0_PSUM_DEPTH, 

    //#################################################################
    //                    PSUM COLUMN 1 SRAM ports
    //#################################################################
    // data signals
    input                                       psum1_read_address_initial,
    output         							psum1_data_in_ready,
    input         								psum1_data_in_valid,
    input 		signed 	[PSUM_SIZE - 1:0] 		psum1_data_in,
    
    input         								psum1_data_out_ready,
    output         							psum1_data_out_valid,
    output 	 	signed 	[PSUM_SIZE - 1:0] 		psum1_data_out,
    
    // control signals
    input         								psum1_write_en,
    input  				[ADDRESS_SIZE - 1:0]  	psum1_write_addr,
    output         							psum1_write_done,

    output 	 									        psum1_read_done,
	input         								        psum1_read_en,
	input  				[ADDRESS_SIZE - 1:0]  	        psum1_read_addr,
	input				[PSUM_WRITE_COUNT_SIZE - 1:0]   psum1_PSUM_DEPTH,

    //#################################################################
    //                    PSUM COLUMN 2 SRAM ports
    //#################################################################
    // data signals
    input                                       psum2_read_address_initial,
    output         							psum2_data_in_ready,
    input         								psum2_data_in_valid,
    input 		signed 	[PSUM_SIZE - 1:0] 		psum2_data_in,
    
    input         								psum2_data_out_ready,
    output         							psum2_data_out_valid,
    output 	 	signed 	[PSUM_SIZE - 1:0] 		psum2_data_out,
    
    // control signals
    input         								psum2_write_en,
    input  				[ADDRESS_SIZE - 1:0]  	psum2_write_addr,
    output         							psum2_write_done,

    output 	                                          psum2_read_done,
    input                                               psum2_read_en,
    input  				[ADDRESS_SIZE - 1:0]  	        psum2_read_addr,
    input				[PSUM_WRITE_COUNT_SIZE - 1:0]   psum2_PSUM_DEPTH,

    //#################################################################
    //                    PSUM COLUMN 3 SRAM ports
    //#################################################################
    //data signals
    input                                       psum3_read_address_initial,
    output            							psum3_data_in_ready,
    input         								psum3_data_in_valid,
    input 		signed 	[PSUM_SIZE - 1:0] 		psum3_data_in,
    
    input         								psum3_data_out_ready,
    output         							psum3_data_out_valid,
    output 	 	signed 	[PSUM_SIZE - 1:0] 		psum3_data_out,
    
    // control signals
    input         								psum3_write_en,
    input  				[ADDRESS_SIZE - 1:0]  	psum3_write_addr,
    output         							psum3_write_done,
    
    output 	 									        psum3_read_done,
    input         								        psum3_read_en,
    input  				[ADDRESS_SIZE - 1:0]  	        psum3_read_addr,
    input				[PSUM_WRITE_COUNT_SIZE - 1:0]   psum3_PSUM_DEPTH
);

//#################################################################
//                    iact GLB instantiation
//#################################################################

iact_SRAM #(
	.IACT_SIZE(IACT_SIZE), 
	.IACT_SRAM_DEPTH (IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE (IACT_SRAM_ADDRESS_SIZE)
) iact_sram (
	.clock(clk),
	.reset(rst),

	// data signals
    .write_address(IACT_write_address),
	.data_in_ready(IACT_data_in_ready),
	.data_in_valid(IACT_data_in_valid),
	.data_in(IACT_data_in), // [IACT_SIZE-1 : 0]

	// router 0 ports
	.data_out_ready_0(IACT_data_out_ready_0),
	.data_out_valid_0(IACT_data_out_valid_0),
	.data_out_0(IACT_data_out_0), //[IACT_SIZE-1 : 0]
	// router 1 ports
	.data_out_ready_1(IACT_data_out_ready_1),
	.data_out_valid_1(IACT_data_out_valid_1),
	.data_out_1(IACT_data_out_1), // [IACT_SIZE-1 : 0]
	// rounter 2 ports
	.data_out_ready_2(IACT_data_out_ready_2),
	.data_out_valid_2(IACT_data_out_valid_2),
	.data_out_2(IACT_data_out_2), // [IACT_SIZE-1 : 0]
	
	// control signals
	.write_en(IACT_write_en), 
	.write_addr(IACT_write_addr), // [IACT_SRAM_ADDRESS_SIZE-1 : 0]
	.write_done(IACT_write_done), 

	// router 0 controls
	.read_en_0(IACT_read_en_0), 
	.read_addr_0(IACT_read_addr_0), // [IACT_SRAM_ADDRESS_SIZE-1 : 0]
	.read_done_0(IACT_read_done_0), 
	// router 1 controls
	.read_en_1(IACT_read_en_1), 
	.read_addr_1(IACT_read_addr_1), // [IACT_SRAM_ADDRESS_SIZE-1 : 0]
	.read_done_1(IACT_read_done_1),  
	// router 2 controls
	.read_en_2(IACT_read_en_2), 
	.read_addr_2(IACT_read_addr_2), // [IACT_SRAM_ADDRESS_SIZE-1 : 0]
	.read_done_2(IACT_read_done_2) 
);

//#################################################################
//                    psum GLB 0 instantiation
//#################################################################

psum_SRAM_Bank #(
    .PSUM_SIZE(PSUM_SIZE),
    .ADDRESS_SIZE(ADDRESS_SIZE),
    .PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH)
) psum_sram_bank_0 (
    .clock(clk),
    .reset(rst),
    .psum_data_in_ready(psum0_data_in_ready),
    .psum_data_in_valid(psum0_data_in_valid),
    .psum_read_address_initial(psum0_read_address_initial),
    .psum_data_in(psum0_data_in),
    .psum_data_out_ready(psum0_data_out_ready),
    .psum_data_out_valid(psum0_data_out_valid),
    .psum_data_out(psum0_data_out),
    .psum_write_en(psum0_write_en),
    .psum_write_addr(psum0_write_addr),
    .psum_write_done(psum0_write_done),
    .psum_read_done(psum0_read_done),
    .psum_read_en(psum0_read_en),
    .psum_read_addr(psum0_read_addr),
    .PSUM_DEPTH(psum0_PSUM_DEPTH)
);

//#################################################################
//                    psum GLB 1 instantiation
//#################################################################

psum_SRAM_Bank #(
    .PSUM_SIZE(PSUM_SIZE),
    .ADDRESS_SIZE(ADDRESS_SIZE),
    .PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH)
) psum_sram_bank_1 (
    .clock(clk),
    .reset(rst),
    .psum_data_in_ready(psum1_data_in_ready),
    .psum_data_in_valid(psum1_data_in_valid),
    .psum_read_address_initial(psum1_read_address_initial),
    .psum_data_in(psum1_data_in),
    .psum_data_out_ready(psum1_data_out_ready),
    .psum_data_out_valid(psum1_data_out_valid),
    .psum_data_out(psum1_data_out),
    .psum_write_en(psum1_write_en),
    .psum_write_addr(psum1_write_addr),
    .psum_write_done(psum1_write_done),
    .psum_read_done(psum1_read_done),
    .psum_read_en(psum1_read_en),
    .psum_read_addr(psum1_read_addr),
    .PSUM_DEPTH(psum1_PSUM_DEPTH)
);

//#################################################################
//                    psum GLB 2 instantiation
//#################################################################

psum_SRAM_Bank #(
    .PSUM_SIZE(PSUM_SIZE),
    .ADDRESS_SIZE(ADDRESS_SIZE),
    .PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH)
) psum_sram_bank_2 (
    .clock(clk),
    .reset(rst),
    .psum_data_in_ready(psum2_data_in_ready),
    .psum_data_in_valid(psum2_data_in_valid),
    .psum_read_address_initial(psum2_read_address_initial),
    .psum_data_in(psum2_data_in),
    .psum_data_out_ready(psum2_data_out_ready),
    .psum_data_out_valid(psum2_data_out_valid),
    .psum_data_out(psum2_data_out),
    .psum_write_en(psum2_write_en),
    .psum_write_addr(psum2_write_addr),
    .psum_write_done(psum2_write_done),
    .psum_read_done(psum2_read_done),
    .psum_read_en(psum2_read_en),
    .psum_read_addr(psum2_read_addr),
    .PSUM_DEPTH(psum2_PSUM_DEPTH)
);

//#################################################################
//                    psum GLB 3 instantiation
//#################################################################

psum_SRAM_Bank #(
    .PSUM_SIZE(PSUM_SIZE),
    .ADDRESS_SIZE(ADDRESS_SIZE),
    .PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH)
) psum_sram_bank_3 (
    .clock(clk),
    .reset(rst),
    .psum_data_in_ready(psum3_data_in_ready),
    .psum_data_in_valid(psum3_data_in_valid),
    .psum_read_address_initial(psum3_read_address_initial),
    .psum_data_in(psum3_data_in),
    .psum_data_out_ready(psum3_data_out_ready),
    .psum_data_out_valid(psum3_data_out_valid),
    .psum_data_out(psum3_data_out),
    .psum_write_en(psum3_write_en),
    .psum_write_addr(psum3_write_addr),
    .psum_write_done(psum3_write_done),
    .psum_read_done(psum3_read_done),
    .psum_read_en(psum3_read_en),
    .psum_read_addr(psum3_read_addr),
    .PSUM_DEPTH(psum3_PSUM_DEPTH)
);

endmodule
