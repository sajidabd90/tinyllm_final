`timescale 1ns / 1ps

module q88_vector_assembler #(
    parameter VECTOR_LEN = 64
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     shift_en, 
    input  wire signed [15:0]       data_in,  
    

    output reg  [VECTOR_LEN*16-1:0] vector_out 
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vector_out <= {VECTOR_LEN*16{1'b0}};
        end else if (shift_en) begin
            vector_out <= {vector_out[(VECTOR_LEN-1)*16-1:0], data_in};
        end
    end

endmodule