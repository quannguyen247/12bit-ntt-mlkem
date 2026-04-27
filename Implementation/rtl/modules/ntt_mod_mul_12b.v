`timescale 1ns / 1ps

// Montgomery-style 12x12 -> 12 modular multiplier for q=3329
// Implemented with shift-add (no '*' operators) to avoid DSP inference.
`include "../utils/ntt_defs.vh"
`include "../utils/ntt_funcs.vh"

module ntt_mod_mul_12b (
    input  wire [11:0] a_i,
    input  wire signed [15:0] b_i, // signed representation from ROM (can be negative)
    output wire [11:0] r_o
);

    // convert signed b_i to unsigned representative in [0,q-1]
    wire signed [15:0] b_s = b_i;
    wire [15:0] b_u16 = b_s[15] ? (b_s + `NTT_Q) : b_s;
    wire [11:0] b_u = b_u16[`NTT_DATA_WIDTH-1:0];

    // partial-product multiply implemented in ntt_funcs.vh
    wire [23:0] t = ntt_mul_12x12(a_i, b_u);

    // Montgomery reduce using shift-add expansions (no '*')
    assign r_o = ntt_montgomery_reduce(t);

endmodule
