`timescale 1ns / 1ps

// Address Generation Unit (simple block generator for in-place NTT)
module ntt_agu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [7:0]  len,       // current half-block length
    input  wire [7:0]  pos,       // position inside block
    input  wire [7:0]  block_idx, // which block

    output reg  [7:0]  addr_a,
    output reg  [7:0]  addr_b
);

    // Basic addressing: addr_a = block_idx * (len*2) + pos
    // addr_b = addr_a + len
    // This is a simplified AGU; for full efficiency refine stride/block mapping.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_a <= 8'd0;
            addr_b <= 8'd0;
        end else begin
            if (start) begin
                addr_a <= (block_idx * (len << 1)) + pos;
                addr_b <= (block_idx * (len << 1)) + pos + len;
            end
        end
    end

endmodule
