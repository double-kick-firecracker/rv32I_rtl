`include "ctrl_signal_def.v"
`include "instruction_def.v"

module NPC(
    input  [1:0]  NPCOp,
    input  [12:1] ex_Offset,
    input  [20:1] ex_Offset20,
    input  [31:0] PC,
    input  [31:0] ex_PC,
    input  [31:0] ex_RD1,
    input  [31:0] ex_RD2,
    input  [4:0]  ex_rs1,
    input  [4:0]  ex_rs2,
    input  [31:0] mem_ALU_result,
    input  [4:0]  mem_rd,
    input  [31:0] wb_WD,
    input  [4:0]  wb_rd,
    input         mem_RFWrite,
    input         wb_RFWrite,
    input  [31:0] ex_imm32,
    input         funct3_0,
    input         stallF,
    input         clk,
    input         rst,
    output        EX_Jump_Taken,
    output reg [31:0] PCA4,
    output reg [31:0] NPC
);
    wire [31:0] mem_PCA4;
    wire signed [31:0] branch_offset = {{19{ex_Offset[12]}}, ex_Offset[12:1], 1'b0};
    wire signed [31:0] jal_offset    = {{11{ex_Offset20[20]}}, ex_Offset20[20:1], 1'b0};

    wire is_branch = (NPCOp == `NPC_Offset12);
    wire is_jalr   = (NPCOp == `NPC_rs);
    wire is_jal    = (NPCOp == `NPC_Offset20);

    wire [31:0] br_A = (mem_RFWrite && (mem_rd != 5'd0) && (mem_rd == ex_rs1)) ? mem_ALU_result :
                       (wb_RFWrite  && (wb_rd  != 5'd0) && (wb_rd  == ex_rs1)) ? wb_WD : ex_RD1;

    wire [31:0] br_B = (mem_RFWrite && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) ? mem_ALU_result :
                       (wb_RFWrite  && (wb_rd  != 5'd0) && (wb_rd  == ex_rs2)) ? wb_WD : ex_RD2;

    wire branch_eq = (br_A == br_B);
    wire branch_condition_met = is_branch && (funct3_0 ? !branch_eq : branch_eq);

    wire [31:0] pc4_target    = PC + 4;
    wire [31:0] branch_target = $signed(ex_PC) + branch_offset;
    wire [31:0] jal_target    = $signed(ex_PC) + jal_offset;
    wire [31:0] jalr_target   = (br_A + ex_imm32) & 32'hffff_fffe;
    wire [31:0] ex_PCA4      = ex_PC + 4;

    assign EX_Jump_Taken = branch_condition_met || is_jalr || is_jal;

    always @(*) begin
        if (stallF)
            NPC = PC;
        else if (branch_condition_met)
            NPC = branch_target;
        else if (is_jal)
            NPC = jal_target;
        else if (is_jalr)
            NPC = jalr_target;
        else
            NPC = pc4_target;
    end

    Flopr U_EX_MEM_PCA4 (
        .clk(clk), .rst(rst), .in_data(ex_PCA4), .out_data(mem_PCA4), .CLR(1'b0), .Stall(1'b0)
    );

    always @(posedge clk or posedge rst) begin
        if (rst)
            PCA4 <= 0;
        else
            PCA4 <= mem_PCA4;
    end
endmodule
