`timescale 1ns / 1ps
`include "ntt_defs.vh"

module ntt_mod_addsub_12b (
    input wire [11:0] a_i,
    input wire [11:0] b_i,
    output wire [11:0] add_o,
    output wire [11:0] sub_o
);

    localparam [12:0] Q = 13'd3329;

    wire [12:0] sum, add_tmp, diff;

    assign sum = {1'b0, a_i} + {1'b0, b_i};
    assign add_tmp = (sum >= Q) ? (sum - Q) : sum;
    assign add_o = add_tmp[11:0];
    assign diff = (a_i >= b_i) ? ({1'b0, a_i} - {1'b0, b_i}) : ({1'b0, a_i} + Q - {1'b0, b_i});
    assign sub_o = diff[11:0];

endmodule
