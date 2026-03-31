`timescale 1ns / 1ps

module q88_layernorm_scale #(
    parameter VECTOR_LEN = 64,
    parameter LUT_FILE = "roms/inv_sqrt_lut.hex" 
)(
    input  wire [15:0] variance_in,
    input  wire [VECTOR_LEN*16-1:0] vec_centered_in,
    output wire [VECTOR_LEN*16-1:0] vec_scaled_out
);

    reg [15:0] inv_sqrt_rom [0:32767];
    initial begin
        $readmemh(LUT_FILE, inv_sqrt_rom);
    end



    wire [14:0] lut_addr = variance_in[14:0];
    wire signed [15:0] scale_factor = inv_sqrt_rom[lut_addr];

    genvar i;
    generate
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin : scale_loop
            wire signed [15:0] element = vec_centered_in[i*16 +: 16];
            

            wire signed [31:0] full_mult = element * scale_factor;
            assign vec_scaled_out[i*16 +: 16] = full_mult[23:8];
        end
    endgenerate

endmodule