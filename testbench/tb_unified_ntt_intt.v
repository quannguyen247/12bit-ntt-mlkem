`timescale 1ns / 1ps

module tb_unified_ntt_intt;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n;
    reg start;
    reg mode;
    reg valid_i;
    reg [11:0] d_i0;
    reg [11:0] d_i1;

    wire [11:0] d_o0;
    wire [11:0] d_o1;
    wire busy;
    wire done;
    wire valid_o;

    unified_ntt_intt dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mode(mode),
        .valid_i(valid_i),
        .d_i0(d_i0),
        .d_i1(d_i1),
        .d_o0(d_o0),
        .d_o1(d_o1),
        .busy(busy),
        .done(done),
        .valid_o(valid_o)
    );

    reg [11:0] vec_in   [0:255];
    reg [11:0] ref_ntt  [0:255];
    reg [11:0] ref_intt [0:255];

    reg [11:0] cur [0:255];
    reg [11:0] nxt [0:255];

    reg [1023:0] in_mem;
    reg [1023:0] ntt_mem;
    reg [1023:0] intt_mem;

    integer i;
    integer j;
    integer base;
    integer len;
    integer err;

    task reset_dut;
        begin
            rst_n   = 0;
            start   = 0;
            mode    = 0;
            valid_i = 0;
            d_i0    = 0;
            d_i1    = 0;

            repeat (10) @(posedge clk);
            rst_n = 1;
            repeat (5) @(posedge clk);
        end
    endtask

    task start_core;
        input mode_i;
        begin
            @(negedge clk);
            mode    = mode_i;
            start   = 1;
            valid_i = 0;

            @(negedge clk);
            start = 0;
        end
    endtask

    task feed_pair;
    input  [11:0] in0;
    input  [11:0] in1;
    output [11:0] out0;
    output [11:0] out1;

    integer wait_cnt;
    begin
        wait_cnt = 0;

        // Cycle N: drive input
        @(negedge clk);
        valid_i = 1'b1;
        d_i0    = in0;
        d_i1    = in1;

        // Posedge N: DUT accepts input
        @(posedge clk);
        #1;

        // Stop driving, otherwise DUT may accept same pair again
        @(negedge clk);
        valid_i = 1'b0;
        d_i0    = 12'd0;
        d_i1    = 12'd0;

        // Cycle N+1 or later: wait for pipelined output
        while (!valid_o) begin
            @(posedge clk);
            #1;

            wait_cnt = wait_cnt + 1;
            if (wait_cnt > 20) begin
                $display("[FAIL] timeout waiting valid_o in feed_pair at time %0t", $time);
                $display("       in0=%0d in1=%0d mode=%0d busy=%0d done=%0d",
                         in0, in1, mode, busy, done);
                $finish;
            end
        end

        out0 = d_o0;
        out1 = d_o1;
    end
endtask

    task stop_feed;
        begin
            @(negedge clk);
            valid_i = 0;
            d_i0    = 0;
            d_i1    = 0;
        end
    endtask

    task run_ntt_stream;
        reg [11:0] o0;
        reg [11:0] o1;
        begin
            for (i = 0; i < 256; i = i + 1)
                cur[i] = vec_in[i];

            start_core(1'b0);

            for (len = 128; len >= 2; len = len >> 1) begin
                for (base = 0; base < 256; base = base + (2 * len)) begin
                    for (j = base; j < base + len; j = j + 1) begin
                        feed_pair(cur[j], cur[j + len], o0, o1);
                        nxt[j]       = o0;
                        nxt[j + len] = o1;
                    end
                end

                for (i = 0; i < 256; i = i + 1)
                    cur[i] = nxt[i];
            end

            stop_feed();
        end
    endtask

    task run_intt_stream;
        reg [11:0] o0;
        reg [11:0] o1;
        begin
            // Test INTT độc lập bằng ref_ntt làm input.
            for (i = 0; i < 256; i = i + 1)
                cur[i] = ref_ntt[i];

            start_core(1'b1);

            for (len = 2; len <= 128; len = len << 1) begin
                for (base = 0; base < 256; base = base + (2 * len)) begin
                    for (j = base; j < base + len; j = j + 1) begin
                        feed_pair(cur[j], cur[j + len], o0, o1);
                        nxt[j]       = o0;
                        nxt[j + len] = o1;
                    end
                end

                for (i = 0; i < 256; i = i + 1)
                    cur[i] = nxt[i];
            end

            // Final scale, area-optimized core: 1 coefficient/cycle on d_i0.
            for (i = 0; i < 256; i = i + 1) begin
                feed_pair(cur[i], 12'd0, o0, o1);
                nxt[i] = o0;
            end

            for (i = 0; i < 256; i = i + 1)
                cur[i] = nxt[i];

            stop_feed();
        end
    endtask

    task check_ntt;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                if (cur[i] !== ref_ntt[i]) begin
                    $display("[NTT FAIL] i=%0d got=%0d exp=%0d",
                             i, cur[i], ref_ntt[i]);
                    err = err + 1;
                end
            end
        end
    endtask

    task check_intt;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                if (cur[i] !== ref_intt[i]) begin
                    $display("[INTT FAIL] i=%0d got=%0d exp=%0d",
                             i, cur[i], ref_intt[i]);
                    err = err + 1;
                end
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("IN_MEM=%s", in_mem))
            in_mem = "build/vec_in.mem";

        if (!$value$plusargs("NTT_MEM=%s", ntt_mem))
            ntt_mem = "build/vec_ntt.mem";

        if (!$value$plusargs("INTT_MEM=%s", intt_mem))
            intt_mem = "build/vec_intt.mem";

        $display("[TB] IN_MEM   = %0s", in_mem);
        $display("[TB] NTT_MEM  = %0s", ntt_mem);
        $display("[TB] INTT_MEM = %0s", intt_mem);

        $readmemh(in_mem,   vec_in);
        $readmemh(ntt_mem,  ref_ntt);
        $readmemh(intt_mem, ref_intt);

        err = 0;

        reset_dut();

        $display("[TB] run streaming NTT");
        run_ntt_stream();
        check_ntt();

        $display("[TB] run streaming INTT");
        run_intt_stream();
        check_intt();

        if (err == 0)
            $display("[PASS] unified_ntt_intt streaming core passed");
        else
            $display("[FAIL] total errors = %0d", err);

        $finish;
    end

endmodule