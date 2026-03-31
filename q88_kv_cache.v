`timescale 1ns / 1ps

module q88_kv_cache #(
    parameter VECTOR_LEN = 64,      
    parameter MAX_SEQ_LEN = 256,    
    parameter ADDR_WIDTH = 8        
)(
    input  wire                     clk,
    input  wire                     we,         
    input  wire [ADDR_WIDTH-1:0]    write_addr, 
    input  wire [ADDR_WIDTH-1:0]    read_addr,  
    input  wire [VECTOR_LEN*16-1:0] data_in,
    output reg  [VECTOR_LEN*16-1:0] data_out
);

    reg [VECTOR_LEN*16-1:0] ram [0:MAX_SEQ_LEN-1];

    always @(posedge clk) begin
        // Write Port
        if (we) begin
            ram[write_addr] <= data_in;
        end
        
        data_out <= ram[read_addr];
    end

endmodule