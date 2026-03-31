module q88_weight_rom #(
    parameter DEPTH = 64,
    parameter INIT_FILE = "roms/dummy.hex" 
)(
    input  wire [15:0] addr,
    output wire [15:0] data
);
    reg [15:0] mem [0:DEPTH-1];

initial begin
    if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, mem);
    end
end

    assign data = mem[addr];
endmodule