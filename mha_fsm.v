`timescale 1ns / 1ps

module mha_fsm #(
    parameter NUM_HEADS = 4,
    parameter MAX_SEQ_LEN = 256
)(
    input  wire clk,
    input  wire rst_n,
    

    input  wire mha_start,
    input  wire [7:0] current_seq_pos,
    output reg  mha_done,
    output wire [3:0] current_mha_state, // Add this right below mha_done!

    input  wire softmax_done,
    output reg  softmax_start,
    

    output reg  [7:0] kv_read_addr,
    

    output reg  [1:0] head_select,      
    output reg  clear_context_acc,     
    output reg  latch_score,            
    output reg  accumulate_context      
);


    // 1. State Encoding

    localparam  IDLE            = 4'd0,
                //Attention Scores (Q * K^T)
                FETCH_K         = 4'd1,
                WAIT_K_BRAM     = 4'd2, // 1-cycle delay for BRAM read
                MAC_SCORE       = 4'd3,
                
                //
                DO_SOFTMAX      = 4'd4,
                
                //Context Vector (Prob * V) ---
                FETCH_V         = 4'd5,
                WAIT_V_BRAM     = 4'd6, // 1-cycle delay for BRAM read
                MAC_CONTEXT     = 4'd7,
                
                //
                LATCH_HEAD_OUT  = 4'd8,
                NEXT_HEAD       = 4'd9,
                DONE            = 4'd10;

    reg [3:0] state, next_state;


    // 2. Nested Loop Counters

    reg [1:0] head_idx;  
    reg [7:0] token_idx; 


    // 3. Sequential Logic & Counter Management

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            head_idx  <= 2'd0;
            token_idx <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    head_idx  <= 2'd0;
                    token_idx <= 8'd0;
                end
                

                MAC_SCORE, MAC_CONTEXT: begin
                    if (token_idx < current_seq_pos) begin
                        token_idx <= token_idx + 1'b1;
                    end else begin
                        token_idx <= 8'd0; 
                    end
                end
                

                NEXT_HEAD: begin
                    head_idx <= head_idx + 1'b1;
                end
            endcase
        end
    end


   // 4. Combinational Next State Logic

    always @(*) begin
        next_state = state; // Default
        
        case (state)
            IDLE: if (mha_start) next_state = FETCH_K;
            

            FETCH_K:     next_state = WAIT_K_BRAM;
            WAIT_K_BRAM: next_state = MAC_SCORE;
            MAC_SCORE: begin
                if (token_idx < current_seq_pos) 
                    next_state = FETCH_K;      
                else 
                    next_state = DO_SOFTMAX;   
            end
            

            DO_SOFTMAX:  if (softmax_done) next_state = FETCH_V;
            

            FETCH_V:     next_state = WAIT_V_BRAM;
            WAIT_V_BRAM: next_state = MAC_CONTEXT;
            MAC_CONTEXT: begin
                if (token_idx < current_seq_pos) 
                    next_state = FETCH_V;      
                else 
                    next_state = LATCH_HEAD_OUT; 
            end
            
            LATCH_HEAD_OUT: next_state = NEXT_HEAD;
            NEXT_HEAD: begin
                if (head_idx == 2'd3) 
                    next_state = DONE;         
                else 
                    next_state = FETCH_K;      
            end
            
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end


//5. Control Signal Outputs

    always @(*) begin
        // Default assignments to prevent latches
        mha_done           = 1'b0;
        softmax_start      = 1'b0;
        kv_read_addr       = token_idx; 
        head_select        = head_idx;
        clear_context_acc  = 1'b0;
        latch_score        = 1'b0;
        accumulate_context = 1'b0;

        case (state)
            FETCH_K: begin

                if (token_idx == 8'd0) clear_context_acc = 1'b1;
            end
            
            MAC_SCORE: begin

                latch_score = 1'b1; 
            end
            
            DO_SOFTMAX: begin
                softmax_start = 1'b1;
            end
            
            MAC_CONTEXT: begin

                accumulate_context = 1'b1;
            end
            
            DONE: begin
                mha_done = 1'b1;
            end
        endcase
    end
assign current_mha_state = state;
endmodule