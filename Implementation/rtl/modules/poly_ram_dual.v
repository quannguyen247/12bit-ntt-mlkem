`timescale 1ns / 1ps
`include "ntt_defs.vh"

module poly_ram_dual #(
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = 8
)(
    input wire clk,
    input wire we,
    input wire [ADDR_WIDTH-1:0] addr_wr,
    input wire [ADDR_WIDTH-1:0] addr_rd0,
    input wire [ADDR_WIDTH-1:0] addr_rd1,
    input wire [11:0] din,
    output wire [11:0] dout0,
    output wire [11:0] dout1
);

    reg [11:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            mem[addr_wr] <= din;
        end
    end

    assign dout0 = mem[addr_rd0];
    assign dout1 = mem[addr_rd1];

endmodule
