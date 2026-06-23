`timescale 1ns / 1ps
`include "ntt_defs.vh"

module ntt_core_top (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire mode,
    input wire ext_we,
    input wire [7:0] ext_addr,
    input wire [11:0] ext_din,
    output wire [11:0] ext_dout,
    output wire busy,
    output wire done
);

    localparam ST_WAIT_AGU = 2'd0;
    localparam ST_FIRE = 2'd1;
    localparam ST_WAIT_BF = 2'd2;
    localparam ST_WRITE_B = 2'd3;

    reg [1:0] pstate;
    reg advance_r;
    reg bf_valid_in;

    reg mem_we;
    reg [7:0] mem_wr_addr;
    reg [11:0] mem_wr_data;

    wire [1:0] fstate;
    wire f_busy, f_done;
    wire [7:0] len;
    wire [7:0] pos;
    wire [7:0] zidx;
    wire [7:0] cnt;
    wire is_scale;

    wire [7:0] addr_a;
    wire [7:0] addr_b;

    wire [11:0] zeta_d;

    wire [11:0] bf_out0;
    wire [11:0] bf_out1;
    wire bf_valid_out;

    wire ram_we;
    wire [7:0] ram_addr_wr;
    wire [7:0] ram_addr_rd;
    wire [11:0] ram_din;
    wire [11:0] mem_dout0;
    wire [11:0] mem_dout1;

    assign busy = f_busy;
    assign done = f_done;
    assign ram_we = f_busy ? mem_we : ext_we;
    assign ram_addr_wr = f_busy ? mem_wr_addr : ext_addr;
    assign ram_addr_rd = f_busy ? addr_a : ext_addr;
    assign ram_din = f_busy ? mem_wr_data : ext_din;
    assign ext_dout = mem_dout0;
    assign is_scale = (fstate == 2'd2);

    ntt_controller u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mode(mode),
        .advance(advance_r),
        .state(fstate),
        .busy(f_busy),
        .done(f_done),
        .len(len),
        .pos(pos),
        .zidx(zidx),
        .cnt(cnt)
    );

    ntt_agu u_agu (
        .clk(clk),
        .rst_n(rst_n),
        .start(f_busy),
        .len(len),
        .pos(pos),
        .block_idx(zidx),
        .addr_a(addr_a),
        .addr_b(addr_b)
    );

    poly_ram_dual #(
        .DEPTH(256),
        .ADDR_WIDTH(8)
    ) u_mem (
        .clk(clk),
        .we(ram_we),
        .addr_wr(ram_addr_wr),
        .addr_rd0(ram_addr_rd),
        .addr_rd1(addr_b),
        .din(ram_din),
        .dout0(mem_dout0),
        .dout1(mem_dout1)
    );

    ntt_twiddle_rom u_rom (
        .addr(zidx[6:0]),
        .is_inv(mode),
        .d_out(zeta_d)
    );

    ntt_butterfly u_bf (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .is_scale(is_scale),
        .a_i(mem_dout0),
        .b_i(mem_dout1),
        .zeta_i(zeta_d),
        .valid_i(bf_valid_in),
        .valid_o(bf_valid_out),
        .out0(bf_out0),
        .out1(bf_out1)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            pstate <= ST_WAIT_AGU;
            mem_we <= 1'b0;
            mem_wr_addr <= 8'd0;
            mem_wr_data <= 12'd0;
            advance_r <= 1'b0;
            bf_valid_in <= 1'b0;
        end else begin
            mem_we <= 1'b0;
            advance_r <= 1'b0;
            bf_valid_in <= 1'b0;
            case (pstate)
                ST_WAIT_AGU: begin
                    if (f_busy) begin
                        pstate <= ST_FIRE;
                    end
                end
                ST_FIRE: begin
                    bf_valid_in <= 1'b1;
                    pstate <= ST_WAIT_BF;
                end
                ST_WAIT_BF: begin
                    if (bf_valid_out) begin
                        mem_we <= 1'b1;
                        mem_wr_addr <= addr_a;
                        mem_wr_data <= bf_out0;
                        if (is_scale) begin
                            advance_r <= 1'b1;
                            pstate <= ST_WAIT_AGU;
                        end else begin
                            pstate <= ST_WRITE_B;
                        end
                    end
                end
                ST_WRITE_B: begin
                    mem_we <= 1'b1;
                    mem_wr_addr <= addr_b;
                    mem_wr_data <= bf_out1;
                    advance_r <= 1'b1;
                    pstate <= ST_WAIT_AGU;
                end
                default: pstate <= ST_WAIT_AGU;
            endcase
        end
    end

endmodule