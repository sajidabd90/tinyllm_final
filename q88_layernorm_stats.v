`timescale 1ns / 1ps

module q88_layernorm_stats #(
    parameter VECTOR_LEN = 64
)(
    input  wire [VECTOR_LEN*16-1:0] vec_in,

    output reg  [VECTOR_LEN*16-1:0] vec_centered_out,

    output reg  signed [15:0]       variance_out
);


    reg signed [15:0] x_unpacked [0:VECTOR_LEN-1];
    integer i;
    always @(*) begin
        for (i = 0; i < VECTOR_LEN; i = i + 1) begin
            x_unpacked[i] = vec_in[i*16 +: 16];
        end
    end


    // STEP 1: Calculate Mean (mu)

    reg signed [31:0] sum_acc;
    reg signed [15:0] mean_val;
    integer j;

    always @(*) begin
        sum_acc = 0;

        for (j = 0; j < VECTOR_LEN; j = j + 1) begin
            sum_acc = sum_acc + x_unpacked[j];
        end

            mean_val = (sum_acc >>> 6);  // bits [21:6] of 32-bit sum = divide by 64, take lower 16 bits for mean output
    end


    // STEP 2: Mean-Centering (x - mu)

    reg signed [15:0] x_centered [0:VECTOR_LEN-1];
    reg signed [31:0] sub_temp;
    integer k;

    always @(*) begin
        for (k = 0; k < VECTOR_LEN; k = k + 1) begin
            sub_temp = x_unpacked[k] - mean_val;
            

            if (sub_temp > 32'sd32767)
                x_centered[k] = 16'sd32767;
            else if (sub_temp < -32'sd32768)
                x_centered[k] = -16'sd32768;
            else
                x_centered[k] = sub_temp[15:0];
                

            vec_centered_out[k*16 +: 16] = x_centered[k];
        end
    end


    // STEP 3: Calculate Variance (sigma^2)

    reg signed [31:0] var_acc;
    reg signed [31:0] sq_temp;
    integer m;

    always @(*) begin
        var_acc = 0;
        for (m = 0; m < VECTOR_LEN; m = m + 1) begin

            sq_temp = (x_centered[m] * x_centered[m]) >>> 8;
            

            var_acc = var_acc + sq_temp;
        end

        if ((var_acc >>> 6) > 32'sd32767)
            variance_out = 16'sd32767;
        else
            variance_out = (var_acc >>> 6);
    end

endmodule