`timescale 1ns / 1ps

module k2_red #(
    parameter signed [15:0] Q       = 16'sd3329,
    parameter signed [15:0] QINV    = -16'sd3327
)(
    input wire signed [31:0] a_i,
    output wire signed [15:0] t_o
);
    wire signed [15:0] a_low; 
    (* use_dsp = "no" *) wire signed [31:0] mul_t;
    wire signed [15:0] t;
    (* use_dsp = "no" *) wire signed [31:0] tq;
    wire signed [31:0] red;

    assign a_low    = a_i[15:0];

    mul_Q u_QINV(
        .d_i(a_low),
        .mode(1'b1),
        .d_o(mul_t)
    );

    mul_Q u_Q(
        .d_i(t),
        .mode(1'b0),
        .d_o(tq)
    );

    assign t        = mul_t[15:0];
    assign red      = (a_i - tq) >>> 16;
    assign t_o      = red[15:0];
endmodule 
