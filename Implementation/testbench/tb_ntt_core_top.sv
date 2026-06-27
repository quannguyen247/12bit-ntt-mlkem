`timescale 1ns / 1ps

module tb_ntt_core_top;

    localparam integer CLK_PERIOD_NS = 5;
    localparam integer TIMEOUT_CYCLES = 30000;
    localparam integer MAX_BUFFER = 1024;

    typedef struct packed {
        logic [255:0][11:0] intt;
        logic [255:0][11:0] ntt;
        logic [255:0][11:0] poly;
    } test_vector_t;

    logic clk;
    logic rst_n;
    logic start;
    logic mode;
    logic ext_we;
    logic [7:0] ext_addr;
    logic [11:0] ext_din;
    logic [11:0] ext_dout;
    logic busy;
    logic done;

    test_vector_t vec_all [0:MAX_BUFFER-1];
    logic [639:0] line_buffer;

    int tv_count_actual;
    int case_idx;
    int ntt_error_count;
    int intt_error_count;
    int roundtrip_error_count;
    int ntt_report_fd;
    int intt_report_fd;
    int spec_fd;
    logic timeout_flag;

    string tb_file;
    string tb_dir;
    string tv_dir;
    string ntt_report_path;
    string intt_report_path;

    function automatic string dirname(string path);
        for (int i = path.len() - 1; i >= 0; i--)
            if (path[i] == "/" || path[i] == "\\")
                return path.substr(0, i - 1);
        return ".";
    endfunction

    ntt_core_top u_dut (
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

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS / 2) clk = ~clk;
    end

    task automatic wait_for_done();
    begin
        timeout_flag = 1'b0;
        fork : wait_block
            begin
                wait (done == 1'b1);
                disable wait_block;
            end
            begin
                repeat (TIMEOUT_CYCLES) @(posedge clk);
                timeout_flag = 1'b1;
                disable wait_block;
            end
        join
    end
    endtask

    task automatic load_polynomial(input logic [255:0][11:0] poly);
    begin
        for (int j = 0; j < 256; j++) begin
            @(posedge clk); #0.5;
            ext_we = 1'b1;
            ext_addr = j[7:0];
            ext_din = poly[j];
        end
        @(posedge clk); #0.5;
        ext_we = 1'b0;
    end
    endtask

    task automatic read_polynomial(output logic [255:0][11:0] poly);
    begin
        for (int j = 0; j < 256; j++) begin
            @(posedge clk); #0.5;
            ext_addr = j[7:0];
            #0.5;
            poly[j] = ext_dout;
        end
    end
    endtask

    task automatic run_pass(
        input integer idx,
        input logic pass_mode,
        input logic [255:0][11:0] in_poly,
        input logic [255:0][11:0] exp_poly,
        output logic pass,
        input int report_fd
    );
    begin
        logic [255:0][11:0] result_poly;
        string mode_str;
        int mismatch_count;

        mode_str = pass_mode ? "INTT" : "NTT";
        mismatch_count = 0;

        @(posedge clk); #0.5;
        rst_n = 1'b0; start = 1'b0; mode = pass_mode;
        ext_we = 1'b0; ext_addr = 8'd0; ext_din = 12'd0;
        repeat (5) @(posedge clk); #0.5;
        rst_n = 1'b1;
        repeat (2) @(posedge clk); #0.5;

        load_polynomial(in_poly);

        @(posedge clk); #0.5; start = 1'b1;
        @(posedge clk); #0.5; start = 1'b0;

        wait_for_done();

        pass = 1'b1;

        if (timeout_flag) begin
            $display("[%0t] FAIL: Case %0d - %s TIMEOUT", $time, idx + 1, mode_str);
            if (report_fd != 0)
                $fwrite(report_fd, "Case %0d | FAIL (TIMEOUT)\n", idx + 1);
            pass = 1'b0;
        end else begin
            read_polynomial(result_poly);

            for (int j = 0; j < 256; j++) begin
                if (result_poly[j] !== exp_poly[j]) begin
                    if (mismatch_count < 10)
                        $display("[%0t] FAIL: Case %0d - %s coeff[%0d] exp=%03h got=%03h",
                                 $time, idx + 1, mode_str, j, exp_poly[j], result_poly[j]);
                    if (report_fd != 0)
                        $fwrite(report_fd, "  coeff[%0d] exp=%03h got=%03h\n",
                                j, exp_poly[j], result_poly[j]);
                    mismatch_count++;
                    pass = 1'b0;
                end
            end

            if (report_fd != 0) begin
                if (pass)
                    $fwrite(report_fd, "Case %0d | PASS\n", idx + 1);
                else
                    $fwrite(report_fd, "Case %0d | FAIL (%0d mismatches)\n", idx + 1, mismatch_count);
            end

            if (mismatch_count > 10)
                $display("[%0t] ... and %0d more mismatches (Case %0d %s)",
                         $time, mismatch_count - 10, idx + 1, mode_str);
        end
    end
    endtask

    task automatic run_roundtrip_test(input integer idx);
    begin
        logic [255:0][11:0] ntt_result, intt_result;
        logic pass;
        int mismatch_count;

        @(posedge clk); #0.5;
        rst_n = 1'b0; start = 1'b0; mode = 1'b0;
        ext_we = 1'b0; ext_addr = 8'd0; ext_din = 12'd0;
        repeat (5) @(posedge clk); #0.5;
        rst_n = 1'b1;
        repeat (2) @(posedge clk); #0.5;

        load_polynomial(vec_all[idx].poly);
        @(posedge clk); #0.5; start = 1'b1;
        @(posedge clk); #0.5; start = 1'b0;
        wait_for_done();
        if (timeout_flag) begin
            $display("[%0t] ROUNDTRIP FAIL: Case %0d - NTT timeout", $time, idx + 1);
            roundtrip_error_count++;
            return;
        end
        read_polynomial(ntt_result);

        @(posedge clk); #0.5;
        rst_n = 1'b0; mode = 1'b1;
        repeat (5) @(posedge clk); #0.5;
        rst_n = 1'b1;
        repeat (2) @(posedge clk); #0.5;

        load_polynomial(ntt_result);
        @(posedge clk); #0.5; start = 1'b1;
        @(posedge clk); #0.5; start = 1'b0;
        wait_for_done();
        if (timeout_flag) begin
            $display("[%0t] ROUNDTRIP FAIL: Case %0d - INTT timeout", $time, idx + 1);
            roundtrip_error_count++;
            return;
        end
        read_polynomial(intt_result);

        pass = 1'b1;
        mismatch_count = 0;
        for (int j = 0; j < 256; j++) begin
            if (intt_result[j] !== vec_all[idx].intt[j]) begin
                if (mismatch_count < 5)
                    $display("[%0t] ROUNDTRIP FAIL: Case %0d coeff[%0d] exp=%03h got=%03h",
                             $time, idx + 1, j, vec_all[idx].intt[j], intt_result[j]);
                mismatch_count++;
                pass = 1'b0;
            end
        end
        if (!pass) roundtrip_error_count++;
    end
    endtask

    task automatic run_one_case(input integer idx);
    begin
        logic pass;

        run_pass(idx, 1'b0, vec_all[idx].poly, vec_all[idx].ntt, pass, ntt_report_fd);
        if (!pass) ntt_error_count++;

        run_pass(idx, 1'b1, vec_all[idx].ntt, vec_all[idx].intt, pass, intt_report_fd);
        if (!pass) intt_error_count++;

        run_roundtrip_test(idx);

        repeat (2) @(posedge clk);
    end
    endtask

    initial begin
        tb_file = `__FILE__;
        tb_dir = dirname(tb_file);
        tv_dir = {dirname(tb_dir), "/vector"};
        ntt_report_path = {tb_dir, "/ntt_result.log"};
        intt_report_path = {tb_dir, "/intt_result.log"};

        ntt_error_count = 0;
        intt_error_count = 0;
        roundtrip_error_count = 0;
        rst_n = 0; start = 0; mode = 0; ext_we = 0; ext_addr = 0; ext_din = 0;

        ntt_report_fd = $fopen(ntt_report_path, "w");
        intt_report_fd = $fopen(intt_report_path, "w");
        spec_fd = $fopen({tv_dir, "/tv_spec.txt"}, "r");

        if (spec_fd == 0) begin
            $display("ERROR: Cannot open %s/tv_spec.txt", tv_dir);
            $finish;
        end

        void'($fgets(line_buffer, spec_fd));
        void'($sscanf(line_buffer, "tv_count=%d", tv_count_actual));
        $fclose(spec_fd);

        if (tv_count_actual > MAX_BUFFER) begin
            $display("ERROR: tv_count=%0d exceeds MAX_BUFFER=%0d", tv_count_actual, MAX_BUFFER);
            $finish;
        end

        $readmemh({tv_dir, "/tv_all.mem"}, vec_all);
        $display("NTT/INTT Core Testbench — %0d test vectors loaded", tv_count_actual);

        #100;
        @(posedge clk); #0.5; rst_n = 1'b1;
        repeat (5) @(posedge clk);

        for (case_idx = 0; case_idx < tv_count_actual; case_idx++) begin
            $display("Case %0d / %0d", case_idx + 1, tv_count_actual);
            run_one_case(case_idx);
        end

        $display(">>> NTT PASSED: %0d/%0d CASES (%0d ERRORS)",
                tv_count_actual - ntt_error_count, tv_count_actual, ntt_error_count);
        $display(">>> INTT PASSED: %0d/%0d CASES (%0d ERRORS)",
                tv_count_actual - intt_error_count, tv_count_actual, intt_error_count);
        $display(">>> ROUNDTRIP: %0d/%0d CASES (%0d ERRORS)",
                tv_count_actual - roundtrip_error_count, tv_count_actual, roundtrip_error_count);

        if (ntt_error_count == 0 && intt_error_count == 0 && roundtrip_error_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        if (ntt_report_fd != 0) $fclose(ntt_report_fd);
        if (intt_report_fd != 0) $fclose(intt_report_fd);
        #100;
        $finish;
    end

endmodule