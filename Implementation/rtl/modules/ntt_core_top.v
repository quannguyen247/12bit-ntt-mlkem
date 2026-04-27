`timescale 1ns / 1ps

// Top-level NTT core wrapper. 
// Tích hợp FSM, AGU, Twiddle ROM, LUTRAM và Datapath Pipeline 5 tầng.

module ntt_core_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        mode,       // 0 = NTT, 1 = INTT

    // --- GIAO DIỆN DATA GIAO TIẾP VỚI CPU/AXI BÊN NGOÀI ---
    input  wire        ext_we,     // Write Enable từ bên ngoài
    input  wire [7:0]  ext_addr,   // Địa chỉ (0 đến 255)
    input  wire [11:0] ext_din,    // Dữ liệu ghi vào
    output wire [11:0] ext_dout,   // Dữ liệu đọc ra

    // Tín hiệu điều khiển/trạng thái
    output wire        busy,
    output wire        done
);

    // --------------------------------------------------------
    // 1. KẾT NỐI FSM TỔNG (ĐIỀU KHIỂN VÒNG LẶP)
    // --------------------------------------------------------
    wire [1:0] fstate;
    wire [7:0] len;
    wire [7:0] pos;
    wire [7:0] zidx;
    wire [7:0] cnt;
    wire f_busy;
    wire f_done;

    reg advance_r; // Tín hiệu kích FSM nhảy bước

    ntt_fsm u_fsm (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .mode     (mode),
        .advance  (advance_r),
        .state    (fstate),
        .busy     (f_busy),
        .done     (f_done),
        .len      (len),
        .pos      (pos),
        .zidx     (zidx),
        .cnt      (cnt)
    );

    assign busy = f_busy;
    assign done = f_done;

    // --------------------------------------------------------
    // 2. KẾT NỐI AGU (BỘ TẠO ĐỊA CHỈ)
    // --------------------------------------------------------
    wire [7:0] addr_a;
    wire [7:0] addr_b;

    ntt_agu u_agu (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (f_busy),
        .len      (len),
        .pos      (pos),
        .block_idx(zidx),
        .addr_a   (addr_a),
        .addr_b   (addr_b)
    );

    // --------------------------------------------------------
    // 3. KẾT NỐI LUTRAM & LOGIC MUX (IN-PLACE MEMORY)
    // --------------------------------------------------------
    wire [11:0] mem_dout0;
    wire [11:0] mem_dout1;

    reg         mem_we;
    reg  [7:0]  mem_wr_addr;
    reg  [11:0] mem_wr_data;

    // --- MUX Định tuyến: 
    // Khi busy == 1: Lõi NTT nắm quyền kiểm soát RAM.
    // Khi busy == 0: CPU bên ngoài nắm quyền Đọc/Ghi RAM.
    wire        ram_we      = f_busy ? mem_we      : ext_we;
    wire [7:0]  ram_addr_wr = f_busy ? mem_wr_addr : ext_addr;
    wire [7:0]  ram_addr_rd = f_busy ? addr_a      : ext_addr;
    wire [11:0] ram_din     = f_busy ? mem_wr_data : ext_din;

    // Mở port 0 ra ngoài để CPU đọc kết quả
    assign ext_dout = mem_dout0;

    poly_ram_dual #(
        .DEPTH(256), 
        .ADDR_WIDTH(8)
    ) u_mem (
        .clk      (clk),
        .we       (ram_we),
        .addr_wr  (ram_addr_wr),
        .addr_rd0 (ram_addr_rd),
        .addr_rd1 (addr_b),
        .din      (ram_din),
        .dout0    (mem_dout0),
        .dout1    (mem_dout1)
    );

    // --------------------------------------------------------
    // 4. KẾT NỐI ROM HỆ SỐ ZETA
    // --------------------------------------------------------
    wire [11:0] zeta_d; 
    
    ntt_twiddle_rom u_rom (
        .addr   (zidx[6:0]),
        .is_inv (mode),
        .d_out  (zeta_d)
    );

    // --------------------------------------------------------
    // 5. KẾT NỐI LÕI BUTTERFLY (DATAPATH 5 TẦNG PIPELINE)
    // --------------------------------------------------------
    wire [11:0] bf_out0;
    wire [11:0] bf_out1;
    
    reg  bf_valid_in;
    wire bf_valid_out;

    ntt_butterfly u_bf (
        .clk     (clk),
        .rst_n   (rst_n),
        .a_i     (mem_dout0),
        .b_i     (mem_dout1),
        .zeta_i  (zeta_d),
        .valid_i (bf_valid_in),
        .valid_o (bf_valid_out),
        .out0    (bf_out0),
        .out1    (bf_out1)
    );

    // --------------------------------------------------------
    // 6. PIPELINE FSM (GIAO TIẾP GIỮA RAM VÀ BƯỚM)
    // --------------------------------------------------------
    localparam ST_WAIT_AGU = 3'd0;
    localparam ST_READ_MEM = 3'd1;
    localparam ST_FIRE     = 3'd2;
    localparam ST_WAIT_BF  = 3'd3;
    localparam ST_WRITE0   = 3'd4;
    localparam ST_WRITE1   = 3'd5;

    reg [2:0] pstate;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pstate      <= ST_WAIT_AGU;
            mem_we      <= 1'b0;
            mem_wr_addr <= 8'd0;
            mem_wr_data <= 12'd0;
            advance_r   <= 1'b0;
            bf_valid_in <= 1'b0;
        end else begin
            // Xóa các tín hiệu kích hoạt về 0 để tạo xung (pulse) 1 nhịp clock
            mem_we      <= 1'b0;
            advance_r   <= 1'b0;
            bf_valid_in <= 1'b0;

            case (pstate)
                ST_WAIT_AGU: begin
                    if (f_busy) begin
                        // Đợi 1 nhịp để AGU cấp phát địa chỉ mới
                        pstate <= ST_READ_MEM;
                    end
                end

                ST_READ_MEM: begin
                    // Đợi 1 nhịp để data từ LUTRAM (đọc tổ hợp) chạy tới cửa Pipeline
                    pstate <= ST_FIRE;
                end

                ST_FIRE: begin
                    // Bắn tín hiệu valid kích hoạt khối Butterfly 5 tầng
                    bf_valid_in <= 1'b1;
                    pstate      <= ST_WAIT_BF;
                end

                ST_WAIT_BF: begin
                    // Chờ dữ liệu chảy qua 5 thanh ghi. Khi valid_o bật lên:
                    if (bf_valid_out) begin
                        mem_we      <= 1'b1;
                        mem_wr_addr <= addr_a;
                        mem_wr_data <= bf_out0;
                        pstate      <= ST_WRITE1;
                    end
                end

                ST_WRITE1: begin
                    // Ghi tiếp kết quả nhánh dưới vào addr_b (Vì RAM chỉ có 1 port ghi)
                    mem_we      <= 1'b1;
                    mem_wr_addr <= addr_b;
                    mem_wr_data <= bf_out1;
                    advance_r   <= 1'b1;     // Kích FSM tổng dịch lên tính phần tử tiếp theo
                    pstate      <= ST_WAIT_AGU;
                end

                default: pstate <= ST_WAIT_AGU;
            endcase
        end
    end

endmodule