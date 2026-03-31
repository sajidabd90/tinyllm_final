`timescale 1ns / 1ps

module embedding_lookup #(
    parameter VOCAB_SIZE = 50257, 
    parameter VECTOR_LEN = 64
)(
    input  wire [15:0] token_id,
    output wire [VECTOR_LEN*16-1:0] emb_vector
);
    // 1. Flattened memory: 50,257 tokens * 64 dimensions = 3,216,448 entries
    reg [15:0] mem [0:(VOCAB_SIZE * VECTOR_LEN) - 1];

    initial begin
        $readmemh("roms/transformer_wte_weight.hex", mem);
    end

    // 2. Assemble the 64 scalars into one 1024-bit output vector
    genvar i;
    generate
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin : assemble_emb
            assign emb_vector[i*16 +: 16] = mem[token_id * VECTOR_LEN + i];
        end
    endgenerate

endmodule