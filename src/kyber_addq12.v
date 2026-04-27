`timescale 1ns / 1ps

module kyber_addq12 (
    input  wire [11:0] a_i,
    input  wire [11:0] b_i,
    output wire [11:0] r_o
);
    wire [12:0] s;
    wire [12:0] s_sub;

    assign s     = {1'b0, a_i} + {1'b0, b_i};
    assign s_sub = s - 13'd3329;

    assign r_o = (s >= 13'd3329) ? s_sub[11:0] : s[11:0];

endmodule