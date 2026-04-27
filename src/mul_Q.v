`timescale 1ns / 1ps

module mul_Q (
    input wire signed [15:0]    d_i,
    input wire                  mode, //0 for Q, 1 for QINV
    output wire signed [31:0]   d_o 
);
    assign d_o = (mode) ?  -(d_i <<< 12) + (d_i <<< 9) + (d_i <<< 8) + d_i
                        :   (d_i << 12) - (d_i << 9) - (d_i << 8) + d_i;
endmodule