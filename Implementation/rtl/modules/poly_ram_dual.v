`timescale 1ns / 1ps

// Dual-read, single-write synchronous poly RAM
module poly_ram_dual #(
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 we,
    input  wire [ADDR_WIDTH-1:0] addr_wr,
    input  wire [ADDR_WIDTH-1:0] addr_rd0,
    input  wire [ADDR_WIDTH-1:0] addr_rd1,
    input  wire [11:0]          din,
    output reg  [11:0]          dout0,
    output reg  [11:0]          dout1
);
    reg [11:0] mem [0:DEPTH-1];
    integer i;

    // Write port (synchronous)
    always @(posedge clk) begin
        if (we) mem[addr_wr] <= din;
    end

    // Explicit combinational read-mux to discourage BRAM inference
    always @(*) begin
        dout0 = {12{1'b0}};
        dout1 = {12{1'b0}};
        for (i = 0; i < DEPTH; i = i + 1) begin
            if (addr_rd0 == i) dout0 = mem[i];
            if (addr_rd1 == i) dout1 = mem[i];
        end
    end

endmodule
