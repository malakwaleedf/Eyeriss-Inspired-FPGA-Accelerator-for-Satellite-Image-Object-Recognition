module CONV_TOP #(
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
	parameter PSUM_SRAM_DEPTH = 16, // This must be equal to 2^(ADDRESS_SIZE)
    parameter PSUM_WRITE_COUNT_SIZE = 5,
	parameter REARANGE_MEM_DEPTH = 1024,
	parameter PE_COL = 4,
	parameter CLUSTER_GROUPS = 16,
    parameter NUMBER_OF_CLUSTERS = 16,
    parameter DRAM_ADDRESS_SIZE = 21 
) (
    // top-level ports
    input clock,
    input global_reset,
	input turn_on,
    input [2:0] top_filter_mode, // affects the number of working PEs, weight spad
	input [4:0] cycles_per_iact_col,
    input [3:0] weight_columns,
    input [2:0] top_input_mode, // size of ifmap 
	input [4:0] unique_values_per_cluster_per_cycle,
	input [7:0] unique_values_per_cluster,
	input [6:0] weight_values_per_filter,

// DRAM input ports
	input signed [IACT_WIDTH-1:0] iact_data_in_from_dram_to_iact_dist,
	output [DRAM_ADDRESS_SIZE-1:0] iact_data_in_addr_from_iact_dist_to_dram,

    // iact data bus, valid signal and ready signal
    input signed [IACT_WIDTH-1:0] IACT_data_in_from_dram_to_glb, // input to all clusters from DRAM
    output IACT_data_in_ready_from_glb_to_dram, // and all clsuters output
    output IACT_column_done_flag_from_ctrl_to_top, // and all clsuters output
    // weight data bus, valid signal and ready signal
    input signed [WEIGHT_WIDTH-1:0] weight_data_in_from_dram_to_glb,
    input weight_data_in_valid_from_dram_to_glb,
    output weight_data_in_ready_from_glb_to_dram,

	output top_done_iact_column // Sends signal to top to load next iact column
);

	localparam cluster0 = 'd0;
	localparam cluster1 = 'd1;
	localparam cluster2 = 'd2;
	localparam cluster3 = 'd3;
	localparam cluster4 = 'd4;
	localparam cluster5 = 'd5;
	localparam cluster6 = 'd6;
	localparam cluster7 = 'd7;
	localparam cluster8 = 'd8;
	localparam cluster9 = 'd9;
	localparam cluster10 = 'd10;
	localparam cluster11 = 'd11;
	localparam cluster12 = 'd12;
	localparam cluster13 = 'd13;
	localparam cluster14 = 'd14;
	localparam cluster15 = 'd15;

	localparam glb_0 = 'd0;
	localparam glb_1 = 'd1;
	localparam glb_2 = 'd2;
	localparam glb_3 = 'd3;


wire local_reset;
wire iact_dist_enable;
wire [NUMBER_OF_CLUSTERS-1:0] iact_data_out_valid_from_iact_dist_to_glb;
wire [NUMBER_OF_CLUSTERS-1:0] iact_data_out_ready_from_glb_to_iact_dist;
wire signed [IACT_WIDTH-1:0] iact_data_out_from_iact_dist_to_glb;

wire iact_dist_enable_0;
wire iact_dist_enable_1;
wire iact_dist_enable_2;
wire iact_dist_enable_3;
wire iact_dist_enable_4;
wire iact_dist_enable_5;
wire iact_dist_enable_6;
wire iact_dist_enable_7;
wire iact_dist_enable_8;
wire iact_dist_enable_9;
wire iact_dist_enable_10;
wire iact_dist_enable_11;
wire iact_dist_enable_12;
wire iact_dist_enable_13;
wire iact_dist_enable_14;
wire iact_dist_enable_15;


assign iact_dist_enable = iact_dist_enable_0 | iact_dist_enable_1 | iact_dist_enable_2 | 
                          iact_dist_enable_3 | iact_dist_enable_4 | iact_dist_enable_5 | 
						  iact_dist_enable_6 | iact_dist_enable_7 | iact_dist_enable_8 | 
						  iact_dist_enable_9 | iact_dist_enable_10 | iact_dist_enable_11 | 
						  iact_dist_enable_12 | iact_dist_enable_13 | iact_dist_enable_14 | iact_dist_enable_15;



wire psum_glb_write_done;
wire last_iact_column;
wire iact_next_ofmap_col_from_ctrl_to_top;

// rearrange signals
	wire [2:0] glb_counter_from_rearrange_to_top;
	wire [4:0] cluster_counter_from_rearrange_to_top;
	wire [4:0] glb_read_idx_counter_from_rearrange_to_top;

	wire pixel_in_ready_from_rearrange_to_psum_glb;
	reg signed [PSUM_WIDTH-1:0] pixel_in_data_from_psum_glb_to_rearrange;
	reg pixel_in_valid_from_psum_glb_to_rearrange;

	wire output_pixel_ready_from_dram_to_rearrange;
	wire signed [PSUM_WIDTH-1:0] output_pixel_data_from_rearrange_to_dram;
	wire output_pixel_valid_from_rearrange_to_dram;

	wire read_en_from_dram_to_rearrange;
	wire [ADDRESS_SIZE-1:0] psum_glb_read_address_from_rearrange_to_psum_glb;

	wire read_done_from_dram_to_rearrange;
	wire rearrange_col_done_from_rearrange_to_top;

// iact ready and done signals 
	wire IACT_data_in_ready_from_glb_to_dram_cluster_0;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_0;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_1;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_1;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_2;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_2;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_3;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_3;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_4;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_4;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_5;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_5;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_6;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_6;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_7;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_7;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_8;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_8;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_9;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_9;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_10;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_10;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_11;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_11;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_12;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_12;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_13;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_13;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_14;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_14;

    wire IACT_data_in_ready_from_glb_to_dram_cluster_15;
	wire IACT_column_done_flag_from_ctrl_to_top_cluster_15;

assign IACT_data_in_ready_from_glb_to_dram = IACT_data_in_ready_from_glb_to_dram_cluster_0 & IACT_data_in_ready_from_glb_to_dram_cluster_1
                                            & IACT_data_in_ready_from_glb_to_dram_cluster_2 & IACT_data_in_ready_from_glb_to_dram_cluster_3
                                            & IACT_data_in_ready_from_glb_to_dram_cluster_4 & IACT_data_in_ready_from_glb_to_dram_cluster_5
                                            & IACT_data_in_ready_from_glb_to_dram_cluster_6 & IACT_data_in_ready_from_glb_to_dram_cluster_7
                                            & IACT_data_in_ready_from_glb_to_dram_cluster_8 & IACT_data_in_ready_from_glb_to_dram_cluster_9
                                            & IACT_data_in_ready_from_glb_to_dram_cluster_10 & IACT_data_in_ready_from_glb_to_dram_cluster_11
                                            & IACT_data_in_ready_from_glb_to_dram_cluster_12 & IACT_data_in_ready_from_glb_to_dram_cluster_13
                                            & IACT_data_in_ready_from_glb_to_dram_cluster_14 & IACT_data_in_ready_from_glb_to_dram_cluster_15;

assign IACT_column_done_flag_from_ctrl_to_top = IACT_column_done_flag_from_ctrl_to_top_cluster_0 & IACT_column_done_flag_from_ctrl_to_top_cluster_1
                                            & IACT_column_done_flag_from_ctrl_to_top_cluster_2 & IACT_column_done_flag_from_ctrl_to_top_cluster_3
                                            & IACT_column_done_flag_from_ctrl_to_top_cluster_4 & IACT_column_done_flag_from_ctrl_to_top_cluster_5
                                            & IACT_column_done_flag_from_ctrl_to_top_cluster_6 & IACT_column_done_flag_from_ctrl_to_top_cluster_7
                                            & IACT_column_done_flag_from_ctrl_to_top_cluster_8 & IACT_column_done_flag_from_ctrl_to_top_cluster_9
                                            & IACT_column_done_flag_from_ctrl_to_top_cluster_10 & IACT_column_done_flag_from_ctrl_to_top_cluster_11
                                            & IACT_column_done_flag_from_ctrl_to_top_cluster_12 & IACT_column_done_flag_from_ctrl_to_top_cluster_13
                                            & IACT_column_done_flag_from_ctrl_to_top_cluster_14 & IACT_column_done_flag_from_ctrl_to_top_cluster_15;


// cluster psum GLB write done signals
	wire glb_write_done_cluster_0;
	wire glb_write_done_cluster_1;
	wire glb_write_done_cluster_2;
	wire glb_write_done_cluster_3;	
	wire glb_write_done_cluster_4;
	wire glb_write_done_cluster_5;
	wire glb_write_done_cluster_6;
	wire glb_write_done_cluster_7;
	wire glb_write_done_cluster_8;
	wire glb_write_done_cluster_9;
	wire glb_write_done_cluster_10;
	wire glb_write_done_cluster_11;
	wire glb_write_done_cluster_12;
	wire glb_write_done_cluster_13;	
	wire glb_write_done_cluster_14;
	wire glb_write_done_cluster_15;

// cluster top_done_iact_column signals
	wire top_done_iact_column_cluster_0;
	wire top_done_iact_column_cluster_1;
	wire top_done_iact_column_cluster_2;
	wire top_done_iact_column_cluster_3;
	wire top_done_iact_column_cluster_4;
	wire top_done_iact_column_cluster_5;
	wire top_done_iact_column_cluster_6;
	wire top_done_iact_column_cluster_7;
	wire top_done_iact_column_cluster_8;
	wire top_done_iact_column_cluster_9;
	wire top_done_iact_column_cluster_10;
	wire top_done_iact_column_cluster_11;
	wire top_done_iact_column_cluster_12;
	wire top_done_iact_column_cluster_13;
	wire top_done_iact_column_cluster_14;
	wire top_done_iact_column_cluster_15;

assign top_done_iact_column = top_done_iact_column_cluster_0 & top_done_iact_column_cluster_1 
							& top_done_iact_column_cluster_2 & top_done_iact_column_cluster_3
							& top_done_iact_column_cluster_4 & top_done_iact_column_cluster_5 
							& top_done_iact_column_cluster_6 & top_done_iact_column_cluster_7
							& top_done_iact_column_cluster_8 & top_done_iact_column_cluster_9 
							& top_done_iact_column_cluster_10 & top_done_iact_column_cluster_11
							& top_done_iact_column_cluster_12 & top_done_iact_column_cluster_13 
							& top_done_iact_column_cluster_14 & top_done_iact_column_cluster_15;

assign psum_glb_write_done = glb_write_done_cluster_15;


// weight GLB control signals (from controller to weight GLB)
    // cluster 0
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_0;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_0;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_0;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_0;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_0;

    wire weight_GLB_read_en_0_from_to_glb_cluster_0;
    wire weight_GLB_read_en_1_from_to_glb_cluster_0;
    wire weight_GLB_read_en_2_from_to_glb_cluster_0;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_0;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_0;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_0;

    // cluster 1
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_1;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_1;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_1;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_1;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_1;

    wire weight_GLB_read_en_0_from_to_glb_cluster_1;
    wire weight_GLB_read_en_1_from_to_glb_cluster_1;
    wire weight_GLB_read_en_2_from_to_glb_cluster_1;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_1;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_1;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_1;

    // cluster 2
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_2;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_2;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_2;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_2;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_2;

    wire weight_GLB_read_en_0_from_to_glb_cluster_2;
    wire weight_GLB_read_en_1_from_to_glb_cluster_2;
    wire weight_GLB_read_en_2_from_to_glb_cluster_2;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_2;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_2;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_2;

    // cluster 3
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_3;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_3;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_3;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_3;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_3;

    wire weight_GLB_read_en_0_from_to_glb_cluster_3;
    wire weight_GLB_read_en_1_from_to_glb_cluster_3;
    wire weight_GLB_read_en_2_from_to_glb_cluster_3;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_3;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_3;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_3;

    // cluster 4
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_4;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_4;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_4;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_4;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_4;

    wire weight_GLB_read_en_0_from_to_glb_cluster_4;
    wire weight_GLB_read_en_1_from_to_glb_cluster_4;
    wire weight_GLB_read_en_2_from_to_glb_cluster_4;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_4;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_4;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_4;

    // cluster 5
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_5;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_5;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_5;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_5;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_5;

    wire weight_GLB_read_en_0_from_to_glb_cluster_5;
    wire weight_GLB_read_en_1_from_to_glb_cluster_5;
    wire weight_GLB_read_en_2_from_to_glb_cluster_5;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_5;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_5;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_5;

    // cluster 6
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_6;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_6;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_6;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_6;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_6;

    wire weight_GLB_read_en_0_from_to_glb_cluster_6;
    wire weight_GLB_read_en_1_from_to_glb_cluster_6;
    wire weight_GLB_read_en_2_from_to_glb_cluster_6;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_6;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_6;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_6;

    // cluster 7
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_7;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_7;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_7;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_7;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_7;

    wire weight_GLB_read_en_0_from_to_glb_cluster_7;
    wire weight_GLB_read_en_1_from_to_glb_cluster_7;
    wire weight_GLB_read_en_2_from_to_glb_cluster_7;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_7;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_7;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_7;

    // cluster 8
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_8;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_8;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_8;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_8;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_8;

    wire weight_GLB_read_en_0_from_to_glb_cluster_8;
    wire weight_GLB_read_en_1_from_to_glb_cluster_8;
    wire weight_GLB_read_en_2_from_to_glb_cluster_8;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_8;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_8;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_8;

    // cluster 9
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_9;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_9;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_9;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_9;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_9;

    wire weight_GLB_read_en_0_from_to_glb_cluster_9;
    wire weight_GLB_read_en_1_from_to_glb_cluster_9;
    wire weight_GLB_read_en_2_from_to_glb_cluster_9;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_9;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_9;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_9;

    // cluster 10
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_10;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_10;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_10;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_10;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_10;

    wire weight_GLB_read_en_0_from_to_glb_cluster_10;
    wire weight_GLB_read_en_1_from_to_glb_cluster_10;
    wire weight_GLB_read_en_2_from_to_glb_cluster_10;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_10;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_10;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_10;

    // cluster 11
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_11;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_11;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_11;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_11;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_11;

    wire weight_GLB_read_en_0_from_to_glb_cluster_11;
    wire weight_GLB_read_en_1_from_to_glb_cluster_11;
    wire weight_GLB_read_en_2_from_to_glb_cluster_11;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_11;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_11;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_11;

    // cluster 12
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_12;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_12;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_12;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_12;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_12;

    wire weight_GLB_read_en_0_from_to_glb_cluster_12;
    wire weight_GLB_read_en_1_from_to_glb_cluster_12;
    wire weight_GLB_read_en_2_from_to_glb_cluster_12;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_12;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_12;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_12;

    // cluster 13
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_13;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_13;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_13;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_13;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_13;

    wire weight_GLB_read_en_0_from_to_glb_cluster_13;
    wire weight_GLB_read_en_1_from_to_glb_cluster_13;
    wire weight_GLB_read_en_2_from_to_glb_cluster_13;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_13;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_13;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_13;

    // cluster 14
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_14;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_14;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_14;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_14;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_14;

    wire weight_GLB_read_en_0_from_to_glb_cluster_14;
    wire weight_GLB_read_en_1_from_to_glb_cluster_14;
    wire weight_GLB_read_en_2_from_to_glb_cluster_14;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_14;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_14;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_14;

    // cluster 15
	wire weight_GLB_write_en_from_ctrl_to_glb_cluster_15;
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb_cluster_15;

    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_15;
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_15;
	wire weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_15;

    wire weight_GLB_read_en_0_from_to_glb_cluster_15;
    wire weight_GLB_read_en_1_from_to_glb_cluster_15;
    wire weight_GLB_read_en_2_from_to_glb_cluster_15;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb_cluster_15;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb_cluster_15;
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb_cluster_15;

// weight GLB
    // write control signals 
    wire weight_GLB_write_en_from_ctrl_to_glb; // and all clsuters output
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_addr_from_ctrl_to_glb; // equate to one from the clusters output 
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_write_address_current_from_weight_glb_to_ctrl; // input to all clusters
    wire weight_GLB_write_done_from_glb_to_ctrl; // input to all clusters

    // read ports
    wire weight_0_GLB_data_in_ready_from_router_to_weight_glb; // and all clsuters output
    wire weight_0_GLB_data_in_valid_from_weight_glb_to_router; // input to all clusters
    wire signed [WEIGHT_WIDTH-1:0] weight_0_GLB_data_in_from_weight_glb_to_router; // input to all clusters
    wire weight_1_GLB_data_in_ready_from_router_to_weight_glb; // and all clsuters output
    wire weight_1_GLB_data_in_valid_from_weight_glb_to_router; // input to all clusters
    wire signed [WEIGHT_WIDTH-1:0] weight_1_GLB_data_in_from_weight_glb_to_router; // input to all clusters
    wire weight_2_GLB_data_in_ready_from_router_to_weight_glb; // and all clsuters output
    wire weight_2_GLB_data_in_valid_from_weight_glb_to_router; // input to all clusters
    wire signed [WEIGHT_WIDTH-1:0] weight_2_GLB_data_in_from_weight_glb_to_router; // input to all clusters

    // read control signals 
    wire weight_GLB_read_en_0_from_to_glb; // and all clsuters output
    wire weight_GLB_read_en_1_from_to_glb; // and all clsuters output
    wire weight_GLB_read_en_2_from_to_glb; // and all clsuters output
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_0_to_glb; // equate to one from the clusters output
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_1_to_glb; // equate to one from the clusters output
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_addr_2_to_glb; // equate to one from the clusters output
    wire weight_GLB_read_done_0_from_glb; // input to all clusters
    wire weight_GLB_read_done_1_from_glb; // input to all clusters
    wire weight_GLB_read_done_2_from_glb; // input to all clusters 
    wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_address_0_current_from_weight_glb_to_ctrl; // input to all clusters
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_address_1_current_from_weight_glb_to_ctrl; // input to all clusters
	wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0] weight_GLB_read_address_2_current_from_weight_glb_to_ctrl; // input to all clusters

    assign weight_GLB_write_en_from_ctrl_to_glb = weight_GLB_write_en_from_ctrl_to_glb_cluster_0 & weight_GLB_write_en_from_ctrl_to_glb_cluster_1
                                                & weight_GLB_write_en_from_ctrl_to_glb_cluster_2 & weight_GLB_write_en_from_ctrl_to_glb_cluster_3
                                                & weight_GLB_write_en_from_ctrl_to_glb_cluster_4 & weight_GLB_write_en_from_ctrl_to_glb_cluster_5
                                                & weight_GLB_write_en_from_ctrl_to_glb_cluster_6 & weight_GLB_write_en_from_ctrl_to_glb_cluster_7
                                                & weight_GLB_write_en_from_ctrl_to_glb_cluster_8 & weight_GLB_write_en_from_ctrl_to_glb_cluster_9
                                                & weight_GLB_write_en_from_ctrl_to_glb_cluster_10 & weight_GLB_write_en_from_ctrl_to_glb_cluster_11
                                                & weight_GLB_write_en_from_ctrl_to_glb_cluster_12 & weight_GLB_write_en_from_ctrl_to_glb_cluster_13
                                                & weight_GLB_write_en_from_ctrl_to_glb_cluster_14 & weight_GLB_write_en_from_ctrl_to_glb_cluster_15;

    assign weight_GLB_write_addr_from_ctrl_to_glb = weight_GLB_write_addr_from_ctrl_to_glb_cluster_0;

    assign weight_0_GLB_data_in_ready_from_router_to_weight_glb = weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_0 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_1
                                                                & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_2 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_3
                                                                & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_4 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_5
                                                                & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_6 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_7
                                                                & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_8 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_9
                                                                & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_10 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_11
                                                                & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_12 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_13
                                                                & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_14 & weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_15;

    assign weight_1_GLB_data_in_ready_from_router_to_weight_glb = weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_0 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_1
                                                                & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_2 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_3
                                                                & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_4 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_5
                                                                & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_6 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_7
                                                                & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_8 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_9
                                                                & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_10 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_11
                                                                & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_12 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_13
                                                                & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_14 & weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_15;

    assign weight_2_GLB_data_in_ready_from_router_to_weight_glb = weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_0 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_1
                                                                & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_2 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_3
                                                                & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_4 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_5
                                                                & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_6 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_7
                                                                & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_8 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_9
                                                                & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_10 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_11
                                                                & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_12 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_13
                                                                & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_14 & weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_15;

    assign weight_GLB_read_en_0_from_to_glb = weight_GLB_read_en_0_from_to_glb_cluster_0 & weight_GLB_read_en_0_from_to_glb_cluster_1
                                            & weight_GLB_read_en_0_from_to_glb_cluster_2 & weight_GLB_read_en_0_from_to_glb_cluster_3
                                            & weight_GLB_read_en_0_from_to_glb_cluster_4 & weight_GLB_read_en_0_from_to_glb_cluster_5
                                            & weight_GLB_read_en_0_from_to_glb_cluster_6 & weight_GLB_read_en_0_from_to_glb_cluster_7
                                            & weight_GLB_read_en_0_from_to_glb_cluster_8 & weight_GLB_read_en_0_from_to_glb_cluster_9
                                            & weight_GLB_read_en_0_from_to_glb_cluster_10 & weight_GLB_read_en_0_from_to_glb_cluster_11
                                            & weight_GLB_read_en_0_from_to_glb_cluster_12 & weight_GLB_read_en_0_from_to_glb_cluster_13
                                            & weight_GLB_read_en_0_from_to_glb_cluster_14 & weight_GLB_read_en_0_from_to_glb_cluster_15;

    assign weight_GLB_read_en_1_from_to_glb = weight_GLB_read_en_1_from_to_glb_cluster_0 & weight_GLB_read_en_1_from_to_glb_cluster_1
                                            & weight_GLB_read_en_1_from_to_glb_cluster_2 & weight_GLB_read_en_1_from_to_glb_cluster_3
                                            & weight_GLB_read_en_1_from_to_glb_cluster_4 & weight_GLB_read_en_1_from_to_glb_cluster_5
                                            & weight_GLB_read_en_1_from_to_glb_cluster_6 & weight_GLB_read_en_1_from_to_glb_cluster_7
                                            & weight_GLB_read_en_1_from_to_glb_cluster_8 & weight_GLB_read_en_1_from_to_glb_cluster_9
                                            & weight_GLB_read_en_1_from_to_glb_cluster_10 & weight_GLB_read_en_1_from_to_glb_cluster_11
                                            & weight_GLB_read_en_1_from_to_glb_cluster_12 & weight_GLB_read_en_1_from_to_glb_cluster_13
                                            & weight_GLB_read_en_1_from_to_glb_cluster_14 & weight_GLB_read_en_1_from_to_glb_cluster_15;

    assign weight_GLB_read_en_2_from_to_glb = weight_GLB_read_en_2_from_to_glb_cluster_0 & weight_GLB_read_en_2_from_to_glb_cluster_1
                                            & weight_GLB_read_en_2_from_to_glb_cluster_2 & weight_GLB_read_en_2_from_to_glb_cluster_3
                                            & weight_GLB_read_en_2_from_to_glb_cluster_4 & weight_GLB_read_en_2_from_to_glb_cluster_5
                                            & weight_GLB_read_en_2_from_to_glb_cluster_6 & weight_GLB_read_en_2_from_to_glb_cluster_7
                                            & weight_GLB_read_en_2_from_to_glb_cluster_8 & weight_GLB_read_en_2_from_to_glb_cluster_9
                                            & weight_GLB_read_en_2_from_to_glb_cluster_10 & weight_GLB_read_en_2_from_to_glb_cluster_11
                                            & weight_GLB_read_en_2_from_to_glb_cluster_12 & weight_GLB_read_en_2_from_to_glb_cluster_13
                                            & weight_GLB_read_en_2_from_to_glb_cluster_14 & weight_GLB_read_en_2_from_to_glb_cluster_15;

    assign weight_GLB_read_addr_0_to_glb = weight_GLB_read_addr_0_to_glb_cluster_0;
    assign weight_GLB_read_addr_1_to_glb = weight_GLB_read_addr_1_to_glb_cluster_0;
    assign weight_GLB_read_addr_2_to_glb = weight_GLB_read_addr_2_to_glb_cluster_0;

// reset logic
local_reset local_reset_instance (
	.clock(clock),
	.global_reset(global_reset),
	.rearrange_col_done(rearrange_col_done_from_rearrange_to_top),
    .local_reset(local_reset)
);


iact_distribution #(
    .IACT_WIDTH (IACT_WIDTH),   
    .IACT_SRAM_DEPTH (IACT_SRAM_DEPTH), 
	.IACT_SRAM_ADDRESS_SIZE (IACT_SRAM_ADDRESS_SIZE),
    .NUMBER_OF_CLUSTERS (NUMBER_OF_CLUSTERS),
    .DRAM_ADDRESS_SIZE (DRAM_ADDRESS_SIZE) 
) iact_distribution_instance (
    .clock(clock),
    .reset(global_reset),
    .enable(iact_dist_enable),

	.local_reset(local_reset),

	.cycles_per_iact_col(cycles_per_iact_col), // = 16
    .unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle), // = 12

    // between iact_dist and dram
    .iact_data_in_from_dram_to_iact_dist(iact_data_in_from_dram_to_iact_dist),
    .iact_data_in_addr_from_iact_dist_to_dram(iact_data_in_addr_from_iact_dist_to_dram),

    // between iact_dist and glb
    .iact_data_out_valid_from_iact_dist_to_glb(iact_data_out_valid_from_iact_dist_to_glb),
    .iact_data_out_ready_from_glb_to_iact_dist(iact_data_out_ready_from_glb_to_iact_dist),
    .iact_data_out_from_iact_dist_to_glb(iact_data_out_from_iact_dist_to_glb)
);


rearrange # (
    .PSUM_WIDTH(PSUM_WIDTH),  
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH (PSUM_SRAM_DEPTH), // This must be equal to 2^(ADDRESS_SIZE)
    .PSUM_WRITE_COUNT_SIZE (PSUM_WRITE_COUNT_SIZE),
	.REARANGE_MEM_DEPTH (REARANGE_MEM_DEPTH),
	.CLUSTER_GROUPS (CLUSTER_GROUPS),
	.PE_COL(PE_COL) 
)
rearrange_inst
(
.clock(clock),
.reset(global_reset),
.cycles_per_iact_col(cycles_per_iact_col),
.glb_write_done_cluster_0(glb_write_done_cluster_0),
.glb_write_done_cluster_1(glb_write_done_cluster_1),
.glb_write_done_cluster_2(glb_write_done_cluster_2),
.glb_write_done_cluster_3(glb_write_done_cluster_3),
.glb_write_done_cluster_4(glb_write_done_cluster_4),
.glb_write_done_cluster_5(glb_write_done_cluster_5),
.glb_write_done_cluster_6(glb_write_done_cluster_6),
.glb_write_done_cluster_7(glb_write_done_cluster_7),
.glb_write_done_cluster_8(glb_write_done_cluster_8),
.glb_write_done_cluster_9(glb_write_done_cluster_9),
.glb_write_done_cluster_10(glb_write_done_cluster_10),
.glb_write_done_cluster_11(glb_write_done_cluster_11),
.glb_write_done_cluster_12(glb_write_done_cluster_12),
.glb_write_done_cluster_13(glb_write_done_cluster_13),
.glb_write_done_cluster_14(glb_write_done_cluster_14),
.glb_write_done_cluster_15(glb_write_done_cluster_15),

.glb_counter(glb_counter_from_rearrange_to_top),
.cluster_counter(cluster_counter_from_rearrange_to_top),
.glb_read_idx_counter(glb_read_idx_counter_from_rearrange_to_top),

.pixel_in_ready(pixel_in_ready_from_rearrange_to_psum_glb),
.pixel_in_data(pixel_in_data_from_psum_glb_to_rearrange),
.pixel_in_valid(pixel_in_valid_from_psum_glb_to_rearrange),

.output_pixel_ready(output_pixel_ready_from_dram_to_rearrange),
.output_pixel_data(output_pixel_data_from_rearrange_to_dram),
.output_pixel_valid(output_pixel_valid_from_rearrange_to_dram),

.psum_glb_read_address(psum_glb_read_address_from_rearrange_to_psum_glb),
.psum_read_address_initial(psum_read_address_initial_from_rearrange_to_psum_glb),

.read_done_from_dram(read_done_from_dram_to_rearrange), 
.rearrange_col_done(rearrange_col_done_from_rearrange_to_top)
);


weight_SRAM #(
	.WEIGHT_SIZE(WEIGHT_WIDTH),
    .WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
    .WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE)
) weight_SRAM_instance (
	.clock(clock),
	.reset(local_reset),

    // write port
	.data_in_ready(weight_data_in_ready_from_glb_to_dram),
	.data_in_valid(weight_data_in_valid_from_dram_to_glb),
	.data_in(weight_data_in_from_dram_to_glb),

	// read port 0
	.data_out_ready_0(weight_0_GLB_data_in_ready_from_router_to_weight_glb),
	.data_out_valid_0(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.data_out_0(weight_0_GLB_data_in_from_weight_glb_to_router),
	// read port 1
	.data_out_ready_1(weight_1_GLB_data_in_ready_from_router_to_weight_glb),
	.data_out_valid_1(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.data_out_1(weight_1_GLB_data_in_from_weight_glb_to_router),
	// read port 2
	.data_out_ready_2(weight_2_GLB_data_in_ready_from_router_to_weight_glb),
	.data_out_valid_2(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.data_out_2(weight_2_GLB_data_in_from_weight_glb_to_router),
	
	// write control signals
	.write_address(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.write_en(weight_GLB_write_en_from_ctrl_to_glb),
	.write_addr(weight_GLB_write_addr_from_ctrl_to_glb),
	.write_done(weight_GLB_write_done_from_glb_to_ctrl),

	// read port 0 control signals 
	.read_en_0(weight_GLB_read_en_0_from_to_glb),
	.read_addr_0(weight_GLB_read_addr_0_to_glb),
	.read_done_0(weight_GLB_read_done_0_from_glb),
	// read port 1 control signals
	.read_en_1(weight_GLB_read_en_1_from_to_glb),
	.read_addr_1(weight_GLB_read_addr_1_to_glb),
	.read_done_1(weight_GLB_read_done_1_from_glb),
	// read port 2 control signals
	.read_en_2(weight_GLB_read_en_2_from_to_glb),
	.read_addr_2(weight_GLB_read_addr_2_to_glb),
	.read_done_2(weight_GLB_read_done_2_from_glb),

	.read_address_0(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.read_address_1(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.read_address_2(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);


	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;
	wire signed[PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;

	reg psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15;
	wire psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;
	wire signed [PSUM_WIDTH - 1 : 0] psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;

	reg psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15;
	wire psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;
	wire signed [PSUM_WIDTH - 1 : 0] psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;

	reg psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15;
	wire psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;
	wire signed [PSUM_WIDTH - 1 : 0] psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;

	reg psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15;
	wire psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;
	wire signed [PSUM_WIDTH - 1 : 0] psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;


	reg psum0_read_en_cluster_0;
	reg psum1_read_en_cluster_0;
	reg psum2_read_en_cluster_0;
	reg psum3_read_en_cluster_0;

	reg psum0_read_en_cluster_1;
	reg psum1_read_en_cluster_1;
	reg psum2_read_en_cluster_1;
	reg psum3_read_en_cluster_1;

	reg psum0_read_en_cluster_2;
	reg psum1_read_en_cluster_2;
	reg psum2_read_en_cluster_2;
	reg psum3_read_en_cluster_2;

	reg psum0_read_en_cluster_3;
	reg psum1_read_en_cluster_3;
	reg psum2_read_en_cluster_3;
	reg psum3_read_en_cluster_3;

	reg psum0_read_en_cluster_4;
	reg psum1_read_en_cluster_4;
	reg psum2_read_en_cluster_4;
	reg psum3_read_en_cluster_4;

	reg psum0_read_en_cluster_5;
	reg psum1_read_en_cluster_5;
	reg psum2_read_en_cluster_5;
	reg psum3_read_en_cluster_5;

	reg psum0_read_en_cluster_6;
	reg psum1_read_en_cluster_6;
	reg psum2_read_en_cluster_6;
	reg psum3_read_en_cluster_6;

	reg psum0_read_en_cluster_7;
	reg psum1_read_en_cluster_7;
	reg psum2_read_en_cluster_7;
	reg psum3_read_en_cluster_7;

	reg psum0_read_en_cluster_8;
	reg psum1_read_en_cluster_8;
	reg psum2_read_en_cluster_8;
	reg psum3_read_en_cluster_8;

	reg psum0_read_en_cluster_9;
	reg psum1_read_en_cluster_9;
	reg psum2_read_en_cluster_9;
	reg psum3_read_en_cluster_9;

	reg psum0_read_en_cluster_10;
	reg psum1_read_en_cluster_10;
	reg psum2_read_en_cluster_10;
	reg psum3_read_en_cluster_10;

	reg psum0_read_en_cluster_11;
	reg psum1_read_en_cluster_11;
	reg psum2_read_en_cluster_11;
	reg psum3_read_en_cluster_11;

	reg psum0_read_en_cluster_12;
	reg psum1_read_en_cluster_12;
	reg psum2_read_en_cluster_12;
	reg psum3_read_en_cluster_12;

	reg psum0_read_en_cluster_13;
	reg psum1_read_en_cluster_13;
	reg psum2_read_en_cluster_13;
	reg psum3_read_en_cluster_13;

	reg psum0_read_en_cluster_14;
	reg psum1_read_en_cluster_14;
	reg psum2_read_en_cluster_14;
	reg psum3_read_en_cluster_14;

	reg psum0_read_en_cluster_15;
	reg psum1_read_en_cluster_15;
	reg psum2_read_en_cluster_15;
	reg psum3_read_en_cluster_15;

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_0 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_0),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_0),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_0),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),

	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_0),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_0),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_0),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_0),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_0),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_0),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_0),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_0),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[0]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[0]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_0),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_0),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_0),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_0),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_0),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_0),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_0),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_0),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_0),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_0),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_0),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_0),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_1 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_1),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_1),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_1),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),

	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_1),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_1),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_1),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_1),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_1),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_1),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_1),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_1),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[1]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[1]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_1),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_1),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_1),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_1),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_1),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_1),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_1),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_1),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_1),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_1),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_1),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_1),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_2 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_2),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_2),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_2),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_2),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_2),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_2),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_2),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_2),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_2),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_2),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_2),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[2]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[2]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_2),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_2),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_2),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_2),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_2),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_2),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_2),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_2),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_2),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_2),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_2),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_2),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_3 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_3),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_3),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_3),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_3),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_3),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_3),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_3),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_3),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_3),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_3),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_3),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[3]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[3]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_3),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_3),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_3),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_3),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_3),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_3),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_3),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_3),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_3),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_3),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_3),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_3),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_4 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_4),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_4),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_4),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_4),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_4),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_4),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_4),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_4),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_4),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_4),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_4),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[4]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[4]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_4),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_4),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_4),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_4),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_4),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_4),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_4),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_4),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_4),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_4),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_4),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_4),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_5 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_5),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_5),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_5),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_5),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_5),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_5),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_5),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_5),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_5),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_5),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_5),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[5]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[5]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_5),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_5),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_5),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_5),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_5),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_5),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_5),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_5),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_5),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_5),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_5),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_5),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_6 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_6),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_6),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_6),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_6),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_6),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_6),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_6),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_6),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_6),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_6),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_6),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[6]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[6]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_6),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_6),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_6),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_6),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_6),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_6),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_6),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_6),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_6),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_6),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_6),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_6),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_7 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_7),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_7),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_7),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_7),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_7),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_7),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_7),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_7),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_7),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_7),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_7),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[7]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[7]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_7),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_7),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_7),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_7),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_7),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_7),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_7),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_7),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_7),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_7),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_7),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_7),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_8 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_8),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_8),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_8),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_8),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_8),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_8),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_8),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_8),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_8),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_8),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_8),
	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[8]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[8]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_8),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_8),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_8),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_8),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_8),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_8),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_8),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_8),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_8),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_8),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_8),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_8),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_9 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_9),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_9),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_9),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_9),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_9),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_9),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_9),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_9),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_9),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_9),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_9),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[9]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[9]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_9),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_9),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_9),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_9),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_9),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_9),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_9),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_9),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_9),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_9),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_9),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_9),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_10 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_10),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_10),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_10),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_10),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_10),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_10),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_10),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_10),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_10),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_10),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_10),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[10]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[10]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_10),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_10),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_10),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_10),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_10),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_10),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_10),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_10),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_10),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_10),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_10),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_10),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_11 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_11),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_11),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_11),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_11),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_11),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_11),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_11),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_11),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_11),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_11),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_11),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[11]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[11]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_11),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_11),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_11),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_11),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_11),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_11),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_11),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_11),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_11),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_11),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_11),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_11),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_12 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_12),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_12),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_12),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_12),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_12),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_12),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_12),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_12),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_12),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_12),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_12),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[12]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[12]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_12),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_12),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_12),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_12),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_12),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_12),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_12),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_12),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_12),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_12),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_12),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_12),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_13 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_13),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_13),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_13),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_13),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_13),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_13),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_13),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_13),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_13),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_13),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_13),

	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[13]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[13]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_13),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_13),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_13),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_13),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_13),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_13),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_13),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_13),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_13),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_13),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_13),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_13),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_14 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_14),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_14),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_14),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_14),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_14),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_14),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_14),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_14),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_14),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_14),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_14),


	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[14]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[14]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_14),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_14),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_14),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_14),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_14),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_14),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_14),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_14),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_14),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_14),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_14),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_14),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);

TOP_Group #(
    .PE_NUM(PE_NUM),
    .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH),
    .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS),

	.IACT_SRAM_DEPTH(IACT_SRAM_DEPTH),
	.IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
	.WEIGHT_SRAM_DEPTH(WEIGHT_SRAM_DEPTH),
	.WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
	.ADDRESS_SIZE(ADDRESS_SIZE),
	.PSUM_SRAM_DEPTH(PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_COUNT_SIZE)
) cluster_15 (
    .clock(clock),
    .reset(local_reset),
	.iact_dist_enable(iact_dist_enable_15),
    .turn_on(turn_on),
    .top_filter_mode(top_filter_mode),
    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .top_input_mode(top_input_mode),
	.unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
	.unique_values_per_cluster(unique_values_per_cluster),
	.weight_values_per_filter(weight_values_per_filter),

    .last_iact_column(last_iact_column),
	.top_done_iact_column(top_done_iact_column_cluster_15),
	.psum_GLB_write_done_from_glb_to_ctrl(glb_write_done_cluster_15),

	.psum0_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum1_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum2_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),
	.psum3_read_address_initial_from_rearrange_to_glb(glb_read_idx_counter_from_rearrange_to_top),


	.psum0_data_out_ready_from_router_to_glb(psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15),
	.psum0_data_out_valid_from_glb_to_router(psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15),
	.psum0_data_out_from_glb_to_router(psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_15),
	.psum0_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum1_data_out_ready_from_router_to_glb(psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15),
	.psum1_data_out_valid_from_glb_to_router(psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15),
	.psum1_data_out_from_glb_to_router(psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_15),
	.psum1_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum2_data_out_ready_from_router_to_glb(psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15),
	.psum2_data_out_valid_from_glb_to_router(psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15),
	.psum2_data_out_from_glb_to_router(psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_15),
	.psum2_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum3_data_out_ready_from_router_to_glb(psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15),
	.psum3_data_out_valid_from_glb_to_router(psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15),
	.psum3_data_out_from_glb_to_router(psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_15),
	.psum3_read_addr_from_ctrl_to_glb(psum_glb_read_address_from_rearrange_to_psum_glb),

	.psum0_read_en_from_ctrl_to_glb(psum0_read_en_cluster_15),
	.psum1_read_en_from_ctrl_to_glb(psum1_read_en_cluster_15),
	.psum2_read_en_from_ctrl_to_glb(psum2_read_en_cluster_15),
	.psum3_read_en_from_ctrl_to_glb(psum3_read_en_cluster_15),
	// iact DRAM
	.IACT_data_in_ready_from_glb_to_dram(iact_data_out_ready_from_glb_to_iact_dist[15]),
	.IACT_data_in_valid_from_dram_to_glb(iact_data_out_valid_from_iact_dist_to_glb[15]),
	.IACT_data_in_from_dram_to_glb(iact_data_out_from_iact_dist_to_glb),
	.IACT_column_done_flag_from_ctrl_to_top(IACT_column_done_flag_from_ctrl_to_top_cluster_15),
    
    // weight glb
	.weight_GLB_write_address_current_from_weight_glb_to_ctrl(weight_GLB_write_address_current_from_weight_glb_to_ctrl),
	.weight_GLB_write_en_from_ctrl_to_glb(weight_GLB_write_en_from_ctrl_to_glb_cluster_15),
	.weight_GLB_write_addr_from_ctrl_to_glb(weight_GLB_write_addr_from_ctrl_to_glb_cluster_15),
	.weight_GLB_write_done_from_glb_to_ctrl(weight_GLB_write_done_from_glb_to_ctrl),

	.weight_0_GLB_data_in_ready_from_router_to_weight_glb(weight_0_GLB_data_in_ready_from_router_to_weight_glb_cluster_15),
	.weight_0_GLB_data_in_valid_from_weight_glb_to_router(weight_0_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_0_GLB_data_in_from_weight_glb_to_router(weight_0_GLB_data_in_from_weight_glb_to_router),

	.weight_1_GLB_data_in_ready_from_router_to_weight_glb(weight_1_GLB_data_in_ready_from_router_to_weight_glb_cluster_15),
	.weight_1_GLB_data_in_valid_from_weight_glb_to_router(weight_1_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_1_GLB_data_in_from_weight_glb_to_router(weight_1_GLB_data_in_from_weight_glb_to_router),

	.weight_2_GLB_data_in_ready_from_router_to_weight_glb(weight_2_GLB_data_in_ready_from_router_to_weight_glb_cluster_15),
	.weight_2_GLB_data_in_valid_from_weight_glb_to_router(weight_2_GLB_data_in_valid_from_weight_glb_to_router),
	.weight_2_GLB_data_in_from_weight_glb_to_router(weight_2_GLB_data_in_from_weight_glb_to_router),

	.weight_GLB_read_en_0_from_to_glb(weight_GLB_read_en_0_from_to_glb_cluster_15),
	.weight_GLB_read_addr_0_to_glb(weight_GLB_read_addr_0_to_glb_cluster_15),
	.weight_GLB_read_done_0_from_glb(weight_GLB_read_done_0_from_glb),

	.weight_GLB_read_en_1_from_to_glb(weight_GLB_read_en_1_from_to_glb_cluster_15),
	.weight_GLB_read_addr_1_to_glb(weight_GLB_read_addr_1_to_glb_cluster_15),
	.weight_GLB_read_done_1_from_glb(weight_GLB_read_done_1_from_glb),
	
	.weight_GLB_read_en_2_from_to_glb(weight_GLB_read_en_2_from_to_glb_cluster_15),
	.weight_GLB_read_addr_2_to_glb(weight_GLB_read_addr_2_to_glb_cluster_15),
	.weight_GLB_read_done_2_to_glb(weight_GLB_read_done_2_from_glb),

	.weight_GLB_read_address_0_current_from_weight_glb_to_ctrl(weight_GLB_read_address_0_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_1_current_from_weight_glb_to_ctrl(weight_GLB_read_address_1_current_from_weight_glb_to_ctrl),
	.weight_GLB_read_address_2_current_from_weight_glb_to_ctrl(weight_GLB_read_address_2_current_from_weight_glb_to_ctrl)
);


always @(*) begin
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = 1'b0;
	psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = 1'b0;
	psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = 1'b0;
	psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = 1'b0;
	psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = 1'b0;
	psum0_read_en_cluster_0 = 1'b0;
	psum1_read_en_cluster_0 = 1'b0;
	psum2_read_en_cluster_0 = 1'b0;
	psum3_read_en_cluster_0 = 1'b0;
	psum0_read_en_cluster_1 = 1'b0;
	psum1_read_en_cluster_1 = 1'b0;
	psum2_read_en_cluster_1 = 1'b0;
	psum3_read_en_cluster_1 = 1'b0;
	psum0_read_en_cluster_2 = 1'b0;
	psum1_read_en_cluster_2 = 1'b0;
	psum2_read_en_cluster_2 = 1'b0;
	psum3_read_en_cluster_2 = 1'b0;
	psum0_read_en_cluster_3 = 1'b0;
	psum1_read_en_cluster_3 = 1'b0;
	psum2_read_en_cluster_3 = 1'b0;
	psum3_read_en_cluster_3 = 1'b0;
	psum0_read_en_cluster_4 = 1'b0;
	psum1_read_en_cluster_4 = 1'b0;
	psum2_read_en_cluster_4 = 1'b0;
	psum3_read_en_cluster_4 = 1'b0;
	psum0_read_en_cluster_5 = 1'b0;
	psum1_read_en_cluster_5 = 1'b0;
	psum2_read_en_cluster_5 = 1'b0;
	psum3_read_en_cluster_5 = 1'b0;
	psum0_read_en_cluster_6 = 1'b0;
	psum1_read_en_cluster_6 = 1'b0;
	psum2_read_en_cluster_6 = 1'b0;
	psum3_read_en_cluster_6 = 1'b0;
	psum0_read_en_cluster_7 = 1'b0;
	psum1_read_en_cluster_7 = 1'b0;
	psum2_read_en_cluster_7 = 1'b0;
	psum3_read_en_cluster_7 = 1'b0;
	psum0_read_en_cluster_8 = 1'b0;
	psum1_read_en_cluster_8 = 1'b0;
	psum2_read_en_cluster_8 = 1'b0;
	psum3_read_en_cluster_8 = 1'b0;
	psum0_read_en_cluster_9 = 1'b0;
	psum1_read_en_cluster_9 = 1'b0;
	psum2_read_en_cluster_9 = 1'b0;
	psum3_read_en_cluster_9 = 1'b0;
	psum0_read_en_cluster_10 = 1'b0;
	psum1_read_en_cluster_10 = 1'b0;
	psum2_read_en_cluster_10 = 1'b0;
	psum3_read_en_cluster_10 = 1'b0;
	psum0_read_en_cluster_11 = 1'b0;
	psum1_read_en_cluster_11 = 1'b0;
	psum2_read_en_cluster_11 = 1'b0;
	psum3_read_en_cluster_11 = 1'b0;
	psum0_read_en_cluster_12 = 1'b0;
	psum1_read_en_cluster_12 = 1'b0;
	psum2_read_en_cluster_12 = 1'b0;
	psum3_read_en_cluster_12 = 1'b0;
	psum0_read_en_cluster_13 = 1'b0;
	psum1_read_en_cluster_13 = 1'b0;
	psum2_read_en_cluster_13 = 1'b0;
	psum3_read_en_cluster_13 = 1'b0;
	psum0_read_en_cluster_14 = 1'b0;
	psum1_read_en_cluster_14 = 1'b0;
	psum2_read_en_cluster_14 = 1'b0;
	psum3_read_en_cluster_14 = 1'b0;
	psum0_read_en_cluster_15 = 1'b0;
	psum1_read_en_cluster_15 = 1'b0;
	psum2_read_en_cluster_15 = 1'b0;
	psum3_read_en_cluster_15 = 1'b0;
	case(cluster_counter_from_rearrange_to_top)  
	cluster0: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_0 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;
		end 
		glb_1: begin
			psum1_read_en_cluster_0 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;			
		end 
		glb_2: begin
			psum2_read_en_cluster_0 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;			
		end 
		glb_3: begin
			psum3_read_en_cluster_0 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_0 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_0;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_0;
		end 
		endcase
	end 
	cluster1: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_1 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;
		end 
		glb_1: begin
			psum1_read_en_cluster_1 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;			
		end 
		glb_2: begin
			psum2_read_en_cluster_1 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;			
		end 
		glb_3: begin
			psum3_read_en_cluster_1 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_1 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_1;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_1;
		end 
		endcase
	end 
	cluster2: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_2 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;
		end 
		glb_1: begin
			psum1_read_en_cluster_2 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;			
		end 
		glb_2: begin
			psum2_read_en_cluster_2 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;			
		end 
		glb_3: begin
			psum3_read_en_cluster_2 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_2 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_2;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_2;
		end 
		endcase
	end 
	cluster3: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_3 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;
		end 
		glb_1: begin
			psum1_read_en_cluster_3 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;			
		end 
		glb_2: begin
			psum2_read_en_cluster_3 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;			
		end 
		glb_3: begin
			psum3_read_en_cluster_3 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_3 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_3;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_3;
		end 
		endcase
	end 
	cluster4: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_4 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;
		end 
		glb_1: begin
			psum1_read_en_cluster_4 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;			
		end 
		glb_2: begin
			psum2_read_en_cluster_4 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;			
		end 
		glb_3: begin
			psum3_read_en_cluster_4 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_4 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_4;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_4;
		end 
		endcase
	end 
	cluster5: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_5 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;
		end 
		glb_1: begin
			psum1_read_en_cluster_5 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;			
		end 
		glb_2: begin
			psum2_read_en_cluster_5 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;			
		end 
		glb_3: begin
			psum3_read_en_cluster_5 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_5 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_5;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_5;
		end 
		endcase
	end 
	cluster6: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_6 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;
		end 
		glb_1: begin
			psum1_read_en_cluster_6 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;			
		end 
		glb_2: begin
			psum2_read_en_cluster_6 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;			
		end 
		glb_3: begin
			psum3_read_en_cluster_6 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_6 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_6;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_6;
		end 
		endcase
	end 
	cluster7: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_7 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;
		end 
		glb_1: begin
			psum1_read_en_cluster_7 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;			
		end 
		glb_2: begin
			psum2_read_en_cluster_7 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;			
		end 
		glb_3: begin
			psum3_read_en_cluster_7 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_7 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_7;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_7;
		end 
		endcase
	end 
	cluster8: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_8 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;
		end 
		glb_1: begin
			psum1_read_en_cluster_8 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;			
		end 
		glb_2: begin
			psum2_read_en_cluster_8 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;			
		end 
		glb_3: begin
			psum3_read_en_cluster_8 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_8 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_8;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_8;
		end 
		endcase
	end 
	cluster9: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_9 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;
		end 
		glb_1: begin
			psum1_read_en_cluster_9 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;			
		end 
		glb_2: begin
			psum2_read_en_cluster_9 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;			
		end 
		glb_3: begin
			psum3_read_en_cluster_9 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_9 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_9;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_9;
		end 
		endcase
	end 
	cluster10: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_10 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;
		end 
		glb_1: begin
			psum1_read_en_cluster_10 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;			
		end 
		glb_2: begin
			psum2_read_en_cluster_10 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;			
		end 
		glb_3: begin
			psum3_read_en_cluster_10 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_10 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_10;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_10;
		end 
		endcase
	end 
	cluster11: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_11 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;
		end 
		glb_1: begin
			psum1_read_en_cluster_11 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;			
		end 
		glb_2: begin
			psum2_read_en_cluster_11 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;			
		end 
		glb_3: begin
			psum3_read_en_cluster_11 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_11 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_11;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_11;
		end 
		endcase
	end 
	cluster12: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_12 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;
		end 
		glb_1: begin
			psum1_read_en_cluster_12 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;			
		end 
		glb_2: begin
			psum2_read_en_cluster_12 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;			
		end 
		glb_3: begin
			psum3_read_en_cluster_12 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_12 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_12;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_12;
		end 
		endcase
	end 
	cluster13: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_13 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;
		end 
		glb_1: begin
			psum1_read_en_cluster_13 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;			
		end 
		glb_2: begin
			psum2_read_en_cluster_13 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;			
		end 
		glb_3: begin
			psum3_read_en_cluster_13 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_13 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_13;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_13;
		end 
		endcase
	end 
	cluster14: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_14 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;
		end 
		glb_1: begin
			psum1_read_en_cluster_14 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;			
		end 
		glb_2: begin
			psum2_read_en_cluster_14 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;			
		end 
		glb_3: begin
			psum3_read_en_cluster_14 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_14 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_14;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_14;
		end 
		endcase
	end 
	cluster15: begin
		case (glb_counter_from_rearrange_to_top) 
		glb_0: begin
			psum0_read_en_cluster_15 = 1'b1;
			psum0_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum0_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;
			pixel_in_valid_from_psum_glb_to_rearrange = psum0_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;
		end 
		glb_1: begin
			psum1_read_en_cluster_15 = 1'b1;
			psum1_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum1_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;
			pixel_in_valid_from_psum_glb_to_rearrange = psum1_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;			
		end 
		glb_2: begin
			psum2_read_en_cluster_15 = 1'b1;
			psum2_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum2_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;
			pixel_in_valid_from_psum_glb_to_rearrange = psum2_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;			
		end 
		glb_3: begin
			psum3_read_en_cluster_15 = 1'b1;
			psum3_pixel_in_ready_from_rearrange_to_psum_glb_cluster_15 = pixel_in_ready_from_rearrange_to_psum_glb;
			pixel_in_data_from_psum_glb_to_rearrange = psum3_pixel_in_data_from_psum_glb_to_rearrange_cluster_15;
			pixel_in_valid_from_psum_glb_to_rearrange = psum3_pixel_in_valid_from_psum_glb_to_rearrange_cluster_15;
		end 
		endcase
	end 
	

	endcase
end 
endmodule
