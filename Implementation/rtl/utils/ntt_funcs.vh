`ifndef NTT_FUNCS_VH
`define NTT_FUNCS_VH

// NOTE: include `ntt_defs.vh` from the calling module with a correct relative path

// Modular add: (a + b) mod q
function [`NTT_DATA_WIDTH-1:0] ntt_mod_add;
    input [`NTT_DATA_WIDTH-1:0] a;
    input [`NTT_DATA_WIDTH-1:0] b;
    reg [`NTT_QWIDTH-1:0] sum;
    begin
        sum = {1'b0, a} + {1'b0, b};
        if (sum >= `NTT_Q)
            ntt_mod_add = sum - `NTT_Q;
        else
            ntt_mod_add = sum[`NTT_DATA_WIDTH-1:0];
    end
endfunction

// Modular sub: (a - b) mod q
function [`NTT_DATA_WIDTH-1:0] ntt_mod_sub;
    input [`NTT_DATA_WIDTH-1:0] a;
    input [`NTT_DATA_WIDTH-1:0] b;
    reg [`NTT_QWIDTH-1:0] diff;
    begin
        if (a >= b)
            diff = {1'b0, a} - {1'b0, b};
        else
            diff = {1'b0, a} + `NTT_Q - {1'b0, b};
        ntt_mod_sub = diff[`NTT_DATA_WIDTH-1:0];
    end
endfunction

// 12x12 multiplication using shift-add of partial products (avoids '*' operator)
function [23:0] ntt_mul_12x12;
    input [11:0] a;
    input [11:0] b;
    reg [23:0] res;
    integer i;
    begin
        res = 24'd0;
        for (i = 0; i < 12; i = i + 1) begin
            if (b[i])
                res = res + ({12'd0, a} << i);
        end
        ntt_mul_12x12 = res;
    end
endfunction

// Montgomery reduction without '*' by using shift-add expansions for constants
// m = (t * QINV) & 0xFFFF  where QINV = 3327 = (1<<12) - (1<<9) - (1<<8) - 1
// m_q = m * Q where Q = 3329 = (1<<12) - (1<<9) - (1<<8) + 1
function [`NTT_DATA_WIDTH-1:0] ntt_montgomery_reduce;
    input [23:0] t;
    reg [47:0] t_ext;
    reg [47:0] t_qinv;
    reg [15:0] m;
    reg [31:0] m_ext;
    reg [31:0] m_q;
    reg [31:0] t_plus;
    reg [15:0] u;
    begin
        t_ext = {24'd0, t};
        // t * QINV = (t<<12) - (t<<9) - (t<<8) - t
        t_qinv = (t_ext << 12) - (t_ext << 9) - (t_ext << 8) - t_ext;
        m = t_qinv[15:0];

        m_ext = {16'd0, m};
        // m * Q = (m<<12) - (m<<9) - (m<<8) + m
        m_q = (m_ext << 12) - (m_ext << 9) - (m_ext << 8) + m_ext;

        t_plus = {8'd0, t} + m_q; // align widths: t is 24b -> extend to 32b
        u = t_plus >> `NTT_R_BITS;

        if (u >= `NTT_Q)
            ntt_montgomery_reduce = u - `NTT_Q;
        else
            ntt_montgomery_reduce = u[`NTT_DATA_WIDTH-1:0];
    end
endfunction

// fqmul: multiply a (12-bit) by signed twiddle b, return reduced 12-bit result
function [`NTT_DATA_WIDTH-1:0] ntt_fqmul;
    input [`NTT_DATA_WIDTH-1:0] a;
    input signed [15:0] b;
    reg [15:0] b_u16;
    reg [11:0] b_u;
    reg [23:0] t;
    begin
        b_u16 = b[15] ? (b + `NTT_Q) : b;
        b_u = b_u16[`NTT_DATA_WIDTH-1:0];
        t = ntt_mul_12x12(a, b_u);
        ntt_fqmul = ntt_montgomery_reduce(t);
    end
endfunction

`endif
