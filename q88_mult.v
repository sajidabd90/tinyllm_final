`timescale 1ns / 1ps

module q88_mult (
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,
    output reg  signed [15:0] result
);

    wire signed [31:0] full_mult;
    assign full_mult = a * b;

    wire signed [31:0] shifted_mult;

    assign shifted_mult = full_mult >>> 8; 


    always @(*) begin
        if (shifted_mult > 32'sd32767) begin

            result = 16'sd32767;
        end else if (shifted_mult < -32'sd32768) begin

            result = -16'sd32768;
        end else begin

            result = shifted_mult[15:0];
        end
    end

endmodule