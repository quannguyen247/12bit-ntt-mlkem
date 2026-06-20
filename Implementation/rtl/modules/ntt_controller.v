`timescale 1ns / 1ps
`include "ntt_defs.vh"

module ntt_controller (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire mode,
    input wire advance,
    output reg [1:0] state,
    output reg busy,
    output reg done,
    output reg [7:0] len,
    output reg [7:0] pos,
    output reg [7:0] zidx,
    output reg [7:0] cnt
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_RUN = 2'd1;
    localparam [1:0] ST_SCALE = 2'd2;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            len <= 8'd0;
            pos <= 8'd0;
            zidx <= 8'd0;
            cnt <= 8'd0;
        end else begin
            done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        state <= ST_RUN;
                        len <= mode ? 8'd2 : 8'd128;
                        zidx <= mode ? 8'd0 : 8'd1;
                        pos <= 8'd0;
                        cnt <= 8'd0;
                    end
                end
                ST_RUN: begin
                    if (advance) begin
                        if (pos == (len - 8'd1)) begin
                            pos <= 8'd0;
                            zidx <= zidx + 8'd1;
                        end else begin
                            pos <= pos + 8'd1;
                        end

                        if (cnt == 8'd127) begin
                            cnt <= 8'd0;
                            pos <= 8'd0;
                            if (!mode) begin
                                if (len == 8'd2) begin
                                    done <= 1'b1;
                                    busy <= 1'b0;
                                    state <= ST_IDLE;
                                end else begin
                                    len <= len >> 1;
                                end
                            end else begin
                                if (len == 8'd128) begin
                                    state <= ST_SCALE;
                                end else begin
                                    len <= len << 1;
                                end
                            end
                        end else begin
                            cnt <= cnt + 8'd1;
                        end
                    end
                end
                ST_SCALE: begin
                    if (advance) begin
                        if (cnt == 8'd255) begin
                            done <= 1'b1;
                            busy <= 1'b0;
                            state <= ST_IDLE;
                        end else begin
                            cnt <= cnt + 8'd1;
                            pos <= pos + 8'd1;
                        end
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule