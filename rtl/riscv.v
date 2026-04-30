`timescale 1ns / 1ps

module riscv(clk, rst);
    input clk, rst;

    wire RFWrite, DMCtrl, PCWrite, IRWrite, InsMemRW, ExtSel, zero, ALUSrcA;
    wire [1:0] ALUSrcB;
    wire [1:0] NPCOp, WDSel, RegSel;
    wire [3:0] ALUOp;
    wire [6:0] opcode;
    wire [2:0] Funct3;
    wire [6:0] Funct7;
    wire [31:0] PC, NPC, PCA4;
    wire [31:0] in_ins, out_ins, RD;
    wire [4:0] rs1, rs2, rd, wb_rd;
    wire [11:0] Imm12;
    wire [31:0] Imm32, ex_imm32;
    wire [20:1] Offset20, ex_Offset20;
    wire [11:0] Offset, ex_Offset;
    wire [4:0] WR;
    wire [31:0] WD;
    wire [31:0] RD1, RD1_r, RD2, RD2_r, ex_RD2;
    wire [31:0] A, B, ALU_result, ALU_result_r;
    wire [31:0] id_PC, ex_PC;
    wire StallF, StallD, FlushE, FlushD;
    wire [4:0] ex_rs1, ex_rs2, mem_rd;
    wire EX_Jump_Taken;
    wire mem_RFWrite;
    wire Funct3_0;

    assign opcode   = out_ins[6:0];
    assign Funct3   = out_ins[14:12];
    assign Funct7   = out_ins[31:25];
    assign rs1      = out_ins[19:15];
    assign rs2      = out_ins[24:20];
    assign rd       = out_ins[11:7];
    assign Imm12    = out_ins[31:20];
    assign Offset20 = {out_ins[31], out_ins[19:12], out_ins[20], out_ins[30:21]};
    assign Offset   = (opcode == `INSTR_BTYPE_OP) ? {out_ins[31], out_ins[7], out_ins[30:25], out_ins[11:8]} :
                      (opcode == `INSTR_SW_OP)   ? {out_ins[31:25], out_ins[11:7]} : Imm12;

    PC U_PC (
        .clk(clk), .rst(rst), .PCWrite(PCWrite), .NPC(NPC), .PC(PC),
        .FlushD(FlushD), .StallD(StallD), .StallF(StallF), .FlushE(FlushE), .id_PC(id_PC), .ex_PC(ex_PC)
    );

    IM U_IM (
        .addr(PC[11:2]), .Ins(in_ins), .InsMemRW(InsMemRW), .clk(clk), .addr_2(NPC[11:2])
    );

    IR U_IR (
        .clk(clk), .IRWrite(IRWrite), .in_ins(in_ins), .out_ins(out_ins),
        .flush(FlushD), .stall(StallD), .rst(rst)
    );

    ControlUnit U_ControlUnit(
        .clk(clk), .rst(rst), .zero(zero), .opcode(opcode), .Funct7(Funct7), .Funct3(Funct3),
        .RFWrite(RFWrite), .DMCtrl(DMCtrl), .PCWrite(PCWrite), .IRWrite(IRWrite), .InsMemRW(InsMemRW),
        .ExtSel(ExtSel), .ALUOp(ALUOp), .NPCOp(NPCOp), .ALUSrcA(ALUSrcA), .mem_RFWrite(mem_RFWrite),
        .WDSel(WDSel), .ALUSrcB(ALUSrcB), .RegSel(RegSel), .id_rs1(rs1), .id_rs2(rs2), .id_rd(rd),
        .ex_rs1(ex_rs1), .ex_rs2(ex_rs2), .mem_rd(mem_rd), .EX_Jump_Taken(EX_Jump_Taken),
        .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE), .wb_rd(wb_rd),
        .Funct3_0(Funct3_0)
    );

    RF U_RF (
        .RR1(rs1), .RR2(rs2), .WR(WR), .WD(WD), .clk(clk),
        .RFWrite(RFWrite), .RD1(RD1), .RD2(RD2)
    );

    EXT U_EXT (
        .imm_in(Imm12), .ExtSel(ExtSel), .imm_out(Imm32), .FlushE(FlushE), .ex_imm32(ex_imm32),
        .Offset20(Offset20), .Offset(Offset), .ex_Offset(ex_Offset), .clk(clk), .rst(rst),
        .ex_Offset20(ex_Offset20)
    );

    Flopr U_A (
        .clk(clk), .rst(rst), .in_data(RD1), .out_data(RD1_r), .CLR(FlushE), .Stall(1'b0)
    );

    Flopr U_B (
        .clk(clk), .rst(rst), .in_data(RD2), .out_data(RD2_r), .CLR(FlushE), .Stall(1'b0)
    );

    MUX_2to1_A U_MUX_2to1_A (
        .X(RD1_r), .Y(5'h0), .control(ALUSrcA), .out(A), .mem_ALU_result(ALU_result_r),
        .wb_WD(WD), .ex_rs1(ex_rs1), .mem_rd(mem_rd), .wb_rd(wb_rd),
        .mem_RFWrite(mem_RFWrite), .wb_RFWrite(RFWrite)
    );

    MUX_3to1_B U_MUX_3to1_B (
        .X(RD2_r), .Y(Imm32), .Z(Offset), .control(ALUSrcB), .out(B), .mem_ALU_result(ALU_result_r),
        .wb_WD(WD), .ex_rs2(ex_rs2), .mem_rd(mem_rd), .wb_rd(wb_rd),
        .mem_RFWrite(mem_RFWrite), .wb_RFWrite(RFWrite), .Y_2(ex_imm32), .Z_2(ex_Offset),
        .Forwarded_Data(ex_RD2), .clk(clk), .rst(rst)
    );

    ALU U_ALU (
        .A(A), .B(B), .ALUOp(ALUOp), .ALU_result(ALU_result), .zero(zero)
    );

    NPC U_NPC (
        .PC(PC), .NPCOp(NPCOp), .ex_Offset(ex_Offset), .ex_Offset20(ex_Offset20),
        .ex_PC(ex_PC), .ex_RD1(RD1_r), .ex_RD2(RD2_r), .ex_rs1(ex_rs1), .ex_rs2(ex_rs2),
        .mem_ALU_result(ALU_result_r), .mem_rd(mem_rd), .wb_WD(WD), .wb_rd(wb_rd),
        .mem_RFWrite(mem_RFWrite), .wb_RFWrite(RFWrite), .ex_imm32(ex_imm32), .funct3_0(Funct3_0),
        .stallF(StallF), .clk(clk), .rst(rst), .EX_Jump_Taken(EX_Jump_Taken), .PCA4(PCA4), .NPC(NPC)
    );

    Flopr U_ALUOut (
        .clk(clk), .rst(rst), .in_data(ALU_result), .out_data(ALU_result_r), .CLR(1'b0), .Stall(1'b0)
    );

    DM U_DM (
        .Addr(ALU_result_r[11:2]), .WD(RD2_r), .DMCtrl(DMCtrl), .clk(clk), .RD(RD),
        .WD2(ex_RD2), .Addr_2(ALU_result[11:2])
    );

    MUX_3to1 U_MUX_3to1 (
        .X(rd), .Y(5'd0), .Z(5'd31), .control(RegSel), .out(WR), .wb_rd(wb_rd)
    );

    MUX_3to1_LMD U_MUX_3to1_LMD (
        .X(ALU_result_r), .Y(RD), .Z(PCA4), .control(WDSel), .out(WD), .clk(clk), .rst(rst)
    );
endmodule
