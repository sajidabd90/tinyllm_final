`timescale 1ns / 1ps

module q88_dot_product #(

    parameter VECTOR_LEN = 64 
)(
    // Flattened inputs
    input  wire [VECTOR_LEN*16-1:0] vec_a,
    input  wire [VECTOR_LEN*16-1:0] vec_b,
    output reg  signed [15:0]       dot_out
);


    wire signed [15:0] mult_results [0:VECTOR_LEN-1];


    genvar i;
    generate
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin : mult_gen
            // Instantiating the module you just verified
            q88_mult u_mult (
                // Extracting 16-bit chunks from the flattened input buses
                .a(vec_a[i*16 +: 16]), 
                .b(vec_b[i*16 +: 16]),
                .result(mult_results[i])
            );
        end
    endgenerate


    integer j;
    reg signed [31:0] accumulator;

    always @(*) begin
        accumulator = 0;
        


        for (j = 0; j < VECTOR_LEN; j = j + 1) begin
            accumulator = accumulator + mult_results[j];
        end


// 3. Accumulator Saturation to Q8.8
        if (accumulator > 32'sd32767) begin
            dot_out = 16'sd32767;
        end else if (accumulator < -32'sd32768) begin
            dot_out = -16'sd32768;
        end else begin
            // FIX: The sum is ALREADY in Q8.8 format. Just take the bottom 16 bits!
            dot_out = accumulator[15:0]; 
        end
    end

endmodule