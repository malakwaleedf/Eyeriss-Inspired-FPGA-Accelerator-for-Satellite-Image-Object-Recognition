module Weight_Router #(
	parameter WEIGHT_SIZE = 8
) (
//******************** Control Signals ****************************
	input         data_in_sel,				// which input source is selected
	input         [1:0] data_out_sel,	// which output destination is selected

//******************** Source Ports ****************************
	// GLB Source
	input         GLB_data_in_valid,		// GLB has valid weight data
	input  signed [WEIGHT_SIZE-1:0]  GLB_data_in,	// input weight data sent from GLB  
	output        GLB_data_in_ready,		// Router tells GLB it's ready to accept the weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         horiz_data_in_valid,		// Left PE has valid weight data
	input  signed [WEIGHT_SIZE-1:0]  horiz_data_in,	// input weight data sent from left PE  
	output        horiz_data_in_ready,		// Router tells left PE it's ready to accept the weight data (If data_in_sel != HORIZ → ready = 0)

//********************* Destination Ports ***************************
	// PE0 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        PE_0_data_out_valid,		// output weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0]  PE_0_data_out,	// output weight data received by the PE  

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        PE_1_data_out_valid,		// output weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0]  PE_1_data_out,	// output weight data received by the PE  

	// PE2 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        PE_2_data_out_valid,		// output weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0]  PE_2_data_out,	// output weight data received by the PE  
	
	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         horiz_data_out_ready,		// Right PE is ready to receive weight data (always set to 1 during horizontal cast)
	output        horiz_data_out_valid,		// output weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output signed [WEIGHT_SIZE-1:0]  horiz_data_out	// output encoded weight data received by the right PE  
);

// ====================================================================	//
// 						 		Parameters  							//
// ====================================================================	//
// data out direction
localparam [1:0] PE0 	= 'd0;
localparam [1:0] PE1 	= 'd1;
localparam [1:0] PE2 	= 'd2;
localparam [1:0] HOR_CAST = 'd3;

// data in direction
localparam GLB   	= 1'b0;
localparam HORIZ	= 1'b1;

// ====================================================================	//
// 						 		Wires  									//
// ====================================================================	//
// internal signals
// destinations
wire 					internal_data_ready = (data_out_sel == HOR_CAST)? horiz_data_out_ready : 1'b1;
// sources
wire 					internal_data_valid = (data_in_sel == HORIZ)? horiz_data_in_valid : GLB_data_in_valid;
wire signed [WEIGHT_SIZE-1:0] 	internal_data = (data_in_sel == HORIZ)? horiz_data_in : GLB_data_in;

// ====================================================================	//
// 						 		Combination  							//
// ====================================================================	//

// in ready switching
assign GLB_data_in_ready 		= (data_in_sel == GLB)	 & internal_data_ready;
assign horiz_data_in_ready 		= (data_in_sel == HORIZ) & internal_data_ready;

// data out switching			
assign PE_0_data_out_valid 		= (data_out_sel == PE0) && internal_data_valid;
assign PE_0_data_out = internal_data;

assign PE_1_data_out_valid 		= (data_out_sel == PE1) && internal_data_valid;
assign PE_1_data_out = internal_data;

assign PE_2_data_out_valid 		= (data_out_sel == PE2) && internal_data_valid;
assign PE_2_data_out = internal_data;

assign horiz_data_out_valid 	= (data_out_sel == HOR_CAST) & internal_data_valid;
assign horiz_data_out = internal_data;

endmodule