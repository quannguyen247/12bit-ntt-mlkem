`timescale 1ns / 1ps

// Single butterfly pipeline stage (combinational by default)
// out0 = a + fqmul(zeta, b)
// out1 = a - fqmul(zeta, b)
module ntt_butterfly (
    input  wire [11:0] a_i,
    input  wire [11:0] b_i,
    input  wire signed [15:0] zeta_i,
    output wire [11:0] out0,
    output wire [11:0] out1
);

    wire [11:0] prod; // fqmul(zeta, b)

    // Montgomery multiply: a = b_i, b = zeta_i (signed)
    ntt_mod_mul_12b u_mul (
        .a_i (b_i),
        .b_i (zeta_i),
        .r_o (prod)
    );

    ntt_mod_addsub_12b u_as (
        .a_i (a_i),
        .b_i (prod),
        .add_o (out0),
        .sub_o (out1)
    );

endmodule
