`timescale 1ns / 1ps
`include "ntt_defs.vh"

module ntt_twiddle_rom (
    input wire [6:0] addr,
    input wire is_inv,
    output wire [`NTT_DATA_WIDTH-1:0] d_out
);

    `include "ntt_funcs.vh"

    assign d_out = ntt_twiddle_u(addr, is_inv);

endmodule
