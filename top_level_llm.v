`timescale 1ns / 1ps

module top_level_llm #(
    parameter VECTOR_LEN = 64,
    parameter VOCAB_SIZE = 50257,
    parameter NUM_LAYERS = 4,
    parameter MAX_GEN_LEN = 10
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start_gen,
    input  wire [15:0] prompt_token_id,
    output reg  [15:0] current_token_id,
    output reg  gen_complete
);

  
    // 1. Internal Signals & State Machine

    typedef enum reg [3:0] {
        STATE_IDLE        = 4'd0,
        STATE_EMBED       = 4'd1,
        STATE_LAYER_0     = 4'd2,
        STATE_LAYER_1     = 4'd3,
        STATE_LAYER_2     = 4'd4,
        STATE_LAYER_3     = 4'd5,
        STATE_FINAL_NORM  = 4'd6,
        STATE_LM_HEAD     = 4'd7,
        STATE_UPDATE_TOK  = 4'd8,
        STATE_DONE        = 4'd9
    } state_t;

    state_t state;
    reg [5:0]  gen_token_count; // Tracks up to 28 tokens
    reg [7:0]  seq_pos_counter; // Tracks KV-cache position
    reg [15:0] vocab_idx;       // Counter for the 50,257 vocabulary rows

    // Interconnect Wires
    wire [VECTOR_LEN*16-1:0] emb_out;
    wire [VECTOR_LEN*16-1:0] l0_out, l1_out, l2_out, l3_out;
    wire l0_done, l1_done, l2_done, l3_done;
    
    // LM Head Wires
    wire [VECTOR_LEN*16-1:0] lm_head_row;
    wire signed [15:0]       current_score;
    reg  signed [15:0]       max_score;
    reg  [15:0]              best_token_id;


    // 2. Component Instantiations


    // --- A. Embedding Lookup ---
    embedding_lookup #(.VOCAB_SIZE(VOCAB_SIZE)) emb_unit (
        .token_id(current_token_id),
        .emb_vector(emb_out)
    );

    // --- B. The 4-Layer Transformer Stack ---

    transformer_block #(
        .WQ_FILE("roms/transformer_h_0_attn_attention_q_proj_weight.hex"),
        .WK_FILE("roms/transformer_h_0_attn_attention_k_proj_weight.hex"),
        .WV_FILE("roms/transformer_h_0_attn_attention_v_proj_weight.hex"),
        .WO_FILE("roms/transformer_h_0_attn_attention_out_proj_weight.hex"),
        .WF1_FILE("roms/transformer_h_0_mlp_c_fc_weight.hex"),
        .WF2_FILE("roms/transformer_h_0_mlp_c_proj_weight.hex")
    )layer_0 (
        .clk(clk), .rst_n(rst_n),
        .start_token(state == STATE_LAYER_0),
        .current_seq_pos(seq_pos_counter),
        .token_in(emb_out),
        .token_out(l0_out),
        .block_done(l0_done)
    );


    transformer_block #(
        .WQ_FILE("roms/transformer_h_1_attn_attention_q_proj_weight.hex"),
        .WK_FILE("roms/transformer_h_1_attn_attention_k_proj_weight.hex"),
        .WV_FILE("roms/transformer_h_1_attn_attention_v_proj_weight.hex"),
        .WO_FILE("roms/transformer_h_1_attn_attention_out_proj_weight.hex"),
        .WF1_FILE("roms/transformer_h_1_mlp_c_fc_weight.hex"),
        .WF2_FILE("roms/transformer_h_1_mlp_c_proj_weight.hex")
    ) layer_1 (
        .clk(clk), .rst_n(rst_n),
        .start_token(l0_done),
        .current_seq_pos(seq_pos_counter),
        .token_in(l0_out),
        .token_out(l1_out),
        .block_done(l1_done)
    );

    transformer_block #(
        .WQ_FILE("roms/transformer_h_2_attn_attention_q_proj_weight.hex"),
        .WK_FILE("roms/transformer_h_2_attn_attention_k_proj_weight.hex"),
        .WV_FILE("roms/transformer_h_2_attn_attention_v_proj_weight.hex"),
        .WO_FILE("roms/transformer_h_2_attn_attention_out_proj_weight.hex"),
        .WF1_FILE("roms/transformer_h_2_mlp_c_fc_weight.hex"),
        .WF2_FILE("roms/transformer_h_2_mlp_c_proj_weight.hex")
    ) layer_2 (
        .clk(clk), .rst_n(rst_n),
        .start_token(l1_done),
        .current_seq_pos(seq_pos_counter),
        .token_in(l1_out),
        .token_out(l2_out),
        .block_done(l2_done)
    );

    transformer_block #(
        .WQ_FILE("roms/transformer_h_3_attn_attention_q_proj_weight.hex"),
        .WK_FILE("roms/transformer_h_3_attn_attention_k_proj_weight.hex"),
        .WV_FILE("roms/transformer_h_3_attn_attention_v_proj_weight.hex"),
        .WO_FILE("roms/transformer_h_3_attn_attention_out_proj_weight.hex"),
        .WF1_FILE("roms/transformer_h_3_mlp_c_fc_weight.hex"),
        .WF2_FILE("roms/transformer_h_3_mlp_c_proj_weight.hex")
    ) layer_3 (
        .clk(clk), .rst_n(rst_n),
        .start_token(l2_done),
        .current_seq_pos(seq_pos_counter),
        .token_in(l2_out),
        .token_out(l3_out),
        .block_done(l3_done)
    );

    // --- C. Final LayerNorm (Pre-LM Head) ---
    wire [VECTOR_LEN*16-1:0] final_norm_out;
    
    q88_layernorm_stats #(.VECTOR_LEN(VECTOR_LEN)) final_norm_unit (
        .vec_in(l3_out),
        .vec_centered_out(final_norm_out), // Normalized output
        .variance_out()                    // Floating for now
    );
    

    // 1. Flattened memory array for the 3.2M LM Head weights
    reg [15:0] lm_head_mem [0:(50257 * 64) - 1];
    
    initial begin
        $readmemh("roms/lm_head_weight.hex", lm_head_mem);
    end

    // 2. Dynamic Assembly Wire
    wire [VECTOR_LEN*16-1:0] current_lm_head_row;
    
    genvar h_idx;
    generate
        for (h_idx = 0; h_idx < VECTOR_LEN; h_idx = h_idx + 1) begin : assemble_head
            assign current_lm_head_row[h_idx*16 +: 16] = lm_head_mem[vocab_idx * VECTOR_LEN + h_idx];
        end
    endgenerate


    q88_dot_product lm_math (
        .vec_a(final_norm_out), // Correctly using normalized vector
        .vec_b(current_lm_head_row),
        .dot_out(current_score)
    );

    // 3. Autoregressive Control Logic

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            current_token_id <= 0;
            gen_token_count <= 0;
            seq_pos_counter <= 0;
            gen_complete <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start_gen) begin
                        current_token_id <= prompt_token_id;
                        state <= STATE_EMBED;
                    end
                end

                STATE_EMBED: state <= STATE_LAYER_0;

                STATE_LAYER_0: if (l0_done) state <= STATE_LAYER_1;
                STATE_LAYER_1: if (l1_done) state <= STATE_LAYER_2;
                STATE_LAYER_2: if (l2_done) state <= STATE_LAYER_3;
                STATE_LAYER_3: if (l3_done) begin
                                    state <= STATE_LM_HEAD;
                                    vocab_idx <= 0;
                                    max_score <= 16'sh8000; 
                                    best_token_id <= 16'd0; 
                                end

                STATE_LM_HEAD: begin
                    // --- EXPANDED X-RAY DEBUG PRINT ---
                    if (vocab_idx == 1) begin
                        $display("====== HARDWARE X-RAY ======");
                        $display("Emb Out [0]   : %h", emb_out[15:0]);
                        $display("L0  Out [0]   : %h", l0_out[15:0]);
                        $display("L1  Out [0]   : %h", l1_out[15:0]);
                        $display("L2  Out [0]   : %h", l2_out[15:0]);
                        $display("L3  Out [0]   : %h", l3_out[15:0]);
                        $display("Final Norm[0] : %h", final_norm_out[15:0]);
                        $display("LM Head [0]   : %h", current_lm_head_row[15:0]);
                        $display("Dot Prod Score: %d", current_score);
                        $display("============================");
                    end

                    if (current_score > max_score) begin
                        max_score <= current_score;
                        best_token_id <= vocab_idx;
                    end

                    if (vocab_idx == VOCAB_SIZE - 1) begin //1000 for testing 
                        state <= STATE_UPDATE_TOK;
                    end else begin
                        vocab_idx <= vocab_idx + 1;
                    end
                end

                STATE_UPDATE_TOK: begin
                    current_token_id <= best_token_id;
                    seq_pos_counter  <= seq_pos_counter + 1;
                    
                    // Increment the token count
                    gen_token_count <= gen_token_count + 1;

                    if (gen_token_count >= MAX_GEN_LEN - 1) begin
                        state <= STATE_DONE;
                    end else begin
                        state <= STATE_EMBED;
                    end
                end

                STATE_DONE: begin
                    gen_complete <= 1;
                    if (!start_gen) state <= STATE_IDLE;
                end

            endcase
        end
    end

endmodule