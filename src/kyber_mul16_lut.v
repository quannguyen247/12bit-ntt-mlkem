`timescale 1ns / 1ps

module kyber_mul16_lut (
    input  wire signed [15:0] a_i,
    input  wire signed [15:0] b_i,
    output wire signed [31:0] p_o
);

    wire        neg;
    wire [15:0] a_abs;
    wire [15:0] b_abs;

    assign neg   = a_i[15] ^ b_i[15];
    assign a_abs = a_i[15] ? (~a_i + 16'd1) : a_i;
    assign b_abs = b_i[15] ? (~b_i + 16'd1) : b_i;

    wire [31:0] a_ext;

    assign a_ext = {16'd0, a_abs};

    wire [31:0] pp0;
    wire [31:0] pp1;
    wire [31:0] pp2;
    wire [31:0] pp3;
    wire [31:0] pp4;
    wire [31:0] pp5;
    wire [31:0] pp6;
    wire [31:0] pp7;
    wire [31:0] pp8;
    wire [31:0] pp9;
    wire [31:0] pp10;
    wire [31:0] pp11;
    wire [31:0] pp12;
    wire [31:0] pp13;
    wire [31:0] pp14;
    wire [31:0] pp15;

    assign pp0  = b_abs[0]  ? (a_ext << 0)  : 32'd0;
    assign pp1  = b_abs[1]  ? (a_ext << 1)  : 32'd0;
    assign pp2  = b_abs[2]  ? (a_ext << 2)  : 32'd0;
    assign pp3  = b_abs[3]  ? (a_ext << 3)  : 32'd0;
    assign pp4  = b_abs[4]  ? (a_ext << 4)  : 32'd0;
    assign pp5  = b_abs[5]  ? (a_ext << 5)  : 32'd0;
    assign pp6  = b_abs[6]  ? (a_ext << 6)  : 32'd0;
    assign pp7  = b_abs[7]  ? (a_ext << 7)  : 32'd0;
    assign pp8  = b_abs[8]  ? (a_ext << 8)  : 32'd0;
    assign pp9  = b_abs[9]  ? (a_ext << 9)  : 32'd0;
    assign pp10 = b_abs[10] ? (a_ext << 10) : 32'd0;
    assign pp11 = b_abs[11] ? (a_ext << 11) : 32'd0;
    assign pp12 = b_abs[12] ? (a_ext << 12) : 32'd0;
    assign pp13 = b_abs[13] ? (a_ext << 13) : 32'd0;
    assign pp14 = b_abs[14] ? (a_ext << 14) : 32'd0;
    assign pp15 = b_abs[15] ? (a_ext << 15) : 32'd0;

    wire [31:0] p_abs;

    assign p_abs = pp0  + pp1  + pp2  + pp3
                 + pp4  + pp5  + pp6  + pp7
                 + pp8  + pp9  + pp10 + pp11
                 + pp12 + pp13 + pp14 + pp15;

    assign p_o = neg ? -$signed(p_abs) : $signed(p_abs);

endmodule