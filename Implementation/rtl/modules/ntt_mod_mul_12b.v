`timescale 1ns / 1ps
`include "ntt_defs.vh"

module ntt_mod_mul_12b (
    input wire clk,
    input wire [11:0] a_i,
    input wire [11:0] b_i,
    output reg [11:0] r_o
);

    reg [23:0] t_reg;
    reg [15:0] m_reg;
    reg [23:0] t_reg_d1;
    reg [28:0] t_plus_reg;

    (* use_dsp = "no" *) wire [23:0] t_comb;
    wire [15:0] t_16;
    wire [15:0] p1_m;
    wire [15:0] p2_m;
    wire [15:0] m_comb;
    wire [28:0] m_29;
    wire [28:0] p1_mq;
    wire [28:0] p2_mq;
    wire [28:0] mq_comb;
    wire [28:0] t_plus_comb;
    wire [12:0] u_comb;
    wire [13:0] sub_val;
    wire is_negative;
    wire [11:0] reduced_comb;

    assign t_comb = a_i * b_i;
    assign t_16 = t_reg[15:0];
    assign p1_m = (t_16 << 12) - (t_16 << 9);
    assign p2_m = (t_16 << 8) + t_16;
    assign m_comb = p1_m - p2_m;
    assign m_29 = {13'd0, m_reg};
    assign p1_mq = (m_29 << 12) - (m_29 << 9);
    assign p2_mq = (m_29 << 8) - m_29;
    assign mq_comb = p1_mq - p2_mq;
    assign t_plus_comb = {5'd0, t_reg_d1} + mq_comb;
    assign u_comb = t_plus_reg[28:16];
    assign sub_val = {1'b0, u_comb} - 14'd3329;
    assign is_negative = sub_val[13];
    assign reduced_comb = is_negative ? u_comb[11:0] : sub_val[11:0];

    always @(posedge clk) begin
        t_reg <= t_comb;
    end

    always @(posedge clk) begin
        m_reg <= m_comb;
        t_reg_d1 <= t_reg;
    end

    always @(posedge clk) begin
        t_plus_reg <= t_plus_comb;
    end

    always @(posedge clk) begin
        r_o <= reduced_comb;
    end

endmodule