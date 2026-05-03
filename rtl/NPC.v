`include "ctrl_signal_def.v"
`include "instruction_def.v"

module NPC(NPCOp, Offset12, Offset20, PC, rs, imm, PCA4, NPC, ID_RD1, ID_RD2, funct3_0, id_PC, stallF,
           ID_rs1, ID_rs2, MEM_ALU_result, MEM_rd, MEM_RFWrite, ID_Branch_Taken, clk, rst, FlushE);
    input  [1:0]  NPCOp;
    input  [12:1] Offset12;
    input  [20:1] Offset20;
    input  [31:0] PC, id_PC;
    input  [31:0] rs;
    input  [31:0] imm;
    output reg [31:0] PCA4;
    output reg [31:0] NPC;
    input clk, rst, FlushE, stallF;
    input [31:0] ID_RD1, ID_RD2;
    input [4:0]  ID_rs1, ID_rs2;
    input [31:0] MEM_ALU_result;
    input [4:0]  MEM_rd;
    input funct3_0;
    input MEM_RFWrite;
    output ID_Branch_Taken;

    wire [31:0] mem_PCA4, ex_PCA4;
    wire signed [12:0] Offset13;
    wire signed [20:0] Offset21;

    wire forward_A_ID = MEM_RFWrite && (MEM_rd != 5'd0) && (MEM_rd == ID_rs1);
    wire forward_B_ID = MEM_RFWrite && (MEM_rd != 5'd0) && (MEM_rd == ID_rs2);

    wire [31:0] cmp_A;
    wire [31:0] cmp_B;
    assign cmp_A = forward_A_ID ? MEM_ALU_result : ID_RD1;
    assign cmp_B = forward_B_ID ? MEM_ALU_result : ID_RD2;

    wire branch_equal;
    wire branch_taken;
    wire jal_taken;
    wire jalr_taken;
    wire id_taken;

    assign branch_equal = (cmp_A == cmp_B);
    assign branch_taken  = (NPCOp == `NPC_Offset12) && (funct3_0 ? !branch_equal : branch_equal);
    assign jal_taken     = (NPCOp == `NPC_Offset20);
    assign jalr_taken    = (NPCOp == `NPC_rs);
    assign id_taken      = branch_taken || jal_taken || jalr_taken;
    assign ID_Branch_Taken = id_taken;

    assign Offset13 = $signed({Offset12[12:1], 1'b0});
    assign Offset21 = $signed({Offset20[20:1], 1'b0});

    wire [31:0] seq_pc;
    wire [31:0] branch_pc;
    wire [31:0] jal_pc;
    wire [31:0] jalr_pc;
    assign seq_pc    = PC + 32'd4;
    assign branch_pc = id_PC + {{19{Offset13[12]}}, Offset13};
    assign jal_pc    = id_PC + {{11{Offset21[20]}}, Offset21};
    assign jalr_pc   = (cmp_A + imm) & 32'hffff_fffe;

    always @(*) begin
        if (stallF) begin
            NPC = PC;
        end else if (id_taken) begin
            case (NPCOp)
                `NPC_Offset12: NPC = branch_pc;
                `NPC_Offset20: NPC = jal_pc;
                `NPC_rs:       NPC = jalr_pc;
                default:       NPC = seq_pc;
            endcase
        end else begin
            NPC = seq_pc;
        end
    end

    wire [31:0] id_PCA4 = id_PC + 32'd4;

    Flopr U_ID_EX_PCA4 (.clk(clk), .rst(rst), .in_data(id_PCA4), .out_data(ex_PCA4), .CLR(FlushE), .Stall(1'b0));
    Flopr U_EX_MEM_PCA4 (.clk(clk), .rst(rst), .in_data(ex_PCA4), .out_data(mem_PCA4), .CLR(1'b0), .Stall(1'b0));

    always @(posedge clk or posedge rst) begin
        if (rst)
            PCA4 <= 32'b0;
        else
            PCA4 <= mem_PCA4;
    end
endmodule