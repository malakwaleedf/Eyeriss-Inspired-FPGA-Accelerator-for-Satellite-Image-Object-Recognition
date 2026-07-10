module cluster_group_controller #(
    parameter IACT_SRAM_ADDRESS_SIZE = 8,
    parameter WEIGHT_SRAM_ADDRESS_SIZE = 7,
    parameter PSUM_SRAM_ADDRESS_SIZE = 5,
    parameter WRITE_COUNT_SIZE = 5,
    parameter WEIGHT_SIZE = 8
) (
    input clock,
    input reset,
    input last_iact_column,

    output reg [1:0] iact_weight_loading_mode_for_pe, // to choose if the pe is loading data from iact router ('d2) or weight router ('d1) or if its not loading at all ('d0)
    output reg iact_dist_enable,

    input [2:0] top_filter_mode, 
    input [2:0] top_input_mode,
    input turn_on, // turn on entire operation 
    // Convolution cofigurations
    input [4:0] cycles_per_iact_col,  // number of needed cycles to process 1 input fmap column with 1 filter column
    input [4:0] unique_values_per_cluster_per_cycle,   // number of unique values per cluster per cycle to process 1 input fmap column with 1 filter column
    input [7:0] unique_values_per_cluster,    // number of unique values per cluster for cycles to process 1 input fmap column with 1 filter column
    input [6:0] weight_values_per_filter,  // number of weight values per filter 
    input [3:0] weight_columns, // number of weight columns per filter

    // iact GLB controls 
    output reg                                  iact_GLB_write_en,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]	iact_GLB_start_write_address,
    input      [IACT_SRAM_ADDRESS_SIZE-1 : 0]	iact_GLB_current_write_address,	
    input                                       iact_GLB_write_done,

    output reg                                  iact_GLB_read_en,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]   iact_GLB_start_read_address_port0,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]   iact_GLB_start_read_address_port1,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]   iact_GLB_start_read_address_port2,
    
    // to request for loading next input fmap columns from bram to glb
    output reg iact_column_done_flag,

    // weight GLB controls 

	input           [WEIGHT_SRAM_ADDRESS_SIZE-1:0]        weight_GLB_write_address_current,
	output reg									weight_GLB_write_en, // enables write
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_write_addr, // initial write address
	input	 									weight_GLB_write_done, // flags the end of write operation

	output reg									weight_GLB_read_en_0, // enables read from port 0
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_0, // initial read address
    input [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]   weight_GLB_read_addr_0_current, // for debug/monitoring
	input	 									weight_GLB_read_done_0, // flags the end of read operation

	output reg									weight_GLB_read_en_1, // enables read from port 1
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_1, // initial read address
    input [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]   weight_GLB_read_addr_1_current, // for debug/monitoring
	input	 									weight_GLB_read_done_1, // flags the end of read operation

	output reg									weight_GLB_read_en_2, // enables read from port 2
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_2, // initial read address
    input [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]   weight_GLB_read_addr_2_current, // for debug/monitoring
	input	 									weight_GLB_read_done_2, // flags the end of read operation


    // psum GLB controls 
    output reg                                  psum_GLB_write_en,
    output reg [PSUM_SRAM_ADDRESS_SIZE-1 : 0]	psum_GLB_start_address,
    input                                       psum_GLB_write_done,
    output reg [WRITE_COUNT_SIZE-1 : 0]         psum_GLB_depth,

    // iact router 0 controls 
    output  reg    [1:0]           iact_router0_data_in_sel,
	output  reg    [2:0]           iact_router0_data_out_sel,
	// UNICAST
	output  reg    [3:0]           iact_router0_PE_sel,
	// MULTICAST
	output  reg    [11:0]          iact_router0_PE_choice,
	output  reg    [2:0]           iact_router0_Multicast_mode,

    // iact router 1 controls 
    output  reg    [1:0]           iact_router1_data_in_sel,
	output  reg    [2:0]           iact_router1_data_out_sel,
	// UNICAST
	output  reg    [3:0]           iact_router1_PE_sel,
	// MULTICAST
	output  reg    [11:0]          iact_router1_PE_choice,
	output  reg    [2:0]           iact_router1_Multicast_mode,

    // iact router 2 controls 
    output  reg    [1:0]           iact_router2_data_in_sel,
	output  reg    [2:0]           iact_router2_data_out_sel,
	// UNICAST
	output  reg    [3:0]           iact_router2_PE_sel,
	// MULTICAST
	output  reg    [11:0]          iact_router2_PE_choice,
	output  reg    [2:0]           iact_router2_Multicast_mode,

// weight router 0  
    output  reg    weight_router0_data_in_sel, 
	output  reg    [1:0] weight_router0_data_out_sel,

// weight router 1  
    output  reg    weight_router1_data_in_sel, 
	output  reg    [1:0] weight_router1_data_out_sel,

// weight router 2 
    output  reg    weight_router2_data_in_sel, 
	output  reg    [1:0] weight_router2_data_out_sel,

// psum router 0 controls
    output reg [1:0] psum_router0_data_in_sel, 
	output reg [1:0] psum_router0_data_out_sel,

// psum router 1 controls
    output reg [1:0] psum_router1_data_in_sel, 
	output reg [1:0] psum_router1_data_out_sel,

// psum router 2 controls  
    output reg [1:0] psum_router2_data_in_sel, 
	output reg [1:0] psum_router2_data_out_sel,

// psum router 3 controls  
    output reg [1:0] psum_router3_data_in_sel, 
	output reg [1:0] psum_router3_data_out_sel,
    
// PE cluster controls
    output  reg    load_PEs_weight,
    input          load_PEs_weight_done,
    output  reg    load_PEs_iact,
    input          load_PEs_iact_done,
    output  reg    mac_start,
    input          mac_done,
    output  reg    psum_stream_start,
    input          psum_stream_done,
    output  reg    read_PEs_psum,

    output reg [4:0] mac_done_counter,  // counts cycles_per_iact_col, index to spad
    output reg [3:0] weight_column_counter, // counts weight_columns

    input          iact_next_ofmap_col, // from top

    //from cluster group controller to pe cluster to determine pe mod is it mac or stream
    output reg PE_mode
);

// ====================================================================	//
// 			    	Top filter modes (top_filter_mode) 			        //
// ====================================================================	//
    localparam FILTER_SIZE_3 = 3'b000;
    localparam FILTER_SIZE_5 = 3'b001;
    localparam FILTER_SIZE_7 = 3'b010;
    localparam FILTER_SIZE_9 = 3'b011;

// ====================================================================	//
// 			    	Top input modes (top_input_mode)                    //
// ====================================================================	//
    localparam INPUT_SIZE_1024 = 3'b000;
    localparam INPUT_SIZE_512  = 3'b001;
    localparam INPUT_SIZE_256  = 3'b010;  
    localparam INPUT_SIZE_128  = 3'b011;
    localparam INPUT_SIZE_64   = 3'b100;
    localparam INPUT_SIZE_32   = 3'b101;

// ====================================================================	//
// 			    	Iact router parameters                              //
// ====================================================================	//
    // data out direction
        localparam IACT_ROUTER_DATA_OUT_UNICAST     = 3'b000;
        localparam IACT_ROUTER_DATA_OUT_MULT_CAST 	= 3'b001;
        localparam IACT_ROUTER_DATA_OUT_HOR_CAST    = 3'b010;
        localparam IACT_ROUTER_DATA_OUT_VER_CAST    = 3'b011;
        localparam IACT_ROUTER_DATA_OUT_BROADCAST 	= 3'b100;

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
        localparam IACT_ROUTER_DATA_IN_GLB = 2'b00;
        localparam IACT_ROUTER_DATA_IN_NORTH = 2'b01;
        localparam IACT_ROUTER_DATA_IN__SOUTH = 2'b10;
        localparam IACT_ROUTER_DATA_IN__HORIZ = 2'b11;

// ====================================================================	//
// 			    	Weight router parameters  					    	//
// ====================================================================	//
    // data out direction
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_PE0  = 'd0;
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_PE1  = 'd1;
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_PE2  = 'd2;
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_HOR_CAST  = 'd3;

    // data in direction
        localparam WEIGHT_ROUTER_DATA_IN_GLB   	= 1'b0;
        localparam WEIGHT_ROUTER_DATA_IN_HORIZ	= 1'b1;


// ====================================================================	//
// 			    		Internal signals and buses  					//
// ====================================================================	//

reg weight_columns_done_flag;

reg psum_stream_done_reg;

reg PE_mac_start;

reg [3:0] iact_load_counter;

reg route_inc_flag;

reg weight_columns_done_flag_reg;
reg iact_column_done_flag_reg;

// ====================================================================	//
// 			    		FSM states                   					//
// ====================================================================	//
    localparam IDLE = 'd0;
    localparam GLB_LOAD_ADDRESS = 'd1; // initially send start write address to weight and iact GLB 
    localparam GLB_LOAD = 'd2; // initially load iact and weight GLB

    localparam GLB_WEIGHT_READ_ADDRESS = 'd3; // send start read address to weight GLB 
    localparam ROUTE_WEIGHT_1 = 'd4; // read weights from GLB, route them to PEs
    localparam ROUTE_WEIGHT_2 = 'd5; // read weights from GLB, route them to PEs
    localparam ROUTE_WEIGHT_3 = 'd6; // read weights from GLB, route them to PEs
    localparam Router_iact_wait = 'd22;

    localparam GLB_IACT_READ_ADDRESS = 'd7; // send start read address to iact GLB 
    localparam ROUTE_IACT_1 = 'd8; // read iacts from GLB, route them to PEs (mode 1)
    localparam ROUTE_IACT_2 = 'd9; // read iacts from GLB, route them to PEs (mode 2)
    localparam ROUTE_IACT_3 = 'd10; // read iacts from GLB, route them to PEs (mode 3)
    localparam ROUTE_IACT_4 = 'd11; // read iacts from GLB, route them to PEs (mode 4)
    localparam ROUTE_IACT_5 = 'd12; // read iacts from GLB, route them to PEs (mode 5)
    localparam ROUTE_IACT_6 = 'd13; // read iacts from GLB, route them to PEs (mode 6)

    localparam IACT_GLB_LOAD_ADDRESS = 'd14; // send start write address to iact GLB 
    localparam PE_START_IACT_GLB_LOAD = 'd15; // PE starts operation for 1 input fmap col & load iact GLB (new iacts) while PE is working

    localparam PSUM_STREAM = 'd16;  // PEs stream psums to the PE beneath every filter window
    localparam PSUM_GLB_LOAD_ADDRESS = 'd17; // send start write address to psum GLB 
    localparam PSUM_GLB_LOAD = 'd18; // load psum GLB (with output fmap col)

reg [4:0] current_state, next_state;
reg mac_on; // internal signals to pulse mac start signal
reg write_back;
reg weight_GLB_write_done_reg;// Register for weight_GLB_write_done
reg iact_GLB_write_done_reg;



always @(posedge clock) begin
    if (reset) begin
        weight_GLB_write_done_reg <= 'd0;
    end
    else begin
        if (weight_GLB_write_done) begin
            if (current_state == GLB_WEIGHT_READ_ADDRESS) begin
                weight_GLB_write_done_reg <= 'd0;
            end
            else begin
                weight_GLB_write_done_reg <= weight_GLB_write_done;
            end
        end
    end
end



always @(posedge clock) begin
    if (reset) begin
        iact_GLB_write_done_reg <= 'd0;
    end
    else if ((current_state == PSUM_STREAM )|| (current_state == IACT_GLB_LOAD_ADDRESS)) begin
        iact_GLB_write_done_reg <= 'd0;
    end
    else if (iact_GLB_write_done) begin
        iact_GLB_write_done_reg <= 'd1;
    end
end

always @(posedge clock) begin
    if(reset) begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

// next state logic 
always @(*) begin
    next_state = current_state;
    case(current_state)
        IDLE: begin
            if (turn_on) begin
                next_state = GLB_LOAD_ADDRESS; 
            end
            else begin
                next_state = IDLE;
            end
        end
        GLB_LOAD_ADDRESS: begin
            next_state = GLB_LOAD;
        end
        GLB_LOAD: begin
            if ((iact_GLB_current_write_address == unique_values_per_cluster) & (weight_GLB_write_done_reg)) begin
                next_state = GLB_WEIGHT_READ_ADDRESS;
            end
            else begin
                next_state = GLB_LOAD;
            end
        end


        GLB_WEIGHT_READ_ADDRESS: begin
            next_state = ROUTE_WEIGHT_1;
        end

        
        ROUTE_WEIGHT_1: begin
            if (load_PEs_weight_done) begin
                next_state = GLB_WEIGHT_READ_ADDRESS;
            end
            else begin
                if (weight_GLB_read_addr_0_current == (weight_columns) - 1) begin
                    next_state = ROUTE_WEIGHT_2;
                end
                else begin
                    next_state = ROUTE_WEIGHT_1;
                end
            end
        end   
        ROUTE_WEIGHT_2: begin
            if (load_PEs_weight_done) begin
                next_state = GLB_WEIGHT_READ_ADDRESS;
            end
            else begin
                if (weight_GLB_read_addr_0_current == (weight_columns<<1) - 1) begin
                    next_state = ROUTE_WEIGHT_3;
                end
                else begin
                    next_state = ROUTE_WEIGHT_2;
                end
            end    
        end
        ROUTE_WEIGHT_3: begin
            if (load_PEs_weight_done) begin
                next_state = GLB_WEIGHT_READ_ADDRESS;
            end
            else begin
                if (weight_GLB_read_addr_0_current == (weight_columns<<1) + weight_columns) begin
                    next_state = GLB_IACT_READ_ADDRESS;
                end
                else begin
                    next_state = ROUTE_WEIGHT_3;
                end
            end  
        end     

        GLB_IACT_READ_ADDRESS: begin
            next_state = Router_iact_wait;    
        end

        Router_iact_wait: begin
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = ROUTE_IACT_1;
            end
        end
        ROUTE_IACT_1: begin
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = ROUTE_IACT_2;
            end
        end
        ROUTE_IACT_2: begin
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = ROUTE_IACT_3;
            end
        end
        ROUTE_IACT_3: begin
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = ROUTE_IACT_4;
            end
        end
        ROUTE_IACT_4: begin
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = ROUTE_IACT_5;
            end
        end
        ROUTE_IACT_5: begin
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = ROUTE_IACT_6;
            end
        end
        ROUTE_IACT_6: begin
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = GLB_IACT_READ_ADDRESS;
            end
        end

        IACT_GLB_LOAD_ADDRESS: begin
            next_state = PE_START_IACT_GLB_LOAD;
        end

        PE_START_IACT_GLB_LOAD: begin
              if (!weight_columns_done_flag_reg && iact_column_done_flag_reg && iact_GLB_write_done_reg) begin
                next_state = GLB_IACT_READ_ADDRESS;
            end
            else if (weight_columns_done_flag_reg && iact_column_done_flag_reg) begin
                next_state = PSUM_STREAM;
            end 
            else begin
                next_state = PE_START_IACT_GLB_LOAD;
            end
        end

        PSUM_STREAM: begin
            if (psum_stream_done) begin
                next_state = PSUM_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = PSUM_STREAM;
            end 
        end
        PSUM_GLB_LOAD_ADDRESS: begin
            next_state = PSUM_GLB_LOAD;
        end
        PSUM_GLB_LOAD: begin
            if(psum_GLB_write_done) begin
                next_state = IDLE;
            end
            else begin
                next_state = PSUM_GLB_LOAD;
            end 
        end
    endcase
end

always @(*) begin
        iact_dist_enable = 'd0;
        iact_weight_loading_mode_for_pe = 'd0;
        iact_GLB_write_en =0;
        iact_GLB_start_write_address=0;
        weight_GLB_write_en = 0;
        weight_GLB_write_addr = 0;
        weight_GLB_read_en_0 = 0;
        weight_GLB_read_en_1 = 0;
        weight_GLB_read_en_2 = 0;
        weight_GLB_read_addr_0 = 0;
        weight_GLB_read_addr_1 = 0;
        weight_GLB_read_addr_2 = 0;
        psum_GLB_write_en = 0;
        psum_GLB_start_address=0;
        iact_router0_data_in_sel=0;
        iact_router0_data_out_sel= 0;
        iact_router0_PE_sel=0;
        iact_router0_PE_choice=0;
        iact_router0_Multicast_mode=0;
        iact_router1_data_in_sel=0;
        iact_router1_data_out_sel= 0;
        iact_router1_PE_sel=0;
        iact_router1_PE_choice=0;
        iact_router1_Multicast_mode=0;
        iact_router2_data_in_sel=0;
        iact_router2_data_out_sel= 0;
        iact_router2_PE_sel=0;
        iact_router2_PE_choice=0;
        iact_router2_Multicast_mode=0;
        load_PEs_weight = 0;
        load_PEs_iact = 0;
        mac_start = 0;
        PE_mode = 0;
        psum_stream_start = 0;
        read_PEs_psum = 0;
        weight_router0_data_in_sel = 0;
        weight_router1_data_in_sel = 0;
        weight_router2_data_in_sel = 0;
        iact_GLB_read_en =0;
        route_inc_flag = 0;
        psum_GLB_depth = cycles_per_iact_col;
    case(current_state)
        IDLE: begin

        end
        GLB_LOAD_ADDRESS: begin
            iact_GLB_start_write_address = 'd0;
            weight_GLB_write_addr = 'd0;  
            iact_dist_enable = 'd1;     
            end
        GLB_LOAD: begin
            if (weight_GLB_write_address_current == weight_values_per_filter) begin
                weight_GLB_write_en = 1'b0;
            end
            else begin 
                weight_GLB_write_en = 1'b1;
            end
            if (iact_GLB_current_write_address == unique_values_per_cluster) begin
                iact_GLB_write_en = 1'b0;
                iact_dist_enable = 'd0;
            end 
            else begin
                iact_GLB_write_en = 1'b1;
                iact_dist_enable = 'd1;
            end
        end
        GLB_WEIGHT_READ_ADDRESS: begin
           iact_weight_loading_mode_for_pe = 'd1; 
           weight_GLB_read_addr_0 = 'd0;
           weight_GLB_read_addr_1 = (weight_columns<<1) + weight_columns;
           weight_GLB_read_addr_2 = (weight_columns<<2) + (weight_columns<<1);
           load_PEs_weight = 'd1;
        end
        ROUTE_WEIGHT_1: begin
            weight_GLB_read_addr_0 = 'd0;
            weight_GLB_read_addr_1 = (weight_columns<<1) + weight_columns;
            weight_GLB_read_addr_2 = (weight_columns<<2) + (weight_columns<<1);

            iact_weight_loading_mode_for_pe = 'd1; 
          
            weight_router0_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            weight_router1_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            weight_router2_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            weight_GLB_read_en_0 = 'd1;  
            weight_GLB_read_en_1 = 'd1;            
            weight_GLB_read_en_2 = 'd1;
            load_PEs_weight = 'd1;
        end
        ROUTE_WEIGHT_2: begin
            weight_GLB_read_addr_0 = 'd0;
            weight_GLB_read_addr_1 = (weight_columns<<1) + weight_columns;
            weight_GLB_read_addr_2 = (weight_columns<<2) + (weight_columns<<1);

            iact_weight_loading_mode_for_pe = 'd1;

            weight_router0_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            weight_router1_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            weight_router2_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            load_PEs_weight = 'd1;
            weight_GLB_read_en_0 = 'd1;  
            weight_GLB_read_en_1 = 'd1;            
            weight_GLB_read_en_2 = 'd1;
        end
        ROUTE_WEIGHT_3: begin
            weight_GLB_read_addr_0 = 'd0;
            weight_GLB_read_addr_1 = (weight_columns<<1) + weight_columns;
            weight_GLB_read_addr_2 = (weight_columns<<2) + (weight_columns<<1);

            iact_weight_loading_mode_for_pe = 'd1;

            weight_router0_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            weight_router1_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            weight_router2_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;

            if ((weight_GLB_read_addr_0_current == (weight_values_per_filter-1)) && (weight_GLB_read_addr_1_current == (weight_values_per_filter-1)) && (weight_GLB_read_addr_2_current == (weight_values_per_filter-1))) begin
                load_PEs_weight = 'd0;
                weight_GLB_read_en_0 = 'd0;  
                weight_GLB_read_en_1 = 'd0;            
                weight_GLB_read_en_2 = 'd0;
            end
            else begin
                load_PEs_weight = 'd1;
                weight_GLB_read_en_0 = 'd1;  
                weight_GLB_read_en_1 = 'd1;            
                weight_GLB_read_en_2 = 'd1;
            end
        end
        
        GLB_IACT_READ_ADDRESS: begin
            
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;

            iact_weight_loading_mode_for_pe = 'd2; 
            case (top_filter_mode)
            FILTER_SIZE_9: begin
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd3; // port1 starts from 3 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd6; // port1 starts from 6 and increments by unique_values_per_cluster_per_cycle
            end
            FILTER_SIZE_7: begin
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd3; // port1 starts from 3 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd6; // port1 starts from 6 and increments by unique_values_per_cluster_per_cycle
            end
            FILTER_SIZE_5: begin
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd3; // port1 starts from 3 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd6; // port1 starts from 6 and increments by unique_values_per_cluster_per_cycle
            end
            FILTER_SIZE_3: begin
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd4; // port1 starts from 4 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd8; // port1 starts from 8 and increments by unique_values_per_cluster_per_cycle
            end
            endcase
        end
        Router_iact_wait: begin
            iact_GLB_read_en = 'd1;
        end
        ROUTE_IACT_1: begin
            load_PEs_iact = 'd1;
            iact_weight_loading_mode_for_pe = 'd2;
            iact_GLB_read_en = 'd1;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0000_0000_0001;
            iact_router0_Multicast_mode = MULTICAST_1;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0000_0000_0001;
            iact_router1_Multicast_mode = MULTICAST_1;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0000_0000_0001;
            iact_router2_Multicast_mode = MULTICAST_1;
        end
        ROUTE_IACT_2: begin
            load_PEs_iact = 'd1;
            iact_GLB_read_en = 'd1;
            iact_weight_loading_mode_for_pe = 'd2;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0000_0001_0010;
            iact_router0_Multicast_mode = MULTICAST_2;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0000_0001_0010;
            iact_router1_Multicast_mode = MULTICAST_2;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0000_0001_0010;
            iact_router2_Multicast_mode = MULTICAST_2;
        end
        ROUTE_IACT_3: begin
            load_PEs_iact = 'd1;
            iact_GLB_read_en = 'd1;

            iact_weight_loading_mode_for_pe = 'd2;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0001_0010_0100;
            iact_router0_Multicast_mode = MULTICAST_3;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0001_0010_0100;
            iact_router1_Multicast_mode = MULTICAST_3;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0001_0010_0100;
            iact_router2_Multicast_mode = MULTICAST_3;
        end
        ROUTE_IACT_4: begin
            load_PEs_iact = 'd1;
            iact_GLB_read_en = 'd1;

            iact_weight_loading_mode_for_pe = 'd2;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0010_0100_1000;
            iact_router0_Multicast_mode = MULTICAST_4;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0010_0100_1000;
            iact_router1_Multicast_mode = MULTICAST_4;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0010_0100_1000;
            iact_router2_Multicast_mode = MULTICAST_4;
        end
        ROUTE_IACT_5: begin
            load_PEs_iact = 'd1;
            iact_GLB_read_en = 'd1;

            iact_weight_loading_mode_for_pe = 'd2;
           
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0100_1000_0000;
            iact_router0_Multicast_mode = MULTICAST_5;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0100_1000_0000;
            iact_router1_Multicast_mode = MULTICAST_5;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0100_1000_0000;
            iact_router2_Multicast_mode = MULTICAST_5;
        end
        ROUTE_IACT_6: begin
            load_PEs_iact = 'd1;
            iact_GLB_read_en = 'd1;
            iact_weight_loading_mode_for_pe = 'd2;
            
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b1000_0000_0000;
            iact_router0_Multicast_mode = MULTICAST_6;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b1000_0000_0000;
            iact_router1_Multicast_mode = MULTICAST_6;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 12'd12;
            iact_router2_PE_choice = 12'b1000_0000_0000;
            iact_router2_Multicast_mode = MULTICAST_6;

            route_inc_flag = 1;
        end

        IACT_GLB_LOAD_ADDRESS: begin
            iact_dist_enable = 'd1;
            iact_GLB_start_write_address = 'd0;
        end
        PE_START_IACT_GLB_LOAD: begin
            iact_dist_enable = 'd1;
            if (iact_GLB_current_write_address == unique_values_per_cluster) begin
                iact_GLB_write_en = 1'b0;
            end 
            else begin
                iact_GLB_write_en = 1'b1;
            end
            
            if (iact_column_done_flag_reg) begin
                mac_start = 'd0;
                PE_mode = 'd0;
            end

            else begin
                PE_mode = 'd0;
                if(!mac_on) begin
                    mac_start = 'd1;
                end
                else begin
                    mac_start = 'd0;
            end
            end
        end
        PSUM_STREAM: begin
            psum_stream_start = 'd1;
            PE_mode = 'd1;
        end
        PSUM_GLB_LOAD_ADDRESS: begin
            psum_GLB_start_address = 0; // same for all psum GLBs
            psum_GLB_depth = cycles_per_iact_col;
            read_PEs_psum = 'd1;
        end
        PSUM_GLB_LOAD: begin
            
            psum_GLB_write_en = 'd1;
            weight_router0_data_in_sel = 'd0;
            weight_router1_data_in_sel = 'd0;
            weight_router2_data_in_sel = 'd0;
        end

    endcase
end

// ====================================================================	//

always @(posedge clock) begin
    if (reset) begin
        weight_router0_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
        weight_router1_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
        weight_router2_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
    end
    else begin
        case (current_state)
            ROUTE_WEIGHT_1: begin
                // Data from ROUTE_WEIGHT_3 arrives here
                weight_router0_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
                weight_router1_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
                weight_router2_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
            end
            ROUTE_WEIGHT_2: begin
                // Data from ROUTE_WEIGHT_1 arrives here
                weight_router0_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE1;
                weight_router1_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE1;
                weight_router2_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE1;
            end
            ROUTE_WEIGHT_3: begin
                // Data from ROUTE_WEIGHT_2 arrives here
                weight_router0_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE2;
                weight_router1_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE2;
                weight_router2_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE2;
            end

        default: begin
            weight_router0_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
            weight_router1_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
            weight_router2_data_out_sel <= WEIGHT_ROUTER_DATA_OUT_PE0;
        end
        endcase
    end
end



// ====================================================================	//
// 			        	Counters                       					//
// ====================================================================	//
// Counter for the iact address offset
always @(posedge clock) begin
    if (reset) begin
        iact_load_counter <= 1'b0;
    end
    else if (route_inc_flag) begin
        iact_load_counter <= iact_load_counter + 1'b1;
    end
    else if(iact_load_counter == unique_values_per_cluster) begin
        iact_load_counter <= 1'b0;
    end
end

// Counter for iact column (mac cycles)
always @(posedge clock) begin
    if (reset) begin
        mac_done_counter <= 4'b0;
    end
    else if (mac_done == 1'b1 && !iact_column_done_flag) begin
        mac_done_counter <= mac_done_counter + 4'b1;
    end
    else if (mac_done_counter == cycles_per_iact_col) begin
        mac_done_counter <= 4'b0;
    end    
end

always @(posedge clock) begin
    if (reset) begin
        iact_column_done_flag <= 1'b0;
    end
    else if (mac_done_counter == cycles_per_iact_col) begin
        iact_column_done_flag <= 1'b1;
    end
    else if(iact_column_done_flag) begin
        iact_column_done_flag <= 1'b0;
    end
end

// Counter for weight column
always @(posedge clock) begin
    if (reset) begin
        weight_column_counter <= 4'b0;
    end
    else if (mac_done_counter == cycles_per_iact_col) begin
        weight_column_counter <= weight_column_counter + 4'b1;
    end
    else if (weight_columns_done_flag) begin
        weight_column_counter <= 4'b0;
    end
end

always @(posedge clock) begin
    if (reset) begin
        weight_columns_done_flag <= 1'b0;
    end
    else if (weight_column_counter == weight_columns) begin
        weight_columns_done_flag <= 1'b1;
    end
    else if (next_state == PSUM_STREAM) begin
        weight_columns_done_flag <= 1'b0;
    end
end

always @(posedge clock) begin
    if(reset) begin
        mac_on <= 1'b0;
    end
    else if (mac_start) begin
        mac_on <= 1'b1;
    end
    else if (write_back) begin
        mac_on <= 1'b0;
    end
end

always @(posedge clock) begin
    if(reset) begin
        write_back <= 1'b0;
    end
    else if (mac_on) begin
        write_back <= 1'b1;
    end
    else if (write_back) begin
        write_back <= 1'b0;
    end
end 

always @(posedge clock) begin
    if(reset) begin
        weight_columns_done_flag_reg <= 1'b0;
    end
    else if (weight_column_counter == weight_columns) begin
        weight_columns_done_flag_reg <= 1'b1;
    end
    else if (current_state ==PSUM_STREAM) begin
        weight_columns_done_flag_reg <= 1'b0;
    end
end


always @(posedge clock) begin
    if(reset) begin
        iact_column_done_flag_reg <= 1'b0;
    end
    else if (iact_column_done_flag || (mac_done_counter == cycles_per_iact_col - 1)) begin
        iact_column_done_flag_reg <= 1'b1;
    end
    else if ((current_state == GLB_IACT_READ_ADDRESS)|| (current_state ==PSUM_STREAM)) begin
        iact_column_done_flag_reg <= 1'b0;
    end
end
    
endmodule