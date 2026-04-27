`timescale 1ns / 1ps

// Unified twiddle ROM: stores forward (high16) and inverse (low16)
`include "../utils/ntt_defs.vh"

module ntt_twiddle_rom (
    input  wire [6:0] addr,
    input  wire       is_inv,
    output wire [`NTT_DATA_WIDTH-1:0] d_out
);

    `include "../utils/ntt_funcs.vh"

    // Return unsigned NTT_DATA_WIDTH twiddle (0..Q-1)
    assign d_out = ntt_twiddle_u(addr, is_inv);

endmodule
