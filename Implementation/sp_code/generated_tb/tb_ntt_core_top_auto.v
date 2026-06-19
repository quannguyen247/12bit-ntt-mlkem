`timescale 1ns / 1ps

module tb_ntt_core_top_auto;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n;
    reg start;
    reg mode;

    reg        ext_we;
    reg [7:0]  ext_addr;
    reg [11:0] ext_din;
    wire [11:0] ext_dout;

    wire busy;
    wire done;

    integer i;
    integer err;
    integer timeout;
    integer mode_sel;

    reg [11:0] vec_in  [0:255];
    reg [11:0] vec_exp [0:255];
    reg [11:0] got;

    reg [1023:0] in_mem;
    reg [1023:0] exp_mem;

    ntt_core_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mode(mode),
        .ext_we(ext_we),
        .ext_addr(ext_addr),
        .ext_din(ext_din),
        .ext_dout(ext_dout),
        .busy(busy),
        .done(done)
    );

    task do_reset;
        begin
            rst_n = 1'b0;
            start = 1'b0;
            mode = 1'b0;
            ext_we = 1'b0;
            ext_addr = 8'd0;
            ext_din = 12'd0;

            repeat (8) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    task load_input_mem;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                @(negedge clk);
                ext_we = 1'b1;
                ext_addr = i[7:0];
                ext_din = vec_in[i];
            end
            @(negedge clk);
            ext_we = 1'b0;
            ext_addr = 8'd0;
            ext_din = 12'd0;
        end
    endtask

    task start_core;
        begin
            @(negedge clk);
            mode = mode_sel[0];
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    task wait_done_or_timeout;
        begin
            timeout = 0;
            while (!done && timeout < 200000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (!done) begin
                $display("[FAIL] Timeout waiting done. mode=%0d busy=%0d", mode_sel, busy);
                $finish;
            end
        end
    endtask

    task check_result;
        begin
            err = 0;
            for (i = 0; i < 256; i = i + 1) begin
                @(negedge clk);
                ext_we = 1'b0;
                ext_addr = i[7:0];
                #1;
                got = ext_dout;

                if (got !== vec_exp[i]) begin
                    $display("[MISMATCH] idx=%0d got=%0d exp=%0d", i, got, vec_exp[i]);
                    err = err + 1;
                end
            end

            if (err == 0)
                $display("[PASS] ntt_core_top verify passed (mode=%0d)", mode_sel);
            else
                $display("[FAIL] ntt_core_top verify failed (mode=%0d) errors=%0d", mode_sel, err);
        end
    endtask

    initial begin
        if (!$value$plusargs("MODE=%d", mode_sel))
            mode_sel = 0;

        if (!$value$plusargs("IN_MEM=%s", in_mem))
            in_mem = "sp_code/build/case_mode0_seed1_in.mem";

        if (!$value$plusargs("EXP_MEM=%s", exp_mem))
            exp_mem = "sp_code/build/case_mode0_seed1_exp.mem";

        $display("[TB] MODE    = %0d", mode_sel);
        $display("[TB] IN_MEM  = %0s", in_mem);
        $display("[TB] EXP_MEM = %0s", exp_mem);

        $readmemh(in_mem, vec_in);
        $readmemh(exp_mem, vec_exp);

        do_reset();
        load_input_mem();
        start_core();
        wait_done_or_timeout();
        check_result();

        $finish;
    end

endmodule
