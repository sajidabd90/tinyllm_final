module tb_verify;

    parameter DEPTH = 5; //elements in your the test tensor
    

    reg [15:0] rom [0:DEPTH-1]; 

    initial begin

        $readmemh("tinystories_q88_roms/lm_head_weight.hex", rom);

        $display("--- ROM Verification ---");
        $display("Index 0: %h", rom[0]);
        $display("Index 1: %h", rom[1]);
        $display("Index 2: %h", rom[2]);
        $display("Index 3: %h", rom[3]);
        $display("Index 4: %h", rom[4]);
        $display("------------------------");
        
        $finish;
    end
endmodule