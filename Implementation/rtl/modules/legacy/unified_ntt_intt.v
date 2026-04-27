`timescale 1ns / 1ps

module unified_ntt_intt (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        mode,      // 0 = NTT, 1 = INTT
    input  wire        valid_i,

    input  wire [11:0] d_i0,
    input  wire [11:0] d_i1,

    output reg  [11:0] d_o0,
    output reg  [11:0] d_o1,
    output reg         busy,
    output reg         done,
    output reg         valid_o
);

    localparam signed [15:0] SCALE = 16'sd1441;

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_RUN   = 2'd1;
    localparam [1:0] S_SCALE = 2'd2;

    reg [1:0] state;
    reg       op_mode;

    reg [7:0] len;
    reg [7:0] pos;
    reg [7:0] zidx;
    reg [7:0] cnt;

    wire accept = busy & valid_i;

    wire signed [31:0] zf_raw;
    wire signed [31:0] zi_raw;

    wire signed [15:0] zeta =
        op_mode ? zi_raw[15:0] : zf_raw[15:0];

    twiddle_factor u_zf (
        .addr  (zidx),
        .d_out (zf_raw)
    );

    twiddle_factor_inv u_zi (
        .addr  (zidx),
        .d_out (zi_raw)
    );

    wire [11:0] add_b;
    wire [11:0] sub_b;

    wire [11:0] add_o;
    wire [11:0] sub_o;

    assign add_b = op_mode ? d_i1  : mont12;
    assign sub_b = op_mode ? d_i1  : mont12;

    kyber_addq12 u_add (
        .a_i (d_i0),
        .b_i (add_b),
        .r_o (add_o)
    );

    kyber_subq12 u_sub (
        .a_i (d_i0),
        .b_i (sub_b),
        .r_o (sub_o)
    );


    wire signed [15:0] intt_sum16;
    wire signed [15:0] barrett_sum16;
    wire [11:0]        barrett_sum12;

    assign intt_sum16 = $signed({4'd0, d_i0}) + $signed({4'd0, d_i1});

    barrett_reduce u_barrett_sum (
        .a_i (intt_sum16),
        .t_o (barrett_sum16)
    );

    kyber_norm12 u_barrett_norm (
        .x_i (barrett_sum16),
        .r_o (barrett_sum12)
    );

    wire signed [15:0] mul_x;
    wire signed [15:0] mul_y;
    wire signed [31:0] mul_in;

    wire signed [15:0] mont_raw;
    wire [11:0]        mont12;

    assign mul_x =
        (state == S_SCALE) ? $signed({4'd0, d_i0}) :
        op_mode            ? $signed({4'd0, sub_o}) :
                             $signed({4'd0, d_i1});

    assign mul_y =
        (state == S_SCALE) ? SCALE : zeta;

    kyber_mul16_lut u_mul_main (
        .a_i (mul_x),
        .b_i (mul_y),
        .p_o (mul_in)
    );

    k2_red u_mont (
        .a_i (mul_in),
        .t_o (mont_raw)
    );

    kyber_norm12 u_mont_norm (
        .x_i (mont_raw),
        .r_o (mont12)
    );

    wire block_last = (pos == len - 8'd1);
    wire stage_last = (cnt == 8'd127);

    wire scale_last = (state == S_SCALE) && (cnt == 8'd255);

    wire ntt_last =
        (state == S_RUN) && !op_mode && stage_last && block_last && (len == 8'd2);

    wire intt_last =
        (state == S_RUN) && op_mode && stage_last && block_last && (len == 8'd128);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            op_mode <= 1'b0;
            len     <= 8'd0;
            pos     <= 8'd0;
            zidx    <= 8'd0;
            cnt     <= 8'd0;

            d_o0    <= 12'd0;
            d_o1    <= 12'd0;

            busy    <= 1'b0;
            done    <= 1'b0;
            valid_o <= 1'b0;

        end else begin
            done    <= 1'b0;
            valid_o <= 1'b0;

            case (state)

                S_IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        busy    <= 1'b1;
                        op_mode <= mode;
                        len     <= mode ? 8'd2   : 8'd128;
                        zidx    <= mode ? 8'd0   : 8'd1;
                        pos     <= 8'd0;
                        cnt     <= 8'd0;
                        state   <= S_RUN;
                    end
                end

                S_RUN: begin
                    if (accept) begin
                        valid_o <= 1'b1;

                        if (!op_mode) begin
                            // NTT:
                            // out0 = a + fqmul(zeta, b)
                            // out1 = a - fqmul(zeta, b)
                            d_o0 <= add_o;
                            d_o1 <= sub_o;
                        end else begin
                            // INTT:
                            // out0 = barrett_reduce(a + b)
                            // out1 = fqmul(zeta, a - b)
                            d_o0 <= barrett_sum12;
                            d_o1 <= mont12;
                        end

                        if (block_last) begin
                            pos  <= 8'd0;
                            zidx <= zidx + 8'd1;
                        end else begin
                            pos <= pos + 8'd1;
                        end

                        if (stage_last) begin
                            cnt <= 8'd0;
                            pos <= 8'd0;

                            if (!op_mode) begin
                                if (len == 8'd2) begin
                                    done  <= 1'b1;
                                    busy  <= 1'b0;
                                    state <= S_IDLE;
                                end else begin
                                    len <= len >> 1;
                                end
                            end else begin
                                if (len == 8'd128) begin
                                    state <= S_SCALE;
                                end else begin
                                    len <= len << 1;
                                end
                            end
                        end else begin
                            cnt <= cnt + 8'd1;
                        end
                    end
                end

                S_SCALE: begin
                    if (accept) begin
                        valid_o <= 1'b1;

                        d_o0 <= mont12;
                        d_o1 <= 12'd0;

                        if (scale_last) begin
                            done  <= 1'b1;
                            busy  <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            cnt <= cnt + 8'd1;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
