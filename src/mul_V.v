`timescale 1ns / 1ps

module mul_V(
    input wire signed [15:0] d_i,
    output wire signed[31:0] d_o
);
    assign d_o = (d_i <<< 14) + (d_i <<< 12) - (d_i <<< 8) - (d_i <<< 6) - d_i;
endmodule