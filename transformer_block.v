`timescale 1ns / 1ps

module transformer_block #(
    parameter VECTOR_LEN = 64,
    parameter MAX_SEQ_LEN = 256,
    parameter WQ_FILE = "roms/q.hex",
    parameter WK_FILE = "roms/k.hex",
    parameter WV_FILE = "roms/v.hex",
    parameter WO_FILE = "roms/out.hex",
    parameter WF1_FILE = "roms/ffn1.hex",
    parameter WF2_FILE = "roms/ffn2.hex"
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start_token,
    input  wire [7:0] current_seq_pos,
    input  wire [VECTOR_LEN*16-1:0] token_in,
    output wire block_done,
    output reg  [VECTOR_LEN*16-1:0] token_out
);


    // 1. ALL Internal Declarations

    
    // FSM & Control Wires
    wire [4:0] master_state;
    wire mha_done;
    wire [3:0] mha_state;
    wire norm_done, matvec_done, cache_done, softmax_done;
    wire softmax_start;
    wire [7:0] kv_read_addr;
    wire [1:0] head_select;
    wire clear_context_acc, latch_score, accumulate_context;
    

    reg [15:0] rom_addr;
    
    // 1024-bit Vector Wires
    wire [VECTOR_LEN*16-1:0] weight_q_out, weight_k_out, weight_v_out;
    wire [VECTOR_LEN*16-1:0] weight_out_proj_out, weight_ffn1_out, weight_ffn2_out;
    wire [VECTOR_LEN*16-1:0] kv_cache_v_out, kv_cache_k_out;
    wire [VECTOR_LEN*16-1:0] assembled_vector;
    wire [VECTOR_LEN*16-1:0] softmax_probs;
    wire [VECTOR_LEN*16-1:0] layernorm_in, layernorm_out;
    
    // Data Path MUX Wires
    reg [VECTOR_LEN*16-1:0] mac_input_a;
    reg [VECTOR_LEN*16-1:0] mac_input_b;
    wire signed [15:0] dot_prod_out;
    
    // Pipeline Registers
    reg [VECTOR_LEN*16-1:0] active_token_reg;
    reg [VECTOR_LEN*16-1:0] residual_1_reg;
    reg [VECTOR_LEN*16-1:0] normed_token_1;
    reg [VECTOR_LEN*16-1:0] normed_token_2;
    reg [VECTOR_LEN*16-1:0] q_proj_reg;
    reg [VECTOR_LEN*16-1:0] context_acc_reg;
    reg [VECTOR_LEN*16-1:0] ffn1_relu_reg;

    // Handshake Registers
    reg norm_done_reg, matvec_done_reg, softmax_done_reg, cache_done_reg;



    // 2. ROM Address Logic

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rom_addr <= 16'd0;

        else if (start_token) rom_addr <= 16'd0;
        else if (master_state == 5'd6 && mha_state == 4'd0) rom_addr <= 16'd0; // Reset at MHA start
        

        else if (master_state == 5'd2 || master_state == 5'd3 || master_state == 5'd4 || 
                 master_state == 5'd9 || master_state == 5'd12 || master_state == 5'd14)
            rom_addr <= rom_addr + 1;
    end


    // 3. FSM Instantiations

    transformer_block_fsm #(.MAX_SEQ_LEN(MAX_SEQ_LEN)) master_fsm (
        .clk(clk), .rst_n(rst_n), .start_token(start_token), .current_seq_pos(current_seq_pos),
        .norm_done(norm_done), .matvec_done(matvec_done), .cache_done(cache_done), 
        .softmax_done(softmax_done), .mha_done(mha_done), .block_done(block_done),
        .current_state(master_state) 
    );

    mha_fsm #(.NUM_HEADS(4), .MAX_SEQ_LEN(MAX_SEQ_LEN)) mha_controller (
        .clk(clk), .rst_n(rst_n), .mha_start(master_state == 5'd6), 
        .current_seq_pos(current_seq_pos), .mha_done(mha_done),
        .softmax_done(softmax_done), .softmax_start(softmax_start), .kv_read_addr(kv_read_addr),
        .head_select(head_select), .clear_context_acc(clear_context_acc), 
        .latch_score(latch_score), .accumulate_context(accumulate_context), .current_mha_state(mha_state)
    );


    // 4. Weight Row ROMs (Task 1 weights)

    q88_weight_row_rom #(.ROW_COUNT(64), .INIT_FILE(WQ_FILE)) rom_q (.row_addr(rom_addr), .row_data(weight_q_out));
    q88_weight_row_rom #(.ROW_COUNT(64), .INIT_FILE(WK_FILE)) rom_k (.row_addr(rom_addr), .row_data(weight_k_out));
    q88_weight_row_rom #(.ROW_COUNT(64), .INIT_FILE(WV_FILE)) rom_v (.row_addr(rom_addr), .row_data(weight_v_out));
    q88_weight_row_rom #(.ROW_COUNT(64), .INIT_FILE(WO_FILE)) rom_out_proj (.row_addr(rom_addr), .row_data(weight_out_proj_out));
// FFN1 needs a depth of 256 rows
    q88_weight_row_rom #(.ROW_COUNT(256), .INIT_FILE(WF1_FILE)) rom_ffn1 (
        .row_addr(rom_addr), .row_data(weight_ffn1_out)
    );

    // FFN2 also needs a depth of 256 rows to match the 256-dim intermediate vector
    q88_weight_row_rom #(.ROW_COUNT(256), .INIT_FILE(WF2_FILE)) rom_ffn2 (
        .row_addr(rom_addr), .row_data(weight_ffn2_out)
    );  

    // 5. Math & Memory Units

    q88_dot_product #(.VECTOR_LEN(VECTOR_LEN)) main_mac (
        .vec_a(mac_input_a), .vec_b(mac_input_b), .dot_out(dot_prod_out) 
    );
    wire signed [15:0] scaled_dot_out = (master_state == 5'd6) ? (dot_prod_out >>> 2) : dot_prod_out;
    q88_kv_cache #(.VECTOR_LEN(VECTOR_LEN), .MAX_SEQ_LEN(MAX_SEQ_LEN)) cache_k (
        .clk(clk), .we(master_state == 5'd5), .write_addr(current_seq_pos),
        .read_addr(kv_read_addr), .data_in(assembled_vector), .data_out(kv_cache_k_out)
    );

    q88_kv_cache #(.VECTOR_LEN(VECTOR_LEN), .MAX_SEQ_LEN(MAX_SEQ_LEN)) cache_v (
        .clk(clk), .we(master_state == 5'd5), .write_addr(current_seq_pos),
        .read_addr(kv_read_addr), .data_in(assembled_vector), .data_out(kv_cache_v_out)
    );

    q88_vector_assembler #(.VECTOR_LEN(VECTOR_LEN)) assembler (
        .clk(clk), .rst_n(rst_n), .shift_en(matvec_done || latch_score),
        .data_in(scaled_dot_out), // <-- Feed the SCALED score into the assembler
        .vector_out(assembled_vector)
    );

    assign layernorm_in = (master_state == 5'd11) ? residual_1_reg : active_token_reg;
// --- The LayerNorm Core ---
    wire [VECTOR_LEN*16-1:0] layernorm_centered;
    wire [15:0] variance_out;

    assign layernorm_in = (master_state == 5'd11) ? residual_1_reg : active_token_reg;
    
    // 1. Calculate Mean and Variance
    q88_layernorm_stats #(.VECTOR_LEN(VECTOR_LEN)) shared_layernorm (
        .vec_in(layernorm_in), 
        .vec_centered_out(layernorm_centered), 
        .variance_out(variance_out) // No longer floating!
    );

    // 2. Look up 1/sqrt(var) and scale the vector
    q88_layernorm_scale #(.VECTOR_LEN(VECTOR_LEN), .LUT_FILE("roms/inv_sqrt_lut.hex")) ln_scale (
        .variance_in(variance_out),
        .vec_centered_in(layernorm_centered),
        .vec_scaled_out(layernorm_out) // The final normalized vector
    );

    // 6. Datapath MUX Logic

    always @(*) begin
        case (master_state)
            5'd2, 5'd3, 5'd4: mac_input_a = normed_token_1;
            5'd6:             mac_input_a = (mha_state <= 4'd3) ? q_proj_reg : softmax_probs;
            5'd8:             mac_input_a = softmax_probs;
            5'd9:             mac_input_a = context_acc_reg;
            5'd12:            mac_input_a = normed_token_2;
            5'd14:            mac_input_a = ffn1_relu_reg;
            default:          mac_input_a = {VECTOR_LEN*16{1'b0}};
        endcase
    end

    always @(*) begin
        case (master_state)
            5'd2:    mac_input_b = weight_q_out;
            5'd3:    mac_input_b = weight_k_out;
            5'd4:    mac_input_b = weight_v_out;
            5'd6:    mac_input_b = (mha_state <= 4'd3) ? kv_cache_k_out : kv_cache_v_out;
            5'd8:    mac_input_b = kv_cache_v_out;
            5'd9:    mac_input_b = weight_out_proj_out;
            5'd12:   mac_input_b = weight_ffn1_out;
            5'd14:   mac_input_b = weight_ffn2_out;
            default: mac_input_b = {VECTOR_LEN*16{1'b0}};
        endcase
    end


    // 7. Softmax Core

    wire signed [15:0] softmax_max_val;
    wire [VECTOR_LEN*16-1:0] softmax_shifted;
    
    q88_max_finder #(.VECTOR_LEN(VECTOR_LEN)) max_find (
        .vec_in(assembled_vector), .max_out(softmax_max_val)
    );
    q88_sub_shift #(.VECTOR_LEN(VECTOR_LEN)) sub_shift (
        .vec_in(assembled_vector), .max_in(softmax_max_val), .vec_out(softmax_shifted)
    );
    q88_softmax_norm #(.VECTOR_LEN(VECTOR_LEN)) softmax_norm (
        .vec_in(softmax_shifted), .vec_out(softmax_probs)
    );

    // 8. Pipeline Registers & Handshakes

    assign norm_done = norm_done_reg;
    assign matvec_done = matvec_done_reg;
    assign softmax_done = softmax_done_reg;
    assign cache_done = cache_done_reg;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_token_reg <= 0; residual_1_reg <= 0; q_proj_reg <= 0;
            normed_token_1 <= 0; normed_token_2 <= 0;
            norm_done_reg <= 0; matvec_done_reg <= 0; softmax_done_reg <= 0; cache_done_reg <= 0;
            
            token_out <= 0;
            context_acc_reg <= 0;
            ffn1_relu_reg <= 0;
        end else begin
            if (start_token) active_token_reg <= token_in;
            if (master_state == 5'd1) normed_token_1 <= layernorm_out;
            if (master_state == 5'd11) normed_token_2 <= layernorm_out;
            if (master_state == 5'd2 && matvec_done) q_proj_reg <= assembled_vector;
            

            // THE MISSING RESIDUAL CONNECTIONS & OUTPUT WIRING

            

            if (master_state == 5'd9 && matvec_done) begin
                for (i = 0; i < VECTOR_LEN; i = i + 1) begin
                    residual_1_reg[i*16 +: 16] <= $signed(active_token_reg[i*16 +: 16]) + $signed(assembled_vector[i*16 +: 16]);
                end
            end
            
            // 2. Second Residual: Residual 1 + FFN Output (State 14 is FFN2 Proj)
            if (master_state == 5'd14 && matvec_done) begin
                for (i = 0; i < VECTOR_LEN; i = i + 1) begin
                    token_out[i*16 +: 16] <= $signed(residual_1_reg[i*16 +: 16]) + $signed(assembled_vector[i*16 +: 16]);
                end
            end


            norm_done_reg    <= (master_state == 5'd1 || master_state == 5'd11);
            matvec_done_reg  <= (master_state == 5'd2 || master_state == 5'd3 || master_state == 5'd4 || 
                                 master_state == 5'd9 || master_state == 5'd12 || master_state == 5'd14);
            softmax_done_reg <= softmax_start;
            cache_done_reg   <= (master_state == 5'd5); 
        end
    end

endmodule   