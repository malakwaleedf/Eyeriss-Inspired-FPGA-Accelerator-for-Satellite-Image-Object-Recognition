module PE_core #(
    parameter IACT_WIDTH = 8,   // iact value bitwidth (INT8)
    parameter WEIGHT_WIDTH = 8, // weight value bitwidth (INT8)
    parameter PSUM_WIDTH = 20,  // accumulator / psum chain bitwidth
    parameter IACT_SPAD_DEPTH = 16, // depth of weight/iact spads (max # unique values per cluster per cycle)
    parameter PSUM_SPAD_DEPTH = 16, // depth of psum spad (max # partial sums per cluster per cycle)
    parameter WEIGHT_SPAD_DEPTH = 9,     // depth of weight spad (max # unique values per cluster per cycle)
    parameter CLUSTER_ROWS  = 9 
) (
    input                   clock,
    input                   reset,
    input                   PE_disable,
    input                   PE_mode,

    output  reg                       psum_in_ready,
    input                           psum_in_valid,
    input  signed [PSUM_WIDTH-1:0]  psum_in, // from pe above

    input                           psum_out_ready,
    output reg                          psum_out_valid,
    output reg signed [PSUM_WIDTH-1:0]  psum_out,

    output                          iact_weight_data_ready,
    input                           iact_weight_data_valid,
    input signed  [IACT_WIDTH-1:0]  iact_weight_data,

    input                           load_weight,
    output                       weight_done,// pulse
    input                           load_iact,
    output                       iact_done, // pulse

    input                           mac_en,  // to move from idle      
    output reg                      mac_done,
    input                           psum_stream_start,
    output reg                      psum_stream_done,
    output reg                      PSUM_to_GLB_read_done, 
    

    //input                           psum_read_ptr_inc,// from pe cluster, oreders all pe's , if error change to internal reg
    input                           psum_to_GLB_en, // from outside to load final values of psum to GLB anf handshake with GLB
    input [4:0] cycles_per_iact_col,
    input [3:0] weight_columns,
    input [3:0] psum_spad_write_index, // mac_done_counter
    input [3:0] weight_spad_index // weight_column_counter
);
localparam IDLE = 'd0;
localparam LOAD_WEIGHTS_SPAD = 'd1;  // from GLB to SPAD
localparam LOAD_IACT_SPAD = 'd2; // from GLB to SPAD
localparam DO_MAC = 'd3; 
localparam WRITE_BACK = 'd4; 
localparam STREAM_1 = 'd6; 
localparam STREAM_2 = 'd7; 
localparam START_PSUM_TO_GLB = 'd8;
localparam PSUM_TO_GLB_1 = 'd9;
localparam PSUM_TO_GLB_2 = 'd10;


reg [4:0] current_state;
reg [4:0] next_state;
reg first_load_from_GLB;

reg iact_read_ptr_inc;
reg weight_read_ptr_inc;
reg psum_idx_restart;
reg  signed [PSUM_WIDTH-1:0] psum_calc;
reg signed [PSUM_WIDTH-1:0] psum_data_in;
reg psum_spad_write_en;
reg psum_read_ptr_inc;
// DO_MAC state internal signals
wire signed[IACT_WIDTH-1:0] iact_data;
wire signed [WEIGHT_WIDTH-1:0] weight_data;
wire  signed [PSUM_WIDTH-1:0] psum_data_out;

reg [$clog2(PSUM_SPAD_DEPTH):0] streamed_psums;
wire psum_in_handshake;
wire psum_out_handshake;

reg signed [PSUM_WIDTH-1:0] psum_out_reg; // to hold the value of psum_out during streaming (since we need to keep valid high for multiple cycles)

// handshake 
assign psum_in_handshake = psum_in_ready && psum_in_valid;
assign psum_out_handshake = psum_out_ready && psum_out_valid;


iact_spad #(
    .IACT_WIDTH  (IACT_WIDTH),
    .SPAD_DEPTH (IACT_SPAD_DEPTH)
) iact_spad_inst (
    .clock          (clock),
    .reset          (reset),

    .write_en       (load_iact),
    .data_in        (iact_weight_data),
    .data_in_valid  (iact_weight_data_valid),
    .data_in_ready  (iact_weight_data_ready),
    .write_fin      (iact_done),

    .read_ptr_inc        (iact_read_ptr_inc),
    .data_out       (iact_data),
    .cycles_per_iact_col (cycles_per_iact_col)
);

weight_spad #(
    .WEIGHT_WIDTH  (WEIGHT_WIDTH),
    .CLUSTER_ROWS (CLUSTER_ROWS)
) weight_spad_inst (
    .clock          (clock),
    .reset          (reset),

    .write_en       (load_weight),
    .data_in        (iact_weight_data),
    .write_fin      (weight_done),
    .data_in_valid  (iact_weight_data_valid),
    .data_in_ready  (iact_weight_data_ready),
    .data_out       (weight_data),
    .filter_size    (weight_columns),
    .read_address   (weight_spad_index)
);

psum_spad #(
    .PSUM_WIDTH (PSUM_WIDTH),
    .SPAD_DEPTH (PSUM_SPAD_DEPTH)
) psum_spad_inst (
    .clock          (clock),
    .reset          (reset),

    .write_en       (psum_spad_write_en),
    .psum_data_in   (psum_data_in),
    .psum_data_out  (psum_data_out), 
    .read_inc       (psum_read_ptr_inc),
    .write_idx      (psum_spad_write_index),
    .read_restart   (psum_idx_restart),
    .pe_mode        (PE_mode),
    .cycles_per_iact_col (cycles_per_iact_col)
);

always @(posedge clock or posedge reset) begin
    if (reset) begin
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
        if(load_weight)
            next_state = LOAD_WEIGHTS_SPAD;
        else if (load_iact)
            next_state = LOAD_IACT_SPAD;
        else if (mac_en)
            next_state = DO_MAC;
        else if (psum_stream_start)
            next_state = STREAM_1;
        else if (psum_to_GLB_en )
            next_state = PSUM_TO_GLB_1;
        else
            next_state = IDLE;
    end
    LOAD_WEIGHTS_SPAD: next_state = weight_done? IDLE : LOAD_WEIGHTS_SPAD;
    LOAD_IACT_SPAD: next_state = iact_done? IDLE : LOAD_IACT_SPAD;
    DO_MAC: next_state = WRITE_BACK;
    WRITE_BACK: next_state = IDLE;
    STREAM_1: next_state = psum_in_handshake ? STREAM_2 : STREAM_1;
    STREAM_2: begin
        if (psum_stream_done) begin
            next_state = IDLE;
        end
        else begin
            next_state = STREAM_1;
        end
    end
    PSUM_TO_GLB_1: next_state = psum_out_ready ? PSUM_TO_GLB_2 : PSUM_TO_GLB_1 ;
    PSUM_TO_GLB_2: next_state = PSUM_to_GLB_read_done ? IDLE : PSUM_TO_GLB_2;
    default: next_state = IDLE;
    endcase
end

always @(*) begin
    iact_read_ptr_inc = 1'b0;
    psum_spad_write_en = 1'b0;
    psum_out_valid = 1'b0;
    weight_read_ptr_inc = 1'b0;
    psum_read_ptr_inc = 1'b0;
    psum_idx_restart = 1'b0;
    psum_out = 'd0;
    mac_done = 1'b0;
    psum_in_ready = 1'b0;   
    psum_stream_done =  1'b0;
    PSUM_to_GLB_read_done = 1'b0;
    
    case (current_state)
    IDLE: begin
    end
    LOAD_WEIGHTS_SPAD: begin
    end
    LOAD_IACT_SPAD: begin
    end
    DO_MAC:begin
        iact_read_ptr_inc = 1'b1;
        psum_read_ptr_inc = 1'b1;
        psum_calc = weight_data * iact_data + psum_data_out; // placeholder for actual mac operation (can be multi-cycle)
        
    end
    WRITE_BACK: begin
        psum_data_in = psum_calc;
        psum_idx_restart = (psum_spad_write_index == cycles_per_iact_col-1) ? 1'b1 : 1'b0;
        mac_done = 1'd1;
        psum_spad_write_en = 1;
    end
    STREAM_1: begin
        psum_read_ptr_inc = 1'b0;
        psum_in_ready = 1'b1;   
        psum_out_valid = 1'b0;
        psum_out = psum_out_reg;
    end
    STREAM_2: begin
        psum_spad_write_en = 1'b1;
        psum_read_ptr_inc = 1'b1;
        psum_out = psum_in + psum_data_out;
        psum_data_in = psum_in + psum_data_out;
        psum_out_valid = 1'b1;
        psum_stream_done = (streamed_psums == cycles_per_iact_col) ? 1'b1 : 1'b0;
    end
    PSUM_TO_GLB_1: begin
        psum_idx_restart =  (streamed_psums == 0) ? 1'b1 : 1'b0;
        psum_out_valid = 1'b0;
    end
    PSUM_TO_GLB_2: begin
        psum_idx_restart = 1'b0;
        psum_read_ptr_inc = 1'b1;
        psum_out_valid = 1'b1;
        psum_out = psum_data_out;
        PSUM_to_GLB_read_done = (streamed_psums == cycles_per_iact_col - 1 ) ? 1'b1 : 1'b0;
    end
    
    default: begin
        
    end
    endcase
end

// streamed psums counter
always @(posedge clock) begin
    if (reset | (current_state == PSUM_TO_GLB_1))
        streamed_psums <= 'd0;
    else if (psum_out_valid) begin
        if(streamed_psums == (cycles_per_iact_col))
            streamed_psums <= 'd0;
        else
            streamed_psums <= streamed_psums + 'd1;
    end
    else
        streamed_psums <= streamed_psums;
end

// register stream value in psum_out_reg 
always @(posedge clock) begin
    if (reset)
        psum_out_reg <= 'd0;
    else if (psum_in_handshake)
        psum_out_reg <= psum_in + psum_data_out;
end


endmodule