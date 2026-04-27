`timescale 1ns / 1ps

// Low-level modular add/sub for q = 3329
module ntt_mod_addsub_12b (
    input  wire [11:0] a_i,
    input  wire [11:0] b_i,
    output wire [11:0] add_o,
    output wire [11:0] sub_o
);
    localparam [12:0] Q = 13'd3329;

    wire [12:0] sum = {1'b0, a_i} + {1'b0, b_i};
    assign add_o = (sum >= Q) ? (sum - Q)[11:0] : sum[11:0];

    wire [12:0] diff = (a_i >= b_i) ? ({1'b0, a_i} - {1'b0, b_i}) : ({1'b0, a_i} + Q - {1'b0, b_i});
    assign sub_o = diff[11:0];

endmodule
