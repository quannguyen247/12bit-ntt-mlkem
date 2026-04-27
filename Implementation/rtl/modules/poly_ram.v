`timescale 1ns / 1ps

// Simple dual-port poly RAM (synchronous read)
module poly_ram #(
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 we,
    input  wire [ADDR_WIDTH-1:0] addr_wr,
    input  wire [ADDR_WIDTH-1:0] addr_rd,
    input  wire [11:0]          din,
    output reg  [11:0]          dout
);
    reg [11:0] mem [0:DEPTH-1];
    integer i;

    // Write port (synchronous)
    always @(posedge clk) begin
        if (we) mem[addr_wr] <= din;
    end

    // Combinational read multiplexer to avoid BRAM inference
    always @(*) begin
        dout = {12{1'b0}};
        for (i = 0; i < DEPTH; i = i + 1) begin
            if (addr_rd == i) dout = mem[i];
        end
    end

endmodule
