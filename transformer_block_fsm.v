`timescale 1ns / 1ps

module transformer_block_fsm #(
    parameter MAX_SEQ_LEN = 256
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start_token,          
    input  wire [7:0] current_seq_pos,
    
    // --- Handshake Inputs from Datapath ---
    input  wire norm_done,
    input  wire matvec_done,
    input  wire cache_done,
    input  wire softmax_done,
    input  wire mha_done, // Signal from the MHA sub-FSM
    
    // --- Master Status ---
    output reg block_done,
    output wire [4:0] current_state
);

    // 1. State Encoding
    localparam  IDLE         = 5'd0,
                NORM_1       = 5'd1,
                PROJ_Q       = 5'd2,
                PROJ_K       = 5'd3,
                PROJ_V       = 5'd4,
                CACHE_WRITE  = 5'd5,
                ATTN_SCORES  = 5'd6,
                SOFTMAX      = 5'd7,
                ATTN_CONTEXT = 5'd8,
                PROJ_OUT     = 5'd9,
                RESIDUAL_1   = 5'd10,
                NORM_2       = 5'd11,
                FFN_1        = 5'd12,
                RELU         = 5'd13,
                FFN_2        = 5'd14,
                RESIDUAL_2   = 5'd15,
                DONE         = 5'd16;

    reg [4:0] state, next_state;

    // 2. Loop Counters
    reg [7:0] token_idx; 

    // 3. Sequential Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            token_idx <= 8'd0;
        end else begin
            state <= next_state;
            
            // Loop counter management for attention
            if (state == ATTN_SCORES || state == ATTN_CONTEXT) begin
                // Increment if the underlying math engine just finished a token
                if (matvec_done) begin
                    if (token_idx < current_seq_pos - 1) begin
                        token_idx <= token_idx + 1'b1;
                    end else begin
                        token_idx <= 8'd0;
                    end
                end
            end
        end
    end

    // 4. Combinational Next State Logic
    always @(*) begin
        next_state = state; // Default
        
        case (state)
            IDLE:        if (start_token)  next_state = NORM_1;
            
            // Wait for handshakes before proceeding
            NORM_1:      if (norm_done)    next_state = PROJ_Q;
            PROJ_Q:      if (matvec_done)  next_state = PROJ_K;
            PROJ_K:      if (matvec_done)  next_state = PROJ_V;
            PROJ_V:      if (matvec_done)  next_state = CACHE_WRITE;
            CACHE_WRITE: if (cache_done)   next_state = ATTN_SCORES;
            
            ATTN_SCORES: if (mha_done) next_state = PROJ_OUT;
            
            SOFTMAX:     if (softmax_done) next_state = ATTN_CONTEXT;
            
            ATTN_CONTEXT: begin
                if (matvec_done && (token_idx == current_seq_pos - 1)) begin
                    next_state = PROJ_OUT;
                end
            end
            
            PROJ_OUT:    if (matvec_done)  next_state = RESIDUAL_1;
            
            // Residual additions are usually single-cycle, so we can transition immediately
            // or wait for a specific adder_done signal if pipelined.
            RESIDUAL_1:                    next_state = NORM_2; 
            
            NORM_2:      if (norm_done)    next_state = FFN_1;
            FFN_1:       if (matvec_done)  next_state = RELU;
            RELU:                          next_state = FFN_2; // RELU bug fixed!
            FFN_2:       if (matvec_done)  next_state = RESIDUAL_2;
            RESIDUAL_2:                    next_state = DONE;
            
            DONE:                          next_state = IDLE;
            default:                       next_state = IDLE;
        endcase
    end

    // 5. Datapath Control Signals
    always @(*) begin
        block_done = 1'b0;
        
        if (state == DONE) begin
            block_done = 1'b1;
        end
        // Add specific enable signals (e.g., start_matvec = 1'b1) depending on state
    end
assign current_state = state;
endmodule