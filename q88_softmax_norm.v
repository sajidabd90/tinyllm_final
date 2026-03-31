`timescale 1ns / 1ps

module q88_softmax_norm #(
    parameter VECTOR_LEN = 64
)(

    input  wire [VECTOR_LEN*16-1:0] vec_in,

    output reg  [VECTOR_LEN*16-1:0] vec_out
);

    reg signed [15:0] x_unpacked [0:VECTOR_LEN-1];
    reg [31:0] sum_acc; // Can reach 16384, fits in 32 (or even 15) bits
    integer i, j, k;


    always @(*) begin
        sum_acc = 0;
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin
            x_unpacked[i] = vec_in[i*16 +: 16];
            sum_acc = sum_acc + x_unpacked[i];
        end
    end


    reg [15:0] recip_rom [0:16384];
    
    initial begin
        $readmemh("roms/recip_lut.hex", recip_rom);
    end


    wire [15:0] reciprocal;
    assign reciprocal = (sum_acc <= 16384) ? recip_rom[sum_acc] : 16'd0;


    reg signed [31:0] mult_temp;
    
    always @(*) begin
        for (k = 0; k < VECTOR_LEN; k = k + 1) begin

            mult_temp = (x_unpacked[k] * reciprocal) >>> 8;
            
            if (mult_temp > 32'sd32767)
                vec_out[k*16 +: 16] = 16'sd32767;
            else
                vec_out[k*16 +: 16] = mult_temp[15:0];
        end
    end

endmodule