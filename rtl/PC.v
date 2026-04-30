`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
module PC(clk, rst, PCWrite, StallF, NPC, PC, FlushD, StallD, FlushE, id_PC, ex_PC);
    input         clk;
    input         rst;
    input         PCWrite;
    input         StallF;
    input         FlushD;
    input         StallD;
    input         FlushE;
    input  [31:0] NPC;
    output reg [31:0] PC;
    output [31:0] id_PC;
    output [31:0] ex_PC;

    always @(posedge clk or posedge rst) begin
        if (rst)
            PC <= 32'h0000_1FFC;
        else if (StallF)
            PC <= PC;
        else if (PCWrite)
            PC <= NPC;
    end

    Flopr U_IF_ID_PC (
        .clk(clk), .rst(rst), .in_data(PC), .out_data(id_PC), .CLR(FlushD), .Stall(StallD)
    );

    Flopr U_ID_EX_PC (
        .clk(clk), .rst(rst), .in_data(id_PC), .out_data(ex_PC), .CLR(FlushE), .Stall(1'b0)
    );
endmodule