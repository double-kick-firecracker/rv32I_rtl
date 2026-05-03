`include "ctrl_signal_def.v"
module EXT(imm_in, ExtSel, imm_out,FlushE,ex_imm32,Offset20,Offset,ex_Offset,ex_Offset20,
            clk,rst);    //鎼炰簡鍗婂ぉ鍏跺疄鍙嫇灞曚簡itype
    input  [11:0]  imm_in;    // 杈撳叆鐨�12浣嶇珛鍗虫暟
    input          ExtSel,FlushE,clk,rst;    // 鎵╁睍閫夋嫨鎺у埗淇″彿
    output reg [31:0] imm_out; // 杈撳嚭鐨�32浣嶆墿灞曞悗绔嬪嵆鏁�
    output [31:0] ex_imm32;
    input  [19:0] Offset20;
    input  [11:0] Offset;
    output reg [11:0] ex_Offset;
    output reg [19:0] ex_Offset20;
    
    always @(imm_in or ExtSel) begin
        case(ExtSel)
            `ExtSel_ZERO:   imm_out = {20'b0, imm_in[11:0]};        // 闆舵墿灞曚负32浣�
            `ExtSel_SIGNED: imm_out = {{20{imm_in[11]}}, imm_in[11:0]};  // 绗﹀彿鎵╁睍涓�32浣�
            default:        imm_out = 32'b0;                       // 榛樿杈撳嚭0
        endcase
    end
    
     Flopr U_IDEX_IMM  ( .clk(clk), .rst(rst), .in_data(imm_out),.out_data(ex_imm32) ,.CLR(FlushE), .Stall(1'b0));
     
     always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_Offset   <= 0;
            ex_Offset20<=0;
        end else if (FlushE) begin
            ex_Offset   <= 0;
            ex_Offset20<=0;
        end   
        else begin
            ex_Offset   <= Offset;
            ex_Offset20 <= Offset20;
        end
    end
endmodule