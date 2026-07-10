module Router_Cluster#(
	parameter IACT_SIZE = 8, // iact precision (from DOTA dataset)
	parameter WEIGHT_SIZE = 8,
	parameter PSUM_SIZE = 20
)(

// **************************************************** control signals ********************************************************** //

    // iact routers
	input   [1:0]   iact_0_data_in_sel,       // GLB = 0, NORTH = 1, SOUTH = 2, HORIZ = 3
    input   [2:0]   iact_0_data_out_sel,      // UNICAST = 0, MULT_CAST = 1, HOR_CAST = 2, VER_CAST = 3, BROADCAST = 4
	input   [3:0]   iact_0_PE_sel,            // PE index 0-11 (for UNICAST)
	input   [11:0]  iact_0_PE_choice,         // 12-bit bitmask for PE selection (for MULTICAST)
	input   [2:0]   iact_0_Multicast_mode,    // MULTICAST modes 1-6

    input   [1:0]   iact_1_data_in_sel,       // GLB = 0, NORTH = 1, SOUTH = 2, HORIZ = 3
    input   [2:0]   iact_1_data_out_sel,      // UNICAST = 0, MULT_CAST = 1, HOR_CAST = 2, VER_CAST = 3, BROADCAST = 4
	input   [3:0]   iact_1_PE_sel,            // PE index 0-11 (for UNICAST)
	input   [11:0]  iact_1_PE_choice,         // 12-bit bitmask for PE selection (for MULTICAST)
	input   [2:0]   iact_1_Multicast_mode,    // MULTICAST modes 1-6

    input   [1:0]   iact_2_data_in_sel,       // GLB = 0, NORTH = 1, SOUTH = 2, HORIZ = 3
    input   [2:0]   iact_2_data_out_sel,      // UNICAST = 0, MULT_CAST = 1, HOR_CAST = 2, VER_CAST = 3, BROADCAST = 4
	input   [3:0]   iact_2_PE_sel,            // PE index 0-11 (for UNICAST)
	input   [11:0]  iact_2_PE_choice,         // 12-bit bitmask for PE selection (for MULTICAST)
	input   [2:0]   iact_2_Multicast_mode,    // MULTICAST modes 1-6


	// weight routers (1 router per row)
	input         weight_0_data_in_sel,   // GLB = 0, HORIZ	= 1
	input         [1:0] weight_0_data_out_sel,  // PE0 = 0, PE1 = 1, PE2 = 2, HOR_CAST = 3

	input         weight_1_data_in_sel,   // GLB = 0, HORIZ	= 1
	input         [1:0] weight_1_data_out_sel,  // PE0 = 0, PE1 = 1, PE2 = 2, HOR_CAST = 3

	input         weight_2_data_in_sel,   // GLB = 0, HORIZ	= 1
	input         [1:0] weight_2_data_out_sel,  // PE0 = 0, PE1 = 1, PE2 = 2, HOR_CAST = 3


	// psum routers (1 router per column)
	input  	[1:0] psum_0_data_in_sel,   // FROM_PE = 0, FROM_NOR = 1, FROM_GLB = 2
	input  	[1:0] psum_0_data_out_sel,  // TO_GLB = 0, TO_SOU = 1, TO_PE = 2
	
	input  	[1:0] psum_1_data_in_sel,   // FROM_PE = 0, FROM_NOR = 1, FROM_GLB = 2
	input  	[1:0] psum_1_data_out_sel,  // TO_GLB = 0, TO_SOU = 1, TO_PE = 2
	
	input  	[1:0] psum_2_data_in_sel,   // FROM_PE = 0, FROM_NOR = 1, FROM_GLB = 2
	input  	[1:0] psum_2_data_out_sel,  // TO_GLB = 0, TO_SOU = 1, TO_PE = 2

	input  	[1:0] psum_3_data_in_sel,   // FROM_PE = 0, FROM_NOR = 1, FROM_GLB = 2
	input  	[1:0] psum_3_data_out_sel,  // TO_GLB = 0, TO_SOU = 1, TO_PE = 2
	

// **************************************************** iact router 0 ********************************************************** //
    // source ports
	output          iact_0_GLB_data_in_ready,		// ready signal to receive data from GLB
	input           iact_0_GLB_data_in_valid,		// data from GLB valid signal
	input   signed [IACT_SIZE-1:0]  iact_0_GLB_data_in,				// data from GLB bus
			
	output          iact_0_north_data_in_ready,     // ready signal to receive data from north neighbour
	input           iact_0_north_data_in_valid,     // data from north neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_0_north_data_in,           // data from north neighbour bus

	output          iact_0_south_data_in_ready,     // ready signal to receive data from south neighbour
	input           iact_0_south_data_in_valid,     // data from south neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_0_south_data_in,           // data from south neighbour bus

	output          iact_0_horiz_data_in_ready,     // ready signal to receive data from horizontal neighbour
	input           iact_0_horiz_data_in_valid,     // data from horizontal neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_0_horiz_data_in,           // data from horizontal neighbour bus
	
	// destination ports
	input           iact_0_PE_0_data_out_ready,     // ready signal from PE 0 to accept data
	output          iact_0_PE_0_data_out_valid,     // data to PE 0 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_0_data_out,           // data to PE 0 bus

	input           iact_0_PE_1_data_out_ready,     // ready signal from PE 1 to accept data
	output          iact_0_PE_1_data_out_valid,     // data to PE 1 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_1_data_out,           // data to PE 1 bus

	input           iact_0_PE_2_data_out_ready,     // ready signal from PE 2 to accept data
	output          iact_0_PE_2_data_out_valid,     // data to PE 2 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_2_data_out,           // data to PE 2 bus

	input           iact_0_PE_3_data_out_ready,     // ready signal from PE 3 to accept data
	output          iact_0_PE_3_data_out_valid,     // data to PE 3 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_3_data_out,           // data to PE 3 bus

	input           iact_0_PE_4_data_out_ready,     // ready signal from PE 4 to accept data
	output          iact_0_PE_4_data_out_valid,     // data to PE 4 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_4_data_out,           // data to PE 4 bus

	input           iact_0_PE_5_data_out_ready,     // ready signal from PE 5 to accept data
	output          iact_0_PE_5_data_out_valid,     // data to PE 5 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_5_data_out,           // data to PE 5 bus

	input           iact_0_PE_6_data_out_ready,     // ready signal from PE 6 to accept data
	output          iact_0_PE_6_data_out_valid,     // data to PE 6 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_6_data_out,           // data to PE 6 bus

	input           iact_0_PE_7_data_out_ready,     // ready signal from PE 7 to accept data
	output          iact_0_PE_7_data_out_valid,     // data to PE 7 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_7_data_out,           // data to PE 7 bus

	input           iact_0_PE_8_data_out_ready,     // ready signal from PE 8 to accept data
	output          iact_0_PE_8_data_out_valid,     // data to PE 8 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_8_data_out,           // data to PE 8 bus

	input           iact_0_PE_9_data_out_ready,     // ready signal from PE 9 to accept data
	output          iact_0_PE_9_data_out_valid,     // data to PE 9 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_9_data_out,           // data to PE 9 bus

	input           iact_0_PE_10_data_out_ready,    // ready signal from PE 10 to accept data
	output          iact_0_PE_10_data_out_valid,    // data to PE 10 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_10_data_out,          // data to PE 10 bus

	input           iact_0_PE_11_data_out_ready,    // ready signal from PE 11 to accept data
	output          iact_0_PE_11_data_out_valid,    // data to PE 11 valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_PE_11_data_out,          // data to PE 11 bus

	input           iact_0_north_data_out_ready,    // ready signal from north neighbour to accept data
	output          iact_0_north_data_out_valid,    // data to north neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_north_data_out,          // data to north neighbour bus

	input           iact_0_south_data_out_ready,    // ready signal from south neighbour to accept data
	output          iact_0_south_data_out_valid,    // data to south neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_south_data_out,          // data to south neighbour bus

	input           iact_0_horiz_data_out_ready,    // ready signal from horizontal neighbour to accept data
	output          iact_0_horiz_data_out_valid,    // data to horizontal neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_0_horiz_data_out,          // data to horizontal neighbour bus

// **************************************************** iact router 1 ********************************************************** //
    // source ports
	output          iact_1_GLB_data_in_ready,       // ready signal to receive data from GLB
	input           iact_1_GLB_data_in_valid,       // data from GLB valid signal
	input   signed [IACT_SIZE-1:0]  iact_1_GLB_data_in,             // data from GLB bus

	output          iact_1_north_data_in_ready,     // ready signal to receive data from north neighbour
	input           iact_1_north_data_in_valid,     // data from north neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_1_north_data_in,           // data from north neighbour bus

	output          iact_1_south_data_in_ready,     // ready signal to receive data from south neighbour
	input           iact_1_south_data_in_valid,     // data from south neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_1_south_data_in,           // data from south neighbour bus

	output          iact_1_horiz_data_in_ready,     // ready signal to receive data from horizontal neighbour
	input           iact_1_horiz_data_in_valid,     // data from horizontal neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_1_horiz_data_in,           // data from horizontal neighbour bus
	
	// destination ports
	input           iact_1_PE_0_data_out_ready,     // ready signal from PE 0 to accept data
	output          iact_1_PE_0_data_out_valid,     // data to PE 0 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_0_data_out,           // data to PE 0 bus

	input           iact_1_PE_1_data_out_ready,     // ready signal from PE 1 to accept data
	output          iact_1_PE_1_data_out_valid,     // data to PE 1 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_1_data_out,           // data to PE 1 bus

	input           iact_1_PE_2_data_out_ready,     // ready signal from PE 2 to accept data
	output          iact_1_PE_2_data_out_valid,     // data to PE 2 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_2_data_out,           // data to PE 2 bus

	input           iact_1_PE_3_data_out_ready,     // ready signal from PE 3 to accept data
	output          iact_1_PE_3_data_out_valid,     // data to PE 3 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_3_data_out,           // data to PE 3 bus

	input           iact_1_PE_4_data_out_ready,     // ready signal from PE 4 to accept data
	output          iact_1_PE_4_data_out_valid,     // data to PE 4 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_4_data_out,           // data to PE 4 bus

	input           iact_1_PE_5_data_out_ready,     // ready signal from PE 5 to accept data
	output          iact_1_PE_5_data_out_valid,     // data to PE 5 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_5_data_out,           // data to PE 5 bus

	input           iact_1_PE_6_data_out_ready,     // ready signal from PE 6 to accept data
	output          iact_1_PE_6_data_out_valid,     // data to PE 6 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_6_data_out,           // data to PE 6 bus

	input           iact_1_PE_7_data_out_ready,     // ready signal from PE 7 to accept data
	output          iact_1_PE_7_data_out_valid,     // data to PE 7 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_7_data_out,           // data to PE 7 bus

	input           iact_1_PE_8_data_out_ready,     // ready signal from PE 8 to accept data
	output          iact_1_PE_8_data_out_valid,     // data to PE 8 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_8_data_out,           // data to PE 8 bus

	input           iact_1_PE_9_data_out_ready,     // ready signal from PE 9 to accept data
	output          iact_1_PE_9_data_out_valid,     // data to PE 9 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_9_data_out,           // data to PE 9 bus

	input           iact_1_PE_10_data_out_ready,    // ready signal from PE 10 to accept data
	output          iact_1_PE_10_data_out_valid,    // data to PE 10 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_10_data_out,          // data to PE 10 bus

	input           iact_1_PE_11_data_out_ready,    // ready signal from PE 11 to accept data
	output          iact_1_PE_11_data_out_valid,    // data to PE 11 valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_PE_11_data_out,          // data to PE 11 bus

	input           iact_1_north_data_out_ready,    // ready signal from north neighbour to accept data
	output          iact_1_north_data_out_valid,    // data to north neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_north_data_out,          // data to north neighbour bus

	input           iact_1_south_data_out_ready,    // ready signal from south neighbour to accept data
	output          iact_1_south_data_out_valid,    // data to south neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_south_data_out,          // data to south neighbour bus

	input           iact_1_horiz_data_out_ready,    // ready signal from horizontal neighbour to accept data
	output          iact_1_horiz_data_out_valid,    // data to horizontal neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_1_horiz_data_out,          // data to horizontal neighbour bus

// **************************************************** iact router 2 ********************************************************** //
    // source ports
	output          iact_2_GLB_data_in_ready,       // ready signal to receive data from GLB
	input           iact_2_GLB_data_in_valid,       // data from GLB valid signal
	input   signed [IACT_SIZE-1:0]  iact_2_GLB_data_in,             // data from GLB bus

	output          iact_2_north_data_in_ready,     // ready signal to receive data from north neighbour
	input           iact_2_north_data_in_valid,     // data from north neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_2_north_data_in,           // data from north neighbour bus
			
	output          iact_2_south_data_in_ready,     // ready signal to receive data from south neighbour
	input           iact_2_south_data_in_valid,     // data from south neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_2_south_data_in,           // data from south neighbour bus

	output          iact_2_horiz_data_in_ready,     // ready signal to receive data from horizontal neighbour
	input           iact_2_horiz_data_in_valid,     // data from horizontal neighbour valid signal
	input   signed [IACT_SIZE-1:0]  iact_2_horiz_data_in,           // data from horizontal neighbour bus
	
	// destination ports
	input           iact_2_PE_0_data_out_ready,     // ready signal from PE 0 to accept data
	output          iact_2_PE_0_data_out_valid,     // data to PE 0 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_0_data_out,           // data to PE 0 bus

	input           iact_2_PE_1_data_out_ready,     // ready signal from PE 1 to accept data
	output          iact_2_PE_1_data_out_valid,     // data to PE 1 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_1_data_out,           // data to PE 1 bus

	input           iact_2_PE_2_data_out_ready,     // ready signal from PE 2 to accept data
	output          iact_2_PE_2_data_out_valid,     // data to PE 2 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_2_data_out,           // data to PE 2 bus

	input           iact_2_PE_3_data_out_ready,     // ready signal from PE 3 to accept data
	output          iact_2_PE_3_data_out_valid,     // data to PE 3 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_3_data_out,           // data to PE 3 bus

	input           iact_2_PE_4_data_out_ready,     // ready signal from PE 4 to accept data
	output          iact_2_PE_4_data_out_valid,     // data to PE 4 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_4_data_out,           // data to PE 4 bus

	input           iact_2_PE_5_data_out_ready,     // ready signal from PE 5 to accept data
	output          iact_2_PE_5_data_out_valid,     // data to PE 5 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_5_data_out,           // data to PE 5 bus

	input           iact_2_PE_6_data_out_ready,     // ready signal from PE 6 to accept data
	output          iact_2_PE_6_data_out_valid,     // data to PE 6 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_6_data_out,           // data to PE 6 bus

	input           iact_2_PE_7_data_out_ready,     // ready signal from PE 7 to accept data
	output          iact_2_PE_7_data_out_valid,     // data to PE 7 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_7_data_out,           // data to PE 7 bus

	input           iact_2_PE_8_data_out_ready,     // ready signal from PE 8 to accept data
	output          iact_2_PE_8_data_out_valid,     // data to PE 8 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_8_data_out,           // data to PE 8 bus

	input           iact_2_PE_9_data_out_ready,     // ready signal from PE 9 to accept data
	output          iact_2_PE_9_data_out_valid,     // data to PE 9 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_9_data_out,           // data to PE 9 bus

	input           iact_2_PE_10_data_out_ready,    // ready signal from PE 10 to accept data
	output          iact_2_PE_10_data_out_valid,    // data to PE 10 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_10_data_out,          // data to PE 10 bus

	input           iact_2_PE_11_data_out_ready,    // ready signal from PE 11 to accept data
	output          iact_2_PE_11_data_out_valid,    // data to PE 11 valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_PE_11_data_out,          // data to PE 11 bus

	input           iact_2_north_data_out_ready,    // ready signal from north neighbour to accept data
	output          iact_2_north_data_out_valid,    // data to north neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_north_data_out,          // data to north neighbour bus

	input           iact_2_south_data_out_ready,    // ready signal from south neighbour to accept data
	output          iact_2_south_data_out_valid,    // data to south neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_south_data_out,          // data to south neighbour bus

	input           iact_2_horiz_data_out_ready,    // ready signal from horizontal neighbour to accept data
	output          iact_2_horiz_data_out_valid,    // data to horizontal neighbour valid signal
	output  signed [IACT_SIZE-1:0]  iact_2_horiz_data_out,          // data to horizontal neighbour bus

// **************************************************** weight router 0 ********************************************************** //
	// ----------Source Ports -----------
	// GLB Source
	input         weight_0_GLB_data_in_valid,   // GLB has valid encoded weight data
	input  signed [WEIGHT_SIZE-1:0] weight_0_GLB_data_in,       // input encoded weight data sent from GLB 
	output        weight_0_GLB_data_in_ready,     // Router tells GLB it's ready to accept the encoded weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         weight_0_horiz_data_in_valid,     // Left PE has valid encoded weight data
	input  signed [WEIGHT_SIZE-1:0] weight_0_horiz_data_in,      // input encoded weight data sent from left PE 
	output        weight_0_horiz_data_in_ready,   // Router tells left PE it's ready to accept the encoded weight data (If data_in_sel != HORIZ → ready = 0)

	// ----------Destination Ports -----------
	// PE0 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_0_PE_0_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_0_PE_0_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_0_PE_1_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_0_PE_1_data_out,       // output encoded weight data received by the PE 

	// PE2 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_0_PE_2_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_0_PE_2_data_out,       // output encoded weight data received by the PE 
	
	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         weight_0_horiz_data_out_ready,      // Right PE is ready to receive encoded weight data (always set to 1 during horizontal cast)
	output        weight_0_horiz_data_out_valid,      // output encoded weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output signed [WEIGHT_SIZE-1:0] weight_0_horiz_data_out,    // output encoded weight data received by the right PE 

// **************************************************** weight router 1 ********************************************************** //
	// ----------Source Ports -----------
	// GLB Source
	input         weight_1_GLB_data_in_valid,   // GLB has valid encoded weight data
	input  signed [WEIGHT_SIZE-1:0] weight_1_GLB_data_in,       // input encoded weight data sent from GLB 
	output        weight_1_GLB_data_in_ready,     // Router tells GLB it's ready to accept the encoded weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         weight_1_horiz_data_in_valid,     // Left PE has valid encoded weight data
	input  signed [WEIGHT_SIZE-1:0] weight_1_horiz_data_in,      // input encoded weight data sent from left PE 
	output        weight_1_horiz_data_in_ready,   // Router tells left PE it's ready to accept the encoded weight data (If data_in_sel != HORIZ → ready = 0)

	// ----------Destination Ports -----------
	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_1_PE_0_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_1_PE_0_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_1_PE_1_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_1_PE_1_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_1_PE_2_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_1_PE_2_data_out,       // output encoded weight data received by the PE 
	
	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         weight_1_horiz_data_out_ready,      // Right PE is ready to receive encoded weight data (always set to 1 during horizontal cast)
	output        weight_1_horiz_data_out_valid,      // output encoded weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output signed [WEIGHT_SIZE-1:0] weight_1_horiz_data_out,    // output encoded weight data received by the right PE 
	
// **************************************************** weight router 2 ********************************************************** //
	// ----------Source Ports -----------
	// GLB Source
	input         weight_2_GLB_data_in_valid,   // GLB has valid encoded weight data
	input  signed [WEIGHT_SIZE-1:0] weight_2_GLB_data_in,       // input encoded weight data sent from GLB 
	output        weight_2_GLB_data_in_ready,     // Router tells GLB it's ready to accept the encoded weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         weight_2_horiz_data_in_valid,     // Left PE has valid encoded weight data
	input  signed [WEIGHT_SIZE-1:0] weight_2_horiz_data_in,      // input encoded weight data sent from left PE 
	output        weight_2_horiz_data_in_ready,   // Router tells left PE it's ready to accept the encoded weight data (If data_in_sel != HORIZ → ready = 0)

	// ----------Destination Ports -----------
	// PE0 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_2_PE_0_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_2_PE_0_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_2_PE_1_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_2_PE_1_data_out,       // output encoded weight data received by the PE 

	// PE2 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_2_PE_2_data_out_valid,      // output encoded weight data received by the PE is valid
	output signed [WEIGHT_SIZE-1:0] weight_2_PE_2_data_out,       // output encoded weight data received by the PE 

	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         weight_2_horiz_data_out_ready,      // Right PE is ready to receive encoded weight data (always set to 1 during horizontal cast)
	output        weight_2_horiz_data_out_valid,      // output encoded weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output signed [WEIGHT_SIZE-1:0] weight_2_horiz_data_out,    // output encoded weight data received by the right PE 


// psum_3_GLB_data_out
// **************************************************** psum router 0 ********************************************************** //
	// source port
	output 								psum_0_PE_data_in_ready,
	input 								psum_0_PE_data_in_valid,
	input signed 	[PSUM_SIZE-1:0]		psum_0_PE_data_in,

	input          						psum_0_GLB_data_out_ready,
	output        					psum_0_GLB_data_out_valid,
	output 	signed 	[PSUM_SIZE-1:0]		psum_0_GLB_data_out,					
// **************************************************** psum router 1 ********************************************************** //
	output 								psum_1_PE_data_in_ready,
	input 								psum_1_PE_data_in_valid,
	input signed 	[PSUM_SIZE-1:0]		psum_1_PE_data_in,

	input          						psum_1_GLB_data_out_ready,
	output        					psum_1_GLB_data_out_valid,
	output 	signed 	[PSUM_SIZE-1:0]		psum_1_GLB_data_out,	
// **************************************************** psum router 2 ********************************************************** //

	output 								psum_2_PE_data_in_ready,
	input 								psum_2_PE_data_in_valid,
	input signed 	[PSUM_SIZE-1:0]		psum_2_PE_data_in,

	input          						psum_2_GLB_data_out_ready,
	output        					psum_2_GLB_data_out_valid,
	output 	signed 	[PSUM_SIZE-1:0]		psum_2_GLB_data_out,	

	// **************************************************** psum router 3 ********************************************************** //

	output 								psum_3_PE_data_in_ready,
	input 								psum_3_PE_data_in_valid,
	input signed 	[PSUM_SIZE-1:0]		psum_3_PE_data_in,

	input          						psum_3_GLB_data_out_ready,
	output        					psum_3_GLB_data_out_valid,
	output 	signed 	[PSUM_SIZE-1:0]		psum_3_GLB_data_out,	
	

	input [2:0] filter_mode
);


// ====================================================================	//
// 						 		Instantiation  							//
// ====================================================================	//
Iact_Router #(
	.IACT_SIZE(IACT_SIZE)
) Iact_Router_0 ( 
	.GLB_data_in_ready      (iact_0_GLB_data_in_ready      	),
	.GLB_data_in_valid      (iact_0_GLB_data_in_valid      	),
	.GLB_data_in	        (iact_0_GLB_data_in				),
	.north_data_in_ready    (iact_0_north_data_in_ready    	),
	.north_data_in_valid    (iact_0_north_data_in_valid    	),
	.north_data_in	        (iact_0_north_data_in			),
	.south_data_in_ready    (iact_0_south_data_in_ready    	),
	.south_data_in_valid    (iact_0_south_data_in_valid    	),
	.south_data_in	        (iact_0_south_data_in			),
	.horiz_data_in_ready    (iact_0_horiz_data_in_ready    	),
	.horiz_data_in_valid    (iact_0_horiz_data_in_valid    	),
	.horiz_data_in          (iact_0_horiz_data_in			),
    .PE_0_data_out_ready    (iact_0_PE_0_data_out_ready       ),
    .PE_0_data_out_valid    (iact_0_PE_0_data_out_valid       ),
    .PE_0_data_out          (iact_0_PE_0_data_out             ),
    .PE_1_data_out_ready    (iact_0_PE_1_data_out_ready       ),
    .PE_1_data_out_valid    (iact_0_PE_1_data_out_valid       ),
    .PE_1_data_out          (iact_0_PE_1_data_out             ),
    .PE_2_data_out_ready    (iact_0_PE_2_data_out_ready       ),
    .PE_2_data_out_valid    (iact_0_PE_2_data_out_valid       ),
    .PE_2_data_out          (iact_0_PE_2_data_out             ),
    .PE_3_data_out_ready    (iact_0_PE_3_data_out_ready       ),
    .PE_3_data_out_valid    (iact_0_PE_3_data_out_valid       ),
    .PE_3_data_out          (iact_0_PE_3_data_out             ),
    .PE_4_data_out_ready    (iact_0_PE_4_data_out_ready       ),
    .PE_4_data_out_valid    (iact_0_PE_4_data_out_valid       ),
    .PE_4_data_out          (iact_0_PE_4_data_out             ),
    .PE_5_data_out_ready    (iact_0_PE_5_data_out_ready       ),
    .PE_5_data_out_valid    (iact_0_PE_5_data_out_valid       ),
    .PE_5_data_out          (iact_0_PE_5_data_out             ),
    .PE_6_data_out_ready    (iact_0_PE_6_data_out_ready       ),
    .PE_6_data_out_valid    (iact_0_PE_6_data_out_valid       ),
    .PE_6_data_out          (iact_0_PE_6_data_out             ),
    .PE_7_data_out_ready    (iact_0_PE_7_data_out_ready       ),
    .PE_7_data_out_valid    (iact_0_PE_7_data_out_valid       ),
    .PE_7_data_out          (iact_0_PE_7_data_out             ),
    .PE_8_data_out_ready    (iact_0_PE_8_data_out_ready       ),
    .PE_8_data_out_valid    (iact_0_PE_8_data_out_valid       ),
    .PE_8_data_out          (iact_0_PE_8_data_out             ),
	.PE_9_data_out_ready    (iact_0_PE_9_data_out_ready       ),
    .PE_9_data_out_valid    (iact_0_PE_9_data_out_valid       ),
    .PE_9_data_out          (iact_0_PE_9_data_out             ),
    .PE_10_data_out_ready    (iact_0_PE_10_data_out_ready       ),
    .PE_10_data_out_valid    (iact_0_PE_10_data_out_valid       ),
    .PE_10_data_out          (iact_0_PE_10_data_out             ),
    .PE_11_data_out_ready    (iact_0_PE_11_data_out_ready       ),
    .PE_11_data_out_valid    (iact_0_PE_11_data_out_valid       ),
    .PE_11_data_out          (iact_0_PE_11_data_out             ),
	.north_data_out_ready	(iact_0_north_data_out_ready	),
	.north_data_out_valid   (iact_0_north_data_out_valid   	),
	.north_data_out         (iact_0_north_data_out		    ),
	.south_data_out_ready(iact_0_south_data_out_ready   	),
	.south_data_out_valid(iact_0_south_data_out_valid   	),
	.south_data_out      (iact_0_south_data_out		    ),
	.horiz_data_out_ready   (iact_0_horiz_data_out_ready   	),
	.horiz_data_out_valid   (iact_0_horiz_data_out_valid   	),
	.horiz_data_out         (iact_0_horiz_data_out		    ),
	.data_in_sel            (iact_0_data_in_sel				),
	.data_out_sel			(iact_0_data_out_sel			),
    .PE_sel                 (iact_0_PE_sel					),
    .PE_choice              (iact_0_PE_choice				),
    .Multicast_mode         (iact_0_Multicast_mode			)
);

Iact_Router #(
	.IACT_SIZE(IACT_SIZE)
) Iact_Router_1 ( 
	.GLB_data_in_ready      (iact_1_GLB_data_in_ready      	),
	.GLB_data_in_valid      (iact_1_GLB_data_in_valid      	),
	.GLB_data_in	        (iact_1_GLB_data_in				),
	.north_data_in_ready    (iact_1_north_data_in_ready    	),
	.north_data_in_valid    (iact_1_north_data_in_valid    	),
	.north_data_in	        (iact_1_north_data_in			),
	.south_data_in_ready    (iact_1_south_data_in_ready    	),
	.south_data_in_valid    (iact_1_south_data_in_valid    	),
	.south_data_in	        (iact_1_south_data_in			),
	.horiz_data_in_ready    (iact_1_horiz_data_in_ready    	),
	.horiz_data_in_valid    (iact_1_horiz_data_in_valid    	),
	.horiz_data_in          (iact_1_horiz_data_in		  	),
    .PE_0_data_out_ready    (iact_1_PE_0_data_out_ready       ),
    .PE_0_data_out_valid    (iact_1_PE_0_data_out_valid       ),
    .PE_0_data_out          (iact_1_PE_0_data_out             ),
    .PE_1_data_out_ready    (iact_1_PE_1_data_out_ready       ),
    .PE_1_data_out_valid    (iact_1_PE_1_data_out_valid       ),
    .PE_1_data_out          (iact_1_PE_1_data_out             ),
    .PE_2_data_out_ready    (iact_1_PE_2_data_out_ready       ),
    .PE_2_data_out_valid    (iact_1_PE_2_data_out_valid       ),
    .PE_2_data_out          (iact_1_PE_2_data_out             ),
    .PE_3_data_out_ready    (iact_1_PE_3_data_out_ready       ),
    .PE_3_data_out_valid    (iact_1_PE_3_data_out_valid       ),
    .PE_3_data_out          (iact_1_PE_3_data_out             ),
    .PE_4_data_out_ready    (iact_1_PE_4_data_out_ready       ),
    .PE_4_data_out_valid    (iact_1_PE_4_data_out_valid       ),
    .PE_4_data_out          (iact_1_PE_4_data_out             ),
    .PE_5_data_out_ready    (iact_1_PE_5_data_out_ready       ),
    .PE_5_data_out_valid    (iact_1_PE_5_data_out_valid       ),
    .PE_5_data_out          (iact_1_PE_5_data_out             ),
    .PE_6_data_out_ready    (iact_1_PE_6_data_out_ready       ),
    .PE_6_data_out_valid    (iact_1_PE_6_data_out_valid       ),
    .PE_6_data_out          (iact_1_PE_6_data_out             ),
    .PE_7_data_out_ready    (iact_1_PE_7_data_out_ready       ),
    .PE_7_data_out_valid    (iact_1_PE_7_data_out_valid       ),
    .PE_7_data_out          (iact_1_PE_7_data_out             ),
    .PE_8_data_out_ready    (iact_1_PE_8_data_out_ready       ),
    .PE_8_data_out_valid    (iact_1_PE_8_data_out_valid       ),
    .PE_8_data_out          (iact_1_PE_8_data_out             ),
	.PE_9_data_out_ready    (iact_1_PE_9_data_out_ready       ),
    .PE_9_data_out_valid    (iact_1_PE_9_data_out_valid       ),
    .PE_9_data_out          (iact_1_PE_9_data_out             ),
    .PE_10_data_out_ready    (iact_1_PE_10_data_out_ready       ),
    .PE_10_data_out_valid    (iact_1_PE_10_data_out_valid       ),
    .PE_10_data_out          (iact_1_PE_10_data_out             ),
    .PE_11_data_out_ready    (iact_1_PE_11_data_out_ready       ),
    .PE_11_data_out_valid    (iact_1_PE_11_data_out_valid       ),
    .PE_11_data_out          (iact_1_PE_11_data_out             ),
	.north_data_out_ready	(iact_1_north_data_out_ready	),
	.north_data_out_valid   (iact_1_north_data_out_valid   	),
	.north_data_out         (iact_1_north_data_out			),
	.south_data_out_ready(iact_1_south_data_out_ready   	),
	.south_data_out_valid(iact_1_south_data_out_valid   	),
	.south_data_out      (iact_1_south_data_out		    ),
	.horiz_data_out_ready   (iact_1_horiz_data_out_ready   	),
	.horiz_data_out_valid   (iact_1_horiz_data_out_valid   	),
	.horiz_data_out         (iact_1_horiz_data_out		    ),
	.data_in_sel            (iact_1_data_in_sel				),
	.data_out_sel			(iact_1_data_out_sel			),
    .PE_sel                 (iact_1_PE_sel					),
    .PE_choice              (iact_1_PE_choice				),
    .Multicast_mode         (iact_1_Multicast_mode			)
);

Iact_Router #(
	.IACT_SIZE(IACT_SIZE)
) Iact_Router_2 ( 
	.GLB_data_in_ready      (iact_2_GLB_data_in_ready      	),
	.GLB_data_in_valid      (iact_2_GLB_data_in_valid      	),
	.GLB_data_in	        (iact_2_GLB_data_in				),
	.north_data_in_ready    (iact_2_north_data_in_ready    	),
	.north_data_in_valid    (iact_2_north_data_in_valid    	),
	.north_data_in	        (iact_2_north_data_in			),
	.south_data_in_ready    (iact_2_south_data_in_ready    	),
	.south_data_in_valid    (iact_2_south_data_in_valid    	),
	.south_data_in	        (iact_2_south_data_in			),
	.horiz_data_in_ready    (iact_2_horiz_data_in_ready    	),
	.horiz_data_in_valid    (iact_2_horiz_data_in_valid    	),
	.horiz_data_in          (iact_2_horiz_data_in		  	),
    .PE_0_data_out_ready    (iact_2_PE_0_data_out_ready       ),
    .PE_0_data_out_valid    (iact_2_PE_0_data_out_valid       ),
    .PE_0_data_out          (iact_2_PE_0_data_out             ),
    .PE_1_data_out_ready    (iact_2_PE_1_data_out_ready       ),
    .PE_1_data_out_valid    (iact_2_PE_1_data_out_valid       ),
    .PE_1_data_out          (iact_2_PE_1_data_out             ),
    .PE_2_data_out_ready    (iact_2_PE_2_data_out_ready       ),
    .PE_2_data_out_valid    (iact_2_PE_2_data_out_valid       ),
    .PE_2_data_out          (iact_2_PE_2_data_out             ),
    .PE_3_data_out_ready    (iact_2_PE_3_data_out_ready       ),
    .PE_3_data_out_valid    (iact_2_PE_3_data_out_valid       ),
    .PE_3_data_out          (iact_2_PE_3_data_out             ),
    .PE_4_data_out_ready    (iact_2_PE_4_data_out_ready       ),
    .PE_4_data_out_valid    (iact_2_PE_4_data_out_valid       ),
    .PE_4_data_out          (iact_2_PE_4_data_out             ),
    .PE_5_data_out_ready    (iact_2_PE_5_data_out_ready       ),
    .PE_5_data_out_valid    (iact_2_PE_5_data_out_valid       ),
    .PE_5_data_out          (iact_2_PE_5_data_out             ),
    .PE_6_data_out_ready    (iact_2_PE_6_data_out_ready       ),
    .PE_6_data_out_valid    (iact_2_PE_6_data_out_valid       ),
    .PE_6_data_out          (iact_2_PE_6_data_out             ),
    .PE_7_data_out_ready    (iact_2_PE_7_data_out_ready       ),
    .PE_7_data_out_valid    (iact_2_PE_7_data_out_valid       ),
    .PE_7_data_out          (iact_2_PE_7_data_out             ),
    .PE_8_data_out_ready    (iact_2_PE_8_data_out_ready       ),
    .PE_8_data_out_valid    (iact_2_PE_8_data_out_valid       ),
    .PE_8_data_out          (iact_2_PE_8_data_out             ),
	.PE_9_data_out_ready    (iact_2_PE_9_data_out_ready       ),
    .PE_9_data_out_valid    (iact_2_PE_9_data_out_valid       ),
    .PE_9_data_out          (iact_2_PE_9_data_out             ),
    .PE_10_data_out_ready    (iact_2_PE_10_data_out_ready       ),
    .PE_10_data_out_valid    (iact_2_PE_10_data_out_valid       ),
    .PE_10_data_out          (iact_2_PE_10_data_out             ),
    .PE_11_data_out_ready    (iact_2_PE_11_data_out_ready       ),
    .PE_11_data_out_valid    (iact_2_PE_11_data_out_valid       ),
    .PE_11_data_out          (iact_2_PE_11_data_out             ),
	.north_data_out_ready	(iact_2_north_data_out_ready	),
	.north_data_out_valid   (iact_2_north_data_out_valid   	),
	.north_data_out         (iact_2_north_data_out			),
	.south_data_out_ready(iact_2_south_data_out_ready   	),
	.south_data_out_valid(iact_2_south_data_out_valid   	),
	.south_data_out      (iact_2_south_data_out		    ),
	.horiz_data_out_ready   (iact_2_horiz_data_out_ready   	),
	.horiz_data_out_valid   (iact_2_horiz_data_out_valid   	),
	.horiz_data_out         (iact_2_horiz_data_out		    ),
	.data_in_sel            (iact_2_data_in_sel				),
	.data_out_sel			(iact_2_data_out_sel			),
    .PE_sel                 (iact_2_PE_sel					),
    .PE_choice              (iact_2_PE_choice				),
    .Multicast_mode         (iact_2_Multicast_mode			)
);

Weight_Router #(
	.WEIGHT_SIZE(WEIGHT_SIZE)
) Weight_Router_0 ( 
	.GLB_data_in_ready      (weight_0_GLB_data_in_ready      	),
	.GLB_data_in_valid      (weight_0_GLB_data_in_valid      	),
	.GLB_data_in            (weight_0_GLB_data_in    			),
	.horiz_data_in_ready    (weight_0_horiz_data_in_ready    	),
	.horiz_data_in_valid    (weight_0_horiz_data_in_valid    	),
	.horiz_data_in          (weight_0_horiz_data_in     		),
	.PE_0_data_out_valid    (weight_0_PE_0_data_out_valid      	),
	.PE_0_data_out          (weight_0_PE_0_data_out   			),
	.PE_1_data_out_valid    (weight_0_PE_1_data_out_valid      	),
	.PE_1_data_out          (weight_0_PE_1_data_out   			),
	.PE_2_data_out_valid    (weight_0_PE_2_data_out_valid      	),
	.PE_2_data_out          (weight_0_PE_2_data_out   			),
	.horiz_data_out_ready   (weight_0_horiz_data_out_ready   	),
	.horiz_data_out_valid   (weight_0_horiz_data_out_valid   	),
	.horiz_data_out         (weight_0_horiz_data_out     		),
	.data_in_sel            (weight_0_data_in_sel            	),
	.data_out_sel           (weight_0_data_out_sel           	)
);

Weight_Router #(
	.WEIGHT_SIZE(WEIGHT_SIZE)
) Weight_Router_1 ( 
	.GLB_data_in_ready      (weight_1_GLB_data_in_ready      	),
	.GLB_data_in_valid      (weight_1_GLB_data_in_valid      	),
	.GLB_data_in            (weight_1_GLB_data_in    			),
	.horiz_data_in_ready    (weight_1_horiz_data_in_ready    	),
	.horiz_data_in_valid    (weight_1_horiz_data_in_valid    	),
	.horiz_data_in          (weight_1_horiz_data_in     		),
	.PE_0_data_out_valid    (weight_1_PE_0_data_out_valid      	),
	.PE_0_data_out          (weight_1_PE_0_data_out   			),
	.PE_1_data_out_valid    (weight_1_PE_1_data_out_valid      	),
	.PE_1_data_out          (weight_1_PE_1_data_out   			),
	.PE_2_data_out_valid    (weight_1_PE_2_data_out_valid      	),
	.PE_2_data_out          (weight_1_PE_2_data_out   			),
	.horiz_data_out_ready   (weight_1_horiz_data_out_ready   	),
	.horiz_data_out_valid   (weight_1_horiz_data_out_valid   	),
	.horiz_data_out         (weight_1_horiz_data_out     		),
	.data_in_sel            (weight_1_data_in_sel            	),
	.data_out_sel           (weight_1_data_out_sel           	)
);

Weight_Router #(
	.WEIGHT_SIZE(WEIGHT_SIZE)
) Weight_Router_2 ( 
	.GLB_data_in_ready      (weight_2_GLB_data_in_ready      	),
	.GLB_data_in_valid      (weight_2_GLB_data_in_valid      	),
	.GLB_data_in            (weight_2_GLB_data_in    			),
	.horiz_data_in_ready    (weight_2_horiz_data_in_ready    	),
	.horiz_data_in_valid    (weight_2_horiz_data_in_valid    	),
	.horiz_data_in          (weight_2_horiz_data_in     		),
	.PE_0_data_out_valid    (weight_2_PE_0_data_out_valid      	),
	.PE_0_data_out          (weight_2_PE_0_data_out   			),
	.PE_1_data_out_valid    (weight_2_PE_1_data_out_valid      	),
	.PE_1_data_out          (weight_2_PE_1_data_out   			),
	.PE_2_data_out_valid    (weight_2_PE_2_data_out_valid      	),
	.PE_2_data_out          (weight_2_PE_2_data_out   			),
	.horiz_data_out_ready   (weight_2_horiz_data_out_ready   	),
	.horiz_data_out_valid   (weight_2_horiz_data_out_valid   	),
	.horiz_data_out         (weight_2_horiz_data_out     		),
	.data_in_sel            (weight_2_data_in_sel            	),
	.data_out_sel           (weight_2_data_out_sel           	)
);

localparam  FILTER_SIZE_9 = 'd0; 
localparam  FILTER_SIZE_7 = 'd1;
localparam  FILTER_SIZE_5 = 'd2;
localparam  FILTER_SIZE_3_1 = 'd3;
localparam  FILTER_SIZE_3_2 = 'd4;
localparam  FILTER_SIZE_3_3 = 'd5;


Psum_Router #(
	.PSUM_SIZE(PSUM_SIZE)
) Psum_Router_0 ( 
	.PE_data_in_ready    (psum_0_PE_data_in_ready    	),
	.PE_data_in_valid    (psum_0_PE_data_in_valid    	),
	.PE_data_in          (psum_0_PE_data_in       	),
	.GLB_out_ready  (psum_0_GLB_data_out_ready  	),
	.GLB_out_valid  (psum_0_GLB_data_out_valid  	),
	.GLB_out        (psum_0_GLB_data_out     	)
);

Psum_Router #(
	.PSUM_SIZE(PSUM_SIZE)
) Psum_Router_1 ( 
	.PE_data_in_ready    (psum_1_PE_data_in_ready    	),
	.PE_data_in_valid    (psum_1_PE_data_in_valid    	),
	.PE_data_in          (psum_1_PE_data_in       	),
	.GLB_out_ready  (psum_1_GLB_data_out_ready  	),
	.GLB_out_valid  (psum_1_GLB_data_out_valid  	),
	.GLB_out        (psum_1_GLB_data_out     	)
);

Psum_Router #(
	.PSUM_SIZE(PSUM_SIZE)
) Psum_Router_2 ( 
	.PE_data_in_ready    (psum_2_PE_data_in_ready    	),
	.PE_data_in_valid    (psum_2_PE_data_in_valid    	),
	.PE_data_in          (psum_2_PE_data_in       	),
	.GLB_out_ready  (psum_2_GLB_data_out_ready  	),
	.GLB_out_valid  (psum_2_GLB_data_out_valid  	),
	.GLB_out        (psum_2_GLB_data_out     	)
);

Psum_Router #(
	.PSUM_SIZE(PSUM_SIZE)
) Psum_Router_3 ( 
	.PE_data_in_ready    (psum_3_PE_data_in_ready    	),
	.PE_data_in_valid    (psum_3_PE_data_in_valid    	),
	.PE_data_in          (psum_3_PE_data_in       	),
	.GLB_out_ready  (psum_3_GLB_data_out_ready  	),
	.GLB_out_valid  (psum_3_GLB_data_out_valid  	),
	.GLB_out        (psum_3_GLB_data_out     	)
);

endmodule