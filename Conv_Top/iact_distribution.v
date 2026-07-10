module iact_distribution #(
    parameter IACT_WIDTH = 8,   // iact value bitwidth (INT8)
    parameter IACT_SRAM_DEPTH = 256, // iact GLB depth 
	parameter IACT_SRAM_ADDRESS_SIZE = 8,
    parameter NUMBER_OF_CLUSTERS = 16,
    parameter DRAM_ADDRESS_SIZE = 21 
)(
    input clock,
    input reset,
    input enable,

    input local_reset,

	input [4:0] cycles_per_iact_col, // = 16
    input [4:0] unique_values_per_cluster_per_cycle, // = 12

    // between iact_dist and dram
    input signed [IACT_WIDTH-1:0] iact_data_in_from_dram_to_iact_dist,
    output [DRAM_ADDRESS_SIZE-1:0] iact_data_in_addr_from_iact_dist_to_dram,

    // between iact_dist and glb
    output reg [NUMBER_OF_CLUSTERS-1:0] iact_data_out_valid_from_iact_dist_to_glb,
    input [NUMBER_OF_CLUSTERS-1:0] iact_data_out_ready_from_glb_to_iact_dist,
    output signed [IACT_WIDTH-1:0] iact_data_out_from_iact_dist_to_glb
);

reg [DRAM_ADDRESS_SIZE-1:0] dram_idx;

reg [4:0] current_state, next_state;

reg [4:0] cycles_per_iact_col_counter;
reg [3:0] unique_values_per_cluster_per_cycle_counter;

reg enable_reg;



localparam IDLE = 'd0;
localparam CLUSTER_0 = 'd1;
localparam CLUSTER_1 = 'd2;
localparam CLUSTER_2 = 'd3;
localparam CLUSTER_3 = 'd4;
localparam CLUSTER_4 = 'd5;
localparam CLUSTER_5 = 'd6;
localparam CLUSTER_6 = 'd7;
localparam CLUSTER_7 = 'd8;
localparam CLUSTER_8 = 'd9;
localparam CLUSTER_9 = 'd10;
localparam CLUSTER_10 = 'd11;
localparam CLUSTER_11 = 'd12;
localparam CLUSTER_12 = 'd13;
localparam CLUSTER_13 = 'd14;
localparam CLUSTER_14 = 'd15;
localparam CLUSTER_15 = 'd16;


assign iact_data_in_addr_from_iact_dist_to_dram = dram_idx;
assign iact_data_out_from_iact_dist_to_glb = iact_data_in_from_dram_to_iact_dist;



always @(posedge clock) begin
    if (reset) begin
        enable_reg <= 'd0;
    end

    else begin
        enable_reg <= enable;
    end
end

reg current_cluster_ready;
always @(*) begin
    case (current_state)
        CLUSTER_0:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[0];
        CLUSTER_1:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[1];
        CLUSTER_2:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[2];
        CLUSTER_3:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[3];
        CLUSTER_4:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[4];
        CLUSTER_5:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[5];
        CLUSTER_6:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[6];
        CLUSTER_7:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[7];
        CLUSTER_8:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[8];
        CLUSTER_9:  current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[9];
        CLUSTER_10: current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[10];
        CLUSTER_11: current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[11];
        CLUSTER_12: current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[12];
        CLUSTER_13: current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[13];
        CLUSTER_14: current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[14];
        CLUSTER_15: current_cluster_ready = iact_data_out_ready_from_glb_to_iact_dist[15];
        default:    current_cluster_ready = 1'b0;
    endcase
end

// dram read index
always @(posedge clock) begin
    if (reset) begin
        dram_idx <= 'd0;
    end
    else if (enable_reg && current_cluster_ready) begin
        if ((current_state == CLUSTER_15) && (cycles_per_iact_col_counter == cycles_per_iact_col - 'd1)) begin
            dram_idx <= dram_idx + 'd1;
        end
        else if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            dram_idx <= dram_idx - 'd967;
        end
        else if (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1) begin
            dram_idx <= dram_idx + 'd53;        
        end
        else if (cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) begin
            dram_idx <= dram_idx + 'd1;
        end
        else begin
            dram_idx <= dram_idx + 'd1;
        end
    end
    else if (local_reset && dram_idx != 0) begin
        dram_idx <= dram_idx - 'd8256;
    end
end

// unique_value_per_cycle_counter
always @(posedge clock) begin
    if (reset) begin
        unique_values_per_cluster_per_cycle_counter <= 'd0;
    end

    else if (enable_reg && current_cluster_ready) begin
        if (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1) begin
            unique_values_per_cluster_per_cycle_counter <= 'd0;
        end
        else begin
            unique_values_per_cluster_per_cycle_counter <= unique_values_per_cluster_per_cycle_counter + 'd1;
        end
    end
end

// cycles_per_iact_col_counter
always @(posedge clock) begin
    if (reset) begin
        cycles_per_iact_col_counter <= 'd0;
    end

    else if (enable && current_cluster_ready) begin
        if (cycles_per_iact_col_counter == cycles_per_iact_col) begin
            cycles_per_iact_col_counter <= 'd0;
        end
        else if (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1) begin
            cycles_per_iact_col_counter <= cycles_per_iact_col_counter + 'd1;
    end
end
end


// State transition
always @(posedge clock) begin
    if(reset || (!enable)) begin
        current_state <= IDLE; 
    end

    else begin
        current_state <= next_state;
    end
end


// next state logic
always @(*) begin
    case (current_state)
    IDLE: begin
        if (enable) begin
            next_state = CLUSTER_0;
        end

        else begin
            next_state = IDLE;
        end
    end

    CLUSTER_0: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_1;
        end

        else begin
            next_state = CLUSTER_0;
        end
    end

    CLUSTER_1: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_2;
        end

        else begin
            next_state = CLUSTER_1;
        end
    end

    CLUSTER_2: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_3;
        end

        else begin
            next_state = CLUSTER_2;
        end
    end

    CLUSTER_3: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_4;
        end

        else begin
            next_state = CLUSTER_3;
        end
    end

    CLUSTER_4: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_5;
        end

        else begin
            next_state = CLUSTER_4;
        end
    end

    CLUSTER_5: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_6;
        end

        else begin
            next_state = CLUSTER_5;
        end
    end

    CLUSTER_6: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_7;
        end

        else begin
            next_state = CLUSTER_6;
        end
    end

    CLUSTER_7: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_8;
        end

        else begin
            next_state = CLUSTER_7;
        end
    end

    CLUSTER_8: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_9;
        end

        else begin
            next_state = CLUSTER_8;
        end
    end

    CLUSTER_9: begin
        if (    (cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_10;
        end

        else begin
            next_state = CLUSTER_9;
        end
    end

    CLUSTER_10: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_11;
        end

        else begin
            next_state = CLUSTER_10;
        end
    end

    CLUSTER_11: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_12;
        end

        else begin
            next_state = CLUSTER_11;
        end
    end

    CLUSTER_12: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_13;
        end

        else begin
            next_state = CLUSTER_12;
        end
    end

    CLUSTER_13: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_14;
        end

        else begin
            next_state = CLUSTER_13;
        end
    end

    CLUSTER_14: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = CLUSTER_15;
        end

        else begin
            next_state = CLUSTER_14;
        end
    end

    CLUSTER_15: begin
        if ((cycles_per_iact_col_counter == cycles_per_iact_col - 'd1) && (unique_values_per_cluster_per_cycle_counter == unique_values_per_cluster_per_cycle - 'd1)) begin
            next_state = IDLE;
        end

        else begin
            next_state = CLUSTER_15;
        end
    end 
    default: begin
        next_state = IDLE;
    end
    endcase
end


// Output logic
always @(*) begin
    iact_data_out_valid_from_iact_dist_to_glb = 'd0;

    case (current_state)
    IDLE: begin
        iact_data_out_valid_from_iact_dist_to_glb = 'd0;

    end
    CLUSTER_0: begin
       iact_data_out_valid_from_iact_dist_to_glb[0] = 'd1; 
    end
    CLUSTER_1: begin
       iact_data_out_valid_from_iact_dist_to_glb[1] = 'd1; 
    end
    CLUSTER_2: begin
       iact_data_out_valid_from_iact_dist_to_glb[2] = 'd1; 
    end
    CLUSTER_3: begin
       iact_data_out_valid_from_iact_dist_to_glb[3] = 'd1; 
    end
    CLUSTER_4: begin
       iact_data_out_valid_from_iact_dist_to_glb[4] = 'd1; 
    end
    CLUSTER_5: begin
       iact_data_out_valid_from_iact_dist_to_glb[5] = 'd1; 
    end
    CLUSTER_6: begin
       iact_data_out_valid_from_iact_dist_to_glb[6] = 'd1; 
    end
    CLUSTER_7: begin
       iact_data_out_valid_from_iact_dist_to_glb[7] = 'd1; 
    end
    CLUSTER_8: begin
       iact_data_out_valid_from_iact_dist_to_glb[8] = 'd1; 
    end
    CLUSTER_9: begin
       iact_data_out_valid_from_iact_dist_to_glb[9] = 'd1; 
    end
    CLUSTER_10: begin
       iact_data_out_valid_from_iact_dist_to_glb[10] = 'd1; 
    end
    CLUSTER_11: begin
       iact_data_out_valid_from_iact_dist_to_glb[11] = 'd1; 
    end
    CLUSTER_12: begin
       iact_data_out_valid_from_iact_dist_to_glb[12] = 'd1; 
    end
    CLUSTER_13: begin
       iact_data_out_valid_from_iact_dist_to_glb[13] = 'd1; 
    end
    CLUSTER_14: begin
       iact_data_out_valid_from_iact_dist_to_glb[14] = 'd1; 
    end
    CLUSTER_15: begin
       iact_data_out_valid_from_iact_dist_to_glb[15] = 'd1; 
    end 
    default: begin
        iact_data_out_valid_from_iact_dist_to_glb = 'd0; 
    end
        
    endcase
end


endmodule
