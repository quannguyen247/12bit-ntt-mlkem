`ifndef NTT_DEFS_VH
`define NTT_DEFS_VH

// NTT parameters for q = 3329
`define NTT_Q           13'd3329
`define NTT_DATA_WIDTH  12
`define NTT_QWIDTH      13
`define NTT_R_BITS      16
`define NTT_QINV        16'd3327 // -inv(q) mod 2^16 used for Montgomery
`define NTT_SCALE       16'sd1441 // INTT scaling constant

`endif
