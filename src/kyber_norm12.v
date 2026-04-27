`timescale 1ns / 1ps

module kyber_norm12 (
    input  wire signed [15:0] x_i,
    output wire [11:0]        r_o
);
    wire signed [16:0] x17;
    wire signed [16:0] add_q;
    wire signed [16:0] t0;
    wire signed [16:0] sub_q;
    wire signed [16:0] t1;

    assign x17   = {x_i[15], x_i};
    assign add_q = x17 + 17'sd3329;

    assign t0 = x17[16] ? add_q : x17;

    assign sub_q = t0 - 17'sd3329;
    assign t1    = (t0 >= 17'sd3329) ? sub_q : t0;

    assign r_o = t1[11:0];

endmodule