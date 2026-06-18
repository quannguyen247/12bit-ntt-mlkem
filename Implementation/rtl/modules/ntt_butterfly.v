`timescale 1ns / 1ps
`include "ntt_defs.vh"

module ntt_butterfly (
    input wire clk,
    input wire rst_n,
    input wire [11:0] a_i,
    input wire [11:0] b_i,
    input wire [11:0] zeta_i,
    input wire valid_i,
    output reg valid_o,
    output reg [11:0] out0,
    output reg [11:0] out1
);

    reg [11:0] a_st1, b_st1, zeta_st1;
    reg v1;
    reg [11:0] a_st2, a_st3, a_st4, a_st5;
    reg v2, v3, v4, v5;
    wire [11:0] mod_mul_out;
    wire [11:0] add_tmp, sub_tmp;

    ntt_mod_mul_12b u_mul (
        .clk(clk),
        .a_i(b_st1),
        .b_i(zeta_st1),
        .r_o(mod_mul_out)
    );

    ntt_mod_addsub_12b u_as (
        .a_i(a_st5),
        .b_i(mod_mul_out),
        .add_o(add_tmp),
        .sub_o(sub_tmp)
    );

    always @(posedge clk) begin
        a_st1 <= a_i;
        b_st1 <= b_i;
        zeta_st1 <= zeta_i;
        v1 <= valid_i;
    end

    always @(posedge clk) begin
        a_st2 <= a_st1;
        v2 <= v1;
        a_st3 <= a_st2;
        v3 <= v2;
        a_st4 <= a_st3;
        v4 <= v3;
        a_st5 <= a_st4;
        v5 <= v4;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_o <= 1'b0;
            out0 <= 12'd0;
            out1 <= 12'd0;
        end else begin
            valid_o <= v5;
            out0 <= add_tmp;
            out1 <= sub_tmp;
        end
    end

endmodule