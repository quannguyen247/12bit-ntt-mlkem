`timescale 1ns / 1ps

module ntt_mod_mul_12b (
    input  wire        clk,
    input  wire [11:0] a_i,
    input  wire [11:0] b_i,
    output reg  [11:0] r_o
);
    // ---------------------------------------------------------
    // INTERNAL STAGE 1: Pure 12x12 LUT Multiplier
    // ---------------------------------------------------------
    (* use_dsp = "no" *) wire [23:0] t_comb = a_i * b_i;
    
    // BÍ THUẬT 2: Cho phép Vivado nhấc FF này trượt về trước hoặc sau 
    // để san bằng Delay nếu phép nhân này quá lâu.
    reg [23:0] t_reg;
    always @(posedge clk) t_reg <= t_comb;

    // ---------------------------------------------------------
    // INTERNAL STAGE 2: Calculate m = (t * 3327) mod 2^16
    // Unrolled Parallel Adder Tree cho 3327
    // ---------------------------------------------------------
    wire [15:0] t_16 = t_reg[15:0];
    wire [15:0] p1_m = (t_16 << 12) - (t_16 << 9); 
    wire [15:0] p2_m = (t_16 << 8)  + t_16;        
    wire [15:0] m_comb = p1_m - p2_m;
    
    reg [15:0] m_reg;
    reg [23:0] t_reg_d1;
    always @(posedge clk) begin
        m_reg    <= m_comb;
        t_reg_d1 <= t_reg; // Đẩy 't' đi tiếp
    end

    // ---------------------------------------------------------
    // INTERNAL STAGE 3: Calculate M*Q and Add T
    // Unrolled Parallel Adder Tree cho 3329
    // ---------------------------------------------------------
    wire [28:0] m_29 = {13'd0, m_reg};
    wire [28:0] p1_mq = (m_29 << 12) - (m_29 << 9);
    wire [28:0] p2_mq = (m_29 << 8)  - m_29;
    wire [28:0] mq_comb = p1_mq - p2_mq;
    
    wire [28:0] t_plus_comb = {5'd0, t_reg_d1} + mq_comb;
    
    reg [28:0] t_plus_reg;
    always @(posedge clk) begin
        t_plus_reg <= t_plus_comb;
    end

    // ---------------------------------------------------------
    // INTERNAL STAGE 4: Modulo Reduction
    // BÍ THUẬT 1: Dùng Sign-bit (Số bù 2) triệt tiêu hoàn toàn bộ so sánh
    // ---------------------------------------------------------
    wire [12:0] u_comb = t_plus_reg[28:16];
    
    // Mở rộng thêm 1 bit 0 ở đầu (thành 14 bit) để làm bit dấu.
    // Thực hiện phép trừ u_comb - 3329.
    wire [13:0] sub_val = {1'b0, u_comb} - 14'd3329;
    
    // Bit cao nhất (bit 13) chính là bit dấu.
    // Nếu âm (u_comb < 3329) -> bit 13 = 1.
    // Nếu dương (u_comb >= 3329) -> bit 13 = 0.
    wire is_negative = sub_val[13];
    
    // MUX chọn kết quả phụ thuộc trực tiếp vào 1 bit duy nhất.
    // Logic này chỉ tốn đúng 1 level LUT, gọt bay ít nhất 200ps!
    wire [11:0] reduced_comb = is_negative ? u_comb[11:0] : sub_val[11:0];
    
    always @(posedge clk) begin
        r_o <= reduced_comb;
    end

endmodule