`include "ctrl_signal_def.v"

module MUX_3to1_B(X, Y, Z, control, out, mem_ALU_result, wb_WD, ex_rs2, mem_rd, wb_rd,
                  mem_RFWrite, wb_RFWrite, Y_2, Z_2, Forwarded_Data, clk, rst);
    input  signed [31:0] X;
    input  signed [31:0] Y, Y_2;
    input         [11:0] Z, Z_2;
    input         [1:0]  control;
    output reg signed [31:0] out;
    input clk, rst;
    input [31:0] mem_ALU_result;
    input [31:0] wb_WD;
    input [4:0] ex_rs2, mem_rd, wb_rd;
    input mem_RFWrite, wb_RFWrite;
    output [31:0] Forwarded_Data;

    wire [1:0] ForwardB;
    assign ForwardB = (mem_RFWrite && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) ? 2'b10 :
                      (wb_RFWrite  && (wb_rd != 5'd0)  && (wb_rd == ex_rs2))  ? 2'b01 :
                                                                                 2'b00;

    assign Forwarded_Data = (ForwardB == 2'b10) ? mem_ALU_result :
                            (ForwardB == 2'b01) ? wb_WD :
                                                   X;

    always @(*) begin
        case (control)
            `ALUSrcB_B      : out = Forwarded_Data;
            `ALUSrcB_Imm    : out = Y_2;
            `ALUSrcB_Offset : out = {{20{Z_2[11]}}, Z_2};
            `ALUSrcB_else   : out = Forwarded_Data;
            default         : out = 32'b0;
        endcase
    end
endmodule
