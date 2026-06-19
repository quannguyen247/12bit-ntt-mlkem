`timescale 1ns / 1ps

module tb_ntt_core_top;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n;
    reg start;
    reg mode;

    wire busy;
    wire done;

    ntt_core_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .mode(mode),
        .busy(busy),
        .done(done)
    );

    initial begin
        $display("[TB] tb_ntt_core_top starting");
        // reset
        rst_n = 0;
        start = 0;
        mode  = 0; // 0 = NTT, 1 = INTT

        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // choose mode and start the core
        mode = 1'b0;
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // wait for completion
        wait (done == 1'b1);
        $display("[TB] ntt_core_top done at time %0t", $time);
        $finish;
    end

endmodule
