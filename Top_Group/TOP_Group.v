module TOP_Group 
#(
    parameter PE_NUM = 36,
    parameter ROW_NUM = 9,
    parameter IACT_WIDTH = 8,   // iact value bitwidth (INT8)
    parameter WEIGHT_WIDTH = 8, // weight value bitwidth (INT8)
    parameter PSUM_WIDTH = 20,  // accumulator / psum chain bitwidth
    parameter IACT_SPAD_DEPTH = 16, // depth of weight/iact spads (max # unique values per cluster per cycle)
    parameter PSUM_SPAD_DEPTH = 16, // depth of psum spad (max # partial sums per cluster per cycle)
    parameter WEIGHT_SPAD_DEPTH = 9,     // depth of weight spad (max # unique values per cluster per cycle)
    parameter CLUSTER_ROWS = 9, 

	parameter IACT_SRAM_DEPTH = 256, // iact GLB depth 
	// for largest conv (filter size = 9) #iacts/clsuter = 16 * 12 = 192 -> 256
	parameter IACT_SRAM_ADDRESS_SIZE = 8,
	parameter WEIGHT_SRAM_DEPTH = 256, // weight GLB depth
	parameter WEIGHT_SRAM_ADDRESS_SIZE = 8,
	parameter ADDRESS_SIZE = 5,
	parameter PSUM_SRAM_DEPTH = 32, // This must be equal to 2^(ADDRESS_SIZE)
    parameter PSUM_WRITE_COUNT_SIZE = 5
)(
    // top-level ports (passed directly to PE_cluster)
    input clock,
    input reset,
	output iact_dist_enable,
    input [2:0] top_filter_mode, // affects the number of working PEs, weight spad
	input [4:0] cycles_per_iact_col,
    input [3:0] weight_columns,
	input last_iact_column,
	output top_done_iact_column, // Sends signal to top to load next iact column
	output psum_GLB_write_done_from_glb_to_ctrl,

	// GLB cluster ports
	input psum0_read_address_initial_from_rearrange_to_glb,
	output psum0_read_done_from_glb_to_ctrl,
	input psum0_data_out_ready_from_router_to_glb,
	output psum0_data_out_valid_from_glb_to_router,
	output signed [PSUM_WIDTH - 1 : 0] psum0_data_out_from_glb_to_router,
	input [ADDRESS_SIZE - 1 : 0] psum0_read_addr_from_ctrl_to_glb,
	input psum0_read_en_from_ctrl_to_glb,
	input psum1_read_address_initial_from_rearrange_to_glb,
	output psum1_read_done_from_glb_to_ctrl,
	input psum1_data_out_ready_from_router_to_glb,
	output psum1_data_out_valid_from_glb_to_router,
	output signed [PSUM_WIDTH - 1 : 0] psum1_data_out_from_glb_to_router,
	input [ADDRESS_SIZE - 1 : 0] psum1_read_addr_from_ctrl_to_glb,
	input psum1_read_en_from_ctrl_to_glb,
	input psum2_read_address_initial_from_rearrange_to_glb,
	output psum2_read_done_from_glb_to_ctrl,
	input psum2_data_out_ready_from_router_to_glb,
	output psum2_data_out_valid_from_glb_to_router,
	output signed [PSUM_WIDTH - 1 : 0] psum2_data_out_from_glb_to_router,
	input [ADDRESS_SIZE - 1 : 0] psum2_read_addr_from_ctrl_to_glb,
	input psum2_read_en_from_ctrl_to_glb,
	input psum3_read_address_initial_from_rearrange_to_glb,
	output psum3_read_done_from_glb_to_ctrl,
	input psum3_data_out_ready_from_router_to_glb,
	output psum3_data_out_valid_from_glb_to_router,
	output signed [PSUM_WIDTH - 1 : 0] psum3_data_out_from_glb_to_router,
	input [ADDRESS_SIZE - 1 : 0] psum3_read_addr_from_ctrl_to_glb,
	input psum3_read_en_from_ctrl_to_glb,
	output IACT_data_in_ready_from_glb_to_dram,
	input IACT_data_in_valid_from_dram_to_glb,
	input signed [IACT_WIDTH-1 : 0] IACT_data_in_from_dram_to_glb,
	output IACT_column_done_flag_from_ctrl_to_top,

	//	Weight router ports (1 per 3 rows)
	input [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_address_current_from_weight_glb_to_ctrl,
	output weight_GLB_write_en_from_ctrl_to_glb,
	output 	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_write_addr_from_ctrl_to_glb,
	input  weight_GLB_write_done_from_glb_to_ctrl,

	output weight_0_GLB_data_in_ready_from_router_to_weight_glb,
	input weight_0_GLB_data_in_valid_from_weight_glb_to_router,
	input signed [WEIGHT_WIDTH-1 : 0] weight_0_GLB_data_in_from_weight_glb_to_router,

	output weight_1_GLB_data_in_ready_from_router_to_weight_glb,
	input weight_1_GLB_data_in_valid_from_weight_glb_to_router,
	input signed [WEIGHT_WIDTH-1 : 0] weight_1_GLB_data_in_from_weight_glb_to_router,

	output weight_2_GLB_data_in_ready_from_router_to_weight_glb,
	input weight_2_GLB_data_in_valid_from_weight_glb_to_router,
	input signed [WEIGHT_WIDTH-1 : 0] weight_2_GLB_data_in_from_weight_glb_to_router,

	output 		weight_GLB_read_en_0_from_to_glb, // enables read from port 0
	output 	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_0_to_glb, // initial read address
	input	 		weight_GLB_read_done_0_from_glb, // flags the end of read operation

	output 		weight_GLB_read_en_1_from_to_glb, // enables read from port 1
	output 	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_1_to_glb, // initial read address
	input	 		weight_GLB_read_done_1_from_glb, // flags the end of read operation
	
	output 		weight_GLB_read_en_2_from_to_glb, // enables read from port 2
	output 	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_2_to_glb, // initial read address
	input	 		weight_GLB_read_done_2_to_glb, // flags the end of read operation

	input [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0] weight_GLB_read_address_0_current_from_weight_glb_to_ctrl,
	input [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0] weight_GLB_read_address_1_current_from_weight_glb_to_ctrl,
	input [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0] weight_GLB_read_address_2_current_from_weight_glb_to_ctrl,

	// controller ports
	input [2:0] top_input_mode, // size of ifmap 
	input turn_on,
	input [4:0] unique_values_per_cluster_per_cycle,
	input [7:0] unique_values_per_cluster,
	input [6:0] weight_values_per_filter,

	input iact_next_ofmap_col_from_ctrl_to_top


);

wire [3:0] weight_spad_index; // weight_column_counter
wire [3:0] psum_spad_write_index; // mac_done_counter

// PE Cluster Internal Signals
	wire top_load_PEs_weight_pe_from_ctrl_to_pe;
	wire top_done_PEs_weight_pe_from_pe_to_ctrl;
	wire top_load_PEs_iact_pe_from_ctrl_to_pe;
	wire top_done_PEs_iact_pe_from_pe_to_ctrl;
	wire top_mac_en_pe_from_ctrl_to_pe;
	wire mac_done_top_from_pe_to_ctrl;
	wire psum_stream_done_top_from_pe_to_ctrl;
	wire top_psum_stream_start_pe_from_ctrl_to_pe;
	wire top_PSUM_to_GLB_en_pe_from_ctrl_to_pe;
	wire PSUM_to_GLB_done_top_from_pe_to_ctrl;
	wire PE_mode_from_ctrl_to_pe;

	// finals psums to be stored in psum GLB
		wire final_psum_out_ready_glb0_from_glb_to_pe;
		wire final_psum_out_valid_glb0_from_pe_to_glb;
		wire signed[PSUM_WIDTH-1:0] final_psum_out_glb0_from_pe_to_glb;
		wire final_psum_out_ready_glb1_from_glb_to_pe;
		wire final_psum_out_valid_glb1_from_pe_to_glb;
		wire signed[PSUM_WIDTH-1:0] final_psum_out_glb1_from_pe_to_glb;
		wire final_psum_out_ready_glb2_from_glb_to_pe;
		wire final_psum_out_valid_glb2_from_pe_to_glb;
		wire signed[PSUM_WIDTH-1:0] final_psum_out_glb2_from_pe_to_glb;
		wire final_psum_out_ready_glb3_from_glb_to_pe;
		wire final_psum_out_valid_glb3_from_pe_to_glb;
		wire signed[PSUM_WIDTH-1:0] final_psum_out_glb3_from_pe_to_glb;

	// iact and weight data to be written to PEs inside spads
		wire PE00_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE00_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE00_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE01_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE01_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE01_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE02_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE02_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE02_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE03_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE03_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE03_iact_weight_data_from_router_to_pe_w0_i0;

		wire PE10_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE10_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE10_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE11_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE11_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE11_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE12_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE12_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE12_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE13_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE13_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE13_iact_weight_data_from_router_to_pe_w0_i0;

		wire PE20_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE20_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE20_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE21_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE21_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE21_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE22_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE22_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE22_iact_weight_data_from_router_to_pe_w0_i0;
		wire PE23_iact_weight_data_ready_from_pe_to_router_w0_i0;
		reg PE23_iact_weight_data_valid_from_router_to_pe_w0_i0;
		reg signed [IACT_WIDTH-1:0]  PE23_iact_weight_data_from_router_to_pe_w0_i0;

		wire PE30_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE30_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE30_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE31_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE31_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE31_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE32_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE32_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE32_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE33_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE33_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE33_iact_weight_data_from_router_to_pe_w1_i1;

		wire PE40_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE40_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE40_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE41_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE41_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE41_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE42_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE42_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE42_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE43_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE43_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE43_iact_weight_data_from_router_to_pe_w1_i1;

		wire PE50_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE50_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE50_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE51_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE51_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE51_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE52_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE52_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE52_iact_weight_data_from_router_to_pe_w1_i1;
		wire PE53_iact_weight_data_ready_from_pe_to_router_w1_i1;
		reg PE53_iact_weight_data_valid_from_router_to_pe_w1_i1;
		reg signed [IACT_WIDTH-1:0]  PE53_iact_weight_data_from_router_to_pe_w1_i1;

		wire PE60_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE60_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE60_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE61_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE61_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE61_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE62_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE62_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE62_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE63_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE63_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE63_iact_weight_data_from_router_to_pe_w2_i2;

		wire PE70_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE70_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE70_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE71_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE71_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE71_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE72_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE72_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE72_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE73_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE73_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE73_iact_weight_data_from_router_to_pe_w2_i2;

		wire PE80_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE80_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE80_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE81_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE81_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE81_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE82_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE82_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE82_iact_weight_data_from_router_to_pe_w2_i2;
		wire PE83_iact_weight_data_ready_from_pe_to_router_w2_i2;
		reg PE83_iact_weight_data_valid_from_router_to_pe_w2_i2;
		reg signed [IACT_WIDTH-1:0]  PE83_iact_weight_data_from_router_to_pe_w2_i2;


// GLB ports for iact glb
	wire IACT_data_out_ready_0_from_router_to_glb;
	wire IACT_data_out_valid_0_from_glb_to_router;
	wire signed [IACT_WIDTH-1 : 0] IACT_data_out_0_from_glb_to_router;

	wire IACT_data_out_ready_1_from_router_to_glb;
	wire IACT_data_out_valid_1_from_glb_to_router;
	wire signed [IACT_WIDTH-1 : 0] IACT_data_out_1_from_glb_to_router;

	wire IACT_data_out_ready_2_from_router_to_glb;
	wire IACT_data_out_valid_2_from_glb_to_router;
	wire signed [IACT_WIDTH-1 : 0] IACT_data_out_2_from_glb_to_router;

	wire [IACT_SRAM_ADDRESS_SIZE-1 : 0] IACT_write_address_from_glb_to_ctrl;
	wire IACT_write_en_from_ctrl_to_glb;
	wire [IACT_SRAM_ADDRESS_SIZE-1 : 0]	IACT_write_addr_from_ctrl_to_glb;
	wire IACT_write_done_from_glb_to_ctrl;

	wire IACT_read_en_from_ctrl_to_glb; //One read enable for all ports

	wire [IACT_SRAM_ADDRESS_SIZE-1 : 0] IACT_read_addr_0_from_ctrl_to_glb;
	wire IACT_read_done_0_from_glb_to_ctrl;

	
	wire [IACT_SRAM_ADDRESS_SIZE-1 : 0] IACT_read_addr_1_from_ctrl_to_glb;
	wire IACT_read_done_1_from_glb_to_ctrl;

	
	wire [IACT_SRAM_ADDRESS_SIZE-1 : 0] IACT_read_addr_2_from_ctrl_to_glb;
	wire IACT_read_done_2_from_glb_to_ctrl;

	//momken nehtag nezawedha ka input lel controller
	wire IACT_read_done_from_glb_to_ctrl = IACT_read_done_0_from_glb_to_ctrl & IACT_read_done_1_from_glb_to_ctrl & IACT_read_done_2_from_glb_to_ctrl; //Asserts when all ports are done reading
    wire [1:0] iact_weight_loading_mode_for_pe;
	

// GLB ports for psum glb
	wire psum_write_en_from_ctrl_to_glb;

	wire psum0_data_in_ready_from_glb_to_router;
	wire psum0_data_in_valid_from_router_to_glb;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_data_in_from_router_to_glb;

	wire psum0_write_en_from_ctrl_to_glb;
	wire [ADDRESS_SIZE - 1 : 0] psum_write_addr_from_ctrl_to_glb;
	wire psum0_write_done_from_glb_to_ctrl;
		
	
	wire [PSUM_WRITE_COUNT_SIZE - 1 : 0] psum_PSUM_DEPTH_from_ctrl_to_glb;

	wire psum1_data_in_ready_from_glb_to_router;
	wire psum1_data_in_valid_from_router_to_glb;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_data_in_from_router_to_glb;

	wire psum1_write_done_from_glb_to_ctrl;

	wire psum2_data_in_ready_from_glb_to_router;
	wire psum2_data_in_valid_from_router_to_glb;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_data_in_from_router_to_glb;

	wire psum2_write_en_from_ctrl_to_glb;
	wire psum2_write_done_from_glb_to_ctrl;

	wire psum3_data_in_ready_from_router_to_glb;
	wire psum3_data_in_valid_from_router_to_glb;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_data_in_from_router_to_glb;

	wire psum3_write_en_from_ctrl_to_glb;
	wire psum3_write_done_from_glb_to_ctrl;

// router control signals
	// iact routers
	wire   [1:0]   iact_0_data_in_sel_from_ctrl_to_router;
    wire   [2:0]   iact_0_data_out_sel_from_ctrl_to_router;
	wire   [3:0]   iact_0_PE_sel_from_ctrl_to_router;
	wire   [11:0]  iact_0_PE_choice_from_ctrl_to_router;
	wire   [2:0]   iact_0_Multicast_mode_from_ctrl_to_router;

    wire   [1:0]   iact_1_data_in_sel_from_ctrl_to_router;
    wire   [2:0]   iact_1_data_out_sel_from_ctrl_to_router;
	wire   [3:0]   iact_1_PE_sel_from_ctrl_to_router;
	wire   [11:0]  iact_1_PE_choice_from_ctrl_to_router;
	wire   [2:0]   iact_1_Multicast_mode_from_ctrl_to_router;

    wire   [1:0]   iact_2_data_in_sel_from_ctrl_to_router;
    wire   [2:0]   iact_2_data_out_sel_from_ctrl_to_router;
	wire   [3:0]   iact_2_PE_sel_from_ctrl_to_router;
	wire   [11:0]  iact_2_PE_choice_from_ctrl_to_router;
	wire   [2:0]   iact_2_Multicast_mode_from_ctrl_to_router;

	// weight routers (1 router per row)
	wire weight_0_data_in_sel_from_ctrl_to_router;
	wire [1:0] weight_0_data_out_sel_from_ctrl_to_router;

	wire weight_1_data_in_sel_from_ctrl_to_router;
	wire [1:0] weight_1_data_out_sel_from_ctrl_to_router;

	wire weight_2_data_in_sel_from_ctrl_to_router;
	wire [1:0] weight_2_data_out_sel_from_ctrl_to_router;

	// psum routers (1 router per column)
	wire [1:0] psum_0_data_in_sel_from_ctrl_to_router;
	wire [1:0] psum_0_data_out_sel_from_ctrl_to_router;
	
	wire [1:0] psum_1_data_in_sel_from_ctrl_to_router;
	wire [1:0] psum_1_data_out_sel_from_ctrl_to_router;
	
	wire [1:0] psum_2_data_in_sel_from_ctrl_to_router;
	wire [1:0] psum_2_data_out_sel_from_ctrl_to_router;

	wire [1:0] psum_3_data_in_sel_from_ctrl_to_router;
	wire [1:0] psum_3_data_out_sel_from_ctrl_to_router;

// iact router 0 
	wire iact_0_north_data_in_ready_dummy;
	wire iact_0_north_data_in_valid_from_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_0_north_dummy;

	wire iact_0_south_data_in_ready_dummy;
	wire iact_0_south_data_in_valid_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_0_south_data_in_dummy;

	wire iact_0_horiz_data_in_ready_dummy;
	wire iact_0_horiz_data_in_valid_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_0_horiz_data_in_dummy;

	// destination ports
	wire iact_0_PE_0_data_out_ready_from_pe_to_router;
	wire iact_0_PE_0_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_0_data_out_from_router_to_pe;

	wire iact_0_PE_1_data_out_ready_from_pe_to_router;
	wire iact_0_PE_1_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_1_data_out_from_router_to_pe;

	wire iact_0_PE_2_data_out_ready_from_pe_to_router;
	wire iact_0_PE_2_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_2_data_out_from_router_to_pe;

	wire iact_0_PE_3_data_out_ready_from_pe_to_router;
	wire iact_0_PE_3_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_3_data_out_from_router_to_pe;

	wire iact_0_PE_4_data_out_ready_from_pe_to_router;
	wire iact_0_PE_4_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_4_data_out_from_router_to_pe;

	wire iact_0_PE_5_data_out_ready_from_pe_to_router;
	wire iact_0_PE_5_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_5_data_out_from_router_to_pe;

	wire iact_0_PE_6_data_out_ready_from_pe_to_router;
	wire iact_0_PE_6_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_6_data_out_from_router_to_pe;

	wire iact_0_PE_7_data_out_ready_from_pe_to_router;
	wire iact_0_PE_7_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_7_data_out_from_router_to_pe;

	wire iact_0_PE_8_data_out_ready_from_pe_to_router;
	wire iact_0_PE_8_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_8_data_out_from_router_to_pe;

	wire iact_0_PE_9_data_out_ready_from_pe_to_router;
	wire iact_0_PE_9_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_9_data_out_from_router_to_pe;

	wire iact_0_PE_10_data_out_ready_from_pe_to_router;
	wire iact_0_PE_10_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_10_data_out_from_router_to_pe;

	wire iact_0_PE_11_data_out_ready_from_pe_to_router;
	wire iact_0_PE_11_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_0_PE_11_data_out_from_router_to_pe;

	wire iact_0_north_data_out_ready_dummy;
	wire iact_0_north_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_0_north_data_out_dummy;

	wire iact_0_south_data_out_ready_dummy;
	wire iact_0_south_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_0_south_data_out_dummy;

	wire iact_0_horiz_data_out_ready_dummy;
	wire iact_0_horiz_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_0_horiz_data_out_dummy;

// iact router 1
	wire iact_1_north_data_in_ready_dummy;
	wire iact_1_north_data_in_valid_from_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_1_north_dummy;

	wire iact_1_south_data_in_ready_dummy;
	wire iact_1_south_data_in_valid_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_1_south_data_in_dummy;

	wire iact_1_horiz_data_in_ready_dummy;
	wire iact_1_horiz_data_in_valid_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_1_horiz_data_in_dummy;

	// destination ports
	wire iact_1_PE_0_data_out_ready_from_pe_to_router;
	wire iact_1_PE_0_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_0_data_out_from_router_to_pe;

	wire iact_1_PE_1_data_out_ready_from_pe_to_router;
	wire iact_1_PE_1_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_1_data_out_from_router_to_pe;

	wire iact_1_PE_2_data_out_ready_from_pe_to_router;
	wire iact_1_PE_2_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_2_data_out_from_router_to_pe;

	wire iact_1_PE_3_data_out_ready_from_pe_to_router;
	wire iact_1_PE_3_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_3_data_out_from_router_to_pe;

	wire iact_1_PE_4_data_out_ready_from_pe_to_router;
	wire iact_1_PE_4_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_4_data_out_from_router_to_pe;

	wire iact_1_PE_5_data_out_ready_from_pe_to_router;
	wire iact_1_PE_5_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_5_data_out_from_router_to_pe;

	wire iact_1_PE_6_data_out_ready_from_pe_to_router;
	wire iact_1_PE_6_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_6_data_out_from_router_to_pe;

	wire iact_1_PE_7_data_out_ready_from_pe_to_router;
	wire iact_1_PE_7_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_7_data_out_from_router_to_pe;

	wire iact_1_PE_8_data_out_ready_from_pe_to_router;
	wire iact_1_PE_8_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_8_data_out_from_router_to_pe;

	wire iact_1_PE_9_data_out_ready_from_pe_to_router;
	wire iact_1_PE_9_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_9_data_out_from_router_to_pe;

	wire iact_1_PE_10_data_out_ready_from_pe_to_router;
	wire iact_1_PE_10_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_10_data_out_from_router_to_pe;

	wire iact_1_PE_11_data_out_ready_from_pe_to_router;
	wire iact_1_PE_11_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_1_PE_11_data_out_from_router_to_pe;

	wire iact_1_north_data_out_ready_dummy;
	wire iact_1_north_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_1_north_data_out_dummy;

	wire iact_1_south_data_out_ready_dummy;
	wire iact_1_south_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_1_south_data_out_dummy;

	wire iact_1_horiz_data_out_ready_dummy;
	wire iact_1_horiz_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_1_horiz_data_out_dummy;

// iact router 2
    // source ports
	wire iact_2_GLB_data_in_ready_from_router_to_glb;
	wire iact_2_GLB_data_in_valid_from_glb_to_router;
	wire signed[IACT_WIDTH - 1 : 0] iact_2_GLB_data_in_from_glb_to_router;

	wire iact_2_north_data_in_ready_dummy;
	wire iact_2_north_data_in_valid_from_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_2_north_data_in_from_dummy;

	wire iact_2_south_data_in_ready_dummy;
	wire iact_2_south_data_in_valid_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_2_south_data_in_dummy;

	wire iact_2_horiz_data_in_ready_dummy;
	wire iact_2_horiz_data_in_valid_dummy;
	wire signed [IACT_WIDTH-1:0]  iact_2_horiz_data_in_dummy;

	// destination ports
	wire iact_2_PE_0_data_out_ready_from_pe_to_router;
	wire iact_2_PE_0_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_0_data_out_from_router_to_pe;

	wire iact_2_PE_1_data_out_ready_from_pe_to_router;
	wire iact_2_PE_1_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_1_data_out_from_router_to_pe;

	wire iact_2_PE_2_data_out_ready_from_pe_to_router;
	wire iact_2_PE_2_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_2_data_out_from_router_to_pe;

	wire iact_2_PE_3_data_out_ready_from_pe_to_router;
	wire iact_2_PE_3_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_3_data_out_from_router_to_pe;

	wire iact_2_PE_4_data_out_ready_from_pe_to_router;
	wire iact_2_PE_4_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_4_data_out_from_router_to_pe;

	wire iact_2_PE_5_data_out_ready_from_pe_to_router;
	wire iact_2_PE_5_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_5_data_out_from_router_to_pe;

	wire iact_2_PE_6_data_out_ready_from_pe_to_router;
	wire iact_2_PE_6_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_6_data_out_from_router_to_pe;

	wire iact_2_PE_7_data_out_ready_from_pe_to_router;
	wire iact_2_PE_7_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_7_data_out_from_router_to_pe;

	wire iact_2_PE_8_data_out_ready_from_pe_to_router;
	wire iact_2_PE_8_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_8_data_out_from_router_to_pe;

	wire iact_2_PE_9_data_out_ready_from_pe_to_router;
	wire iact_2_PE_9_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_9_data_out_from_router_to_pe;

	wire iact_2_PE_10_data_out_ready_from_pe_to_router;
	wire iact_2_PE_10_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_10_data_out_from_router_to_pe;

	wire iact_2_PE_11_data_out_ready_from_pe_to_router;
	wire iact_2_PE_11_data_out_valid_from_router_to_pe;
	wire signed [IACT_WIDTH-1:0]   iact_2_PE_11_data_out_from_router_to_pe;

	wire iact_2_north_data_out_ready_dummy;
	wire iact_2_north_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_2_north_data_out_dummy;

	wire iact_2_south_data_out_ready_dummy;
	wire iact_2_south_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_2_south_data_out_dummy;

	wire iact_2_horiz_data_out_ready_dummy;
	wire iact_2_horiz_data_out_valid_dummy;
	wire signed [IACT_WIDTH-1:0]   iact_2_horiz_data_out_dummy;

// weight router 0
	// Horizontal Source (dummy)
	wire weight_0_horiz_data_in_valid_dummy;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_0_horiz_data_in_dummy;
	wire weight_0_horiz_data_in_ready_dummy;

	// Destination Ports
	wire weight_0_PE_0_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_0_PE_0_data_out_from_router_to_pe;

	wire weight_0_PE_1_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_0_PE_1_data_out_from_router_to_pe;

	wire weight_0_PE_2_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_0_PE_2_data_out_from_router_to_pe;

	// Horizantal Destination (dummy)
	wire weight_0_horiz_data_out_ready_dummy;
	wire weight_0_horiz_data_out_valid_dummy;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_0_horiz_data_out_dummy;

// weight router 1
	// Horizontal Source (dummy)
	wire weight_1_horiz_data_in_valid_dummy;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_1_horiz_data_in_dummy;
	wire weight_1_horiz_data_in_ready_dummy;

	// Destination Ports
	wire weight_1_PE_0_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_1_PE_0_data_out_from_router_to_pe;

	wire weight_1_PE_1_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_1_PE_1_data_out_from_router_to_pe;

	wire weight_1_PE_2_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_1_PE_2_data_out_from_router_to_pe;

	// Horizantal Destination (dummy)
	wire weight_1_horiz_data_out_ready_dummy;
	wire weight_1_horiz_data_out_valid_dummy;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_1_horiz_data_out_dummy;

// weight router 2
	// Horizontal Source (dummy)
	wire weight_2_horiz_data_in_valid_dummy;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_2_horiz_data_in_dummy;
	wire weight_2_horiz_data_in_ready_dummy;

	// Destination Ports
	wire weight_2_PE_0_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_2_PE_0_data_out_from_router_to_pe;

	wire weight_2_PE_1_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_2_PE_1_data_out_from_router_to_pe;

	wire weight_2_PE_2_data_out_valid_from_router_to_pe;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_2_PE_2_data_out_from_router_to_pe;

	// Horizantal Destination (dummy)
	wire weight_2_horiz_data_out_ready_dummy;
	wire weight_2_horiz_data_out_valid_dummy;
	wire signed [WEIGHT_WIDTH-1 : 0] weight_2_horiz_data_out_dummy;

// psum router 0
	wire psum_0_GLB_data_in_ready_dummy;
	wire psum_0_GLB_data_in_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_0_GLB_data_in_dummy;

    wire psum_0_north_data_in_ready_dummy;
    wire psum_0_north_data_in_valid_dummy;
    wire signed[PSUM_WIDTH-1:0] psum_0_north_data_in_dummy;       

    wire psum_0_PE_data_out_ready_dummy;
    wire psum_0_PE_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_0_PE_data_out_dummy;

	wire psum_0_south_data_out_ready_dummy;
	wire psum_0_south_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_0_south_data_out_dummy;

// psum router 1
	wire psum_1_GLB_data_in_ready_dummy;
	wire psum_1_GLB_data_in_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_1_GLB_data_in_dummy;

    wire psum_1_north_data_in_ready_dummy;
    wire psum_1_north_data_in_valid_dummy;
    wire signed[PSUM_WIDTH-1:0] psum_1_north_data_in_dummy;       

    wire psum_1_PE_data_out_ready_dummy;
    wire psum_1_PE_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_1_PE_data_out_dummy;

	wire psum_1_south_data_out_ready_dummy;
	wire psum_1_south_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_1_south_data_out_dummy;

// psum router 2
	wire psum_2_GLB_data_in_ready_dummy;
	wire psum_2_GLB_data_in_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_2_GLB_data_in_dummy;

    wire psum_2_north_data_in_ready_dummy;
    wire psum_2_north_data_in_valid_dummy;
    wire signed[PSUM_WIDTH-1:0] psum_2_north_data_in_dummy;       

    wire psum_2_PE_data_out_ready_dummy;
    wire psum_2_PE_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_2_PE_data_out_dummy;

	wire psum_2_south_data_out_ready_dummy;
	wire psum_2_south_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_2_south_data_out_dummy;

// psum router 3
	wire psum_3_GLB_data_in_ready_dummy;
	wire psum_3_GLB_data_in_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_3_GLB_data_in_dummy;

    wire psum_3_north_data_in_ready_dummy;
    wire psum_3_north_data_in_valid_dummy;
    wire signed[PSUM_WIDTH-1:0] psum_3_north_data_in_dummy;       

    wire psum_3_PE_data_out_ready_dummy;
    wire psum_3_PE_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_3_PE_data_out_dummy;

	wire psum_3_south_data_out_ready_dummy;
	wire psum_3_south_data_out_valid_dummy;
	wire signed[PSUM_WIDTH-1:0] psum_3_south_data_out_dummy;



PE_cluster #(
    .PE_NUM (PE_NUM),
    .ROW_NUM (ROW_NUM),
    .IACT_WIDTH (IACT_WIDTH),
    .WEIGHT_WIDTH (WEIGHT_WIDTH),
    .PSUM_WIDTH (PSUM_WIDTH),
    .IACT_SPAD_DEPTH (IACT_SPAD_DEPTH), 
    .PSUM_SPAD_DEPTH (PSUM_SPAD_DEPTH), 
    .WEIGHT_SPAD_DEPTH (WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS (CLUSTER_ROWS) 
) PE_cluster_instance (
    .clock (clock),
    .reset (reset),

    .top_filter_mode (top_filter_mode),

    .top_load_PEs_weight_pe (top_load_PEs_weight_pe_from_ctrl_to_pe),
    .load_PEs_weight_done_top (top_done_PEs_weight_pe_from_pe_to_ctrl),
    .top_load_PEs_iact_pe (top_load_PEs_iact_pe_from_ctrl_to_pe),
    .load_PEs_iact_done_top (top_done_PEs_iact_pe_from_pe_to_ctrl),
    .top_mac_en_pe (top_mac_en_pe_from_ctrl_to_pe), 
    .mac_done_top(mac_done_top_from_pe_to_ctrl),

    .top_psum_stream_start_pe (top_psum_stream_start_pe_from_ctrl_to_pe),
    .psum_stream_done_top(psum_stream_done_top_from_pe_to_ctrl),
    .top_PSUM_to_GLB_en_pe (top_PSUM_to_GLB_en_pe_from_ctrl_to_pe),
	.PSUM_to_GLB_done_top(PSUM_to_GLB_done_top_from_pe_to_ctrl),
    .PE_mode(PE_mode_from_ctrl_to_pe),

    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .psum_spad_write_index(psum_spad_write_index),
    .weight_spad_index(weight_spad_index),

    .final_psum_out_ready_glb0(final_psum_out_ready_glb0_from_glb_to_pe),
    .final_psum_out_valid_glb0(final_psum_out_valid_glb0_from_pe_to_glb),
    .final_psum_out_glb0(final_psum_out_glb0_from_pe_to_glb),
    .final_psum_out_ready_glb1(final_psum_out_ready_glb1_from_glb_to_pe),
    .final_psum_out_valid_glb1(final_psum_out_valid_glb1_from_pe_to_glb),
    .final_psum_out_glb1(final_psum_out_glb1_from_pe_to_glb),
    .final_psum_out_ready_glb2(final_psum_out_ready_glb2_from_glb_to_pe),
    .final_psum_out_valid_glb2(final_psum_out_valid_glb2_from_pe_to_glb),
    .final_psum_out_glb2(final_psum_out_glb2_from_pe_to_glb),
    .final_psum_out_ready_glb3(final_psum_out_ready_glb3_from_glb_to_pe),
    .final_psum_out_valid_glb3(final_psum_out_valid_glb3_from_pe_to_glb),
    .final_psum_out_glb3(final_psum_out_glb3_from_pe_to_glb),

    .PE00_iact_weight_data_ready(PE00_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE00_iact_weight_data_valid(PE00_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE00_iact_weight_data(PE00_iact_weight_data_from_router_to_pe_w0_i0),
    .PE01_iact_weight_data_ready(PE01_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE01_iact_weight_data_valid(PE01_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE01_iact_weight_data(PE01_iact_weight_data_from_router_to_pe_w0_i0),
    .PE02_iact_weight_data_ready(PE02_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE02_iact_weight_data_valid(PE02_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE02_iact_weight_data(PE02_iact_weight_data_from_router_to_pe_w0_i0),
    .PE03_iact_weight_data_ready(PE03_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE03_iact_weight_data_valid(PE03_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE03_iact_weight_data(PE03_iact_weight_data_from_router_to_pe_w0_i0),

    .PE10_iact_weight_data_ready(PE10_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE10_iact_weight_data_valid(PE10_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE10_iact_weight_data(PE10_iact_weight_data_from_router_to_pe_w0_i0),
    .PE11_iact_weight_data_ready(PE11_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE11_iact_weight_data_valid(PE11_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE11_iact_weight_data(PE11_iact_weight_data_from_router_to_pe_w0_i0),
    .PE12_iact_weight_data_ready(PE12_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE12_iact_weight_data_valid(PE12_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE12_iact_weight_data(PE12_iact_weight_data_from_router_to_pe_w0_i0),
    .PE13_iact_weight_data_ready(PE13_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE13_iact_weight_data_valid(PE13_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE13_iact_weight_data(PE13_iact_weight_data_from_router_to_pe_w0_i0),

    .PE20_iact_weight_data_ready(PE20_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE20_iact_weight_data_valid(PE20_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE20_iact_weight_data(PE20_iact_weight_data_from_router_to_pe_w0_i0),
    .PE21_iact_weight_data_ready(PE21_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE21_iact_weight_data_valid(PE21_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE21_iact_weight_data(PE21_iact_weight_data_from_router_to_pe_w0_i0),
    .PE22_iact_weight_data_ready(PE22_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE22_iact_weight_data_valid(PE22_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE22_iact_weight_data(PE22_iact_weight_data_from_router_to_pe_w0_i0),
    .PE23_iact_weight_data_ready(PE23_iact_weight_data_ready_from_pe_to_router_w0_i0),
    .PE23_iact_weight_data_valid(PE23_iact_weight_data_valid_from_router_to_pe_w0_i0),
    .PE23_iact_weight_data(PE23_iact_weight_data_from_router_to_pe_w0_i0),

    .PE30_iact_weight_data_ready(PE30_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE30_iact_weight_data_valid(PE30_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE30_iact_weight_data(PE30_iact_weight_data_from_router_to_pe_w1_i1),
    .PE31_iact_weight_data_ready(PE31_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE31_iact_weight_data_valid(PE31_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE31_iact_weight_data(PE31_iact_weight_data_from_router_to_pe_w1_i1),
    .PE32_iact_weight_data_ready(PE32_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE32_iact_weight_data_valid(PE32_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE32_iact_weight_data(PE32_iact_weight_data_from_router_to_pe_w1_i1),
    .PE33_iact_weight_data_ready(PE33_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE33_iact_weight_data_valid(PE33_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE33_iact_weight_data(PE33_iact_weight_data_from_router_to_pe_w1_i1),

    .PE40_iact_weight_data_ready(PE40_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE40_iact_weight_data_valid(PE40_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE40_iact_weight_data(PE40_iact_weight_data_from_router_to_pe_w1_i1),
    .PE41_iact_weight_data_ready(PE41_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE41_iact_weight_data_valid(PE41_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE41_iact_weight_data(PE41_iact_weight_data_from_router_to_pe_w1_i1),
    .PE42_iact_weight_data_ready(PE42_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE42_iact_weight_data_valid(PE42_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE42_iact_weight_data(PE42_iact_weight_data_from_router_to_pe_w1_i1),
    .PE43_iact_weight_data_ready(PE43_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE43_iact_weight_data_valid(PE43_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE43_iact_weight_data(PE43_iact_weight_data_from_router_to_pe_w1_i1),

    .PE50_iact_weight_data_ready(PE50_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE50_iact_weight_data_valid(PE50_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE50_iact_weight_data(PE50_iact_weight_data_from_router_to_pe_w1_i1),
    .PE51_iact_weight_data_ready(PE51_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE51_iact_weight_data_valid(PE51_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE51_iact_weight_data(PE51_iact_weight_data_from_router_to_pe_w1_i1),
    .PE52_iact_weight_data_ready(PE52_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE52_iact_weight_data_valid(PE52_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE52_iact_weight_data(PE52_iact_weight_data_from_router_to_pe_w1_i1),
    .PE53_iact_weight_data_ready(PE53_iact_weight_data_ready_from_pe_to_router_w1_i1),
    .PE53_iact_weight_data_valid(PE53_iact_weight_data_valid_from_router_to_pe_w1_i1),
    .PE53_iact_weight_data(PE53_iact_weight_data_from_router_to_pe_w1_i1),

    .PE60_iact_weight_data_ready(PE60_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE60_iact_weight_data_valid(PE60_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE60_iact_weight_data(PE60_iact_weight_data_from_router_to_pe_w2_i2),
    .PE61_iact_weight_data_ready(PE61_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE61_iact_weight_data_valid(PE61_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE61_iact_weight_data(PE61_iact_weight_data_from_router_to_pe_w2_i2),
    .PE62_iact_weight_data_ready(PE62_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE62_iact_weight_data_valid(PE62_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE62_iact_weight_data(PE62_iact_weight_data_from_router_to_pe_w2_i2),
    .PE63_iact_weight_data_ready(PE63_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE63_iact_weight_data_valid(PE63_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE63_iact_weight_data(PE63_iact_weight_data_from_router_to_pe_w2_i2),

    .PE70_iact_weight_data_ready(PE70_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE70_iact_weight_data_valid(PE70_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE70_iact_weight_data(PE70_iact_weight_data_from_router_to_pe_w2_i2),
    .PE71_iact_weight_data_ready(PE71_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE71_iact_weight_data_valid(PE71_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE71_iact_weight_data(PE71_iact_weight_data_from_router_to_pe_w2_i2),
    .PE72_iact_weight_data_ready(PE72_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE72_iact_weight_data_valid(PE72_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE72_iact_weight_data(PE72_iact_weight_data_from_router_to_pe_w2_i2),
    .PE73_iact_weight_data_ready(PE73_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE73_iact_weight_data_valid(PE73_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE73_iact_weight_data(PE73_iact_weight_data_from_router_to_pe_w2_i2),

    .PE80_iact_weight_data_ready(PE80_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE80_iact_weight_data_valid(PE80_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE80_iact_weight_data(PE80_iact_weight_data_from_router_to_pe_w2_i2),
    .PE81_iact_weight_data_ready(PE81_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE81_iact_weight_data_valid(PE81_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE81_iact_weight_data(PE81_iact_weight_data_from_router_to_pe_w2_i2),
    .PE82_iact_weight_data_ready(PE82_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE82_iact_weight_data_valid(PE82_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE82_iact_weight_data(PE82_iact_weight_data_from_router_to_pe_w2_i2),
    .PE83_iact_weight_data_ready(PE83_iact_weight_data_ready_from_pe_to_router_w2_i2),
    .PE83_iact_weight_data_valid(PE83_iact_weight_data_valid_from_router_to_pe_w2_i2),
    .PE83_iact_weight_data(PE83_iact_weight_data_from_router_to_pe_w2_i2)
);

GLB_CLUSTER #(
	.IACT_SIZE(IACT_WIDTH),
	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),

	.WEIGHT_SIZE(WEIGHT_WIDTH),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),

	.PSUM_SIZE(PSUM_WIDTH),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) GLB_CLUSTER_instance (
    .clk(clock),
    .rst(reset),

    .IACT_data_in_ready(IACT_data_in_ready_from_glb_to_dram),
    .IACT_data_in_valid(IACT_data_in_valid_from_dram_to_glb),
    .IACT_data_in(IACT_data_in_from_dram_to_glb),

    .IACT_data_out_ready_0(IACT_data_out_ready_0_from_router_to_glb),
	.IACT_data_out_valid_0(IACT_data_out_valid_0_from_glb_to_router),
	.IACT_data_out_0(IACT_data_out_0_from_glb_to_router),
	.IACT_data_out_ready_1(IACT_data_out_ready_1_from_router_to_glb),
	.IACT_data_out_valid_1(IACT_data_out_valid_1_from_glb_to_router),
	.IACT_data_out_1(IACT_data_out_1_from_glb_to_router),
	.IACT_data_out_ready_2(IACT_data_out_ready_2_from_router_to_glb),
	.IACT_data_out_valid_2(IACT_data_out_valid_2_from_glb_to_router),
	.IACT_data_out_2(IACT_data_out_2_from_glb_to_router),

	.IACT_write_address(IACT_write_address_from_glb_to_ctrl),
	.IACT_write_en(IACT_write_en_from_ctrl_to_glb),
	.IACT_write_addr(IACT_write_addr_from_ctrl_to_glb),
	.IACT_write_done(IACT_write_done_from_glb_to_ctrl),

	.IACT_read_en_0(IACT_read_en_from_ctrl_to_glb),
	.IACT_read_addr_0(IACT_read_addr_0_from_ctrl_to_glb),
	.IACT_read_done_0(IACT_read_done_0_from_glb_to_ctrl), 
	
	.IACT_read_en_1(IACT_read_en_from_ctrl_to_glb),
	.IACT_read_addr_1(IACT_read_addr_1_from_ctrl_to_glb),
	.IACT_read_done_1(IACT_read_done_1_from_glb_to_ctrl),

	.IACT_read_en_2(IACT_read_en_from_ctrl_to_glb),
	.IACT_read_addr_2(IACT_read_addr_2_from_ctrl_to_glb),
	.IACT_read_done_2(IACT_read_done_2_from_glb_to_ctrl),

	.psum0_read_address_initial(psum0_read_address_initial_from_rearrange_to_glb),
    .psum0_data_in_ready(psum0_data_in_ready_from_glb_to_router),
	.psum0_data_in_valid(psum0_data_in_valid_from_router_to_glb),
	.psum0_data_in(psum0_data_in_from_router_to_glb),

	//el mafrood mafeesh data rayha men el GLB lel router
	.psum0_data_out_ready(psum0_data_out_ready_from_router_to_glb),
	.psum0_data_out_valid(psum0_data_out_valid_from_glb_to_router),
	.psum0_data_out(psum0_data_out_from_glb_to_router),

	.psum0_write_en(psum_write_en_from_ctrl_to_glb),
	.psum0_write_addr(psum_write_addr_from_ctrl_to_glb),
	.psum0_write_done(psum0_write_done_from_glb_to_ctrl),

	.psum0_read_done(psum0_read_done_from_glb_to_ctrl),
	.psum0_read_en(psum0_read_en_from_ctrl_to_glb),
	.psum0_read_addr(psum0_read_addr_from_ctrl_to_glb),
	.psum0_PSUM_DEPTH(psum_PSUM_DEPTH_from_ctrl_to_glb),

	.psum1_read_address_initial(psum1_read_address_initial_from_rearrange_to_glb),
	.psum1_data_in_ready(psum1_data_in_ready_from_glb_to_router),
	.psum1_data_in_valid(psum1_data_in_valid_from_router_to_glb),
	.psum1_data_in(psum1_data_in_from_router_to_glb),
	//el mafrood mafeesh data rayha men el GLB lel router
	.psum1_data_out_ready(psum1_data_out_ready_from_router_to_glb),
	.psum1_data_out_valid(psum1_data_out_valid_from_glb_to_router),
	.psum1_data_out(psum1_data_out_from_glb_to_router),

	.psum1_write_en(psum_write_en_from_ctrl_to_glb),
	.psum1_write_addr(psum_write_addr_from_ctrl_to_glb),
	.psum1_write_done(psum1_write_done_from_glb_to_ctrl),
	
	.psum1_read_done(psum1_read_done_from_glb_to_ctrl),
	.psum1_read_en(psum1_read_en_from_ctrl_to_glb),
	.psum1_read_addr(psum1_read_addr_from_ctrl_to_glb),
	.psum1_PSUM_DEPTH(psum_PSUM_DEPTH_from_ctrl_to_glb),

	.psum2_read_address_initial(psum2_read_address_initial_from_rearrange_to_glb),
	.psum2_data_in_ready(psum2_data_in_ready_from_glb_to_router),
	.psum2_data_in_valid(psum2_data_in_valid_from_router_to_glb),
	.psum2_data_in(psum2_data_in_from_router_to_glb),
	//el mafrood mafeesh data rayha men el GLB lel router
	.psum2_data_out_ready(psum2_data_out_ready_from_router_to_glb),
	.psum2_data_out_valid(psum2_data_out_valid_from_glb_to_router),
	.psum2_data_out(psum2_data_out_from_glb_to_router),

	.psum2_write_en(psum_write_en_from_ctrl_to_glb),
	.psum2_write_addr(psum_write_addr_from_ctrl_to_glb),
	.psum2_write_done(psum2_write_done_from_glb_to_ctrl),
	
	.psum2_read_done(psum2_read_done_from_glb_to_ctrl),
	.psum2_read_en(psum2_read_en_from_ctrl_to_glb),
	.psum2_read_addr(psum2_read_addr_from_ctrl_to_glb),
	.psum2_PSUM_DEPTH(psum_PSUM_DEPTH_from_ctrl_to_glb),

	.psum3_read_address_initial(psum3_read_address_initial_from_rearrange_to_glb),
	.psum3_data_in_ready(psum3_data_in_ready_from_glb_to_router),
	.psum3_data_in_valid(psum3_data_in_valid_from_router_to_glb),
	.psum3_data_in(psum3_data_in_from_router_to_glb),
	//el mafrood mafeesh data rayha men el GLB lel router
	.psum3_data_out_ready(psum3_data_out_ready_from_router_to_glb),
	.psum3_data_out_valid(psum3_data_out_valid_from_glb_to_router),
	.psum3_data_out(psum3_data_out_from_glb_to_router),

	.psum3_write_en(psum_write_en_from_ctrl_to_glb),
	.psum3_write_addr(psum_write_addr_from_ctrl_to_glb),
	.psum3_write_done(psum3_write_done_from_glb_to_ctrl),
	
	.psum3_read_done(psum3_read_done_from_glb_to_ctrl),
	.psum3_read_en(psum3_read_en_from_ctrl_to_glb),
	.psum3_read_addr(psum3_read_addr_from_ctrl_to_glb),
	.psum3_PSUM_DEPTH(psum_PSUM_DEPTH_from_ctrl_to_glb)
);


Router_Cluster #(
	.IACT_SIZE(IACT_WIDTH),
	.WEIGHT_SIZE(WEIGHT_WIDTH),
	.PSUM_SIZE(PSUM_WIDTH)
) Router_Cluster_instance (

	.iact_0_data_in_sel(iact_0_data_in_sel_from_ctrl_to_router),
    .iact_0_data_out_sel(iact_0_data_out_sel_from_ctrl_to_router),
	.iact_0_PE_sel(iact_0_PE_sel_from_ctrl_to_router), 
	.iact_0_PE_choice(iact_0_PE_choice_from_ctrl_to_router),
	.iact_0_Multicast_mode(iact_0_Multicast_mode_from_ctrl_to_router),

    .iact_1_data_in_sel(iact_1_data_in_sel_from_ctrl_to_router),
    .iact_1_data_out_sel(iact_1_data_out_sel_from_ctrl_to_router),
	.iact_1_PE_sel(iact_1_PE_sel_from_ctrl_to_router), 
	.iact_1_PE_choice(iact_1_PE_choice_from_ctrl_to_router),
	.iact_1_Multicast_mode(iact_1_Multicast_mode_from_ctrl_to_router),

    .iact_2_data_in_sel(iact_2_data_in_sel_from_ctrl_to_router),
    .iact_2_data_out_sel(iact_2_data_out_sel_from_ctrl_to_router),
	.iact_2_PE_sel(iact_2_PE_sel_from_ctrl_to_router), 
	.iact_2_PE_choice(iact_2_PE_choice_from_ctrl_to_router),
	.iact_2_Multicast_mode(iact_2_Multicast_mode_from_ctrl_to_router),

	.weight_0_data_in_sel(weight_0_data_in_sel_from_ctrl_to_router),
	.weight_0_data_out_sel(weight_0_data_out_sel_from_ctrl_to_router),

	.weight_1_data_in_sel(weight_1_data_in_sel_from_ctrl_to_router),
	.weight_1_data_out_sel(weight_1_data_out_sel_from_ctrl_to_router),

	.weight_2_data_in_sel(weight_2_data_in_sel_from_ctrl_to_router),
	.weight_2_data_out_sel(weight_2_data_out_sel_from_ctrl_to_router),

	.psum_0_data_in_sel(psum_0_data_in_sel_from_ctrl_to_router),
	.psum_0_data_out_sel(psum_0_data_out_sel_from_ctrl_to_router),
	
	.psum_1_data_in_sel(psum_1_data_in_sel_from_ctrl_to_router),
	.psum_1_data_out_sel(psum_1_data_out_sel_from_ctrl_to_router),
	
	.psum_2_data_in_sel(psum_2_data_in_sel_from_ctrl_to_router),
	.psum_2_data_out_sel(psum_2_data_out_sel_from_ctrl_to_router),

	.psum_3_data_in_sel(psum_3_data_in_sel_from_ctrl_to_router),
	.psum_3_data_out_sel(psum_3_data_out_sel_from_ctrl_to_router),
	

	.iact_0_GLB_data_in_ready(IACT_data_out_ready_0_from_router_to_glb),
	.iact_0_GLB_data_in_valid(IACT_data_out_valid_0_from_glb_to_router),
	.iact_0_GLB_data_in(IACT_data_out_0_from_glb_to_router),
			
	.iact_0_north_data_in_ready(iact_0_north_data_in_ready_dummy),
	.iact_0_north_data_in_valid(iact_0_north_data_in_valid_from_dummy),
	.iact_0_north_data_in(iact_0_north_dummy),

	.iact_0_south_data_in_ready(iact_0_south_data_in_ready_dummy),
	.iact_0_south_data_in_valid(iact_0_south_data_in_valid_dummy),
	.iact_0_south_data_in(iact_0_south_data_in_dummy),

	.iact_0_horiz_data_in_ready(iact_0_horiz_data_in_ready_dummy),
	.iact_0_horiz_data_in_valid(iact_0_horiz_data_in_valid_dummy),
	.iact_0_horiz_data_in(iact_0_horiz_data_in_dummy),

	.iact_0_PE_0_data_out_ready(PE00_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_0_data_out_valid(iact_0_PE_0_data_out_valid_from_router_to_pe),
	.iact_0_PE_0_data_out(iact_0_PE_0_data_out_from_router_to_pe),

	.iact_0_PE_1_data_out_ready(PE01_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_1_data_out_valid(iact_0_PE_1_data_out_valid_from_router_to_pe),
	.iact_0_PE_1_data_out(iact_0_PE_1_data_out_from_router_to_pe),

	.iact_0_PE_2_data_out_ready(PE02_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_2_data_out_valid(iact_0_PE_2_data_out_valid_from_router_to_pe),
	.iact_0_PE_2_data_out(iact_0_PE_2_data_out_from_router_to_pe),

	.iact_0_PE_3_data_out_ready(PE03_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_3_data_out_valid(iact_0_PE_3_data_out_valid_from_router_to_pe),
	.iact_0_PE_3_data_out(iact_0_PE_3_data_out_from_router_to_pe),

	.iact_0_PE_4_data_out_ready(PE10_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_4_data_out_valid(iact_0_PE_4_data_out_valid_from_router_to_pe),
	.iact_0_PE_4_data_out(iact_0_PE_4_data_out_from_router_to_pe),

	.iact_0_PE_5_data_out_ready(PE11_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_5_data_out_valid(iact_0_PE_5_data_out_valid_from_router_to_pe),
	.iact_0_PE_5_data_out(iact_0_PE_5_data_out_from_router_to_pe),

	.iact_0_PE_6_data_out_ready(PE12_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_6_data_out_valid(iact_0_PE_6_data_out_valid_from_router_to_pe),
	.iact_0_PE_6_data_out(iact_0_PE_6_data_out_from_router_to_pe),

	.iact_0_PE_7_data_out_ready(PE13_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_7_data_out_valid(iact_0_PE_7_data_out_valid_from_router_to_pe),
	.iact_0_PE_7_data_out(iact_0_PE_7_data_out_from_router_to_pe),

	.iact_0_PE_8_data_out_ready(PE20_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_8_data_out_valid(iact_0_PE_8_data_out_valid_from_router_to_pe),
	.iact_0_PE_8_data_out(iact_0_PE_8_data_out_from_router_to_pe),

	.iact_0_PE_9_data_out_ready(PE21_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_9_data_out_valid(iact_0_PE_9_data_out_valid_from_router_to_pe),
	.iact_0_PE_9_data_out(iact_0_PE_9_data_out_from_router_to_pe),

	.iact_0_PE_10_data_out_ready(PE22_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_10_data_out_valid(iact_0_PE_10_data_out_valid_from_router_to_pe),
	.iact_0_PE_10_data_out(iact_0_PE_10_data_out_from_router_to_pe),

	.iact_0_PE_11_data_out_ready(PE23_iact_weight_data_ready_from_pe_to_router_w0_i0),
	.iact_0_PE_11_data_out_valid(iact_0_PE_11_data_out_valid_from_router_to_pe),
	.iact_0_PE_11_data_out(iact_0_PE_11_data_out_from_router_to_pe),

	.iact_0_north_data_out_ready(iact_0_north_data_out_ready_dummy),
	.iact_0_north_data_out_valid(iact_0_north_data_out_valid_dummy),
	.iact_0_north_data_out(iact_0_north_data_out_dummy),

	.iact_0_south_data_out_ready(iact_0_south_data_out_ready_dummy),
	.iact_0_south_data_out_valid(iact_0_south_data_out_valid_dummy),
	.iact_0_south_data_out(iact_0_south_data_out_dummy),

	.iact_0_horiz_data_out_ready(iact_0_horiz_data_out_ready_dummy),
	.iact_0_horiz_data_out_valid(iact_0_horiz_data_out_valid_dummy),
	.iact_0_horiz_data_out(iact_0_horiz_data_out_dummy),

	.iact_1_GLB_data_in_ready(IACT_data_out_ready_1_from_router_to_glb),
	.iact_1_GLB_data_in_valid(IACT_data_out_valid_1_from_glb_to_router),
	.iact_1_GLB_data_in(IACT_data_out_1_from_glb_to_router),
			
	.iact_1_north_data_in_ready(iact_1_north_data_in_ready_dummy),
	.iact_1_north_data_in_valid(iact_1_north_data_in_valid_from_dummy),
	.iact_1_north_data_in(iact_1_north_dummy),

	.iact_1_south_data_in_ready(iact_1_south_data_in_ready_dummy),
	.iact_1_south_data_in_valid(iact_1_south_data_in_valid_dummy),
	.iact_1_south_data_in(iact_1_south_data_in_dummy),

	.iact_1_horiz_data_in_ready(iact_1_horiz_data_in_ready_dummy),
	.iact_1_horiz_data_in_valid(iact_1_horiz_data_in_valid_dummy),
	.iact_1_horiz_data_in(iact_1_horiz_data_in_dummy),

	.iact_1_PE_0_data_out_ready(PE30_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_0_data_out_valid(iact_1_PE_0_data_out_valid_from_router_to_pe),
	.iact_1_PE_0_data_out(iact_1_PE_0_data_out_from_router_to_pe),

	.iact_1_PE_1_data_out_ready(PE31_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_1_data_out_valid(iact_1_PE_1_data_out_valid_from_router_to_pe),
	.iact_1_PE_1_data_out(iact_1_PE_1_data_out_from_router_to_pe),

	.iact_1_PE_2_data_out_ready(PE32_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_2_data_out_valid(iact_1_PE_2_data_out_valid_from_router_to_pe),
	.iact_1_PE_2_data_out(iact_1_PE_2_data_out_from_router_to_pe),

	.iact_1_PE_3_data_out_ready(PE33_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_3_data_out_valid(iact_1_PE_3_data_out_valid_from_router_to_pe),
	.iact_1_PE_3_data_out(iact_1_PE_3_data_out_from_router_to_pe),

	.iact_1_PE_4_data_out_ready(PE40_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_4_data_out_valid(iact_1_PE_4_data_out_valid_from_router_to_pe),
	.iact_1_PE_4_data_out(iact_1_PE_4_data_out_from_router_to_pe),

	.iact_1_PE_5_data_out_ready(PE41_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_5_data_out_valid(iact_1_PE_5_data_out_valid_from_router_to_pe),
	.iact_1_PE_5_data_out(iact_1_PE_5_data_out_from_router_to_pe),

	.iact_1_PE_6_data_out_ready(PE42_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_6_data_out_valid(iact_1_PE_6_data_out_valid_from_router_to_pe),
	.iact_1_PE_6_data_out(iact_1_PE_6_data_out_from_router_to_pe),

	.iact_1_PE_7_data_out_ready(PE43_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_7_data_out_valid(iact_1_PE_7_data_out_valid_from_router_to_pe),
	.iact_1_PE_7_data_out(iact_1_PE_7_data_out_from_router_to_pe),

	.iact_1_PE_8_data_out_ready(PE50_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_8_data_out_valid(iact_1_PE_8_data_out_valid_from_router_to_pe),
	.iact_1_PE_8_data_out(iact_1_PE_8_data_out_from_router_to_pe),

	.iact_1_PE_9_data_out_ready(PE51_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_9_data_out_valid(iact_1_PE_9_data_out_valid_from_router_to_pe),
	.iact_1_PE_9_data_out(iact_1_PE_9_data_out_from_router_to_pe),

	.iact_1_PE_10_data_out_ready(PE52_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_10_data_out_valid(iact_1_PE_10_data_out_valid_from_router_to_pe),
	.iact_1_PE_10_data_out(iact_1_PE_10_data_out_from_router_to_pe),

	.iact_1_PE_11_data_out_ready(PE53_iact_weight_data_ready_from_pe_to_router_w1_i1),
	.iact_1_PE_11_data_out_valid(iact_1_PE_11_data_out_valid_from_router_to_pe),
	.iact_1_PE_11_data_out(iact_1_PE_11_data_out_from_router_to_pe),

	.iact_1_north_data_out_ready(iact_1_north_data_out_ready_dummy),
	.iact_1_north_data_out_valid(iact_1_north_data_out_valid_dummy),
	.iact_1_north_data_out(iact_1_north_data_out_dummy),

	.iact_1_south_data_out_ready(iact_1_south_data_out_ready_dummy),
	.iact_1_south_data_out_valid(iact_1_south_data_out_valid_dummy),
	.iact_1_south_data_out(iact_1_south_data_out_dummy),

	.iact_1_horiz_data_out_ready(iact_1_horiz_data_out_ready_dummy),
	.iact_1_horiz_data_out_valid(iact_1_horiz_data_out_valid_dummy),
	.iact_1_horiz_data_out(iact_1_horiz_data_out_dummy),

	.iact_2_GLB_data_in_ready(IACT_data_out_ready_2_from_router_to_glb),       // ready signal to receive data from GLB
	.iact_2_GLB_data_in_valid(IACT_data_out_valid_2_from_glb_to_router),       // data from GLB valid signal
	.iact_2_GLB_data_in(IACT_data_out_2_from_glb_to_router),             // data from GLB bus

	.iact_2_north_data_in_ready(iact_2_north_data_in_ready_dummy),     // ready signal to receive data from north neighbour
	.iact_2_north_data_in_valid(iact_2_north_data_in_valid_from_dummy),     // data from north neighbour valid signal
	.iact_2_north_data_in(iact_2_north_data_in_from_dummy),           // data from north neighbour bus
			
	.iact_2_south_data_in_ready(iact_2_south_data_in_ready_dummy),     // ready signal to receive data from south neighbour
	.iact_2_south_data_in_valid(iact_2_south_data_in_valid_dummy),     // data from south neighbour valid signal
	.iact_2_south_data_in(iact_2_south_data_in_dummy),           // data from south neighbour bus

	.iact_2_horiz_data_in_ready(iact_2_horiz_data_in_ready_dummy),     // ready signal to receive data from horizontal neighbour
	.iact_2_horiz_data_in_valid(iact_2_horiz_data_in_valid_dummy),     // data from horizontal neighbour valid signal
	.iact_2_horiz_data_in(iact_2_horiz_data_in_dummy),   

	.iact_2_PE_0_data_out_ready(PE60_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_0_data_out_valid(iact_2_PE_0_data_out_valid_from_router_to_pe),
	.iact_2_PE_0_data_out(iact_2_PE_0_data_out_from_router_to_pe),

	.iact_2_PE_1_data_out_ready(PE61_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_1_data_out_valid(iact_2_PE_1_data_out_valid_from_router_to_pe),
	.iact_2_PE_1_data_out(iact_2_PE_1_data_out_from_router_to_pe),

	.iact_2_PE_2_data_out_ready(PE62_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_2_data_out_valid(iact_2_PE_2_data_out_valid_from_router_to_pe),
	.iact_2_PE_2_data_out(iact_2_PE_2_data_out_from_router_to_pe),

	.iact_2_PE_3_data_out_ready(PE63_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_3_data_out_valid(iact_2_PE_3_data_out_valid_from_router_to_pe),
	.iact_2_PE_3_data_out(iact_2_PE_3_data_out_from_router_to_pe),

	.iact_2_PE_4_data_out_ready(PE70_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_4_data_out_valid(iact_2_PE_4_data_out_valid_from_router_to_pe),
	.iact_2_PE_4_data_out(iact_2_PE_4_data_out_from_router_to_pe),

	.iact_2_PE_5_data_out_ready(PE71_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_5_data_out_valid(iact_2_PE_5_data_out_valid_from_router_to_pe),
	.iact_2_PE_5_data_out(iact_2_PE_5_data_out_from_router_to_pe),

	.iact_2_PE_6_data_out_ready(PE72_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_6_data_out_valid(iact_2_PE_6_data_out_valid_from_router_to_pe),
	.iact_2_PE_6_data_out(iact_2_PE_6_data_out_from_router_to_pe),

	.iact_2_PE_7_data_out_ready(PE73_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_7_data_out_valid(iact_2_PE_7_data_out_valid_from_router_to_pe),
	.iact_2_PE_7_data_out(iact_2_PE_7_data_out_from_router_to_pe),

	.iact_2_PE_8_data_out_ready(PE80_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_8_data_out_valid(iact_2_PE_8_data_out_valid_from_router_to_pe),
	.iact_2_PE_8_data_out(iact_2_PE_8_data_out_from_router_to_pe),

	.iact_2_PE_9_data_out_ready(PE81_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_9_data_out_valid(iact_2_PE_9_data_out_valid_from_router_to_pe),
	.iact_2_PE_9_data_out(iact_2_PE_9_data_out_from_router_to_pe),

	.iact_2_PE_10_data_out_ready(PE82_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_10_data_out_valid(iact_2_PE_10_data_out_valid_from_router_to_pe),
	.iact_2_PE_10_data_out(iact_2_PE_10_data_out_from_router_to_pe),

	.iact_2_PE_11_data_out_ready(PE83_iact_weight_data_ready_from_pe_to_router_w2_i2),
	.iact_2_PE_11_data_out_valid(iact_2_PE_11_data_out_valid_from_router_to_pe),
	.iact_2_PE_11_data_out(iact_2_PE_11_data_out_from_router_to_pe),

	.iact_2_north_data_out_ready(iact_2_north_data_out_ready_dummy),
	.iact_2_north_data_out_valid(iact_2_north_data_out_valid_dummy),
	.iact_2_north_data_out(iact_2_north_data_out_dummy),

	.iact_2_south_data_out_ready(iact_2_south_data_out_ready_dummy),
	.iact_2_south_data_out_valid(iact_2_south_data_out_valid_dummy),
	.iact_2_south_data_out(iact_2_south_data_out_dummy),

	.iact_2_horiz_data_out_ready(iact_2_horiz_data_out_ready_dummy),
	.iact_2_horiz_data_out_valid(iact_2_horiz_data_out_valid_dummy),
	.iact_2_horiz_data_out(iact_2_horiz_data_out_dummy),


	.weight_0_GLB_data_in_valid(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in(weight_0_GLB_data_in_from_weight_glb_to_router),
	.weight_0_GLB_data_in_ready(weight_0_GLB_data_in_ready_from_router_to_weight_glb),

	.weight_0_horiz_data_in_valid(weight_0_horiz_data_in_valid_dummy),
	.weight_0_horiz_data_in(weight_0_horiz_data_in_dummy),
	.weight_0_horiz_data_in_ready(weight_0_horiz_data_in_ready_dummy),

	.weight_0_PE_0_data_out_valid(weight_0_PE_0_data_out_valid_from_router_to_pe),
	.weight_0_PE_0_data_out(weight_0_PE_0_data_out_from_router_to_pe),

	.weight_0_PE_1_data_out_valid(weight_0_PE_1_data_out_valid_from_router_to_pe),
	.weight_0_PE_1_data_out(weight_0_PE_1_data_out_from_router_to_pe),

	.weight_0_PE_2_data_out_valid(weight_0_PE_2_data_out_valid_from_router_to_pe),
	.weight_0_PE_2_data_out(weight_0_PE_2_data_out_from_router_to_pe),
	
	.weight_0_horiz_data_out_ready(weight_0_horiz_data_out_ready_dummy),
	.weight_0_horiz_data_out_valid(weight_0_horiz_data_out_valid_dummy),
	.weight_0_horiz_data_out(weight_0_horiz_data_out_dummy),

	.weight_1_GLB_data_in_valid(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in(weight_1_GLB_data_in_from_weight_glb_to_router),
	.weight_1_GLB_data_in_ready(weight_1_GLB_data_in_ready_from_router_to_weight_glb),

	.weight_1_horiz_data_in_valid(weight_1_horiz_data_in_valid_dummy),
	.weight_1_horiz_data_in(weight_1_horiz_data_in_dummy),
	.weight_1_horiz_data_in_ready(weight_1_horiz_data_in_ready_dummy),

	.weight_1_PE_0_data_out_valid(weight_1_PE_0_data_out_valid_from_router_to_pe),
	.weight_1_PE_0_data_out(weight_1_PE_0_data_out_from_router_to_pe),

	.weight_1_PE_1_data_out_valid(weight_1_PE_1_data_out_valid_from_router_to_pe),
	.weight_1_PE_1_data_out(weight_1_PE_1_data_out_from_router_to_pe),

	.weight_1_PE_2_data_out_valid(weight_1_PE_2_data_out_valid_from_router_to_pe),
	.weight_1_PE_2_data_out(weight_1_PE_2_data_out_from_router_to_pe),
	
	.weight_1_horiz_data_out_ready(weight_1_horiz_data_out_ready_dummy),
	.weight_1_horiz_data_out_valid(weight_1_horiz_data_out_valid_dummy),
	.weight_1_horiz_data_out(weight_1_horiz_data_out_dummy),
	
	.weight_2_GLB_data_in_valid(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in(weight_2_GLB_data_in_from_weight_glb_to_router),
	.weight_2_GLB_data_in_ready(weight_2_GLB_data_in_ready_from_router_to_weight_glb),

	.weight_2_horiz_data_in_valid(weight_2_horiz_data_in_valid_dummy),
	.weight_2_horiz_data_in(weight_2_horiz_data_in_dummy),
	.weight_2_horiz_data_in_ready(weight_2_horiz_data_in_ready_dummy),

	.weight_2_PE_0_data_out_valid(weight_2_PE_0_data_out_valid_from_router_to_pe),
	.weight_2_PE_0_data_out(weight_2_PE_0_data_out_from_router_to_pe),

	.weight_2_PE_1_data_out_valid(weight_2_PE_1_data_out_valid_from_router_to_pe),
	.weight_2_PE_1_data_out(weight_2_PE_1_data_out_from_router_to_pe),

	.weight_2_PE_2_data_out_valid(weight_2_PE_2_data_out_valid_from_router_to_pe),
	.weight_2_PE_2_data_out(weight_2_PE_2_data_out_from_router_to_pe),
	
	.weight_2_horiz_data_out_ready(weight_2_horiz_data_out_ready_dummy),
	.weight_2_horiz_data_out_valid(weight_2_horiz_data_out_valid_dummy),
	.weight_2_horiz_data_out(weight_2_horiz_data_out_dummy),

	.psum_0_PE_data_in_ready(final_psum_out_ready_glb0_from_glb_to_pe),
	.psum_0_PE_data_in_valid(final_psum_out_valid_glb0_from_pe_to_glb),
	.psum_0_PE_data_in(final_psum_out_glb0_from_pe_to_glb),

	.psum_0_GLB_data_out_ready(psum0_data_in_ready_from_glb_to_router),
	.psum_0_GLB_data_out_valid(psum0_data_in_valid_from_router_to_glb),
	.psum_0_GLB_data_out(psum0_data_in_from_router_to_glb),					

	.psum_1_PE_data_in_ready(final_psum_out_ready_glb1_from_glb_to_pe),
	.psum_1_PE_data_in_valid(final_psum_out_valid_glb1_from_pe_to_glb),
	.psum_1_PE_data_in(final_psum_out_glb1_from_pe_to_glb),

	.psum_1_GLB_data_out_ready(psum1_data_in_ready_from_glb_to_router),
	.psum_1_GLB_data_out_valid(psum1_data_in_valid_from_router_to_glb),
	.psum_1_GLB_data_out(psum1_data_in_from_router_to_glb),	

	.psum_2_PE_data_in_ready(final_psum_out_ready_glb2_from_glb_to_pe),
	.psum_2_PE_data_in_valid(final_psum_out_valid_glb2_from_pe_to_glb),
	.psum_2_PE_data_in(final_psum_out_glb2_from_pe_to_glb),

	.psum_2_GLB_data_out_ready(psum2_data_in_ready_from_glb_to_router),
	.psum_2_GLB_data_out_valid(psum2_data_in_valid_from_router_to_glb),
	.psum_2_GLB_data_out(psum2_data_in_from_router_to_glb),

	.psum_3_PE_data_in_ready(final_psum_out_ready_glb3_from_glb_to_pe),
	.psum_3_PE_data_in_valid(final_psum_out_valid_glb3_from_pe_to_glb),
	.psum_3_PE_data_in(final_psum_out_glb3_from_pe_to_glb),

	.psum_3_GLB_data_out_ready(psum3_data_in_ready_from_glb_to_router),
	.psum_3_GLB_data_out_valid(psum3_data_in_valid_from_router_to_glb),
	.psum_3_GLB_data_out(psum3_data_in_from_router_to_glb),	
	.filter_mode(top_filter_mode)
);



cluster_group_controller #(
    .IACT_SRAM_ADDRESS_SIZE (IACT_SRAM_ADDRESS_SIZE),
    .WEIGHT_SRAM_ADDRESS_SIZE (WEIGHT_SRAM_ADDRESS_SIZE),
    .PSUM_SRAM_ADDRESS_SIZE (ADDRESS_SIZE),
    .WRITE_COUNT_SIZE (PSUM_WRITE_COUNT_SIZE),
    .WEIGHT_SIZE (WEIGHT_WIDTH)
) cluster_group_controller_instance (
    .clock(clock),
    .reset(reset),
	.iact_dist_enable(iact_dist_enable),
	.last_iact_column(last_iact_column),
	.iact_weight_loading_mode_for_pe(iact_weight_loading_mode_for_pe), // to choose if the pe is loading data from iact router ('d2) or weight router ('d1) or if its not loading at all ('d0)
    .top_filter_mode(top_filter_mode), 
    .top_input_mode(top_input_mode),
    .turn_on(turn_on), 
    // Convolution cofigurations
    .cycles_per_iact_col(cycles_per_iact_col),  // number of needed cycles to process 1 input fmap column with 1 filter column
    .unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),   // number of unique values per cluster per cycle to process 1 input fmap column with 1 filter column
    .unique_values_per_cluster(unique_values_per_cluster),    // number of unique values per cluster for cycles to process 1 input fmap column with 1 filter column
    .weight_values_per_filter(weight_values_per_filter),  // number of weight values per filter 
    .weight_columns(weight_columns), // number of weight columns per filter

    // iact GLB controls 
    .iact_GLB_write_en(IACT_write_en_from_ctrl_to_glb),
    .iact_GLB_start_write_address(IACT_write_addr_from_ctrl_to_glb),
    .iact_GLB_current_write_address(IACT_write_address_from_glb_to_ctrl),	
    .iact_GLB_write_done(IACT_write_done_from_glb_to_ctrl),

    .iact_GLB_read_en(IACT_read_en_from_ctrl_to_glb),
    .iact_GLB_start_read_address_port0(IACT_read_addr_0_from_ctrl_to_glb),
    .iact_GLB_start_read_address_port1(IACT_read_addr_1_from_ctrl_to_glb),
    .iact_GLB_start_read_address_port2(IACT_read_addr_2_from_ctrl_to_glb),
    // to request for loading next input fmap columns from bram to glb
    .iact_column_done_flag(IACT_column_done_flag_from_ctrl_to_top), // Heya output leh?

    // weight GLB controls 
	.weight_GLB_write_address_current(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en(weight_GLB_write_en_from_ctrl_to_glb), // enables write
	.weight_GLB_write_addr(weight_GLB_write_addr_from_ctrl_to_glb), // initial write address
	.weight_GLB_write_done(weight_GLB_write_done_from_glb_to_ctrl), // flags the end of write operation

	.weight_GLB_read_en_0(weight_GLB_read_en_0_from_to_glb), // enables read from port 0
	.weight_GLB_read_addr_0(weight_GLB_read_addr_0_to_glb), // initial read address
	.weight_GLB_read_addr_0_current (weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_done_0(weight_GLB_read_done_0_from_glb), // flags the end of read operation

	.weight_GLB_read_en_1(weight_GLB_read_en_1_from_to_glb), // enables read from port 1
	.weight_GLB_read_addr_1(weight_GLB_read_addr_1_to_glb), // initial read address
	.weight_GLB_read_addr_1_current (weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_done_1(weight_GLB_read_done_1_from_glb), // flags the end of read operation

	.weight_GLB_read_en_2(weight_GLB_read_en_2_from_to_glb), // enables read from port 2
	.weight_GLB_read_addr_2(weight_GLB_read_addr_2_to_glb), // initial read address
	.weight_GLB_read_addr_2_current (weight_GLB_read_address_2_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_done_2(weight_GLB_read_done_2_from_glb), // flags the end of read operation


    // psum GLB controls 
    .psum_GLB_write_en(psum_write_en_from_ctrl_to_glb),
    .psum_GLB_start_address(psum_write_addr_from_ctrl_to_glb),
    .psum_GLB_write_done(psum_GLB_write_done_from_glb_to_ctrl),
    .psum_GLB_depth(psum_PSUM_DEPTH_from_ctrl_to_glb),

    // iact router 0 controls 
    .iact_router0_data_in_sel(iact_0_data_in_sel_from_ctrl_to_router),
	.iact_router0_data_out_sel(iact_0_data_out_sel_from_ctrl_to_router),
	// UNICAST
	.iact_router0_PE_sel(iact_0_PE_sel_from_ctrl_to_router),
	// MULTICAST
	.iact_router0_PE_choice(iact_0_PE_choice_from_ctrl_to_router),
	.iact_router0_Multicast_mode(iact_0_Multicast_mode_from_ctrl_to_router),

    // iact router 1 controls 
    .iact_router1_data_in_sel(iact_1_data_in_sel_from_ctrl_to_router),
	.iact_router1_data_out_sel(iact_1_data_out_sel_from_ctrl_to_router),
	// UNICAST
	.iact_router1_PE_sel(iact_1_PE_sel_from_ctrl_to_router),
	// MULTICAST
	.iact_router1_PE_choice(iact_1_PE_choice_from_ctrl_to_router),
	.iact_router1_Multicast_mode(iact_1_Multicast_mode_from_ctrl_to_router),

    // iact router 2 controls 
    .iact_router2_data_in_sel(iact_2_data_in_sel_from_ctrl_to_router),
	.iact_router2_data_out_sel(iact_2_data_out_sel_from_ctrl_to_router),
	// UNICAST
	.iact_router2_PE_sel(iact_2_PE_sel_from_ctrl_to_router),
	// MULTICAST
	.iact_router2_PE_choice(iact_2_PE_choice_from_ctrl_to_router),
	.iact_router2_Multicast_mode(iact_2_Multicast_mode_from_ctrl_to_router),

// weight router 0  
    .weight_router0_data_in_sel(weight_0_data_in_sel_from_ctrl_to_router), 
	.weight_router0_data_out_sel(weight_0_data_out_sel_from_ctrl_to_router),

// weight router 1  
    .weight_router1_data_in_sel(weight_1_data_in_sel_from_ctrl_to_router), 
	.weight_router1_data_out_sel(weight_1_data_out_sel_from_ctrl_to_router),

// weight router 2 
    .weight_router2_data_in_sel(weight_2_data_in_sel_from_ctrl_to_router), 
	.weight_router2_data_out_sel(weight_2_data_out_sel_from_ctrl_to_router),

    // psum router 0 controls
    .psum_router0_data_in_sel(psum_0_data_in_sel_from_ctrl_to_router), 
	.psum_router0_data_out_sel(psum_0_data_out_sel_from_ctrl_to_router),

    // psum router 1 controls
    .psum_router1_data_in_sel(psum_1_data_in_sel_from_ctrl_to_router), 
	.psum_router1_data_out_sel(psum_1_data_out_sel_from_ctrl_to_router),

    // psum router 2 controls  
    .psum_router2_data_in_sel(psum_2_data_in_sel_from_ctrl_to_router), 
	.psum_router2_data_out_sel(psum_2_data_out_sel_from_ctrl_to_router),

    // psum router 3 controls  
    .psum_router3_data_in_sel(psum_3_data_in_sel_from_ctrl_to_router), 
	.psum_router3_data_out_sel(psum_3_data_out_sel_from_ctrl_to_router),
    
    // PE cluster controls
    .load_PEs_weight(top_load_PEs_weight_pe_from_ctrl_to_pe),
    .load_PEs_weight_done(top_done_PEs_weight_pe_from_pe_to_ctrl),
    .load_PEs_iact(top_load_PEs_iact_pe_from_ctrl_to_pe),
    .load_PEs_iact_done(top_done_PEs_iact_pe_from_pe_to_ctrl),
    .mac_start(top_mac_en_pe_from_ctrl_to_pe),
    .mac_done(mac_done_top_from_pe_to_ctrl),
    .psum_stream_start(top_psum_stream_start_pe_from_ctrl_to_pe),
    .psum_stream_done(psum_stream_done_top_from_pe_to_ctrl),
    .read_PEs_psum(top_PSUM_to_GLB_en_pe_from_ctrl_to_pe),

    .mac_done_counter(psum_spad_write_index),  // counts cycles_per_iact_col, index to spad
    .weight_column_counter(weight_spad_index), // counts weight_columns

    .iact_next_ofmap_col(iact_next_ofmap_col_from_ctrl_to_top), // from top

    //from cluster group controller to pe cluster to determine pe mod is it mac or stream
    .PE_mode(PE_mode_from_ctrl_to_pe)
);

//Flag to top to indicate that a new iact column needs to be loaded from DRAM to GLB.
assign top_done_iact_column = top_done_PEs_iact_pe_from_pe_to_ctrl;

// Flag that all psum glbs are done writing
assign psum_GLB_write_done_from_glb_to_ctrl = psum0_write_done_from_glb_to_ctrl & psum1_write_done_from_glb_to_ctrl & psum2_write_done_from_glb_to_ctrl & psum3_write_done_from_glb_to_ctrl; // can be used as a single signal to indicate all psum write operations are done since we only write to one psum GLB at a time


// choose loading to pes (iact or weight)
always @(*) begin
		if (iact_weight_loading_mode_for_pe == 'd1) begin
			// All PEs of row 0 take from weight router 0 PE 0
			PE00_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_valid_from_router_to_pe;  
			PE00_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_from_router_to_pe; 

			PE01_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_valid_from_router_to_pe;
			PE01_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_from_router_to_pe;

			PE02_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_valid_from_router_to_pe;
			PE02_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_from_router_to_pe;

			PE03_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_valid_from_router_to_pe;
			PE03_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_0_data_out_from_router_to_pe; 

			// All PEs of row 1 take from weight router 1 PE 0
			PE10_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_valid_from_router_to_pe;
			PE10_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_from_router_to_pe;

			PE11_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_valid_from_router_to_pe;
			PE11_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_from_router_to_pe;

			PE12_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_valid_from_router_to_pe;
			PE12_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_from_router_to_pe;

			PE13_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_valid_from_router_to_pe;
			PE13_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_1_data_out_from_router_to_pe;

			// All PEs of row 2 take from weight router 2 PE 0
			PE20_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_valid_from_router_to_pe;
			PE20_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_from_router_to_pe;

			PE21_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_valid_from_router_to_pe;
			PE21_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_from_router_to_pe;

			PE22_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_valid_from_router_to_pe;
			PE22_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_from_router_to_pe;

			PE23_iact_weight_data_valid_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_valid_from_router_to_pe;
			PE23_iact_weight_data_from_router_to_pe_w0_i0 = weight_0_PE_2_data_out_from_router_to_pe;

			// All PEs of row 3 take from weight router 0 PE 1
			PE30_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_0_data_out_valid_from_router_to_pe;
			PE30_iact_weight_data_from_router_to_pe_w1_i1 =  weight_1_PE_0_data_out_from_router_to_pe;

			PE31_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_0_data_out_valid_from_router_to_pe; 
			PE31_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_0_data_out_from_router_to_pe;

			PE32_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_0_data_out_valid_from_router_to_pe;
			PE32_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_0_data_out_from_router_to_pe;

			PE33_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_0_data_out_valid_from_router_to_pe;
			PE33_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_0_data_out_from_router_to_pe;

			// All PEs of row 4 take from weight router 1 PE 1
			PE40_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_valid_from_router_to_pe;
			PE40_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_from_router_to_pe;

			PE41_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_valid_from_router_to_pe;
			PE41_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_from_router_to_pe;

			PE42_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_valid_from_router_to_pe;
			PE42_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_from_router_to_pe;

			PE43_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_valid_from_router_to_pe;
			PE43_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_1_data_out_from_router_to_pe;

			// All PEs of row 5 take from weight router 2 PE 1
			PE50_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_valid_from_router_to_pe;
			PE50_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_from_router_to_pe;

			PE51_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_valid_from_router_to_pe;
			PE51_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_from_router_to_pe;

			PE52_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_valid_from_router_to_pe;
			PE52_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_from_router_to_pe;

			PE53_iact_weight_data_valid_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_valid_from_router_to_pe;
			PE53_iact_weight_data_from_router_to_pe_w1_i1 = weight_1_PE_2_data_out_from_router_to_pe;

			// All PEs of row 6 take from weight router 0 PE 2
			PE60_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_valid_from_router_to_pe;
			PE60_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_from_router_to_pe;

			PE61_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_valid_from_router_to_pe;
			PE61_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_from_router_to_pe;

			PE62_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_valid_from_router_to_pe;
			PE62_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_from_router_to_pe;

			PE63_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_valid_from_router_to_pe;
			PE63_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_0_data_out_from_router_to_pe;

			// All PEs of row 7 take from weight router 1 PE 2
			PE70_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_valid_from_router_to_pe;
			PE70_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_from_router_to_pe;

			PE71_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_valid_from_router_to_pe;
			PE71_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_from_router_to_pe;

			PE72_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_valid_from_router_to_pe;
			PE72_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_from_router_to_pe;

			PE73_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_valid_from_router_to_pe;
			PE73_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_1_data_out_from_router_to_pe;

			// All PEs of row 8 take from weight router 2 PE 2
			PE80_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_2_data_out_valid_from_router_to_pe;
			PE80_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_2_data_out_from_router_to_pe;

			PE81_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_2_data_out_valid_from_router_to_pe;
			PE81_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_2_data_out_from_router_to_pe;

			PE82_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_2_data_out_valid_from_router_to_pe;
			PE82_iact_weight_data_from_router_to_pe_w2_i2 = weight_2_PE_2_data_out_from_router_to_pe;

			PE83_iact_weight_data_valid_from_router_to_pe_w2_i2 = weight_2_PE_2_data_out_valid_from_router_to_pe;
			PE83_iact_weight_data_from_router_to_pe_w2_i2 =	weight_2_PE_2_data_out_from_router_to_pe;
		end

		else if (iact_weight_loading_mode_for_pe == 'd2) begin
			// All PEs of row 0 take from iact router 0 
			PE00_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_0_data_out_valid_from_router_to_pe;  
			PE00_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_0_data_out_from_router_to_pe; 

			PE01_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_1_data_out_valid_from_router_to_pe;
			PE01_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_1_data_out_from_router_to_pe;

			PE02_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_2_data_out_valid_from_router_to_pe;
			PE02_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_2_data_out_from_router_to_pe;

			PE03_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_3_data_out_valid_from_router_to_pe;
			PE03_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_3_data_out_from_router_to_pe; 

			// All PEs of row 1 take from iact router 0 
			PE10_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_4_data_out_valid_from_router_to_pe;
			PE10_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_4_data_out_from_router_to_pe;

			PE11_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_5_data_out_valid_from_router_to_pe;
			PE11_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_5_data_out_from_router_to_pe;

			PE12_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_6_data_out_valid_from_router_to_pe;
			PE12_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_6_data_out_from_router_to_pe;

			PE13_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_7_data_out_valid_from_router_to_pe;
			PE13_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_7_data_out_from_router_to_pe;

			// All PEs of row 2 take from iact router 0 
			PE20_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_8_data_out_valid_from_router_to_pe;
			PE20_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_8_data_out_from_router_to_pe;

			PE21_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_9_data_out_valid_from_router_to_pe;
			PE21_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_9_data_out_from_router_to_pe;

			PE22_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_10_data_out_valid_from_router_to_pe;
			PE22_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_10_data_out_from_router_to_pe;

			PE23_iact_weight_data_valid_from_router_to_pe_w0_i0 = iact_0_PE_11_data_out_valid_from_router_to_pe;
			PE23_iact_weight_data_from_router_to_pe_w0_i0 = iact_0_PE_11_data_out_from_router_to_pe;

			// All PEs of row 3 take from iact router 1
			PE30_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_0_data_out_valid_from_router_to_pe;
			PE30_iact_weight_data_from_router_to_pe_w1_i1 =  iact_1_PE_0_data_out_from_router_to_pe;

			PE31_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_1_data_out_valid_from_router_to_pe; 
			PE31_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_1_data_out_from_router_to_pe;

			PE32_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_2_data_out_valid_from_router_to_pe;
			PE32_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_2_data_out_from_router_to_pe;

			PE33_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_3_data_out_valid_from_router_to_pe;
			PE33_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_3_data_out_from_router_to_pe;

			// All PEs of row 4 take from iact router 1
			PE40_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_4_data_out_valid_from_router_to_pe;
			PE40_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_4_data_out_from_router_to_pe;

			PE41_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_5_data_out_valid_from_router_to_pe;
			PE41_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_5_data_out_from_router_to_pe;

			PE42_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_6_data_out_valid_from_router_to_pe;
			PE42_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_6_data_out_from_router_to_pe;

			PE43_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_7_data_out_valid_from_router_to_pe;
			PE43_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_7_data_out_from_router_to_pe;

			// All PEs of row 5 take from iact router 1
			PE50_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_8_data_out_valid_from_router_to_pe;
			PE50_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_8_data_out_from_router_to_pe;

			PE51_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_9_data_out_valid_from_router_to_pe;
			PE51_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_9_data_out_from_router_to_pe;

			PE52_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_10_data_out_valid_from_router_to_pe;
			PE52_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_10_data_out_from_router_to_pe;

			PE53_iact_weight_data_valid_from_router_to_pe_w1_i1 = iact_1_PE_11_data_out_valid_from_router_to_pe;
			PE53_iact_weight_data_from_router_to_pe_w1_i1 = iact_1_PE_11_data_out_from_router_to_pe;

			// All PEs of row 6 take from iact router 2
			PE60_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_0_data_out_valid_from_router_to_pe;
			PE60_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_0_data_out_from_router_to_pe;

			PE61_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_1_data_out_valid_from_router_to_pe;
			PE61_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_1_data_out_from_router_to_pe;

			PE62_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_2_data_out_valid_from_router_to_pe;
			PE62_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_2_data_out_from_router_to_pe;

			PE63_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_3_data_out_valid_from_router_to_pe;
			PE63_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_3_data_out_from_router_to_pe;

			// All PEs of row 7 take from iact router 2
			PE70_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_4_data_out_valid_from_router_to_pe;
			PE70_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_4_data_out_from_router_to_pe;

			PE71_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_5_data_out_valid_from_router_to_pe;
			PE71_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_5_data_out_from_router_to_pe;

			PE72_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_6_data_out_valid_from_router_to_pe;
			PE72_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_6_data_out_from_router_to_pe;

			PE73_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_7_data_out_valid_from_router_to_pe;
			PE73_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_7_data_out_from_router_to_pe;

			// All PEs of row 8 take from iact router 2
			PE80_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_8_data_out_valid_from_router_to_pe;
			PE80_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_8_data_out_from_router_to_pe;

			PE81_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_9_data_out_valid_from_router_to_pe;
			PE81_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_9_data_out_from_router_to_pe;

			PE82_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_10_data_out_valid_from_router_to_pe;
			PE82_iact_weight_data_from_router_to_pe_w2_i2 = iact_2_PE_10_data_out_from_router_to_pe;

			PE83_iact_weight_data_valid_from_router_to_pe_w2_i2 = iact_2_PE_11_data_out_valid_from_router_to_pe;
			PE83_iact_weight_data_from_router_to_pe_w2_i2 =	iact_2_PE_11_data_out_from_router_to_pe;
		end

		else begin
			// All PEs of row 0 take from weight router 0 PE 0
			PE00_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;  
			PE00_iact_weight_data_from_router_to_pe_w0_i0 = 0; 

			PE01_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE01_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE02_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE02_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE03_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE03_iact_weight_data_from_router_to_pe_w0_i0 = 0; 

			// All PEs of row 1 take from weight router 1 PE 0
			PE10_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE10_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE11_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE11_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE12_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE12_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE13_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE13_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			// All PEs of row 2 take from weight router 2 PE 0
			PE20_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE20_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE21_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE21_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE22_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE22_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			PE23_iact_weight_data_valid_from_router_to_pe_w0_i0 = 0;
			PE23_iact_weight_data_from_router_to_pe_w0_i0 = 0;

			// All PEs of row 3 take from weight router 0 PE 1
			PE30_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE30_iact_weight_data_from_router_to_pe_w1_i1 =  0;

			PE31_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0; 
			PE31_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE32_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE32_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE33_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE33_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			// All PEs of row 4 take from weight router 1 PE 1
			PE40_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE40_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE41_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE41_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE42_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE42_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE43_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE43_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			// All PEs of row 5 take from weight router 2 PE 1
			PE50_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE50_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE51_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE51_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE52_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE52_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			PE53_iact_weight_data_valid_from_router_to_pe_w1_i1 = 0;
			PE53_iact_weight_data_from_router_to_pe_w1_i1 = 0;

			// All PEs of row 6 take from weight router 0 PE 2
			PE60_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE60_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE61_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE61_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE62_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE62_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE63_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE63_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			// All PEs of row 7 take from weight router 1 PE 2
			PE70_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE70_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE71_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE71_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE72_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE72_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE73_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE73_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			// All PEs of row 8 take from weight router 2 PE 2
			PE80_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE80_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE81_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE81_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE82_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE82_iact_weight_data_from_router_to_pe_w2_i2 = 0;

			PE83_iact_weight_data_valid_from_router_to_pe_w2_i2 = 0;
			PE83_iact_weight_data_from_router_to_pe_w2_i2 = 0;
		end
		end


endmodule
