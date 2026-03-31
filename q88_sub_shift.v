`timescale 1ns / 1ps

module q88_sub_shift #(
    parameter VECTOR_LEN = 64
)(
    input  wire [VECTOR_LEN*16-1:0] vec_in,
    input  wire signed [15:0]       max_in,
    output reg  [VECTOR_LEN*16-1:0] vec_out 
);

    reg signed [15:0] x_in;
    reg signed [16:0] diff; // 17 bits to prevent underflow during subtraction
    reg [7:0]         shift_amt;
    reg [15:0]        shifted_val;
    integer i;

    always @(*) begin
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin
            x_in = vec_in[i*16 +: 16];
            

            diff = x_in - max_in;

            shift_amt = (-diff) >> 8; 


            if (shift_amt >= 8) begin

                shifted_val = 16'd0; 
            end else begin

                shifted_val = 16'd256 >> shift_amt;
            end
            
            vec_out[i*16 +: 16] = shifted_val;
        end
    end

endmodule