
module PE_cluster #(
    parameter PE_NUM = 36,
    parameter ROW_NUM = 9,
    parameter IACT_WIDTH = 8,   // iact value bitwidth (INT8)
    parameter WEIGHT_WIDTH = 8, // weight value bitwidth (INT8)
    parameter PSUM_WIDTH = 20,  // accumulator / psum chain bitwidth
    parameter IACT_SPAD_DEPTH = 16, // depth of weight/iact spads (max # unique values per cluster per cycle)
    parameter PSUM_SPAD_DEPTH = 16, // depth of psum spad (max # partial sums per cluster per cycle)
    parameter WEIGHT_SPAD_DEPTH = 9,     // depth of weight spad (max # unique values per cluster per cycle)
    parameter CLUSTER_ROWS = 9 
) (
    input clock,
    input reset,

    input [2:0] top_filter_mode, // affects the number of working PEs, weight spad
    // input [2:0] top_input_mode, // affects the iact spad 

    input top_load_PEs_weight_pe, // from cluster group controller to start loading weights
    output reg load_PEs_weight_done_top, // to cluster group controller to flag weights load done
    input top_load_PEs_iact_pe, // from cluster group controller to start loading iacts
    output reg load_PEs_iact_done_top, // to cluster group controller to flag iacts load done

    // input top_read_PE_psum_pe, // from cluster group to read psum spad (final output)
    // psum out 
    input top_mac_en_pe, // from cluster group controller to start mac operation
    output reg mac_done_top, // to cluster group controller to flag mac done

    input top_psum_stream_start_pe, // from cluster group controller to start psum stream
    output reg psum_stream_done_top, // to cluster group controller to flag psum stream done
    input top_PSUM_to_GLB_en_pe, // from cluster group controller to start writing final psum values to GLB
    output reg PSUM_to_GLB_done_top, // to cluster group controller to flag psum sent to GLB

    input PE_mode, // 0 -> mac, 1 -> stream

    input [4:0] cycles_per_iact_col,
    input [3:0] weight_columns,
    input [3:0] psum_spad_write_index, // mac_done_counter
    input [3:0] weight_spad_index, // weight_column_counter

// finals psums to be stored in psum GLB
    input final_psum_out_ready_glb0,
    output reg final_psum_out_valid_glb0,
    output reg signed [PSUM_WIDTH-1:0] final_psum_out_glb0,
    input final_psum_out_ready_glb1,
    output reg final_psum_out_valid_glb1,
    output reg signed [PSUM_WIDTH-1:0] final_psum_out_glb1,
    input final_psum_out_ready_glb2,
    output reg final_psum_out_valid_glb2,
    output reg signed [PSUM_WIDTH-1:0] final_psum_out_glb2,
    input final_psum_out_ready_glb3,
    output reg final_psum_out_valid_glb3,
    output reg signed [PSUM_WIDTH-1:0] final_psum_out_glb3,

// iact and weight data to be written to PEs inside spads
    output PE00_iact_weight_data_ready,
    input PE00_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE00_iact_weight_data,
    output PE01_iact_weight_data_ready,
    input PE01_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE01_iact_weight_data,
    output PE02_iact_weight_data_ready,
    input PE02_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE02_iact_weight_data,
    output PE03_iact_weight_data_ready,
    input PE03_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE03_iact_weight_data,

    output PE10_iact_weight_data_ready,
    input PE10_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE10_iact_weight_data,
    output PE11_iact_weight_data_ready,
    input PE11_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE11_iact_weight_data,
    output PE12_iact_weight_data_ready,
    input PE12_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE12_iact_weight_data,
    output PE13_iact_weight_data_ready,
    input PE13_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE13_iact_weight_data,

    output PE20_iact_weight_data_ready,
    input PE20_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE20_iact_weight_data,
    output PE21_iact_weight_data_ready,
    input PE21_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE21_iact_weight_data,
    output PE22_iact_weight_data_ready,
    input PE22_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE22_iact_weight_data,
    output PE23_iact_weight_data_ready,
    input PE23_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE23_iact_weight_data,

    output PE30_iact_weight_data_ready,
    input PE30_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE30_iact_weight_data,
    output PE31_iact_weight_data_ready,
    input PE31_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE31_iact_weight_data,
    output PE32_iact_weight_data_ready,
    input PE32_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE32_iact_weight_data,
    output PE33_iact_weight_data_ready,
    input PE33_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE33_iact_weight_data,

    output PE40_iact_weight_data_ready,
    input PE40_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE40_iact_weight_data,
    output PE41_iact_weight_data_ready,
    input PE41_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE41_iact_weight_data,
    output PE42_iact_weight_data_ready,
    input PE42_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE42_iact_weight_data,
    output PE43_iact_weight_data_ready,  
    input PE43_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE43_iact_weight_data,

    output PE50_iact_weight_data_ready,
    input PE50_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE50_iact_weight_data,
    output PE51_iact_weight_data_ready,
    input PE51_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE51_iact_weight_data,
    output PE52_iact_weight_data_ready,
    input PE52_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE52_iact_weight_data,
    output PE53_iact_weight_data_ready,
    input PE53_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE53_iact_weight_data,

    output PE60_iact_weight_data_ready,
    input PE60_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE60_iact_weight_data,
    output PE61_iact_weight_data_ready,
    input PE61_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE61_iact_weight_data,
    output PE62_iact_weight_data_ready,
    input PE62_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE62_iact_weight_data,
    output PE63_iact_weight_data_ready,
    input PE63_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE63_iact_weight_data,

    output PE70_iact_weight_data_ready,  
    input PE70_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE70_iact_weight_data,
    output PE71_iact_weight_data_ready,
    input PE71_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE71_iact_weight_data,
    output PE72_iact_weight_data_ready,
    input PE72_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE72_iact_weight_data,
    output PE73_iact_weight_data_ready,
    input PE73_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE73_iact_weight_data,

    output PE80_iact_weight_data_ready,
    input PE80_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE80_iact_weight_data,
    output PE81_iact_weight_data_ready,
    input PE81_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE81_iact_weight_data,
    output PE82_iact_weight_data_ready,
    input PE82_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE82_iact_weight_data,
    output PE83_iact_weight_data_ready,
    input PE83_iact_weight_data_valid,
    input signed [IACT_WIDTH-1:0] PE83_iact_weight_data
);

// filter modes
    localparam FILTER_3 = 'd0;
    localparam FILTER_5 = 'd1;
    localparam FILTER_7 = 'd2;
    localparam FILTER_9 = 'd3;

reg [PE_NUM-1 : 0] PE_disable; // per row, apply it sequentially indide pe

// psum_in_ready signals 
    wire PE00_psum_in_ready;
    wire PE01_psum_in_ready;
    wire PE02_psum_in_ready;
    wire PE03_psum_in_ready;

    wire PE10_psum_in_ready;
    wire PE11_psum_in_ready;
    wire PE12_psum_in_ready;
    wire PE13_psum_in_ready;

    wire PE20_psum_in_ready;
    wire PE21_psum_in_ready;
    wire PE22_psum_in_ready;
    wire PE23_psum_in_ready;

    wire PE30_psum_in_ready;
    wire PE31_psum_in_ready;
    wire PE32_psum_in_ready;
    wire PE33_psum_in_ready;

    wire PE40_psum_in_ready;
    wire PE41_psum_in_ready;
    wire PE42_psum_in_ready;
    wire PE43_psum_in_ready;

    wire PE50_psum_in_ready;
    wire PE51_psum_in_ready;
    wire PE52_psum_in_ready;
    wire PE53_psum_in_ready;

    wire PE60_psum_in_ready;
    wire PE61_psum_in_ready;
    wire PE62_psum_in_ready;
    wire PE63_psum_in_ready;

    wire PE70_psum_in_ready;
    wire PE71_psum_in_ready;
    wire PE72_psum_in_ready;
    wire PE73_psum_in_ready;

    wire PE80_psum_in_ready;
    wire PE81_psum_in_ready;
    wire PE82_psum_in_ready;
    wire PE83_psum_in_ready;

// psum_out signals
    wire PE00_psum_out_ready = PE10_psum_in_ready;
    wire PE00_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE00_psum_out;

    wire PE01_psum_out_ready = PE11_psum_in_ready;
    wire PE01_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE01_psum_out;

    wire PE02_psum_out_ready = PE12_psum_in_ready;
    wire PE02_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE02_psum_out;

    wire PE03_psum_out_ready = PE13_psum_in_ready;
    wire PE03_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE03_psum_out;

    wire PE10_psum_out_ready = PE20_psum_in_ready;
    wire PE10_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE10_psum_out;

    wire PE11_psum_out_ready = PE21_psum_in_ready;
    wire PE11_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE11_psum_out;

    wire PE12_psum_out_ready = PE22_psum_in_ready;
    wire PE12_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE12_psum_out;

    wire PE13_psum_out_ready = PE23_psum_in_ready;
    wire PE13_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE13_psum_out;

    wire PE20_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb0 : PE30_psum_in_ready;
    wire PE20_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE20_psum_out;

    wire PE21_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb1 : PE31_psum_in_ready;
    wire PE21_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE21_psum_out;

    wire PE22_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb2 : PE32_psum_in_ready;
    wire PE22_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE22_psum_out;

    wire PE23_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb3 : PE33_psum_in_ready;
    wire PE23_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE23_psum_out;

    wire PE30_psum_out_ready = PE40_psum_in_ready;
    wire PE30_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE30_psum_out;

    wire PE31_psum_out_ready = PE41_psum_in_ready;
    wire PE31_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE31_psum_out;

    wire PE32_psum_out_ready = PE42_psum_in_ready;
    wire PE32_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE32_psum_out;

    wire PE33_psum_out_ready = PE43_psum_in_ready;
    wire PE33_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE33_psum_out;

    wire PE40_psum_out_ready = (top_filter_mode == FILTER_5)? final_psum_out_ready_glb0 : PE50_psum_in_ready;
    wire PE40_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE40_psum_out;

    wire PE41_psum_out_ready = (top_filter_mode == FILTER_5)? final_psum_out_ready_glb1 : PE51_psum_in_ready;
    wire PE41_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE41_psum_out;

    wire PE42_psum_out_ready = (top_filter_mode == FILTER_5)? final_psum_out_ready_glb2 : PE52_psum_in_ready;
    wire PE42_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE42_psum_out;

    wire PE43_psum_out_ready = (top_filter_mode == FILTER_5)? final_psum_out_ready_glb3 : PE53_psum_in_ready;
    wire PE43_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE43_psum_out;

    wire PE50_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb0 : PE60_psum_in_ready;
    wire PE50_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE50_psum_out;

    wire PE51_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb1 : PE61_psum_in_ready;
    wire PE51_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE51_psum_out;

    wire PE52_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb2 : PE62_psum_in_ready;
    wire PE52_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE52_psum_out;

    wire PE53_psum_out_ready = (top_filter_mode == FILTER_3)? final_psum_out_ready_glb3 : PE63_psum_in_ready;
    wire PE53_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE53_psum_out;

    wire PE60_psum_out_ready = (top_filter_mode == FILTER_7)? final_psum_out_ready_glb0 : PE70_psum_in_ready;
    wire PE60_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE60_psum_out;

    wire PE61_psum_out_ready = (top_filter_mode == FILTER_7)? final_psum_out_ready_glb1 : PE71_psum_in_ready;
    wire PE61_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE61_psum_out;

    wire PE62_psum_out_ready = (top_filter_mode == FILTER_7)? final_psum_out_ready_glb2 : PE72_psum_in_ready;
    wire PE62_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE62_psum_out;

    wire PE63_psum_out_ready = (top_filter_mode == FILTER_7)? final_psum_out_ready_glb3 : PE73_psum_in_ready;
    wire PE63_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE63_psum_out;

    wire PE70_psum_out_ready = PE80_psum_in_ready;
    wire PE70_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE70_psum_out;

    wire PE71_psum_out_ready = PE81_psum_in_ready;
    wire PE71_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE71_psum_out;

    wire PE72_psum_out_ready = PE82_psum_in_ready;
    wire PE72_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE72_psum_out;

    wire PE73_psum_out_ready = PE83_psum_in_ready;
    wire PE73_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE73_psum_out;

    wire PE80_psum_out_ready = final_psum_out_ready_glb0;
    wire PE80_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE80_psum_out;

    wire PE81_psum_out_ready = final_psum_out_ready_glb1;
    wire PE81_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE81_psum_out;

    wire PE82_psum_out_ready = final_psum_out_ready_glb2;
    wire PE82_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE82_psum_out;

    wire PE83_psum_out_ready = final_psum_out_ready_glb3;
    wire PE83_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE83_psum_out;

// psum_in signals
    wire PE00_psum_in_valid = 1;
    wire signed [PSUM_WIDTH-1:0] PE00_psum_in = 0;

    wire PE01_psum_in_valid = 1;
    wire signed [PSUM_WIDTH-1:0] PE01_psum_in = 0;

    wire PE02_psum_in_valid = 1;
    wire signed [PSUM_WIDTH-1:0] PE02_psum_in = 0;

    wire PE03_psum_in_valid = 1;
    wire signed [PSUM_WIDTH-1:0] PE03_psum_in = 0;

    wire PE10_psum_in_valid = PE00_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE10_psum_in = PE00_psum_out;

    wire PE11_psum_in_valid = PE01_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE11_psum_in = PE01_psum_out;

    wire PE12_psum_in_valid = PE02_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE12_psum_in = PE02_psum_out;

    wire PE13_psum_in_valid = PE03_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE13_psum_in = PE03_psum_out;

    wire PE20_psum_in_valid = PE10_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE20_psum_in = PE10_psum_out;

    wire PE21_psum_in_valid = PE11_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE21_psum_in = PE11_psum_out;

    wire PE22_psum_in_valid = PE12_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE22_psum_in = PE12_psum_out;

    wire PE23_psum_in_valid = PE13_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE23_psum_in = PE13_psum_out;

    wire PE30_psum_in_valid = PE20_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE30_psum_in = PE20_psum_out;

    wire PE31_psum_in_valid = PE21_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE31_psum_in = PE21_psum_out;

    wire PE32_psum_in_valid = PE22_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE32_psum_in = PE22_psum_out;

    wire PE33_psum_in_valid = PE23_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE33_psum_in = PE23_psum_out;

    wire PE40_psum_in_valid = PE30_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE40_psum_in = PE30_psum_out;

    wire PE41_psum_in_valid = PE31_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE41_psum_in = PE31_psum_out;

    wire PE42_psum_in_valid = PE32_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE42_psum_in = PE32_psum_out;

    wire PE43_psum_in_valid = PE33_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE43_psum_in = PE33_psum_out;

    wire PE50_psum_in_valid = PE40_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE50_psum_in = PE40_psum_out;

    wire PE51_psum_in_valid = PE41_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE51_psum_in = PE41_psum_out;

    wire PE52_psum_in_valid = PE42_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE52_psum_in = PE42_psum_out;

    wire PE53_psum_in_valid = PE43_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE53_psum_in = PE43_psum_out;

    wire PE60_psum_in_valid = PE50_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE60_psum_in = PE50_psum_out;

    wire PE61_psum_in_valid = PE51_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE61_psum_in = PE51_psum_out;

    wire PE62_psum_in_valid = PE52_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE62_psum_in = PE52_psum_out;

    wire PE63_psum_in_valid = PE53_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE63_psum_in = PE53_psum_out;

    wire PE70_psum_in_valid = PE60_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE70_psum_in = PE60_psum_out;

    wire PE71_psum_in_valid = PE61_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE71_psum_in = PE61_psum_out;

    wire PE72_psum_in_valid = PE62_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE72_psum_in = PE62_psum_out;

    wire PE73_psum_in_valid = PE63_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE73_psum_in = PE63_psum_out;

    wire PE80_psum_in_valid = PE70_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE80_psum_in = PE70_psum_out;

    wire PE81_psum_in_valid = PE71_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE81_psum_in = PE71_psum_out;

    wire PE82_psum_in_valid = PE72_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE82_psum_in = PE72_psum_out;

    wire PE83_psum_in_valid = PE73_psum_out_valid;
    wire signed [PSUM_WIDTH-1:0] PE83_psum_in = PE73_psum_out;

// to flag weight load is done inside PEs
    wire PE00_weight_load_done;
    wire PE01_weight_load_done;
    wire PE02_weight_load_done;
    wire PE03_weight_load_done;

    wire PE10_weight_load_done;
    wire PE11_weight_load_done;
    wire PE12_weight_load_done;
    wire PE13_weight_load_done;

    wire PE20_weight_load_done;
    wire PE21_weight_load_done;
    wire PE22_weight_load_done;
    wire PE23_weight_load_done;

    wire PE30_weight_load_done;
    wire PE31_weight_load_done;
    wire PE32_weight_load_done;
    wire PE33_weight_load_done;

    wire PE40_weight_load_done;
    wire PE41_weight_load_done;
    wire PE42_weight_load_done;
    wire PE43_weight_load_done;

    wire PE50_weight_load_done;
    wire PE51_weight_load_done;
    wire PE52_weight_load_done;
    wire PE53_weight_load_done;

    wire PE60_weight_load_done;
    wire PE61_weight_load_done;
    wire PE62_weight_load_done;
    wire PE63_weight_load_done;

    wire PE70_weight_load_done;
    wire PE71_weight_load_done;
    wire PE72_weight_load_done;
    wire PE73_weight_load_done;

    wire PE80_weight_load_done;
    wire PE81_weight_load_done;
    wire PE82_weight_load_done;
    wire PE83_weight_load_done;

// to flag iact load is done inside PEs
    wire PE00_iact_load_done;
    wire PE01_iact_load_done;
    wire PE02_iact_load_done;
    wire PE03_iact_load_done;

    wire PE10_iact_load_done;
    wire PE11_iact_load_done;
    wire PE12_iact_load_done;
    wire PE13_iact_load_done;

    wire PE20_iact_load_done;
    wire PE21_iact_load_done;
    wire PE22_iact_load_done;
    wire PE23_iact_load_done;

    wire PE30_iact_load_done;
    wire PE31_iact_load_done;
    wire PE32_iact_load_done;
    wire PE33_iact_load_done;

    wire PE40_iact_load_done;
    wire PE41_iact_load_done;
    wire PE42_iact_load_done;
    wire PE43_iact_load_done;

    wire PE50_iact_load_done;
    wire PE51_iact_load_done;
    wire PE52_iact_load_done;
    wire PE53_iact_load_done;

    wire PE60_iact_load_done;
    wire PE61_iact_load_done;
    wire PE62_iact_load_done;
    wire PE63_iact_load_done;

    wire PE70_iact_load_done;
    wire PE71_iact_load_done;
    wire PE72_iact_load_done;
    wire PE73_iact_load_done;

    wire PE80_iact_load_done;
    wire PE81_iact_load_done;
    wire PE82_iact_load_done;
    wire PE83_iact_load_done;

// to flag mac operation is done inside PEs
    wire PE00_mac_done;
    wire PE01_mac_done;
    wire PE02_mac_done;
    wire PE03_mac_done;

    wire PE10_mac_done;
    wire PE11_mac_done;
    wire PE12_mac_done;
    wire PE13_mac_done;

    wire PE20_mac_done;
    wire PE21_mac_done;
    wire PE22_mac_done;
    wire PE23_mac_done;

    wire PE30_mac_done;
    wire PE31_mac_done;
    wire PE32_mac_done;
    wire PE33_mac_done;

    wire PE40_mac_done;
    wire PE41_mac_done;
    wire PE42_mac_done;
    wire PE43_mac_done;

    wire PE50_mac_done;
    wire PE51_mac_done;
    wire PE52_mac_done;
    wire PE53_mac_done;

    wire PE60_mac_done;
    wire PE61_mac_done;
    wire PE62_mac_done;
    wire PE63_mac_done;

    wire PE70_mac_done;
    wire PE71_mac_done;
    wire PE72_mac_done;
    wire PE73_mac_done;

    wire PE80_mac_done;
    wire PE81_mac_done;
    wire PE82_mac_done;
    wire PE83_mac_done;

// to flag psum stream start inside PEs
    wire PE00_psum_stream_start = top_psum_stream_start_pe;
    wire PE01_psum_stream_start = top_psum_stream_start_pe;
    wire PE02_psum_stream_start = top_psum_stream_start_pe;
    wire PE03_psum_stream_start = top_psum_stream_start_pe;

    wire PE10_psum_stream_start = top_psum_stream_start_pe;
    wire PE11_psum_stream_start = top_psum_stream_start_pe;
    wire PE12_psum_stream_start = top_psum_stream_start_pe;
    wire PE13_psum_stream_start = top_psum_stream_start_pe;

    wire PE20_psum_stream_start = top_psum_stream_start_pe;
    wire PE21_psum_stream_start = top_psum_stream_start_pe;
    wire PE22_psum_stream_start = top_psum_stream_start_pe;
    wire PE23_psum_stream_start = top_psum_stream_start_pe;

    wire PE30_psum_stream_start = top_psum_stream_start_pe;
    wire PE31_psum_stream_start = top_psum_stream_start_pe;
    wire PE32_psum_stream_start = top_psum_stream_start_pe;
    wire PE33_psum_stream_start = top_psum_stream_start_pe;

    wire PE40_psum_stream_start = top_psum_stream_start_pe;
    wire PE41_psum_stream_start = top_psum_stream_start_pe;
    wire PE42_psum_stream_start = top_psum_stream_start_pe;
    wire PE43_psum_stream_start = top_psum_stream_start_pe;

    wire PE50_psum_stream_start = top_psum_stream_start_pe;
    wire PE51_psum_stream_start = top_psum_stream_start_pe;
    wire PE52_psum_stream_start = top_psum_stream_start_pe;
    wire PE53_psum_stream_start = top_psum_stream_start_pe;

    wire PE60_psum_stream_start = top_psum_stream_start_pe;
    wire PE61_psum_stream_start = top_psum_stream_start_pe;
    wire PE62_psum_stream_start = top_psum_stream_start_pe;
    wire PE63_psum_stream_start = top_psum_stream_start_pe;

    wire PE70_psum_stream_start = top_psum_stream_start_pe;
    wire PE71_psum_stream_start = top_psum_stream_start_pe;
    wire PE72_psum_stream_start = top_psum_stream_start_pe;
    wire PE73_psum_stream_start = top_psum_stream_start_pe;

    wire PE80_psum_stream_start = top_psum_stream_start_pe;
    wire PE81_psum_stream_start = top_psum_stream_start_pe;
    wire PE82_psum_stream_start = top_psum_stream_start_pe;
    wire PE83_psum_stream_start = top_psum_stream_start_pe;

// to flag psum stream is done inside PEs
    wire PE00_psum_stream_done;
    wire PE01_psum_stream_done;
    wire PE02_psum_stream_done;
    wire PE03_psum_stream_done;

    wire PE10_psum_stream_done;
    wire PE11_psum_stream_done;
    wire PE12_psum_stream_done;
    wire PE13_psum_stream_done;

    wire PE20_psum_stream_done;
    wire PE21_psum_stream_done;
    wire PE22_psum_stream_done;
    wire PE23_psum_stream_done;

    wire PE30_psum_stream_done;
    wire PE31_psum_stream_done;
    wire PE32_psum_stream_done;
    wire PE33_psum_stream_done;

    wire PE40_psum_stream_done;
    wire PE41_psum_stream_done;
    wire PE42_psum_stream_done;
    wire PE43_psum_stream_done;

    wire PE50_psum_stream_done;
    wire PE51_psum_stream_done;
    wire PE52_psum_stream_done;
    wire PE53_psum_stream_done;

    wire PE60_psum_stream_done;
    wire PE61_psum_stream_done;
    wire PE62_psum_stream_done;
    wire PE63_psum_stream_done;

    wire PE70_psum_stream_done;
    wire PE71_psum_stream_done;
    wire PE72_psum_stream_done;
    wire PE73_psum_stream_done;

    wire PE80_psum_stream_done;
    wire PE81_psum_stream_done;
    wire PE82_psum_stream_done;
    wire PE83_psum_stream_done;

// to flag reading psum enable from PE to GLB inside PEs accesses by row
    wire PE0_psum_to_GLB_en = 0;
    wire PE1_psum_to_GLB_en = 0;
    wire PE2_psum_to_GLB_en = (top_filter_mode == FILTER_3)? top_PSUM_to_GLB_en_pe : 0;
    wire PE3_psum_to_GLB_en = 0;
    wire PE4_psum_to_GLB_en = (top_filter_mode == FILTER_5)? top_PSUM_to_GLB_en_pe : 0;
    wire PE5_psum_to_GLB_en = (top_filter_mode == FILTER_3)? top_PSUM_to_GLB_en_pe : 0;
    wire PE6_psum_to_GLB_en = (top_filter_mode == FILTER_7)? top_PSUM_to_GLB_en_pe : 0;
    wire PE7_psum_to_GLB_en = 0;
    wire PE8_psum_to_GLB_en = top_PSUM_to_GLB_en_pe;

// to flag reading psum from PE to GLB is done inside PEs
    wire DUMMY_FLAG_PE00_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE01_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE02_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE03_PSUM_to_GLB_read_done;

    wire DUMMY_FLAG_PE10_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE11_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE12_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE13_PSUM_to_GLB_read_done;

    // 3*3 mode
    wire PE20_PSUM_to_GLB_read_done;
    wire PE21_PSUM_to_GLB_read_done;
    wire PE22_PSUM_to_GLB_read_done;
    wire PE23_PSUM_to_GLB_read_done;

    wire DUMMY_FLAG_PE30_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE31_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE32_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE33_PSUM_to_GLB_read_done;

    // 5*5 mode
    wire PE40_PSUM_to_GLB_read_done;
    wire PE41_PSUM_to_GLB_read_done;
    wire PE42_PSUM_to_GLB_read_done;
    wire PE43_PSUM_to_GLB_read_done;

    // 3*3 mode
    wire PE50_PSUM_to_GLB_read_done;
    wire PE51_PSUM_to_GLB_read_done;
    wire PE52_PSUM_to_GLB_read_done;
    wire PE53_PSUM_to_GLB_read_done;

    // 7*7 mode
    wire PE60_PSUM_to_GLB_read_done;
    wire PE61_PSUM_to_GLB_read_done;
    wire PE62_PSUM_to_GLB_read_done;
    wire PE63_PSUM_to_GLB_read_done;

    wire DUMMY_FLAG_PE70_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE71_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE72_PSUM_to_GLB_read_done;
    wire DUMMY_FLAG_PE73_PSUM_to_GLB_read_done;

    // 3*3 mode and 9*9 mode
    wire PE80_PSUM_to_GLB_read_done;
    wire PE81_PSUM_to_GLB_read_done;
    wire PE82_PSUM_to_GLB_read_done;
    wire PE83_PSUM_to_GLB_read_done;

// // internal signals to track row load done for weight, helps to start load operation in PEs at right time
    // registered flags
    reg weight_load_done_row0_reg;
    reg weight_load_done_row1_reg;
    reg weight_load_done_row2_reg;
    reg weight_load_done_row3_reg;
    reg weight_load_done_row4_reg;
    reg weight_load_done_row5_reg;
    reg weight_load_done_row6_reg;
    reg weight_load_done_row7_reg;
    reg weight_load_done_row8_reg;
    
    // wires
    wire weight_load_done_row0 = weight_load_done_row0_reg;
    wire weight_load_done_row1 = weight_load_done_row1_reg;
    wire weight_load_done_row2 = weight_load_done_row2_reg;
    wire weight_load_done_row3 = weight_load_done_row3_reg;
    wire weight_load_done_row4 = weight_load_done_row4_reg;
    wire weight_load_done_row5 = weight_load_done_row5_reg;
    wire weight_load_done_row6 = weight_load_done_row6_reg;
    wire weight_load_done_row7 = weight_load_done_row7_reg;
    wire weight_load_done_row8 = weight_load_done_row8_reg;

// internal signals to track diagonal load done for iact, helps to start mac operation in PEs at right time
    // registered flags
    reg load_done_diagonal1_reg;
    reg load_done_diagonal2_reg;
    reg load_done_diagonal3_reg;
    reg load_done_diagonal4_reg;
    reg load_done_diagonal5_reg;
    
    // wires
    wire load_done_diagonal1 = load_done_diagonal1_reg;
    wire load_done_diagonal2 = load_done_diagonal2_reg;
    wire load_done_diagonal3 = load_done_diagonal3_reg;
    wire load_done_diagonal4 = load_done_diagonal4_reg;
    wire load_done_diagonal5 = load_done_diagonal5_reg;

// internal signals to track psum stream done to streaming of the PEs in the early rows
    // registered flags
    reg stream_done_row0_reg;
    reg stream_done_row1_reg;
    reg stream_done_row2_reg;
    reg stream_done_row3_reg;
    reg stream_done_row4_reg;
    reg stream_done_row5_reg;
    reg stream_done_row6_reg;
    reg stream_done_row7_reg;

    // wires
    wire stream_done_row0 = stream_done_row0_reg;
    wire stream_done_row1 = stream_done_row1_reg;
    wire stream_done_row2 = stream_done_row2_reg;
    wire stream_done_row3 = stream_done_row3_reg;
    wire stream_done_row4 = stream_done_row4_reg;
    wire stream_done_row5 = stream_done_row5_reg;
    wire stream_done_row6 = stream_done_row6_reg;
    wire stream_done_row7 = stream_done_row7_reg;

// 36 PEs instantiations (9 rows x 4 cols)
    // PE 00
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE00 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[0]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE00_psum_in_ready),
        .psum_in_valid(PE00_psum_in_valid),
        .psum_in(PE00_psum_in),

        .psum_out_ready(PE00_psum_out_ready),
        .psum_out_valid(PE00_psum_out_valid),
        .psum_out(PE00_psum_out),

        .iact_weight_data_ready(PE00_iact_weight_data_ready),
        .iact_weight_data_valid(PE00_iact_weight_data_valid),
        .iact_weight_data(PE00_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row0),
        .weight_done(PE00_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal1),
        .iact_done(PE00_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE00_mac_done),
        .psum_stream_start(PE00_psum_stream_start & stream_done_row0),
        .psum_stream_done(PE00_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE00_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE0_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 01
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE01 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[1]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE01_psum_in_ready),
        .psum_in_valid(PE01_psum_in_valid),
        .psum_in(PE01_psum_in),

        .psum_out_ready(PE01_psum_out_ready),
        .psum_out_valid(PE01_psum_out_valid),
        .psum_out(PE01_psum_out),

        .iact_weight_data_ready(PE01_iact_weight_data_ready),
        .iact_weight_data_valid(PE01_iact_weight_data_valid),
        .iact_weight_data(PE01_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row0),
        .weight_done(PE01_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal2),
        .iact_done(PE01_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE01_mac_done),
        .psum_stream_start(PE01_psum_stream_start & stream_done_row0),
        .psum_stream_done(PE01_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE01_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE0_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 02
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE02 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[2]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE02_psum_in_ready),
        .psum_in_valid(PE02_psum_in_valid),
        .psum_in(PE02_psum_in),

        .psum_out_ready(PE02_psum_out_ready),
        .psum_out_valid(PE02_psum_out_valid),
        .psum_out(PE02_psum_out),

        .iact_weight_data_ready(PE02_iact_weight_data_ready),
        .iact_weight_data_valid(PE02_iact_weight_data_valid),
        .iact_weight_data(PE02_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row0),
        .weight_done(PE02_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE02_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE02_mac_done),
        .psum_stream_start(PE02_psum_stream_start & stream_done_row0),
        .psum_stream_done(PE02_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE02_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE0_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 03
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE03 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[3]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE03_psum_in_ready),
        .psum_in_valid(PE03_psum_in_valid),
        .psum_in(PE03_psum_in),

        .psum_out_ready(PE03_psum_out_ready),
        .psum_out_valid(PE03_psum_out_valid),
        .psum_out(PE03_psum_out),

        .iact_weight_data_ready(PE03_iact_weight_data_ready),
        .iact_weight_data_valid(PE03_iact_weight_data_valid),
        .iact_weight_data(PE03_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row0),
        .weight_done(PE03_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE03_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE03_mac_done),
        .psum_stream_start(PE03_psum_stream_start & stream_done_row0),
        .psum_stream_done(PE03_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE03_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE0_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 10
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE10 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[4]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE10_psum_in_ready),
        .psum_in_valid(PE10_psum_in_valid),
        .psum_in(PE10_psum_in),

        .psum_out_ready(PE10_psum_out_ready),
        .psum_out_valid(PE10_psum_out_valid),
        .psum_out(PE10_psum_out),

        .iact_weight_data_ready(PE10_iact_weight_data_ready),
        .iact_weight_data_valid(PE10_iact_weight_data_valid),
        .iact_weight_data(PE10_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row1),
        .weight_done(PE10_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal2),
        .iact_done(PE10_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE10_mac_done),
        .psum_stream_start(PE10_psum_stream_start & stream_done_row1),
        .psum_stream_done(PE10_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE10_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE1_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 11
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE11 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[5]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE11_psum_in_ready),
        .psum_in_valid(PE11_psum_in_valid),
        .psum_in(PE11_psum_in),

        .psum_out_ready(PE11_psum_out_ready),
        .psum_out_valid(PE11_psum_out_valid),
        .psum_out(PE11_psum_out),

        .iact_weight_data_ready(PE11_iact_weight_data_ready),
        .iact_weight_data_valid(PE11_iact_weight_data_valid),
        .iact_weight_data(PE11_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row1),
        .weight_done(PE11_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE11_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE11_mac_done),
        .psum_stream_start(PE11_psum_stream_start & stream_done_row1),
        .psum_stream_done(PE11_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE11_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE1_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 12
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE12 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[6]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE12_psum_in_ready),
        .psum_in_valid(PE12_psum_in_valid),
        .psum_in(PE12_psum_in),

        .psum_out_ready(PE12_psum_out_ready),
        .psum_out_valid(PE12_psum_out_valid),
        .psum_out(PE12_psum_out),

        .iact_weight_data_ready(PE12_iact_weight_data_ready),
        .iact_weight_data_valid(PE12_iact_weight_data_valid),
        .iact_weight_data(PE12_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row1),
        .weight_done(PE12_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE12_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE12_mac_done),
        .psum_stream_start(PE12_psum_stream_start & stream_done_row1),
        .psum_stream_done(PE12_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE12_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE1_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 13
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE13 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[7]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE13_psum_in_ready),
        .psum_in_valid(PE13_psum_in_valid),
        .psum_in(PE13_psum_in),

        .psum_out_ready(PE13_psum_out_ready),
        .psum_out_valid(PE13_psum_out_valid),
        .psum_out(PE13_psum_out),

        .iact_weight_data_ready(PE13_iact_weight_data_ready),
        .iact_weight_data_valid(PE13_iact_weight_data_valid),
        .iact_weight_data(PE13_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row1),
        .weight_done(PE13_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal5),
        .iact_done(PE13_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE13_mac_done),
        .psum_stream_start(PE13_psum_stream_start & stream_done_row1),
        .psum_stream_done(PE13_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE13_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE1_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE 20
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE20 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[8]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE20_psum_in_ready),
        .psum_in_valid(PE20_psum_in_valid),
        .psum_in(PE20_psum_in),

        .psum_out_ready(PE20_psum_out_ready),
        .psum_out_valid(PE20_psum_out_valid),
        .psum_out(PE20_psum_out),

        .iact_weight_data_ready(PE20_iact_weight_data_ready),
        .iact_weight_data_valid(PE20_iact_weight_data_valid),
        .iact_weight_data(PE20_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row2),
        .weight_done(PE20_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE20_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE20_mac_done),
        .psum_stream_start(PE20_psum_stream_start & stream_done_row2),
        .psum_stream_done(PE20_psum_stream_done),
        .PSUM_to_GLB_read_done(PE20_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE2_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE21
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE21 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[9]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE21_psum_in_ready),
        .psum_in_valid(PE21_psum_in_valid),
        .psum_in(PE21_psum_in),

        .psum_out_ready(PE21_psum_out_ready),
        .psum_out_valid(PE21_psum_out_valid),
        .psum_out(PE21_psum_out),

        .iact_weight_data_ready(PE21_iact_weight_data_ready),
        .iact_weight_data_valid(PE21_iact_weight_data_valid),
        .iact_weight_data(PE21_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row2),
        .weight_done(PE21_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE21_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE21_mac_done),
        .psum_stream_start(PE21_psum_stream_start & stream_done_row2),
        .psum_stream_done(PE21_psum_stream_done),
        .PSUM_to_GLB_read_done(PE21_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE2_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE22
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE22 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[10]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE22_psum_in_ready),
        .psum_in_valid(PE22_psum_in_valid),
        .psum_in(PE22_psum_in),

        .psum_out_ready(PE22_psum_out_ready),
        .psum_out_valid(PE22_psum_out_valid),
        .psum_out(PE22_psum_out),

        .iact_weight_data_ready(PE22_iact_weight_data_ready),
        .iact_weight_data_valid(PE22_iact_weight_data_valid),
        .iact_weight_data(PE22_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row2),
        .weight_done(PE22_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal5),
        .iact_done(PE22_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE22_mac_done),
        .psum_stream_start(PE22_psum_stream_start & stream_done_row2),
        .psum_stream_done(PE22_psum_stream_done),
        .PSUM_to_GLB_read_done(PE22_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE2_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );
    // PE23
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE23 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[11]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE23_psum_in_ready),
        .psum_in_valid(PE23_psum_in_valid),
        .psum_in(PE23_psum_in),

        .psum_out_ready(PE23_psum_out_ready),
        .psum_out_valid(PE23_psum_out_valid),
        .psum_out(PE23_psum_out),

        .iact_weight_data_ready(PE23_iact_weight_data_ready),
        .iact_weight_data_valid(PE23_iact_weight_data_valid),
        .iact_weight_data(PE23_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe),
        .weight_done(PE23_weight_load_done),
        .load_iact(top_load_PEs_iact_pe),
        .iact_done(PE23_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE23_mac_done),
        .psum_stream_start(PE23_psum_stream_start & stream_done_row2),
        .psum_stream_done(PE23_psum_stream_done),
        .PSUM_to_GLB_read_done(PE23_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE2_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );
    // PE30
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE30 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[12]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE30_psum_in_ready),
        .psum_in_valid(PE30_psum_in_valid),
        .psum_in(PE30_psum_in),

        .psum_out_ready(PE30_psum_out_ready),
        .psum_out_valid(PE30_psum_out_valid),
        .psum_out(PE30_psum_out),

        .iact_weight_data_ready(PE30_iact_weight_data_ready),
        .iact_weight_data_valid(PE30_iact_weight_data_valid),
        .iact_weight_data(PE30_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row3),
        .weight_done(PE30_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal1),
        .iact_done(PE30_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE30_mac_done),
        .psum_stream_start(PE30_psum_stream_start & stream_done_row3),
        .psum_stream_done(PE30_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE30_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE3_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );
    // PE31
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE31 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[13]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE31_psum_in_ready),
        .psum_in_valid(PE31_psum_in_valid),
        .psum_in(PE31_psum_in),

        .psum_out_ready(PE31_psum_out_ready),
        .psum_out_valid(PE31_psum_out_valid),
        .psum_out(PE31_psum_out),

        .iact_weight_data_ready(PE31_iact_weight_data_ready),
        .iact_weight_data_valid(PE31_iact_weight_data_valid),
        .iact_weight_data(PE31_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row3),
        .weight_done(PE31_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal2),
        .iact_done(PE31_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE31_mac_done),
        .psum_stream_start(PE31_psum_stream_start & stream_done_row3),
        .psum_stream_done(PE31_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE31_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE3_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

        // PE32
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE32 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[14]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE32_psum_in_ready),
        .psum_in_valid(PE32_psum_in_valid),
        .psum_in(PE32_psum_in),

        .psum_out_ready(PE32_psum_out_ready),
        .psum_out_valid(PE32_psum_out_valid),
        .psum_out(PE32_psum_out),

        .iact_weight_data_ready(PE32_iact_weight_data_ready),
        .iact_weight_data_valid(PE32_iact_weight_data_valid),
        .iact_weight_data(PE32_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row3),
        .weight_done(PE32_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal2),
        .iact_done(PE32_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE32_mac_done),
        .psum_stream_start(PE32_psum_stream_start & stream_done_row3),
        .psum_stream_done(PE32_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE32_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE3_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );
        // PE33
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE33 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[15]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE33_psum_in_ready),
        .psum_in_valid(PE33_psum_in_valid),
        .psum_in(PE33_psum_in),

        .psum_out_ready(PE33_psum_out_ready),
        .psum_out_valid(PE33_psum_out_valid),
        .psum_out(PE33_psum_out),

        .iact_weight_data_ready(PE33_iact_weight_data_ready),
        .iact_weight_data_valid(PE33_iact_weight_data_valid),
        .iact_weight_data(PE33_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row3),
        .weight_done(PE33_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE33_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE33_mac_done),
        .psum_stream_start(PE33_psum_stream_start & stream_done_row3),
        .psum_stream_done(PE33_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE33_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE3_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE40
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE40 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[16]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE40_psum_in_ready),
        .psum_in_valid(PE40_psum_in_valid),
        .psum_in(PE40_psum_in),

        .psum_out_ready(PE40_psum_out_ready),
        .psum_out_valid(PE40_psum_out_valid),
        .psum_out(PE40_psum_out),

        .iact_weight_data_ready(PE40_iact_weight_data_ready),
        .iact_weight_data_valid(PE40_iact_weight_data_valid),
        .iact_weight_data(PE40_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row4),
        .weight_done(PE40_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal2),
        .iact_done(PE40_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE40_mac_done),
        .psum_stream_start(PE40_psum_stream_start & stream_done_row4),
        .psum_stream_done(PE40_psum_stream_done),
        .PSUM_to_GLB_read_done(PE40_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE4_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE41
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE41 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[17]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE41_psum_in_ready),
        .psum_in_valid(PE41_psum_in_valid),
        .psum_in(PE41_psum_in),

        .psum_out_ready(PE41_psum_out_ready),
        .psum_out_valid(PE41_psum_out_valid),
        .psum_out(PE41_psum_out),

        .iact_weight_data_ready(PE41_iact_weight_data_ready),
        .iact_weight_data_valid(PE41_iact_weight_data_valid),
        .iact_weight_data(PE41_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row4),
        .weight_done(PE41_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE41_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE41_mac_done),
        .psum_stream_start(PE41_psum_stream_start & stream_done_row4),
        .psum_stream_done(PE41_psum_stream_done),
        .PSUM_to_GLB_read_done(PE41_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE4_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE42
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE42 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[18]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE42_psum_in_ready),
        .psum_in_valid(PE42_psum_in_valid),
        .psum_in(PE42_psum_in),

        .psum_out_ready(PE42_psum_out_ready),
        .psum_out_valid(PE42_psum_out_valid),
        .psum_out(PE42_psum_out),

        .iact_weight_data_ready(PE42_iact_weight_data_ready),
        .iact_weight_data_valid(PE42_iact_weight_data_valid),
        .iact_weight_data(PE42_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row4),
        .weight_done(PE42_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE42_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE42_mac_done),
        .psum_stream_start(PE42_psum_stream_start & stream_done_row4),
        .psum_stream_done(PE42_psum_stream_done),
        .PSUM_to_GLB_read_done(PE42_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE4_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE43
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE43 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[19]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE43_psum_in_ready),
        .psum_in_valid(PE43_psum_in_valid),
        .psum_in(PE43_psum_in),

        .psum_out_ready(PE43_psum_out_ready),
        .psum_out_valid(PE43_psum_out_valid),
        .psum_out(PE43_psum_out),

        .iact_weight_data_ready(PE43_iact_weight_data_ready),
        .iact_weight_data_valid(PE43_iact_weight_data_valid),
        .iact_weight_data(PE43_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row4),
        .weight_done(PE43_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal5),
        .iact_done(PE43_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE43_mac_done),
        .psum_stream_start(PE43_psum_stream_start & stream_done_row4),
        .psum_stream_done(PE43_psum_stream_done),
        .PSUM_to_GLB_read_done(PE43_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE4_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE50
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE50 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[20]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE50_psum_in_ready),
        .psum_in_valid(PE50_psum_in_valid),
        .psum_in(PE50_psum_in),

        .psum_out_ready(PE50_psum_out_ready),
        .psum_out_valid(PE50_psum_out_valid),
        .psum_out(PE50_psum_out),

        .iact_weight_data_ready(PE50_iact_weight_data_ready),
        .iact_weight_data_valid(PE50_iact_weight_data_valid),
        .iact_weight_data(PE50_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row5),
        .weight_done(PE50_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE50_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE50_mac_done),
        .psum_stream_start(PE50_psum_stream_start & stream_done_row5),
        .psum_stream_done(PE50_psum_stream_done),
        .PSUM_to_GLB_read_done(PE50_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE5_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE51
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE51 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[21]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE51_psum_in_ready),
        .psum_in_valid(PE51_psum_in_valid),
        .psum_in(PE51_psum_in),

        .psum_out_ready(PE51_psum_out_ready),
        .psum_out_valid(PE51_psum_out_valid),
        .psum_out(PE51_psum_out),

        .iact_weight_data_ready(PE51_iact_weight_data_ready),
        .iact_weight_data_valid(PE51_iact_weight_data_valid),
        .iact_weight_data(PE51_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row5),
        .weight_done(PE51_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE51_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE51_mac_done),
        .psum_stream_start(PE51_psum_stream_start & stream_done_row5),
        .psum_stream_done(PE51_psum_stream_done),
        .PSUM_to_GLB_read_done(PE51_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE5_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE52
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE52 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[22]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE52_psum_in_ready),
        .psum_in_valid(PE52_psum_in_valid),
        .psum_in(PE52_psum_in),

        .psum_out_ready(PE52_psum_out_ready),
        .psum_out_valid(PE52_psum_out_valid),
        .psum_out(PE52_psum_out),

        .iact_weight_data_ready(PE52_iact_weight_data_ready),
        .iact_weight_data_valid(PE52_iact_weight_data_valid),
        .iact_weight_data(PE52_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row5),
        .weight_done(PE52_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal5),
        .iact_done(PE52_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE52_mac_done),
        .psum_stream_start(PE52_psum_stream_start & stream_done_row5),
        .psum_stream_done(PE52_psum_stream_done),
        .PSUM_to_GLB_read_done(PE52_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE5_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE53
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE53 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[23]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE53_psum_in_ready),
        .psum_in_valid(PE53_psum_in_valid),
        .psum_in(PE53_psum_in),

        .psum_out_ready(PE53_psum_out_ready),
        .psum_out_valid(PE53_psum_out_valid),
        .psum_out(PE53_psum_out),

        .iact_weight_data_ready(PE53_iact_weight_data_ready),
        .iact_weight_data_valid(PE53_iact_weight_data_valid),
        .iact_weight_data(PE53_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row5),
        .weight_done(PE53_weight_load_done),
        .load_iact(top_load_PEs_iact_pe),
        .iact_done(PE53_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE53_mac_done),
        .psum_stream_start(PE53_psum_stream_start & stream_done_row5),
        .psum_stream_done(PE53_psum_stream_done),
        .PSUM_to_GLB_read_done(PE53_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE5_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE60
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE60 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[24]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE60_psum_in_ready),
        .psum_in_valid(PE60_psum_in_valid),
        .psum_in(PE60_psum_in),

        .psum_out_ready(PE60_psum_out_ready),
        .psum_out_valid(PE60_psum_out_valid),
        .psum_out(PE60_psum_out),

        .iact_weight_data_ready(PE60_iact_weight_data_ready),
        .iact_weight_data_valid(PE60_iact_weight_data_valid),
        .iact_weight_data(PE60_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row6),
        .weight_done(PE60_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal1),
        .iact_done(PE60_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE60_mac_done),
        .psum_stream_start(PE60_psum_stream_start & stream_done_row6),
        .psum_stream_done(PE60_psum_stream_done),
        .PSUM_to_GLB_read_done(PE60_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE6_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    
    // PE61
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE61 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[25]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE61_psum_in_ready),
        .psum_in_valid(PE61_psum_in_valid),
        .psum_in(PE61_psum_in),

        .psum_out_ready(PE61_psum_out_ready),
        .psum_out_valid(PE61_psum_out_valid),
        .psum_out(PE61_psum_out),

        .iact_weight_data_ready(PE61_iact_weight_data_ready),
        .iact_weight_data_valid(PE61_iact_weight_data_valid),
        .iact_weight_data(PE61_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row6),
        .weight_done(PE61_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal2),
        .iact_done(PE61_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE61_mac_done),
        .psum_stream_start(PE61_psum_stream_start & stream_done_row6),
        .psum_stream_done(PE61_psum_stream_done),
        .PSUM_to_GLB_read_done(PE61_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE6_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    
    // PE62
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE62 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[26]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE62_psum_in_ready),
        .psum_in_valid(PE62_psum_in_valid),
        .psum_in(PE62_psum_in),

        .psum_out_ready(PE62_psum_out_ready),
        .psum_out_valid(PE62_psum_out_valid),
        .psum_out(PE62_psum_out),

        .iact_weight_data_ready(PE62_iact_weight_data_ready),
        .iact_weight_data_valid(PE62_iact_weight_data_valid),
        .iact_weight_data(PE62_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row6),
        .weight_done(PE62_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE62_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE62_mac_done),
        .psum_stream_start(PE62_psum_stream_start & stream_done_row6),
        .psum_stream_done(PE62_psum_stream_done),
        .PSUM_to_GLB_read_done(PE62_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE6_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );
    
    // PE63
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE63 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[27]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE63_psum_in_ready),
        .psum_in_valid(PE63_psum_in_valid),
        .psum_in(PE63_psum_in),

        .psum_out_ready(PE63_psum_out_ready),
        .psum_out_valid(PE63_psum_out_valid),
        .psum_out(PE63_psum_out),

        .iact_weight_data_ready(PE63_iact_weight_data_ready),
        .iact_weight_data_valid(PE63_iact_weight_data_valid),
        .iact_weight_data(PE63_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row6),
        .weight_done(PE63_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE63_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE63_mac_done),
        .psum_stream_start(PE63_psum_stream_start & stream_done_row6),
        .psum_stream_done(PE63_psum_stream_done),
        .PSUM_to_GLB_read_done(PE63_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE6_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    
    // PE70
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE70 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[28]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE70_psum_in_ready),
        .psum_in_valid(PE70_psum_in_valid),
        .psum_in(PE70_psum_in),

        .psum_out_ready(PE70_psum_out_ready),
        .psum_out_valid(PE70_psum_out_valid),
        .psum_out(PE70_psum_out),

        .iact_weight_data_ready(PE70_iact_weight_data_ready),
        .iact_weight_data_valid(PE70_iact_weight_data_valid),
        .iact_weight_data(PE70_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row7),
        .weight_done(PE70_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal2),
        .iact_done(PE70_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE70_mac_done),
        .psum_stream_start(PE70_psum_stream_start & stream_done_row7),
        .psum_stream_done(PE70_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE70_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE7_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE71
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE71 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[29]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE71_psum_in_ready),
        .psum_in_valid(PE71_psum_in_valid),
        .psum_in(PE71_psum_in),

        .psum_out_ready(PE71_psum_out_ready),
        .psum_out_valid(PE71_psum_out_valid),
        .psum_out(PE71_psum_out),

        .iact_weight_data_ready(PE71_iact_weight_data_ready),
        .iact_weight_data_valid(PE71_iact_weight_data_valid),
        .iact_weight_data(PE71_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row7),
        .weight_done(PE71_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE71_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE71_mac_done),
        .psum_stream_start(PE71_psum_stream_start & stream_done_row7),
        .psum_stream_done(PE71_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE71_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE7_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE72
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE72 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[30]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE72_psum_in_ready),
        .psum_in_valid(PE72_psum_in_valid),
        .psum_in(PE72_psum_in),

        .psum_out_ready(PE72_psum_out_ready),
        .psum_out_valid(PE72_psum_out_valid),
        .psum_out(PE72_psum_out),

        .iact_weight_data_ready(PE72_iact_weight_data_ready),
        .iact_weight_data_valid(PE72_iact_weight_data_valid),
        .iact_weight_data(PE72_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row7),
        .weight_done(PE72_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE72_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE72_mac_done),
        .psum_stream_start(PE72_psum_stream_start & stream_done_row7),
        .psum_stream_done(PE72_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE72_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE7_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE73
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE73 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[31]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE73_psum_in_ready),
        .psum_in_valid(PE73_psum_in_valid),
        .psum_in(PE73_psum_in),

        .psum_out_ready(PE73_psum_out_ready),
        .psum_out_valid(PE73_psum_out_valid),
        .psum_out(PE73_psum_out),

        .iact_weight_data_ready(PE73_iact_weight_data_ready),
        .iact_weight_data_valid(PE73_iact_weight_data_valid),
        .iact_weight_data(PE73_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe & weight_load_done_row7),
        .weight_done(PE73_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal5),
        .iact_done(PE73_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE73_mac_done),
        .psum_stream_start(PE73_psum_stream_start & stream_done_row7),
        .psum_stream_done(PE73_psum_stream_done),
        .PSUM_to_GLB_read_done(DUMMY_FLAG_PE73_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE7_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

        // PE80
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE80 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[32]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE80_psum_in_ready),
        .psum_in_valid(PE80_psum_in_valid),
        .psum_in(PE80_psum_in),

        .psum_out_ready(PE80_psum_out_ready),
        .psum_out_valid(PE80_psum_out_valid),
        .psum_out(PE80_psum_out),

        .iact_weight_data_ready(PE80_iact_weight_data_ready),
        .iact_weight_data_valid(PE80_iact_weight_data_valid),
        .iact_weight_data(PE80_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe),
        .weight_done(PE80_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal3),
        .iact_done(PE80_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE80_mac_done),
        .psum_stream_start(PE80_psum_stream_start),
        .psum_stream_done(PE80_psum_stream_done),
        .PSUM_to_GLB_read_done(PE80_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE8_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE81
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE81 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[33]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE81_psum_in_ready),
        .psum_in_valid(PE81_psum_in_valid),
        .psum_in(PE81_psum_in),

        .psum_out_ready(PE81_psum_out_ready),
        .psum_out_valid(PE81_psum_out_valid),
        .psum_out(PE81_psum_out),

        .iact_weight_data_ready(PE81_iact_weight_data_ready),
        .iact_weight_data_valid(PE81_iact_weight_data_valid),
        .iact_weight_data(PE81_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe),
        .weight_done(PE81_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal4),
        .iact_done(PE81_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE81_mac_done),
        .psum_stream_start(PE81_psum_stream_start),
        .psum_stream_done(PE81_psum_stream_done),
        .PSUM_to_GLB_read_done(PE81_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE8_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE82
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE82 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[34]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE82_psum_in_ready),
        .psum_in_valid(PE82_psum_in_valid),
        .psum_in(PE82_psum_in),

        .psum_out_ready(PE82_psum_out_ready),
        .psum_out_valid(PE82_psum_out_valid),
        .psum_out(PE82_psum_out),

        .iact_weight_data_ready(PE82_iact_weight_data_ready),
        .iact_weight_data_valid(PE82_iact_weight_data_valid),
        .iact_weight_data(PE82_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe),
        .weight_done(PE82_weight_load_done),
        .load_iact(top_load_PEs_iact_pe & load_done_diagonal5),
        .iact_done(PE82_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE82_mac_done),
        .psum_stream_start(PE82_psum_stream_start),
        .psum_stream_done(PE82_psum_stream_done),
        .PSUM_to_GLB_read_done(PE82_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE8_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

    // PE83
    PE_core #(
        .IACT_WIDTH(IACT_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH),
        .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
        .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH),
        .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
        .CLUSTER_ROWS(CLUSTER_ROWS)
    ) PE83 (
        .clock(clock),
        .reset(reset),
        .PE_disable(PE_disable[35]),
        .PE_mode(PE_mode),

        .psum_in_ready(PE83_psum_in_ready),
        .psum_in_valid(PE83_psum_in_valid),
        .psum_in(PE83_psum_in),

        .psum_out_ready(PE83_psum_out_ready),
        .psum_out_valid(PE83_psum_out_valid),
        .psum_out(PE83_psum_out),

        .iact_weight_data_ready(PE83_iact_weight_data_ready),
        .iact_weight_data_valid(PE83_iact_weight_data_valid),
        .iact_weight_data(PE83_iact_weight_data),

        .load_weight(top_load_PEs_weight_pe),
        .weight_done(PE83_weight_load_done),
        .load_iact(top_load_PEs_iact_pe),
        .iact_done(PE83_iact_load_done),

        .mac_en(top_mac_en_pe),
        .mac_done(PE83_mac_done),
        .psum_stream_start(PE83_psum_stream_start),
        .psum_stream_done(PE83_psum_stream_done),
        .PSUM_to_GLB_read_done(PE83_PSUM_to_GLB_read_done),

        .psum_to_GLB_en(PE8_psum_to_GLB_en),

        .cycles_per_iact_col(cycles_per_iact_col),
        .weight_columns(weight_columns),
        .psum_spad_write_index(psum_spad_write_index),
        .weight_spad_index(weight_spad_index)
    );

always @(*) begin
    PE_disable = 'd0;
    case (top_filter_mode)
    FILTER_3: PE_disable = 'd0;
    FILTER_5: PE_disable = 'hFFFF_00000;
    FILTER_7: PE_disable = 'hFF00_00000;
    FILTER_9: PE_disable = 'd0;
    endcase
end

always @(*) begin
    load_PEs_weight_done_top = 1'b0;
    load_PEs_iact_done_top = 1'b0; 
    mac_done_top = 1'b0;
    psum_stream_done_top = 1'b0;
    PSUM_to_GLB_done_top = 1'b0;
    final_psum_out_valid_glb0 = 1'b0;
    final_psum_out_glb0 = 'd0;
    final_psum_out_valid_glb1 = 1'b0;
    final_psum_out_glb1 = 'd0;
    final_psum_out_valid_glb2 = 1'b0;
    final_psum_out_glb2 = 'd0;
    final_psum_out_valid_glb3 = 1'b0;
    final_psum_out_glb3 = 'd0;
    case (top_filter_mode)
    FILTER_3: begin 

        load_PEs_weight_done_top = PE80_weight_load_done & PE81_weight_load_done & PE82_weight_load_done & PE83_weight_load_done;
        load_PEs_iact_done_top = PE23_iact_load_done & PE53_iact_load_done & PE83_iact_load_done;
        mac_done_top = PE00_mac_done & PE01_mac_done & PE02_mac_done & PE03_mac_done  // AND all 36 PEs mac done
                        & PE10_mac_done & PE11_mac_done & PE12_mac_done & PE13_mac_done
                        & PE20_mac_done & PE21_mac_done & PE22_mac_done & PE23_mac_done
                        & PE30_mac_done & PE31_mac_done & PE32_mac_done & PE33_mac_done
                        & PE40_mac_done & PE41_mac_done & PE42_mac_done & PE43_mac_done
                        & PE50_mac_done & PE51_mac_done & PE52_mac_done & PE53_mac_done
                        & PE60_mac_done & PE61_mac_done & PE62_mac_done & PE63_mac_done
                        & PE70_mac_done & PE71_mac_done & PE72_mac_done & PE73_mac_done
                        & PE80_mac_done & PE81_mac_done & PE82_mac_done & PE83_mac_done;
        psum_stream_done_top = PE23_psum_stream_done & PE53_psum_stream_done & PE83_psum_stream_done;

        PSUM_to_GLB_done_top = PE20_PSUM_to_GLB_read_done & PE21_PSUM_to_GLB_read_done & PE22_PSUM_to_GLB_read_done & PE23_PSUM_to_GLB_read_done
                            & PE50_PSUM_to_GLB_read_done & PE51_PSUM_to_GLB_read_done & PE52_PSUM_to_GLB_read_done & PE53_PSUM_to_GLB_read_done
                            & PE80_PSUM_to_GLB_read_done & PE81_PSUM_to_GLB_read_done & PE82_PSUM_to_GLB_read_done & PE83_PSUM_to_GLB_read_done;

        final_psum_out_valid_glb0 = PE80_psum_out_valid;
        final_psum_out_glb0 = PE80_psum_out;
        final_psum_out_valid_glb1 = PE81_psum_out_valid;
        final_psum_out_glb1 = PE81_psum_out;
        final_psum_out_valid_glb2 = PE82_psum_out_valid;
        final_psum_out_glb2 = PE82_psum_out;
        final_psum_out_valid_glb3 = PE83_psum_out_valid;
        final_psum_out_glb3 = PE83_psum_out;
    end
    FILTER_5: begin 

        load_PEs_weight_done_top = PE40_weight_load_done & PE41_weight_load_done & PE42_weight_load_done & PE43_weight_load_done;
        load_PEs_iact_done_top = PE43_iact_load_done;
                                
        mac_done_top = PE00_mac_done & PE01_mac_done & PE02_mac_done & PE03_mac_done  // AND all 20 PEs mac finish
                        & PE10_mac_done & PE11_mac_done & PE12_mac_done & PE13_mac_done
                        & PE20_mac_done & PE21_mac_done & PE22_mac_done & PE23_mac_done
                        & PE30_mac_done & PE31_mac_done & PE32_mac_done & PE33_mac_done
                        & PE40_mac_done & PE41_mac_done & PE42_mac_done & PE43_mac_done;
        psum_stream_done_top = PE43_psum_stream_done;

        PSUM_to_GLB_done_top = PE40_PSUM_to_GLB_read_done & PE41_PSUM_to_GLB_read_done & PE42_PSUM_to_GLB_read_done & PE43_PSUM_to_GLB_read_done;

        final_psum_out_valid_glb0 = PE40_psum_out_valid;
        final_psum_out_glb0 = PE40_psum_out;
        final_psum_out_valid_glb1 = PE41_psum_out_valid;
        final_psum_out_glb1 = PE41_psum_out;
        final_psum_out_valid_glb2 = PE42_psum_out_valid;
        final_psum_out_glb2 = PE42_psum_out;
        final_psum_out_valid_glb3 = PE43_psum_out_valid;
        final_psum_out_glb3 = PE43_psum_out;
    end
    FILTER_7: begin 
        load_PEs_weight_done_top = PE60_weight_load_done & PE61_weight_load_done & PE62_weight_load_done & PE63_weight_load_done;
        load_PEs_iact_done_top = PE63_iact_load_done;

        mac_done_top = PE00_mac_done & PE01_mac_done & PE02_mac_done & PE03_mac_done  // AND 28 PEs mac finish
                        & PE10_mac_done & PE11_mac_done & PE12_mac_done & PE13_mac_done
                        & PE20_mac_done & PE21_mac_done & PE22_mac_done & PE23_mac_done
                        & PE30_mac_done & PE31_mac_done & PE32_mac_done & PE33_mac_done
                        & PE40_mac_done & PE41_mac_done & PE42_mac_done & PE43_mac_done
                        & PE50_mac_done & PE51_mac_done & PE52_mac_done & PE53_mac_done
                        & PE60_mac_done & PE61_mac_done & PE62_mac_done & PE63_mac_done;
        psum_stream_done_top = PE63_psum_stream_done;

        PSUM_to_GLB_done_top = PE60_PSUM_to_GLB_read_done & PE61_PSUM_to_GLB_read_done & PE62_PSUM_to_GLB_read_done & PE63_PSUM_to_GLB_read_done;

        final_psum_out_valid_glb0 = PE60_psum_out_valid;
        final_psum_out_glb0 = PE60_psum_out;
        final_psum_out_valid_glb1 = PE61_psum_out_valid;
        final_psum_out_glb1 = PE61_psum_out;
        final_psum_out_valid_glb2 = PE62_psum_out_valid;
        final_psum_out_glb2 = PE62_psum_out;
        final_psum_out_valid_glb3 = PE63_psum_out_valid;
        final_psum_out_glb3 = PE63_psum_out;
    end
    FILTER_9: begin 
        load_PEs_weight_done_top = PE80_weight_load_done & PE81_weight_load_done & PE82_weight_load_done & PE83_weight_load_done;
        load_PEs_iact_done_top = PE23_iact_load_done & PE53_iact_load_done & PE83_iact_load_done;

        mac_done_top = PE00_mac_done & PE01_mac_done & PE02_mac_done & PE03_mac_done  // AND all 36 PEs mac finish
                        & PE10_mac_done & PE11_mac_done & PE12_mac_done & PE13_mac_done
                        & PE20_mac_done & PE21_mac_done & PE22_mac_done & PE23_mac_done
                        & PE30_mac_done & PE31_mac_done & PE32_mac_done & PE33_mac_done
                        & PE40_mac_done & PE41_mac_done & PE42_mac_done & PE43_mac_done
                        & PE50_mac_done & PE51_mac_done & PE52_mac_done & PE53_mac_done
                        & PE60_mac_done & PE61_mac_done & PE62_mac_done & PE63_mac_done
                        & PE70_mac_done & PE71_mac_done & PE72_mac_done & PE73_mac_done
                        & PE80_mac_done & PE81_mac_done & PE82_mac_done & PE83_mac_done;
        
        psum_stream_done_top = PE83_psum_stream_done;

        PSUM_to_GLB_done_top = PE80_PSUM_to_GLB_read_done & PE81_PSUM_to_GLB_read_done & PE82_PSUM_to_GLB_read_done & PE83_PSUM_to_GLB_read_done;

        final_psum_out_valid_glb0 = PE80_psum_out_valid;
        final_psum_out_glb0 = PE80_psum_out;
        final_psum_out_valid_glb1 = PE81_psum_out_valid;
        final_psum_out_glb1 = PE81_psum_out;
        final_psum_out_valid_glb2 = PE82_psum_out_valid;
        final_psum_out_glb2 = PE82_psum_out;
        final_psum_out_valid_glb3 = PE83_psum_out_valid;
        final_psum_out_glb3 = PE83_psum_out;
    end
    endcase
end

always @(posedge clock) begin
    if (reset) begin
        weight_load_done_row0_reg <= 1'b1;
        weight_load_done_row1_reg <= 1'b1;
        weight_load_done_row2_reg <= 1'b1;
        weight_load_done_row3_reg <= 1'b1;
        weight_load_done_row4_reg <= 1'b1;
        weight_load_done_row5_reg <= 1'b1;
        weight_load_done_row6_reg <= 1'b1;
        weight_load_done_row7_reg <= 1'b1;
        weight_load_done_row8_reg <= 1'b1;
    end 
    else begin
        if (PE00_weight_load_done & PE01_weight_load_done & PE02_weight_load_done & PE03_weight_load_done) begin
            weight_load_done_row0_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row0_reg <= 1'b1;
        end

        if (PE10_weight_load_done & PE11_weight_load_done & PE12_weight_load_done & PE13_weight_load_done) begin
            weight_load_done_row1_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row1_reg <= 1'b1;
        end

        if (PE20_weight_load_done & PE21_weight_load_done & PE22_weight_load_done & PE23_weight_load_done) begin
            weight_load_done_row2_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row2_reg <= 1'b1;
        end

        if (PE30_weight_load_done & PE31_weight_load_done & PE32_weight_load_done & PE33_weight_load_done) begin
            weight_load_done_row3_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row3_reg <= 1'b1;
        end
        
        if (PE40_weight_load_done & PE41_weight_load_done & PE42_weight_load_done & PE43_weight_load_done) begin
            weight_load_done_row4_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row4_reg <= 1'b1;
        end

        if (PE50_weight_load_done & PE51_weight_load_done & PE52_weight_load_done & PE53_weight_load_done) begin
            weight_load_done_row5_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row5_reg <= 1'b1;
        end

        if (PE60_weight_load_done & PE61_weight_load_done & PE62_weight_load_done & PE63_weight_load_done) begin
            weight_load_done_row6_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row6_reg <= 1'b1;
        end

        if (PE70_weight_load_done & PE71_weight_load_done & PE72_weight_load_done & PE73_weight_load_done) begin
            weight_load_done_row7_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row7_reg <= 1'b1;
        end

        if (PE80_weight_load_done & PE81_weight_load_done & PE82_weight_load_done & PE83_weight_load_done) begin
            weight_load_done_row8_reg <= 1'b0;
        end
        else if(load_PEs_weight_done_top) begin
            weight_load_done_row8_reg <= 1'b1;
        end
    end
end 

always @(posedge clock) begin
    if (reset) begin
        load_done_diagonal1_reg <= 1'b1;
        load_done_diagonal2_reg <= 1'b1;
        load_done_diagonal3_reg <= 1'b1;
        load_done_diagonal4_reg <= 1'b1;
        load_done_diagonal5_reg <= 1'b1;
    end 
    else begin
        if (PE00_iact_load_done & PE30_iact_load_done & PE60_iact_load_done) begin
            load_done_diagonal1_reg <= 1'b0;
        end
        else if(load_PEs_iact_done_top) begin
            load_done_diagonal1_reg <= 1'b1;
        end

        if (PE01_iact_load_done & PE10_iact_load_done & PE31_iact_load_done 
                & PE40_iact_load_done & PE61_iact_load_done & PE70_iact_load_done) begin
            load_done_diagonal2_reg <= 1'b0;
        end
        else if(load_PEs_iact_done_top) begin
            load_done_diagonal2_reg <= 1'b1;
        end

        if (PE02_iact_load_done & PE11_iact_load_done & PE20_iact_load_done 
                & PE32_iact_load_done & PE41_iact_load_done & PE50_iact_load_done 
                & PE62_iact_load_done & PE71_iact_load_done & PE80_iact_load_done) begin
            load_done_diagonal3_reg <= 1'b0;
        end
        else if(load_PEs_iact_done_top) begin
            load_done_diagonal3_reg <= 1'b1;
        end

        if (PE03_iact_load_done & PE12_iact_load_done & PE21_iact_load_done 
                & PE33_iact_load_done & PE42_iact_load_done & PE51_iact_load_done 
                & PE63_iact_load_done & PE72_iact_load_done & PE81_iact_load_done) begin
            load_done_diagonal4_reg <= 1'b0;
        end
        else if(load_PEs_iact_done_top) begin
            load_done_diagonal4_reg <= 1'b1;
        end

        if (PE13_iact_load_done & PE22_iact_load_done & PE43_iact_load_done 
                & PE52_iact_load_done & PE73_iact_load_done & PE82_iact_load_done) begin
            load_done_diagonal5_reg <= 1'b0;
        end
        else if(load_PEs_iact_done_top) begin
            load_done_diagonal5_reg <= 1'b1;
        end
    end
end 

always @(posedge clock) begin
    if (reset) begin
        stream_done_row0_reg <= 1'b1;
        stream_done_row1_reg <= 1'b1;
        stream_done_row2_reg <= 1'b1;
        stream_done_row3_reg <= 1'b1;
        stream_done_row4_reg <= 1'b1;
        stream_done_row5_reg <= 1'b1;
        stream_done_row6_reg <= 1'b1;
        stream_done_row7_reg <= 1'b1;
    end 
    else begin
        if (PE00_psum_stream_done & PE01_psum_stream_done & PE02_psum_stream_done & PE03_psum_stream_done) begin
            stream_done_row0_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row0_reg <= 1'b1;
        end

        if (PE10_psum_stream_done & PE11_psum_stream_done & PE12_psum_stream_done & PE13_psum_stream_done) begin
            stream_done_row1_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row1_reg <= 1'b1;
        end

        if (PE20_psum_stream_done & PE21_psum_stream_done & PE22_psum_stream_done & PE23_psum_stream_done) begin
            stream_done_row2_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row2_reg <= 1'b1;
        end

        if (PE30_psum_stream_done & PE31_psum_stream_done & PE32_psum_stream_done & PE33_psum_stream_done) begin
            stream_done_row3_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row3_reg <= 1'b1;
        end

        if (PE40_psum_stream_done & PE41_psum_stream_done & PE42_psum_stream_done & PE43_psum_stream_done) begin
            stream_done_row4_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row4_reg <= 1'b1;
        end

        if (PE50_psum_stream_done & PE51_psum_stream_done & PE52_psum_stream_done & PE53_psum_stream_done) begin
            stream_done_row5_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row5_reg <= 1'b1;
        end

        if (PE60_psum_stream_done & PE61_psum_stream_done & PE62_psum_stream_done & PE63_psum_stream_done) begin
            stream_done_row6_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row6_reg <= 1'b1;
        end

        if (PE70_psum_stream_done & PE71_psum_stream_done & PE72_psum_stream_done & PE73_psum_stream_done) begin
            stream_done_row7_reg <= 1'b0;
        end
        else if(psum_stream_done_top) begin
            stream_done_row7_reg <= 1'b1;
        end
    end
end 

endmodule