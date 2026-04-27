`timescale 1ns / 1ps

module barrett_reduce (
    input  wire signed [15:0] a_i,
    output wire signed [15:0] t_o
);
    wire signed [31:0] mul_va;
    wire signed [15:0] t;
    wire signed [31:0] r;
    wire signed [31:0] mul_tq;

    // assign mul_va = $signed(a_i) * $signed(V);
    
    mul_V u_V(
        .d_i(a_i),
        .d_o(mul_va)
    );

    assign t = (mul_va + 32'sd33554432) >>> 26;

    // assign r = $signed(a_i) - ($signed(t) * $signed(Q));

    mul_Q u_Q_mul(
        .d_i(t),
        .mode(1'b0),
        .d_o(mul_tq)
    );

    assign r = $signed(a_i) - mul_tq;

    assign t_o = r[15:0];

endmodule
