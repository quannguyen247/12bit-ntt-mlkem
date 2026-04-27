`timescale 1ns / 1ps

module kyber_subq12 (
    input  wire [11:0] a_i,
    input  wire [11:0] b_i,
    output wire [11:0] r_o
);
    wire [12:0] d_pos;
    wire [12:0] d_neg;

    assign d_pos = {1'b0, a_i} - {1'b0, b_i};
    assign d_neg = {1'b0, a_i} + 13'd3329 - {1'b0, b_i};

    assign r_o = (a_i >= b_i) ? d_pos[11:0] : d_neg[11:0];

endmodule
