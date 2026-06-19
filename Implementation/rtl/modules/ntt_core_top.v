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

    wire [1:0] fstate;
    wire f_busy, f_done;
    reg advance_r;

    wire [7:0] len, pos, zidx, cnt;
    wire [7:0] addr_a, addr_b;

    wire [11:0] mem_dout0, mem_dout1;
    reg mem_we;
    reg [7:0] mem_wr_addr;
    reg [11:0] mem_wr_data;

    wire ram_we;
    wire [7:0] ram_addr_wr, ram_addr_rd;
    wire [11:0] ram_din;

    wire [11:0] zeta_d;

    wire [11:0] bf_out0, bf_out1;
    reg bf_valid_in;
    wire bf_valid_out;

    localparam [2:0] ST_WAIT_AGU = 3'd0;
    localparam [2:0] ST_READ_MEM = 3'd1;
    localparam [2:0] ST_FIRE = 3'd2;
    localparam [2:0] ST_WAIT_BF = 3'd3;
    localparam [2:0] ST_WRITE0 = 3'd4;
    localparam [2:0] ST_WRITE1 = 3'd5;

    reg [2:0] pstate;

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

    assign busy = f_busy;
    assign done = f_done;

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

    assign ram_we = f_busy ? mem_we : ext_we;
    assign ram_addr_wr = f_busy ? mem_wr_addr : ext_addr;
    assign ram_addr_rd = f_busy ? addr_a : ext_addr;
    assign ram_din = f_busy ? mem_wr_data : ext_din;
    assign ext_dout = mem_dout0;

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
                        pstate <= ST_READ_MEM;
                    end
                end
                ST_READ_MEM: begin
                    pstate <= ST_FIRE;
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
                        pstate <= ST_WRITE1;
                    end
                end
                ST_WRITE1: begin
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