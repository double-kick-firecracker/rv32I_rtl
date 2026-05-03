`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
module PC(clk, rst, PCWrite,StallF, NPC, PC,FlushD,StallD,FlushE,id_PC);
    input         clk,FlushD,StallD,FlushE;        //鏃堕挓淇″彿
    input         rst;        //澶嶄綅淇″彿
    input         PCWrite;    //PC鍐欎娇鑳戒俊鍙�
    input  [31:0] NPC;        //涓嬫潯鎸囦护鐨勫湴鍧�
    input         StallF;
    output reg [31:0] PC;      //鏈潯鎸囦护鍦板潃,PC鏈韩鍙互鐪嬩綔IF_PC
    wire [31:0] ex_PC;    //PC鍦↖D闃舵鐢ㄤ笉鍒帮紝EXE鎵嶉渶瑕�
    output [31:0] id_PC;
    
    always @(posedge clk or posedge rst) begin
        // reset
        if (rst) begin
            PC <= 32'h0000_1FFC;  //澶嶄綅鍚嶱C鐨勫��
        end
        else if (StallF)
            PC <= PC;
        else if (PCWrite) begin
            PC <= NPC;            //淇敼鎸囦护鍦板潃
        end
    end
    
    Flopr U_IF_ID_PC (.clk(clk), .rst(rst), .in_data(PC), .out_data(id_PC), .CLR(FlushD), .Stall(StallD) ); 
    
endmodule
