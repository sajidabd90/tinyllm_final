module q88_weight_row_rom #(
    parameter VECTOR_LEN = 64,
    parameter ROW_COUNT = 64,
    parameter INIT_FILE = "roms/dummy.hex"
)(
    input  wire [15:0] row_addr,
    output wire [VECTOR_LEN*16-1:0] row_data
);

    reg [15:0] mem [0:(ROW_COUNT * VECTOR_LEN) - 1];

initial begin
    if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, mem);
    end
end


    genvar i;
    generate
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin : assemble_row
            assign row_data[i*16 +: 16] = mem[row_addr * VECTOR_LEN + i];
        end
    endgenerate
endmodule