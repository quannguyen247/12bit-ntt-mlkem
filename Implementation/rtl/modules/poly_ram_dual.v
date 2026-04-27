`timescale 1ns / 1ps

// Dual-read, single-write asynchronous poly RAM (CẤM BRAM - DÙNG LUTRAM/REGFILE)
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
    output wire [11:0]          dout0,  // Đổi thành wire
    output wire [11:0]          dout1   // Đổi thành wire
);

    // Khai báo bộ nhớ (Register File)
    reg [11:0] mem [0:DEPTH-1];

`ifndef SYNTHESIS
    initial begin
        $readmemh("build/vec_in.mem", mem);
    end
`endif

    // Ghi đồng bộ (Luôn phải có xung nhịp để cập nhật giá trị vào thanh ghi)
    always @(posedge clk) begin
        if (we) begin
            mem[addr_wr] <= din;
        end
    end

    // ĐỌC TỔ HỢP TRỰC TIẾP (Asynchronous Read)
    // Cách viết này báo cho Vivado biết đây là cấu trúc Memory Array, 
    // không phải một mớ logic hỗn độn.
    assign dout0 = mem[addr_rd0];
    assign dout1 = mem[addr_rd1];

endmodule