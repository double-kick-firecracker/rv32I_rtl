`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ControlUnit(
    input rst,
    input clk,
    input zero,
    input [6:0] opcode,
    input [6:0] Funct7,
    input [2:0] Funct3,
    input [4:0] id_rs1, id_rs2, id_rd,
    input ID_Branch_Taken,

    output reg PCWrite,
    output reg InsMemRW,
    output reg IRWrite,
    output reg RFWrite, mem_RFWrite,
    output reg DMCtrl,
    output reg ExtSel,
    output reg ALUSrcA,
    output reg [1:0] ALUSrcB,
    output reg [1:0] RegSel,
    output reg [1:0] mem_WDSel,
    output reg [1:0] NPCOp,
    output reg [1:0] WDSel,
    output reg [3:0] ALUOp,
    output reg [4:0] ex_rs1, ex_rs2, wb_rd,
    output StallF, StallD, FlushD, FlushE,
    output reg [4:0] mem_rd
);
    reg id_RFWrite, id_DMCtrl, id_ALUSrcA;
    reg [1:0] id_ALUSrcB, id_RegSel, id_WDSel;
    reg [3:0] id_ALUOp;
    reg ex_RFWrite;
    reg [1:0] ex_WDSel;
    reg [1:0] mem_RegSel, ex_RegSel;
    reg [4:0] ex_rd;

    wire ID_is_Branch = (opcode == `INSTR_BTYPE_OP);
    wire ID_is_JALR   = (opcode == `INSTR_JALR_OP);
    wire ID_is_JAL    = (opcode == `INSTR_JAL_OP);

    wire id_reads_rs1 = !ID_is_JAL;
    wire id_reads_rs2 = (opcode == `INSTR_RTYPE_OP) || (opcode == `INSTR_SW_OP) || ID_is_Branch;

    wire ex_is_load  = (ex_WDSel == `WDSel_FromMEM);
    wire mem_is_load = (mem_WDSel == `WDSel_FromMEM);
    wire mem_is_link  = mem_RFWrite && (mem_WDSel == `WDSel_FromPC);

    wire load_use_stall = ex_is_load && (ex_rd != 5'd0) &&
                          ((id_reads_rs1 && (ex_rd == id_rs1)) ||
                           (id_reads_rs2 && (ex_rd == id_rs2)));

    wire id_npc_needs_rs1 = ID_is_Branch || ID_is_JALR;
    wire id_npc_needs_rs2 = ID_is_Branch;

    wire npc_stall = (ID_is_Branch || ID_is_JALR) &&
                     (
                         (ex_RFWrite && (ex_rd != 5'd0) &&
                          ((id_npc_needs_rs1 && (ex_rd == id_rs1)) ||
                           (id_npc_needs_rs2 && (ex_rd == id_rs2)))) ||
                         (mem_is_load && (mem_rd != 5'd0) &&
                          ((id_npc_needs_rs1 && (mem_rd == id_rs1)) ||
                           (id_npc_needs_rs2 && (mem_rd == id_rs2)))) ||
                         (mem_is_link && (mem_rd != 5'd0) &&
                          ((id_npc_needs_rs1 && (mem_rd == id_rs1)) ||
                           (id_npc_needs_rs2 && (mem_rd == id_rs2))))
                     );

    wire Stall_Global = load_use_stall || npc_stall;

    always @(*) begin
        PCWrite  = 1'b1;
        InsMemRW = 1'b1;
        IRWrite  = 1'b1;
        id_RFWrite = 1'b0;
        id_DMCtrl  = `DMCtrl_RD;
        id_ALUSrcA = `ALUSrcA_A;
        id_ALUSrcB = `ALUSrcB_B;
        id_RegSel  = `RegSel_rd;
        id_WDSel   = `WDSel_FromALU;
        NPCOp      = `NPC_PC;
        ExtSel     = `ExtSel_SIGNED;
        id_ALUOp   = `ALUOp_ADD;

        case (opcode)
            `INSTR_RTYPE_OP: begin
                id_RFWrite = 1'b1;
                case (Funct3)
                    3'b000: id_ALUOp = (Funct7[5]) ? `ALUOp_SUB : `ALUOp_ADD;
                    3'b001: id_ALUOp = `ALUOp_SLL;
                    3'b100: id_ALUOp = `ALUOp_XOR;
                    3'b101: id_ALUOp = (Funct7[5]) ? `ALUOp_SRA : `ALUOp_SRL;
                    3'b110: id_ALUOp = `ALUOp_OR;
                    3'b111: id_ALUOp = `ALUOp_AND;
                    default: id_ALUOp = `ALUOp_ADD;
                endcase
            end
            `INSTR_ITYPE_OP: begin
                id_RFWrite = 1'b1;
                id_ALUSrcB = `ALUSrcB_Imm;
                case (Funct3)
                    `INSTR_ADDI_FUNCT: id_ALUOp = `ALUOp_ADD;
                    `INSTR_ORI_FUNCT:  id_ALUOp = `ALUOp_OR;
                    default: id_ALUOp = `ALUOp_ADD;
                endcase
            end
            `INSTR_LW_OP: begin
                id_RFWrite = 1'b1;
                id_ALUSrcB = `ALUSrcB_Imm;
                id_WDSel   = `WDSel_FromMEM;
                id_ALUOp   = `ALUOp_ADD;
            end
            `INSTR_SW_OP: begin
                id_DMCtrl  = `DMCtrl_WR;
                id_ALUSrcB = `ALUSrcB_Offset;
                id_ALUOp   = `ALUOp_ADD;
            end
            `INSTR_BTYPE_OP: begin
                NPCOp    = `NPC_Offset12;
                id_ALUOp = `ALUOp_SUB;
            end
            `INSTR_JAL_OP: begin
                id_RFWrite = 1'b1;
                id_WDSel   = `WDSel_FromPC;
                NPCOp      = `NPC_Offset20;
                id_ALUOp   = `ALUOp_ADD;
            end
            `INSTR_JALR_OP: begin
                id_RFWrite = 1'b1;
                id_WDSel   = `WDSel_FromPC;
                NPCOp      = `NPC_rs;
                id_ALUSrcB = `ALUSrcB_Imm;
                id_ALUOp   = `ALUOp_ADD;
            end
            default: ;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ALUOp <= 0;
            ALUSrcB <= 0;
            ex_WDSel <= 0;
            ex_RegSel <= 0;
            ALUSrcA <= 0;
            DMCtrl <= 0;
            ex_RFWrite <= 0;
            ex_rs1 <= 0;
            ex_rs2 <= 0;
            ex_rd <= 0;
        end else if (FlushE) begin
            ALUOp <= 0;
            ALUSrcB <= 0;
            ex_WDSel <= 0;
            ex_RegSel <= 0;
            ALUSrcA <= 0;
            DMCtrl <= 0;
            ex_RFWrite <= 0;
            ex_rs1 <= 0;
            ex_rs2 <= 0;
            ex_rd <= 0;
        end else begin
            ALUOp <= id_ALUOp;
            ALUSrcB <= id_ALUSrcB;
            ex_WDSel <= id_WDSel;
            ex_RegSel <= id_RegSel;
            ALUSrcA <= id_ALUSrcA;
            DMCtrl <= id_DMCtrl;
            ex_RFWrite <= id_RFWrite;
            ex_rs1 <= id_rs1;
            ex_rs2 <= id_rs2;
            ex_rd <= id_rd;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_RFWrite <= 0;
            mem_WDSel   <= 0;
            mem_rd      <= 5'b0;
            mem_RegSel  <= 0;
        end else begin
            mem_RFWrite <= ex_RFWrite;
            mem_WDSel   <= ex_WDSel;
            mem_rd      <= ex_rd;
            mem_RegSel  <= ex_RegSel;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RFWrite <= 0;
            RegSel  <= 0;
            wb_rd   <= 5'b0;
            WDSel   <= 0;
        end else begin
            RFWrite <= mem_RFWrite;
            RegSel  <= mem_RegSel;
            wb_rd   <= mem_rd;
            WDSel   <= mem_WDSel;
        end
    end

    assign StallF = Stall_Global;
    assign StallD = Stall_Global;
    assign FlushE = Stall_Global;
    assign FlushD = ID_Branch_Taken && !Stall_Global;
endmodule
