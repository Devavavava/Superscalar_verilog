module Assembled_Superscalar #(
    parameter SB_SIZE           = 5,
    parameter ROB_SIZE          = 7,
    parameter RRF_SIZE          = 7,
    parameter R_CZ_SIZE         = 8,
    parameter RS_AL_ENTRY_SIZE  = 145,
    parameter RS_LS_ENTRY_SIZE  = 75,
    parameter ROB_ENTRY_SIZE    = 44
)(
	input wire clk,				// external clock
	input wire stall,			// external stall
	input wire flush,			// external flush
	input wire reset
);

// ----------------------------------------------------------------------------

// FetchStage inputs
wire R0w;
wire [15:0] R0d;

// FetchStage outputs
wire [15:0] fetch_I1, fetch_I2; // to decode stage
wire fetch_I1V, fetch_I2V; // to decode stage
wire fetch_I1P, fetch_I2P; // to decode stage
wire [15:0] fetch_I1PC, fetch_I2PC; // to decode stage

// ----------------------------------------------------------------------------

// Decoder inputs
// wire stall; -- already declared above
wire [SB_SIZE-1:0] SB_idx_1, SB_idx_2; // from store buffer
wire [ROB_SIZE-1:0] ROB_idx_1, ROB_idx_2; // from reorder buffer
wire [RRF_SIZE-1:0] RRF_ptr_1, RRF_ptr_2; // from RRF
wire [R_CZ_SIZE-1:0] R_CZ_ptr_1, R_CZ_ptr_2, R_CZ_ptr_3, R_CZ_ptr_4; // from CZ RRF
wire [7:0] ARF_B; // from ARF
wire [15:0] ARF_D1, ARF_D2, ARF_D3, ARF_D4, ARF_D5, ARF_D6, ARF_D7; // from ARF
wire [RRF_SIZE-1:0] ARF_tag_1, ARF_tag_2, ARF_tag_3, ARF_tag_4, ARF_tag_5, ARF_tag_6, ARF_tag_7; // from ARF
wire [7:0] RRF_V_ARF_tags; // from RRF
wire [15:0] RRF_D_ARF_tag_1, RRF_D_ARF_tag_2, RRF_D_ARF_tag_3, RRF_D_ARF_tag_4, RRF_D_ARF_tag_5, RRF_D_ARF_tag_6, RRF_D_ARF_tag_7; // from RRF
wire arch_C, arch_C_B; // from RRF
wire [R_CZ_SIZE-1:0] arch_C_tag; // from RRF
wire arch_Z, arch_Z_B; // from RRF
wire [R_CZ_SIZE-1:0] arch_Z_tag; // from RRF
wire R_CZ_V_arch_C_tag, R_CZ_D_arch_C_tag; // from RRF
wire R_CZ_V_arch_Z_tag, R_CZ_D_arch_Z_tag; // from RRF

wire [15:0] PR_I1, PR_I2; // from IF_ID_PR
wire PR_I1V, PR_I2V; // from IF_ID_PR
wire PR_I1P, PR_I2P; // from IF_ID_PR
wire [15:0] PR_I1PC, PR_I2PC; // from IF_ID_PR
wire [5:0] PR_I1_prev_IMM, PR_I2_prev_IMM; // from IF_ID_PR

// Decoder outputs
wire loop; // to IF_ID_PR
wire [15:0] I1_loop, I2_loop; // to IF_ID_PR
wire I1V_loop, I2V_loop; // to IF_ID_PR
wire I1P_loop, I2P_loop; // to IF_ID_PR
wire [15:0] I1PC_loop, I2PC_loop; // to IF_ID_PR
wire [5:0] I1IMM_loop, I2IMM_loop; // to IF_ID_PR

wire RS_AL_V1, RS_AL_V2; // to RS_AL
wire [RS_AL_ENTRY_SIZE-1:0] RS_AL_1, RS_AL_2; // to RS_AL
wire RS_LS_V1, RS_LS_V2; // to RS_LS
wire [RS_LS_ENTRY_SIZE-1:0] RS_LS_1, RS_LS_2; // to RS_LS
wire ROB_V1, ROB_V2; // to ROB
wire [ROB_ENTRY_SIZE-1:0] ROB_1, ROB_2; // to ROB

wire using_RRF_ptr_1, using_RRF_ptr_2; // to RRF
wire using_R_CZ_ptr_1, using_R_CZ_ptr_2, using_R_CZ_ptr_3, using_R_CZ_ptr_4; // to RRF

wire ARF_update_tag_1, ARF_update_tag_2; // to ARF
wire [2:0] ARF_new_reg_1, ARF_new_reg_2; // to ARF
wire [RRF_SIZE-1:0] ARF_new_tag_1, ARF_new_tag_2; // to ARF
wire update_arch_C; // to ARF
wire [R_CZ_SIZE-1:0] new_C_tag; // to ARF
wire update_arch_Z; // to ARF
wire [R_CZ_SIZE-1:0] new_Z_tag; // to ARF

wire SB_reserve_1, SB_reserve_2; // to SB

// ----------------------------------------------------------------------------

// RS AL inputs
// From ALU1
wire ALU1_D_W;
wire [15:0] ALU1_D;
wire [6:0] ALU1_D_RR;

// From ALU2
wire ALU2_D_W;
wire [15:0] ALU2_D;
wire [6:0] ALU2_D_RR;

// From LS
wire LS_D_W;
wire [15:0] LS_D;
wire [6:0] LS_D_RR;

// RS AL Outputs
wire rs_al_stall;                // Fetch/decode stall signal

// To ALU1
wire ALU1_V;
wire [3:0] ALU1_opcode;
wire [15:0] ALU1_opr1;
wire [15:0] ALU1_opr2;
wire [15:0] ALU1_imm;
wire ALU1_carry;
wire ALU1_zero;
wire ALU1_neg_opr2;
wire [1:0] ALU1_CZ_cond;
wire [6:0] ALU1_dest;
wire [2:0] ALU1_arch_dest;
wire [15:0] ALU1_prev_dest;
wire [15:0] ALU1_PC;
wire [7:0] ALU1_C_dest;
wire [7:0] ALU1_Z_dest;
wire ALU1_branch_pred;
wire [ROB_SIZE-1:0] ALU1_ROB_index;

// To ALU2
wire ALU2_V;
wire [3:0] ALU2_opcode;
wire [15:0] ALU2_opr1;
wire [15:0] ALU2_opr2;
wire [15:0] ALU2_imm;
wire ALU2_carry;
wire ALU2_zero;
wire ALU2_neg_opr2;
wire [1:0] ALU2_CZ_cond;
wire [6:0] ALU2_dest;
wire [2:0] ALU2_arch_dest;
wire [15:0] ALU2_prev_dest;
wire [15:0] ALU2_PC;
wire [7:0] ALU2_C_dest;
wire [7:0] ALU2_Z_dest;
wire ALU2_branch_pred;
wire [ROB_SIZE-1:0] ALU2_ROB_index;

// General outputs
wire [4:0] rs_al_empty_pos1, rs_al_empty_pos2; 

// RS LS outputs
wire rs_ls_stall;                // Fetch/decode stall signal

// To LoadStore
wire LS_LS_V1;
wire LS_load_store;
wire [15:0] LS_Base;
wire [15:0] LS_Offset;
wire [15:0] LS_Source_Data;
wire [6:0] LS_dest;
wire [2:0] LS_arch_dest_ls;
wire [7:0] LS_Z_dest;
wire [SB_SIZE-1:0] LS_SB_index;
wire [ROB_SIZE-1:0] LS_ROB_index;
wire LS_is_LMSM;

// General outputs
wire [4:0] rs_ls_empty_pos1;

// Instantiate FetchStage
FetchStage fetch_stage_inst (
    .clk(clk),					// external clock
    .stall(stall),				// external stall
    .flush(flush),			   	// external flush
    .R0w(R0w),	 				// FOR NOW external R0 update		
    .R0d(R0d),					// FOR NOW external R0 data

	// To Decoder
    .I1(fetch_I1),
    .I2(fetch_I2),
    .I1V(fetch_I1V),
    .I2V(fetch_I2V),
    .I1P(fetch_I1P),
    .I2P(fetch_I2P),
    .I1PC(fetch_I1PC),
    .I2PC(fetch_I2PC)
);

// Instantiate IF_ID_PR 
IF_ID_PR if_id_pr_inst (
	.clk(clk),					// external clock
	.reset(reset),				// external reset
	.stall(stall),				// external stall
	.flush(flush),			   	// external flush

	// From FetchStage
	.I1(fetch_I1),
	.I2(fetch_I2),
	.I1V(fetch_I1V),
	.I2V(fetch_I2V),
	.I1P(fetch_I1P),
	.I2P(fetch_I2P),
	.I1PC(fetch_I1PC),
	.I2PC(fetch_I2PC),

	// From Decoder
	.loop(loop),
	.I1_loop(I1_loop),
	.I2_loop(I2_loop),
	.I1V_loop(I1V_loop),
	.I2V_loop(I2V_loop),
	.I1P_loop(I1P_loop),
	.I2P_loop(I2P_loop),
	.I1PC_loop(I1PC_loop),
	.I2PC_loop(I2PC_loop),
	.I1_IMM(I1IMM_loop),
	.I2_IMM(I2IMM_loop),

	// Outputs to Decoder
	.I1_out(PR_I1),
	.I2_out(PR_I2),
	.I1V_out(PR_I1V),
	.I2V_out(PR_I2V),
	.I1P_out(PR_I1P),
	.I2P_out(PR_I2P),
	.I1PC_out(PR_I1PC),
	.I2PC_out(PR_I2PC),
	.I1_prev_IMM(PR_I1_prev_IMM),
	.I2_prev_IMM(PR_I2_prev_IMM)
);

// Instantiate Decoder
Decoder decoder_inst (
	.stall(stall),				// external stall

	// From SB
	.SB_idx_1(SB_idx_1),
	.SB_idx_2(SB_idx_2),

	// From ROB
	.ROB_idx_1(ROB_idx_1),
	.ROB_idx_2(ROB_idx_2),
	
	// From RRF
	.RRF_ptr_1(RRF_ptr_1),
	.RRF_ptr_2(RRF_ptr_2),
	.R_CZ_ptr_1(R_CZ_ptr_1),
	.R_CZ_ptr_2(R_CZ_ptr_2),
	.R_CZ_ptr_3(R_CZ_ptr_3),
	.R_CZ_ptr_4(R_CZ_ptr_4),
	.RRF_V_ARF_tags(RRF_V_ARF_tags),
	.RRF_D_ARF_tag_1(RRF_D_ARF_tag_1),
	.RRF_D_ARF_tag_2(RRF_D_ARF_tag_2),
	.RRF_D_ARF_tag_3(RRF_D_ARF_tag_3),
	.RRF_D_ARF_tag_4(RRF_D_ARF_tag_4),
	.RRF_D_ARF_tag_5(RRF_D_ARF_tag_5),
	.RRF_D_ARF_tag_6(RRF_D_ARF_tag_6),
	.RRF_D_ARF_tag_7(RRF_D_ARF_tag_7),

	// From ARF
	.ARF_B(ARF_B),
	.ARF_D1(ARF_D1),
	.ARF_D2(ARF_D2),
	.ARF_D3(ARF_D3),
	.ARF_D4(ARF_D4),
	.ARF_D5(ARF_D5),
	.ARF_D6(ARF_D6),
	.ARF_D7(ARF_D7),
	.ARF_tag_1(ARF_tag_1),
	.ARF_tag_2(ARF_tag_2),
	.ARF_tag_3(ARF_tag_3),
	.ARF_tag_4(ARF_tag_4),
	.ARF_tag_5(ARF_tag_5),
	.ARF_tag_6(ARF_tag_6),
	.ARF_tag_7(ARF_tag_7),
	.arch_C(arch_C),
	.arch_C_B(arch_C_B),
	.arch_C_tag(arch_C_tag),
	.arch_Z(arch_Z),
	.arch_Z_B(arch_Z_B),
	.arch_Z_tag(arch_Z_tag),
	.R_CZ_V_arch_C_tag(R_CZ_V_arch_C_tag),
	.R_CZ_D_arch_C_tag(R_CZ_D_arch_C_tag),
	.R_CZ_V_arch_Z_tag(R_CZ_V_arch_Z_tag),
	.R_CZ_D_arch_Z_tag(R_CZ_D_arch_Z_tag),

	// From IF_ID_PR
	.PR_I1(PR_I1),
	.PR_I2(PR_I2),
	.PR_I1V(PR_I1V),
	.PR_I2V(PR_I2V),
	.PR_I1P(PR_I1P),
	.PR_I2P(PR_I2P),
	.PR_I1PC(PR_I1PC),
	.PR_I2PC(PR_I2PC),
	.PR_I1_prev_IMM(PR_I1_prev_IMM),
	.PR_I2_prev_IMM(PR_I2_prev_IMM),

	// To IF_ID_PR
	.loop(loop),
	.I1_loop(I1_loop),
	.I2_loop(I2_loop),
	.I1V_loop(I1V_loop),
	.I2V_loop(I2V_loop),
	.I1P_loop(I1P_loop),
	.I2P_loop(I2P_loop),
	.I1PC_loop(I1PC_loop),
	.I2PC_loop(I2PC_loop),
	.I1IMM_loop(I1IMM_loop),
	.I2IMM_loop(I2IMM_loop),

	// To RS
	.RS_AL_V1(RS_AL_V1),
	.RS_AL_V2(RS_AL_V2),
	.RS_AL_1(RS_AL_1),
	.RS_AL_2(RS_AL_2),
	.RS_LS_V1(RS_LS_V1),
	.RS_LS_V2(RS_LS_V2),
	.RS_LS_1(RS_LS_1),
	.RS_LS_2(RS_LS_2),
	
	// To ROB
	.ROB_V1(ROB_V1),
	.ROB_V2(ROB_V2),
	.ROB_1(ROB_1),
	.ROB_2(ROB_2),

	// To RRF
	.using_RRF_ptr_1(using_RRF_ptr_1),
	.using_RRF_ptr_2(using_RRF_ptr_2),
	.using_R_CZ_ptr_1(using_R_CZ_ptr_1),
	.using_R_CZ_ptr_2(using_R_CZ_ptr_2),
	.using_R_CZ_ptr_3(using_R_CZ_ptr_3),
	.using_R_CZ_ptr_4(using_R_CZ_ptr_4),

	// To ARF
	.ARF_update_tag_1(ARF_update_tag_1),
	.ARF_update_tag_2(ARF_update_tag_2),
	.ARF_new_reg_1(ARF_new_reg_1),
	.ARF_new_reg_2(ARF_new_reg_2),
	.ARF_new_tag_1(ARF_new_tag_1),
	.ARF_new_tag_2(ARF_new_tag_2),
	.update_arch_C(update_arch_C),
	.new_C_tag(new_C_tag),
	.update_arch_Z(update_arch_Z),
	.new_Z_tag(new_Z_tag),

	// To SB
	.SB_reserve_1(SB_reserve_1),
	.SB_reserve_2(SB_reserve_2)
);

// Instantiate RS
// Instantiate RS_ArithmeticLogical
RS_ArithmeticLogical #(
    .RS_AL_ENTRY_SIZE(RS_AL_ENTRY_SIZE)
) rs_arithmetic_logical_inst (
    .clk(clk),                          // external clock
    .reset(reset),                      // external reset
    .stall(stall),                      // external stall
    .flush(flush),                      // external flush THIS DOES NOTHING HERE

    // From Decoder (2 entries)
    .RS_AL_V1(RS_AL_V1),
    .RS_AL_1(RS_AL_1),
    .RS_AL_V2(RS_AL_V2),
    .RS_AL_2(RS_AL_2),

    // From ALU1
    .ALU1_D_W(0),	// ALU1_D_W
    .ALU1_D(ALU1_D),
    .ALU1_D_RR(ALU1_D_RR),

    // From ALU2
    .ALU2_D_W(0),	// ALU2_D_W
    .ALU2_D(ALU2_D),
    .ALU2_D_RR(ALU2_D_RR),

    // From LS
    .LS_D_W(0),	// LS_D_W
    .LS_D(LS_D),
    .LS_D_RR(LS_D_RR),

    // Outputs
    .rs_stall(rs_al_stall),                // Fetch/decode stall signal

    // To ALU1
    .ALU1_V(ALU1_V),
    .ALU1_opcode(ALU1_opcode),
    .ALU1_opr1(ALU1_opr1),
    .ALU1_opr2(ALU1_opr2),
    .ALU1_imm(ALU1_imm),
    .ALU1_carry(ALU1_carry),
    .ALU1_zero(ALU1_zero),
    .ALU1_neg_opr2(ALU1_neg_opr2),
    .ALU1_CZ_cond(ALU1_CZ_cond),
    .ALU1_dest(ALU1_dest),
    .ALU1_arch_dest(ALU1_arch_dest),
    .ALU1_prev_dest(ALU1_prev_dest),
    .ALU1_PC(ALU1_PC),
    .ALU1_C_dest(ALU1_C_dest),
    .ALU1_Z_dest(ALU1_Z_dest),
    .ALU1_branch_pred(ALU1_branch_pred),
    .ALU1_ROB_index(ALU1_ROB_index),

    // To ALU2
    .ALU2_V(ALU2_V),
    .ALU2_opcode(ALU2_opcode),
    .ALU2_opr1(ALU2_opr1),
    .ALU2_opr2(ALU2_opr2),
    .ALU2_imm(ALU2_imm),
    .ALU2_carry(ALU2_carry),
    .ALU2_zero(ALU2_zero),
    .ALU2_neg_opr2(ALU2_neg_opr2),
    .ALU2_CZ_cond(ALU2_CZ_cond),
    .ALU2_dest(ALU2_dest),
    .ALU2_arch_dest(ALU2_arch_dest),
    .ALU2_prev_dest(ALU2_prev_dest),
    .ALU2_PC(ALU2_PC),
    .ALU2_C_dest(ALU2_C_dest),
    .ALU2_Z_dest(ALU2_Z_dest),
    .ALU2_branch_pred(ALU2_branch_pred),
    .ALU2_ROB_index(ALU2_ROB_index),

	// General outputs
	.empty_pos1(rs_al_empty_pos1),
	.empty_pos2(rs_al_empty_pos2)
);

RS_LoadStore #(
    .RS_LS_ENTRY_SIZE(RS_LS_ENTRY_SIZE)
) rs_load_store_inst (
    .clk(clk),                          // external clock
    .reset(reset),                      // external reset
    .stall(stall),                      // external stall
    .flush(flush),                      // external flush THIS DOES NOTHING HERE

    // From Decoder (2 entries)
    .RS_LS_V1(RS_LS_V1),
    .RS_LS_1(RS_LS_1),
    .RS_LS_V2(RS_LS_V2),
    .RS_LS_2(RS_LS_2),

    // From ALU1
    .ALU1_D_W(0),	// ALU1_D_W
    .ALU1_D(ALU1_D),
    .ALU1_D_RR(ALU1_D_RR),

    // From ALU2
    .ALU2_D_W(0),	// ALU2_D_W
    .ALU2_D(ALU2_D),
    .ALU2_D_RR(ALU2_D_RR),

    // From LS
    .LS_D_W(0),	// LS_D_W
    .LS_D(LS_D),
    .LS_D_RR(LS_D_RR),

    // Outputs
    .rs_stall(rs_ls_stall),                // Fetch/decode stall signal

	// To LoadStore
	.LS_V1(LS_LS_V1),
	.Load_Store(LS_load_store),
	.Base(LS_Base),
	.Offset(LS_Offset),
	.Source_Data(LS_Source_Data),
	.dest(LS_dest),
	.arch_dest_ls(LS_arch_dest_ls),
	.Z_dest(LS_Z_dest),
	.SB_index(LS_SB_index),
	.ROB_index(LS_ROB_index),
	.is_LMSM(LS_is_LMSM),

	// Check values
	.empty_pos1(rs_ls_empty_pos1)
);


endmodule
