`timescale 1ns / 1ps
module riscv(clk, rst);
    input clk, rst;

    wire RFWrite, DMCtrl, PCWrite, IRWrite, InsMemRW, ExtSel, zero, ALUSrcA;
    wire [1:0] ALUSrcB, mem_WDSel;
    wire [1:0] NPCOp, WDSel, RegSel;
    wire [3:0] ALUOp;
    wire [6:0] opcode;
    wire [2:0] Funct3;
    wire [6:0] Funct7;
    wire [31:0] PC, NPC, PCA4;
    wire [31:0] in_ins, out_ins, RD, DR_out;
    wire [4:0] rs1, rs2, rd, wb_rd;
    wire [11:0] Imm12;
    wire [31:0] Imm32,ex_imm32;
    wire [20:1] Offset20,ex_Offset20;
    wire [11:0] Offset,ex_Offset;
    wire [4:0] WR;
    wire [31:0] WD;
    wire [31:0] RD1, RD1_r, RD2, RD2_r,ex_RD2;
    wire [31:0] A, B, ALU_result, ALU_result_r;
    wire [31:0] id_PC,ex_PC;
    wire StallF,StallD,FlushE,FlushD;
    wire [4:0] ex_rs1, ex_rs2,mem_rd;
    wire ID_Branch_Taken;
    wire mem_RFWrite;
    wire wb_RD;

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

    // ?     PC鈥斺?斺?斺?擨F闃舵
    PC U_PC (
        .clk(clk), .rst(rst), .PCWrite(PCWrite), .NPC(NPC), .PC(PC),.FlushD(FlushD),.StallD(StallD),
        .StallF(StallF),.FlushE(FlushE),.id_PC(id_PC)   //鍛冨憙锛孭Cwrite鍙笉鍙互褰撲綔stallD鐢ㄥ晩锛屽埌鏃跺?欑爺绌朵竴涓嬪晩
    );                                                  //PC鐩存帴杈撳叆鍒癐M锛孭C鍦↖D闃舵涓嶉渶瑕侊紝鐩存帴浼犲埌EX闃舵
    
    // ?     IM
    IM U_IM (
        .addr(PC[11:2]), .Ins(in_ins), .InsMemRW(InsMemRW),.clk(clk),.addr_2(NPC[11:2])
    );//InsMemRW娌′粈涔堢敤鎰熻锛孖M鍒版椂鍊欐兂鍔炴硶鎸塖RAM鏍囧噯鏀?;涓轰簡婊¤冻鏃跺簭锛宎ddr涔熶笉鑳借浜?
    
        
    // ?     IR鈥斺?旈渶瑕佸ソ濂界爺绌剁殑IR
    IR U_IR (
        .clk(clk), .IRWrite(IRWrite), .in_ins(in_ins), .out_ins(out_ins), .flush(FlushD),.stall(StallD),.rst(rst)
    );

    // ?     ControlUnit鈥斺?斺?斺?擨D
    ControlUnit U_ControlUnit(
        .clk(clk), .rst(rst), .zero(zero), .opcode(opcode), .Funct7(Funct7), .Funct3(Funct3),
        .RFWrite(RFWrite), .DMCtrl(DMCtrl), .PCWrite(PCWrite), .IRWrite(IRWrite), .InsMemRW(InsMemRW),//杩欎笁涓槸搴熺墿锛屼笉鐢ㄧ
        .ExtSel(ExtSel), .ALUOp(ALUOp), .NPCOp(NPCOp), .ALUSrcA(ALUSrcA),.mem_RFWrite(mem_RFWrite),
        .WDSel(WDSel), .ALUSrcB(ALUSrcB), .RegSel(RegSel),.id_rs1(rs1),.id_rs2(rs2), .id_rd(rd),
        .ex_rs1(ex_rs1),.ex_rs2(ex_rs2),.mem_rd(mem_rd),
        .ID_Branch_Taken(ID_Branch_Taken),.StallF(StallF),.StallD(StallD), .FlushD(FlushD), .FlushE(FlushE),.wb_rd(wb_rd),.mem_WDSel(mem_WDSel)
    );//鐢变簬鍐崇瓥鎻愬墠锛孨PCOp涓嶉渶瑕佷紶涓ょ骇浜?,鍏朵綑閮芥槸缁忚繃鍐呴儴flopr浼犲叆EX鎴栨洿杩滅殑
      //RFWrite璨屼技鍙渶瑕佹渶鍚嶹B鐨勬椂鍊欎娇鐢?;DMCtrl鍙湪mem闇?瑕佷娇鐢紱WDSel浼犲埌WB闃舵锛汻egSel鏈?缁堜細浼犲埌WB;funct3_0鐢ㄤ簬鍒嗘敮鍒ゅ畾锛岀洿鎺D闃舵NPC鑷彇鍒犻櫎
      //ID_Branch_Taken鐢盢PC浼犲叆锛沬d_rs1/2缁橰F锛宔x_rs1/2缁橫UX鍓嶉?掞紱ex_rd鐢ㄤ簬cu鍐呴儴鍐掗櫓妫?娴嬶紝涓嶉渶瑕佹帴鍙ｏ紝rd鏄《灞傜殑assign銆傛渶缁堜細鐩撮?歁UX锛孧UX搴旇
      //鍙﹀紑涓?涓帴鍙ｄ簡,NPC闇?瑕乵em_rd锛沵em_RfWrite涔熼渶瑕佷紶鍏PC
      
      
    // ?     RF
    RF U_RF (
        .RR1(rs1), .RR2(rs2), .WR(WR), .WD(WD), .clk(clk),
        .RFWrite(RFWrite), .RD1(RD1), .RD2(RD2)
    );//WR鍜學D鏄湪WB闃舵琚啓鍥炵殑锛屼笉杩嘡egSel鍜學DSel閮芥槸浼犲埌WB闃舵锛屾墍浠ュ簲璇ユ病闂锛汻FWrite鐢盬Breg鍥炲埌杩欓噷锛?


    // ?     EXT
    EXT U_EXT (
        .imm_in(Imm12), .ExtSel(ExtSel), .imm_out(Imm32),.FlushE(FlushE),.ex_imm32(ex_imm32),.Offset20(Offset20),.Offset(Offset),
        .ex_Offset(ex_Offset),.clk(clk),.rst(rst),.ex_Offset20(ex_Offset20)//涓嶅锛屼紶鍏ux鍜宎lu鐨勬槸鍘熺増鐨刼ffse 鍜? offset20,Imm32闇?瑕佺粰NPC绠梛alr
    );

      
    // ?     NPC--鐜板湪NPC鍙堝彉鍥炵殑浜轰簡锛堟偛
    NPC U_NPC (
        .PC(PC), .NPCOp(NPCOp), .Offset12(Offset), .Offset20(Offset20), .rs({RD1[31:2],2'b00}), .PCA4(PCA4), .NPC(NPC),
        .imm(Imm32),.id_PC(id_PC),.clk(clk),.rst(rst), .FlushE(FlushE),.ID_RD1(RD1), .ID_RD2(RD2),.funct3_0(Funct3[0]),
        .ID_rs1(rs1), .ID_rs2(rs2),.MEM_ALU_result(ALU_result_r),.MEM_rd(mem_rd),.MEM_RFWrite(mem_RFWrite),
        .MEM_WDSel(mem_WDSel),.ID_Branch_Taken(ID_Branch_Taken),.stallF(StallF)
    );//PC鐢变簬璺ㄩ樁娈典簡锛屾墍浠ヤ笉瑕佷簡锛夛紝鑷繁鍒涢?犱竴涓帴鍙ｏ紱PCA4鐩存帴鍘诲埌WB闃舵;rs鎺ュ叆鐨勬暟鍊兼槸RD1锛屾墍浠ヨ鑰冭檻鍓嶉?掔殑鎯呭喌锛?
      //offset涔熷簾浜嗭紝rs鐨凴D1涔熶笉鑳借浜?

    // ?     Flopr  ID_EX pipeline reg
    Flopr U_A (
        .clk(clk), .rst(rst), .in_data(RD1), .out_data(RD1_r),.CLR(FlushE),.Stall(1'b0)
    );

    // ?     Flopr
    Flopr U_B (
        .clk(clk), .rst(rst), .in_data(RD2), .out_data(RD2_r),.CLR(FlushE),.Stall(1'b0)
    );

    // ?     MUX_2to1_A锛岀敤浜嶢LUA鐨勬潵婧?
    MUX_2to1_A U_MUX_2to1_A (
        .X(RD1_r), .Y(5'h0), .control(ALUSrcA), .out(A),.mem_ALU_result(ALU_result_r),
        .wb_WD(WD),.ex_rs1(ex_rs1),.mem_rd(mem_rd),.wb_rd(wb_rd),
        .mem_RFWrite(mem_RFWrite), .wb_RFWrite(RFWrite)
    );

    // ?     MUX_3to1_B锛岀敤浜嶢LUB鐨勬潵婧?
    MUX_3to1_B U_MUX_3to1_B (
        .X(RD2_r), .Y(Imm32), .Z(Offset), .control(ALUSrcB), .out(B),.mem_ALU_result(ALU_result_r),.wb_WD(WD),.ex_rs2(ex_rs2), 
        .mem_rd(mem_rd), .wb_rd(wb_rd),.mem_RFWrite(mem_RFWrite), .wb_RFWrite(RFWrite),//杩欎釜offset浼拌寰楀純鎺?,杩欎釜Imm32涔熷緱寮冩帀
        .Y_2(ex_imm32),.Z_2(ex_Offset),.Forwarded_Data(ex_RD2),
         .clk(clk), .rst(rst)
    );

    // ?     ALU
    ALU U_ALU (
        .A(A), .B(B), .ALUOp(ALUOp), .ALU_result(ALU_result), .zero(zero)
    );//RD2_r闇?瑕佷紶鍏X鐨凪UX妯″潡鍐咃紝涔熼渶瑕佷紶鍏M鍐呴儴锛屾墍浠ラ潬ALU澶氭墦涓?鎷嶃??


    // ?     Flopr鈥斺?斺?斺?旀寜鐞嗘潵璇碋X/MEM锛屾墍浠ユ渶鍚庣殑MUX鎴戣寰楀簲璇ュ彟瀵昏箠璺蜂簡锛?
    Flopr U_ALUOut (
        .clk(clk), .rst(rst), .in_data(ALU_result), .out_data(ALU_result_r),.CLR(1'b0),.Stall(1'b0)
    );

    // ?     DM
    DM U_DM (
        .Addr(ALU_result_r[11:2]), .WD(RD2_r), .DMCtrl(DMCtrl), .clk(clk), .RD(RD),.WD2(ex_RD2),.Addr_2(ALU_result[11:2])
    );//ALU_result_r鍙敤浜庤繖涓?澶勶紝鍏朵粬鍙﹁緹韫婂緞锛沇D涓嶈兘鐢ㄤ簡锛屼紶閫佺殑鏄疎X鐨勶紝鎶婂唴閮╓D鐩稿叧鏁版嵁鏇挎崲涓轰簡mem_RD2
      //RD瀹為檯涓婂氨鏄疻B鐨勶紝DM浣滀负flopr涔嬩竴;璇曡瘯鐪嬩笉鐢ˋLU鐨凢lopr鎵撴媿锛岀渷鏃跺簭鐢ㄧ殑
    
        // ?     MUX_3to1----WB
    MUX_3to1 U_MUX_3to1 (
        .X(rd), .Y(5'd0), .Z(5'd31),
        .control(RegSel), .out(WR),.wb_rd(wb_rd)
    );//rd鐢变簬鏄兌姘撮?昏緫锛屼笉鑳戒娇鐢紱WR浼犲埌RF锛沊鐨勯?昏緫鍏ㄩ儴鎹㈡垚浜唚b_rd

    // ?     MUX_3to1_LMD
    MUX_3to1_LMD U_MUX_3to1_LMD (
        .X(ALU_result_r), .Y(DR_out), .Z(PCA4),
        .control(WDSel), .out(WD), .clk(clk), .rst(rst)
    );//ALU_result_r鍦ㄨ繖閲屼笉鑳界敤浜嗭紙鎭硷級;涓嶅锛岀収鏍峰彲浠ワ紝ALU_result_r杈撳叆杩涘幓鍚庣敤涓猣lopr鎵撲竴鎷嶅氨鍙互浜?
    
    assign DR_out = RD;
endmodule
