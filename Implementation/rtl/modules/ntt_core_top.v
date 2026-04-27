`timescale 1ns / 1ps

// Top-level NTT core wrapper. Connects FSM, AGU, Twiddle ROM, RAM and Butterfly datapath.
module ntt_core_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        mode,   // 0 = NTT, 1 = INTT

    // simple control/status
    output wire        busy,
    output wire        done
);

    // FSM
    wire [1:0] fstate;
    wire [7:0] len;
    wire [7:0] pos;
    wire [7:0] zidx;
    wire [7:0] cnt;
    wire f_busy;
    wire f_done;

    reg advance_r;

    ntt_fsm u_fsm (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .mode     (mode),
        .advance  (advance_r),
        .state    (fstate),
        .busy     (f_busy),
        .done     (f_done),
        .len      (len),
        .pos      (pos),
        .zidx     (zidx),
        .cnt      (cnt)
    );

    assign busy = f_busy;
    assign done = f_done;

    // AGU
    wire [7:0] addr_a;
    wire [7:0] addr_b;

    ntt_agu u_agu (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (f_busy),
        .len      (len),
        .pos      (pos),
        .block_idx(zidx),
        .addr_a   (addr_a),
        .addr_b   (addr_b)
    );

    // Dual-port poly RAM
    wire [11:0] mem_dout0;
    wire [11:0] mem_dout1;
    reg         mem_we;
    reg  [7:0]  mem_wr_addr;
    reg  [11:0] mem_wr_data;

    poly_ram_dual #(.DEPTH(256), .ADDR_WIDTH(8)) u_mem (
        .clk    (clk),
        .we     (mem_we),
        .addr_wr(mem_wr_addr),
        .addr_rd0(addr_a),
        .addr_rd1(addr_b),
        .din    (mem_wr_data),
        .dout0  (mem_dout0),
        .dout1  (mem_dout1)
    );

    // Twiddle ROM
    wire signed [31:0] zeta_d;
    ntt_twiddle_rom u_rom (
        .addr  (zidx),
        .is_inv(mode),
        .d_out(zeta_d)
    );

    // Datapath: butterfly
    wire [11:0] bf_out0;
    wire [11:0] bf_out1;

    ntt_butterfly u_bf (
        .a_i (mem_dout0),
        .b_i (mem_dout1),
        .zeta_i (zeta_d[15:0]),
        .out0 (bf_out0),
        .out1 (bf_out1)
    );

    // Simple 4-cycle pipeline to perform read->compute->write0->write1
    reg [1:0] pstate;
    // pstate: 0 = idle/wait, 1 = capture (compute), 2 = write0, 3 = write1

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pstate <= 2'd0;
            mem_we <= 1'b0;
            mem_wr_addr <= 8'd0;
            mem_wr_data <= 12'd0;
            advance_r <= 1'b0;
        end else begin
            // default
            mem_we <= 1'b0;
            advance_r <= 1'b0;

            case (pstate)
                2'd0: begin
                    if (f_busy) begin
                        // when busy, start capture on next cycle (assume AGU provided addr this cycle)
                        pstate <= 2'd1;
                    end
                end

                2'd1: begin
                    // capture/computation happened (mem_dout0/1 are available from previous cycle)
                    // move to write0
                    pstate <= 2'd2;
                end

                2'd2: begin
                    // write result0 to addr_a
                    mem_we <= 1'b1;
                    mem_wr_addr <= addr_a;
                    mem_wr_data <= bf_out0;
                    pstate <= 2'd3;
                end

                2'd3: begin
                    // write result1 to addr_b
                    mem_we <= 1'b1;
                    mem_wr_addr <= addr_b;
                    mem_wr_data <= bf_out1;
                    // signal FSM that this butterfly is done
                    advance_r <= 1'b1;
                    pstate <= 2'd0;
                end

                default: pstate <= 2'd0;
            endcase
        end
    end

endmodule
