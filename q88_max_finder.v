`timescale 1ns / 1ps

module q88_max_finder #(
    parameter VECTOR_LEN = 64
)(

    input  wire [VECTOR_LEN*16-1:0] vec_in,

    output reg  signed [15:0]       max_out
);

    reg signed [15:0] x_unpacked [0:VECTOR_LEN-1];
    integer i;
    
    always @(*) begin
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin
            x_unpacked[i] = vec_in[i*16 +: 16];
        end
    end


    integer j;
    always @(*) begin

        max_out = x_unpacked[0];
        
        for (j = 1; j < VECTOR_LEN; j = j + 1) begin
            if (x_unpacked[j] > max_out) begin
                max_out = x_unpacked[j];
            end
        end
    end

endmodule