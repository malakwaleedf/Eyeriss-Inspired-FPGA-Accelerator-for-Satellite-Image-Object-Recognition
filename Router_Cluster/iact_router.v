
module Iact_Router #(
	parameter IACT_SIZE = 8 // iact precision (from DOTA dataset)
) (
	// source ports
	output                     GLB_data_in_ready,
	input                      GLB_data_in_valid,
	input      signed [IACT_SIZE-1 : 0] GLB_data_in,
			
	output                     north_data_in_ready,
	input                      north_data_in_valid,
	input      signed [IACT_SIZE-1 : 0] north_data_in,
			
	output                     south_data_in_ready,
	input                      south_data_in_valid,
	input      signed [IACT_SIZE-1 : 0] south_data_in,
			
	output                     horiz_data_in_ready,
	input                      horiz_data_in_valid,
	input      signed [IACT_SIZE-1 : 0] horiz_data_in,
	
	// destination ports
	// PE 0
	input                      PE_0_data_out_ready,
	output                     PE_0_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_0_data_out,

	// PE 1
	input                      PE_1_data_out_ready,
	output                     PE_1_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_1_data_out,

	// PE 2
	input                      PE_2_data_out_ready,
	output                     PE_2_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_2_data_out,

	// PE 3
	input                      PE_3_data_out_ready,
	output                     PE_3_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_3_data_out,

	// PE 4
	input                      PE_4_data_out_ready,
	output                     PE_4_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_4_data_out,

	// PE 5
	input                      PE_5_data_out_ready,
	output                     PE_5_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_5_data_out,

	// PE 6
	input                      PE_6_data_out_ready,
	output                     PE_6_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_6_data_out,

	// PE 7
	input                      PE_7_data_out_ready,
	output                     PE_7_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_7_data_out,

	// PE 8
	input                      PE_8_data_out_ready,
	output                     PE_8_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_8_data_out,

	// PE 9
	input                      PE_9_data_out_ready,
	output                     PE_9_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_9_data_out,

	// PE 10
	input                      PE_10_data_out_ready,
	output                     PE_10_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_10_data_out,

	// PE 11
	input                      PE_11_data_out_ready,
	output                     PE_11_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] PE_11_data_out,
	
	input                      north_data_out_ready,
	output reg                 north_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] north_data_out,

	input                      south_data_out_ready,
	output reg                 south_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] south_data_out,
	
	input                      horiz_data_out_ready,
	output reg                 horiz_data_out_valid,
	output     signed [IACT_SIZE-1 : 0] horiz_data_out,
	
	// control
	input      [1:0]           data_in_sel,
	input      [2:0]           data_out_sel,
	// UNICAST
	input      [3:0]           PE_sel,
	// MULTICAST
	input      [11:0]          PE_choice,
	input      [2:0]           Multicast_mode
);

// ====================================================================	//
// 						 		Parameters  							//
// ====================================================================	//
// data out direction
localparam UNICAST 		= 3'b000;
localparam MULT_CAST 	= 3'b001;
localparam HOR_CAST		= 3'b010;
localparam VER_CAST		= 3'b011;
localparam BROADCAST 	= 3'b100;

// Multicast modes
localparam MULTICAST_1 = 3'd1;
localparam MULTICAST_2 = 3'd2;
localparam MULTICAST_3 = 3'd3;
localparam MULTICAST_4 = 3'd4;
localparam MULTICAST_5 = 3'd5;
localparam MULTICAST_6 = 3'd6;

// PE indices 
localparam PE0  = 4'd0;
localparam PE1  = 4'd1;
localparam PE2  = 4'd2;
localparam PE3  = 4'd3;
localparam PE4  = 4'd4;
localparam PE5  = 4'd5;
localparam PE6  = 4'd6;
localparam PE7  = 4'd7;
localparam PE8  = 4'd8;
localparam PE9  = 4'd9;
localparam PE10 = 4'd10;
localparam PE11 = 4'd11;

// data in direction
localparam GLB   = 2'b00;
localparam NORTH = 2'b01;
localparam SOUTH = 2'b10;
localparam HORIZ = 2'b11;

// ====================================================================	//
// 						 		internal signals  						//
// ====================================================================	//
reg  				internal_data_ready;
reg  				internal_data_valid;
reg	signed [IACT_SIZE-1 : 0]	internal_data;

reg		[11:0]	PEs_data_out_valid_bus; 
wire	[11:0]	PEs_data_out_ready_bus; 


// output in_ready signals
assign GLB_data_in_ready = (data_in_sel == GLB) & internal_data_ready; 
assign north_data_in_ready = (data_in_sel == NORTH) & internal_data_ready;
assign south_data_in_ready = (data_in_sel == SOUTH) & internal_data_ready;
assign horiz_data_in_ready = (data_in_sel == HORIZ) & internal_data_ready;

// internal data bus is connected to all ports
assign PE_0_data_out		= internal_data;
assign PE_1_data_out 		= internal_data;
assign PE_2_data_out 		= internal_data;
assign PE_3_data_out 		= internal_data;
assign PE_4_data_out 		= internal_data;
assign PE_5_data_out 		= internal_data;
assign PE_6_data_out 		= internal_data;
assign PE_7_data_out 		= internal_data;
assign PE_8_data_out 		= internal_data;
assign PE_9_data_out 		= internal_data;
assign PE_10_data_out 		= internal_data;
assign PE_11_data_out 		= internal_data;

assign north_data_out 		= internal_data;
assign south_data_out 		= internal_data;
assign horiz_data_out 		= internal_data;

// connect valid signals to all PEs
assign PE_0_data_out_valid = PEs_data_out_valid_bus[0];
assign PE_1_data_out_valid = PEs_data_out_valid_bus[1];
assign PE_2_data_out_valid = PEs_data_out_valid_bus[2];
assign PE_3_data_out_valid = PEs_data_out_valid_bus[3];
assign PE_4_data_out_valid = PEs_data_out_valid_bus[4];
assign PE_5_data_out_valid = PEs_data_out_valid_bus[5];
assign PE_6_data_out_valid = PEs_data_out_valid_bus[6];
assign PE_7_data_out_valid = PEs_data_out_valid_bus[7];
assign PE_8_data_out_valid = PEs_data_out_valid_bus[8];
assign PE_9_data_out_valid = PEs_data_out_valid_bus[9];
assign PE_10_data_out_valid = PEs_data_out_valid_bus[10];
assign PE_11_data_out_valid = PEs_data_out_valid_bus[11];

// connect PEs ready signals to internal ready bus
assign PEs_data_out_ready_bus = { 
	PE_11_data_out_ready,
	PE_10_data_out_ready,
	PE_9_data_out_ready,
	PE_8_data_out_ready,
	PE_7_data_out_ready,
	PE_6_data_out_ready,
	PE_5_data_out_ready,
	PE_4_data_out_ready,
	PE_3_data_out_ready,
	PE_2_data_out_ready,
	PE_1_data_out_ready,
	PE_0_data_out_ready
};

// valid signals logic
always@(*) begin
	north_data_out_valid 	= 'd0;
	south_data_out_valid 	= 'd0;
	horiz_data_out_valid 	= 'd0;

	PEs_data_out_valid_bus = 12'b0;
	case(data_out_sel)
		UNICAST: begin
			case(PE_sel)
			PE0: begin
				PEs_data_out_valid_bus[0] = internal_data_valid;
			end
			PE1: begin 
				PEs_data_out_valid_bus[1] = internal_data_valid;
			end
			PE2: begin
				PEs_data_out_valid_bus[2] = internal_data_valid;
			end
			PE3: begin 
				PEs_data_out_valid_bus[3] = internal_data_valid;
			end
			PE4: begin
				PEs_data_out_valid_bus[4] = internal_data_valid;
			end
			PE5: begin 
				PEs_data_out_valid_bus[5] = internal_data_valid;
			end
			PE6: begin
				PEs_data_out_valid_bus[6] = internal_data_valid;
			end
			PE7: begin 
				PEs_data_out_valid_bus[7] = internal_data_valid;
			end
			PE8: begin
				PEs_data_out_valid_bus[8] = internal_data_valid;
			end
			PE9: begin 
				PEs_data_out_valid_bus[9] = internal_data_valid;
			end
			PE10: begin
				PEs_data_out_valid_bus[10] = internal_data_valid;
			end
			PE11: begin 
				PEs_data_out_valid_bus[11] = internal_data_valid;
			end
			default: begin
				
			end
			endcase
		end
		MULT_CAST: begin
			PEs_data_out_valid_bus[0] = PE_choice[0] & internal_data_valid;
			PEs_data_out_valid_bus[1] = PE_choice[1] & internal_data_valid;
			PEs_data_out_valid_bus[2] = PE_choice[2] & internal_data_valid;
			PEs_data_out_valid_bus[3] = PE_choice[3] & internal_data_valid;
			PEs_data_out_valid_bus[4] = PE_choice[4] & internal_data_valid;
			PEs_data_out_valid_bus[5] = PE_choice[5] & internal_data_valid;
			PEs_data_out_valid_bus[6] = PE_choice[6] & internal_data_valid;
			PEs_data_out_valid_bus[7] = PE_choice[7] & internal_data_valid;
			PEs_data_out_valid_bus[8] = PE_choice[8] & internal_data_valid;
			PEs_data_out_valid_bus[9] = PE_choice[9] & internal_data_valid;
			PEs_data_out_valid_bus[10] = PE_choice[10] & internal_data_valid;
			PEs_data_out_valid_bus[11] = PE_choice[11] & internal_data_valid;
		end
		HOR_CAST : begin
			horiz_data_out_valid 	= internal_data_valid;
		end	
		VER_CAST : begin
			north_data_out_valid 	= internal_data_valid;
			south_data_out_valid 	= internal_data_valid;
		end	
		BROADCAST : begin
			north_data_out_valid 	= internal_data_valid;
			south_data_out_valid 	= internal_data_valid;
			horiz_data_out_valid 	= internal_data_valid;

			PEs_data_out_valid_bus = {12{internal_data_valid}};
		end	
		default : begin
		end	                        
	endcase                         
end

// internal signals
always@(*) begin
	case(data_out_sel)
		UNICAST: begin
			case(PE_sel)
			PE0: internal_data_ready = PEs_data_out_ready_bus[0];
			PE1: internal_data_ready = PEs_data_out_ready_bus[1];
			PE2: internal_data_ready = PEs_data_out_ready_bus[2];
			PE3: internal_data_ready = PEs_data_out_ready_bus[3];
			PE4: internal_data_ready = PEs_data_out_ready_bus[4];
			PE5: internal_data_ready = PEs_data_out_ready_bus[5];
			PE6: internal_data_ready = PEs_data_out_ready_bus[6];
			PE7: internal_data_ready = PEs_data_out_ready_bus[7];
			PE8: internal_data_ready = PEs_data_out_ready_bus[8];
			PE9: internal_data_ready = PEs_data_out_ready_bus[9];
			PE10: internal_data_ready = PEs_data_out_ready_bus[10];
			PE11: internal_data_ready = PEs_data_out_ready_bus[11];
			default: internal_data_ready = 1'b0;
			endcase
		end
		MULT_CAST: begin
			case (Multicast_mode)
			MULTICAST_1: internal_data_ready = PEs_data_out_ready_bus[0];
			MULTICAST_2: internal_data_ready = PEs_data_out_ready_bus[1] & PEs_data_out_ready_bus[4];
			MULTICAST_3: internal_data_ready = PEs_data_out_ready_bus[2] & PEs_data_out_ready_bus[5] & PEs_data_out_ready_bus[8];
			MULTICAST_4: internal_data_ready = PEs_data_out_ready_bus[3] & PEs_data_out_ready_bus[6] & PEs_data_out_ready_bus[9];
			MULTICAST_5: internal_data_ready = PEs_data_out_ready_bus[7] & PEs_data_out_ready_bus[10];
			MULTICAST_6: internal_data_ready = PEs_data_out_ready_bus[11];
			default: internal_data_ready = 1'b0;
			endcase
		end
		HOR_CAST: internal_data_ready = horiz_data_out_ready;
		VER_CAST: internal_data_ready = south_data_out_ready;
		BROADCAST: internal_data_ready = &PEs_data_out_ready_bus & north_data_out_ready & south_data_out_ready & horiz_data_out_ready;
		default: internal_data_ready = 1'b0;
	endcase
end

always@(*) begin
	case(data_in_sel)
		GLB     : internal_data_valid = GLB_data_in_valid;
		NORTH   : internal_data_valid = north_data_in_valid;
		SOUTH   : internal_data_valid = south_data_in_valid;
		HORIZ   : internal_data_valid = horiz_data_in_valid;
		default : internal_data_valid = 1'b0;
	endcase
end

always@(*) begin
	case(data_in_sel)
		GLB     : internal_data = GLB_data_in;
		NORTH   : internal_data = north_data_in;
		SOUTH   : internal_data = south_data_in;
		HORIZ   : internal_data = horiz_data_in;
		default : internal_data = 'd0;
	endcase
end

endmodule