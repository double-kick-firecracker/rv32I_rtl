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
    input EX_Jump_Taken,

    output reg PCWrite,
    output reg InsMemRW,
    output reg IRWrite,
    output reg RFWrite, mem_RFWrite,
    output reg DMCtrl,
    output reg ExtSel,
    output reg ALUSrcA,
    output reg [1:0] ALUSrcB,
    output reg [1:0] RegSel,
    output reg [1:0] NPCOp,
    output reg [1:0] WDSel,
    output reg [3:0] ALUOp,
    output reg [4:0] ex_rs1, ex_rs2, wb_rd,
    output StallF, StallD, FlushD, FlushE,
    output reg [4:0] mem_rd,
    output reg Funct3_0
);
    reg id_RFWrite, id_DMCtrl, id_ALUSrcA;
    reg [1:0] id_ALUSrcB, id_RegSel, id_WDSel, id_NPCOp;
    reg [1:0] mem_WDSel, ex_WDSel;
    reg [3:0] id_ALUOp;
    reg ex_RFWrite;
    reg [1:0] ALU_category;
    reg [1:0] mem_RegSel, ex_RegSel;
    reg [4:0] ex_rd;

    always @(*) begin
        PCWrite     = 1'b1;
        InsMemRW    = 1'b1;
        IRWrite     = 1'b1;
        id_RFWrite  = 1'b0;
        id_DMCtrl   = `DMCtrl_RD;
        id_ALUSrcA  = `ALUSrcA_A;
        id_ALUSrcB  = `ALUSrcB_B;
        id_RegSel   = `RegSel_rd;
        id_WDSel    = `WDSel_FromALU;
        id_NPCOp    = `NPC_PC;
        ExtSel      = `ExtSel_SIGNED;
        ALU_category = 2'b00;

        case (opcode)
            `INSTR_RTYPE_OP: begin
                id_RFWrite  = 1'b1;
                ALU_category = 2'b10;
            end
            `INSTR_ITYPE_OP: begin
                id_RFWrite  = 1'b1;
                id_ALUSrcB  = `ALUSrcB_Imm;
                ALU_category = 2'b11;
            end
            `INSTR_LW_OP: begin
                id_RFWrite  = 1'b1;
                id_ALUSrcB  = `ALUSrcB_Imm;
                id_WDSel    = `WDSel_FromMEM;
                ALU_category = 2'b00;
            end
            `INSTR_SW_OP: begin
                id_DMCtrl   = `DMCtrl_WR;
                id_ALUSrcB  = `ALUSrcB_Offset;
                ALU_category = 2'b00;
            end
            `INSTR_BTYPE_OP: begin
                id_NPCOp    = `NPC_Offset12;
                ALU_category = 2'b01;
            end
            `INSTR_JAL_OP: begin
                id_RFWrite  = 1'b1;
                id_WDSel    = `WDSel_FromPC;
                id_NPCOp    = `NPC_Offset20;
            end
            `INSTR_JALR_OP: begin
                id_RFWrite  = 1'b1;
                id_WDSel    = `WDSel_FromPC;
                id_NPCOp    = `NPC_rs;
                id_ALUSrcB  = `ALUSrcB_Imm;
            end
            default: ;
        endcase
    end

    always @(*) begin
        id_ALUOp = `ALUOp_ADD;
        case (ALU_category)
            2'b00: id_ALUOp = `ALUOp_ADD;
            2'b01: id_ALUOp = `ALUOp_SUB;
            2'b10: begin
                case (Funct3)
                    3'b000: id_ALUOp = Funct7[5] ? `ALUOp_SUB : `ALUOp_ADD;
                    3'b001: id_ALUOp = `ALUOp_SLL;
                    3'b100: id_ALUOp = `ALUOp_XOR;
                    3'b101: id_ALUOp = Funct7[5] ? `ALUOp_SRA : `ALUOp_SRL;
                    3'b110: id_ALUOp = `ALUOp_OR;
                    3'b111: id_ALUOp = `ALUOp_AND;
                    default: id_ALUOp = `ALUOp_ADD;
                endcase
            end
            2'b11: begin
                case (Funct3)
                    `INSTR_ADDI_FUNCT: id_ALUOp = `ALUOp_ADD;
                    `INSTR_ORI_FUNCT:  id_ALUOp = `ALUOp_OR;
                    default: id_ALUOp = `ALUOp_ADD;
                endcase
            end
            default: id_ALUOp = `ALUOp_ADD;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ALUOp <= 0; ALUSrcB <= 0; ex_WDSel <= 0; ex_RegSel <= 0;
            ALUSrcA <= 0; DMCtrl <= 0; ex_RFWrite <= 0; NPCOp <= 0;
            ex_rs1 <= 0; ex_rs2 <= 0; ex_rd <= 0; Funct3_0 <= 0;
        end else if (FlushE) begin
            ALUOp <= 0; ALUSrcB <= 0; ex_WDSel <= 0; ex_RegSel <= 0;
            ALUSrcA <= 0; DMCtrl <= 0; ex_RFWrite <= 0; NPCOp <= 0;
            ex_rs1 <= 0; ex_rs2 <= 0; ex_rd <= 0; Funct3_0 <= 0;
        end else begin
            ALUOp <= id_ALUOp; ALUSrcB <= id_ALUSrcB;
            ex_WDSel <= id_WDSel; ex_RegSel <= id_RegSel; ALUSrcA <= id_ALUSrcA;
            DMCtrl <= id_DMCtrl; ex_RFWrite <= id_RFWrite; NPCOp <= id_NPCOp;
            ex_rs1 <= id_rs1; ex_rs2 <= id_rs2; ex_rd <= id_rd; Funct3_0 <= Funct3[0];
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

    wire id_reads_rs1 = (opcode != `INSTR_JAL_OP);
    wire id_reads_rs2 = (opcode == `INSTR_RTYPE_OP) ||
                        (opcode == `INSTR_SW_OP) ||
                        (opcode == `INSTR_BTYPE_OP);
    wire ex_is_load = (ex_WDSel == `WDSel_FromMEM);

    wire load_use_stall = ex_is_load && (ex_rd != 5'd0) &&
                          ((id_reads_rs1 && (ex_rd == id_rs1)) ||
                           (id_reads_rs2 && (ex_rd == id_rs2)));

    wire mem_is_link = (mem_WDSel == `WDSel_FromPC);
    wire link_use_stall = mem_is_link && mem_RFWrite && (mem_rd != 5'd0) &&
                          ((id_reads_rs1 && (mem_rd == id_rs1)) ||
                           (id_reads_rs2 && (mem_rd == id_rs2)));

    wire Stall_Global = load_use_stall || link_use_stall;

    assign StallF = Stall_Global;
    assign StallD = Stall_Global;
    assign FlushE = Stall_Global || EX_Jump_Taken;
    assign FlushD = EX_Jump_Taken;
endmodule