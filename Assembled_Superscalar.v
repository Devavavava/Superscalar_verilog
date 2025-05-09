module assembled_superscalar (
);

// FetchStage inputs
wire R0w, R0d;

// FetchStage outputs
wire [15:0] fetch_I1, fetch_I2;
wire fetch_I1V, fetch_I2V;
wire fetch_I1P, fetch_I2P;
wire [15:0] fetch_I1PC, fetch_I2PC;

// Instantiate FetchStage
FetchStage fetch_stage_inst (
    .clk(clk),					// external clock
    .stall(stall),				// external stall
    .flush(flush),			   	// external flush
    .R0w(R0w),	 				// FOR NOW external R0 update		
    .R0d(R0d),					// FOR NOW external R0 data
    .I1(fetch_I1),				// instruction 1 --- to decode stage
    .I2(fetch_I2),				// instruction 2 --- to decode stage
    .I1V(fetch_I1V),			// instruction 1 valid	--- to decode stage
    .I2V(fetch_I2V),			// instruction 2 valid	--- to decode stage
    .I1P(fetch_I1P),			// instruction 1 prediction	--- to decode stage
    .I2P(fetch_I2P),			// instruction 2 prediction	--- to decode stage
    .I1PC(fetch_I1PC),			// instruction 1 PC	--- to decode stage
    .I2PC(fetch_I2PC)			// instruction 2 PC	--- to decode stage
);

// module Decoder #(
//     parameter SB_SIZE           = 5,
//     parameter ROB_SIZE          = 7,
//     parameter RRF_SIZE          = 7,
//     parameter R_CZ_SIZE         = 8,
//     parameter RS_AL_ENTRY_SIZE  = 145,
//     parameter RS_LS_ENTRY_SIZE  = 75,
//     parameter ROB_ENTRY_SIZE    = 44
// )(
//     input  wire                     stall,
//     input  wire [SB_SIZE-1:0]       SB_idx_1,
//     input  wire [SB_SIZE-1:0]       SB_idx_2,
//     input  wire [ROB_SIZE-1:0]      ROB_idx_1,
//     input  wire [ROB_SIZE-1:0]      ROB_idx_2,
//     input  wire [RRF_SIZE-1:0]      RRF_ptr_1,
//     input  wire [RRF_SIZE-1:0]      RRF_ptr_2,
//     input  wire [R_CZ_SIZE-1:0]     R_CZ_ptr_1,
//     input  wire [R_CZ_SIZE-1:0]     R_CZ_ptr_2,
//     input  wire [R_CZ_SIZE-1:0]     R_CZ_ptr_3,
//     input  wire [R_CZ_SIZE-1:0]     R_CZ_ptr_4,
//     input  wire [7:0]               ARF_B,
//     input  wire [15:0]              ARF_D1,
//     input  wire [15:0]              ARF_D2,
//     input  wire [15:0]              ARF_D3,
//     input  wire [15:0]              ARF_D4,
//     input  wire [15:0]              ARF_D5,
//     input  wire [15:0]              ARF_D6,
//     input  wire [15:0]              ARF_D7,
//     input  wire [RRF_SIZE-1:0]      ARF_tag_1,
//     input  wire [RRF_SIZE-1:0]      ARF_tag_2,
//     input  wire [RRF_SIZE-1:0]      ARF_tag_3,
//     input  wire [RRF_SIZE-1:0]      ARF_tag_4,
//     input  wire [RRF_SIZE-1:0]      ARF_tag_5,
//     input  wire [RRF_SIZE-1:0]      ARF_tag_6,
//     input  wire [RRF_SIZE-1:0]      ARF_tag_7,
//     input  wire [7:0]               RRF_V_ARF_tags,
//     input  wire [15:0]              RRF_D_ARF_tag_1,
//     input  wire [15:0]              RRF_D_ARF_tag_2,
//     input  wire [15:0]              RRF_D_ARF_tag_3,
//     input  wire [15:0]              RRF_D_ARF_tag_4,
//     input  wire [15:0]              RRF_D_ARF_tag_5,
//     input  wire [15:0]              RRF_D_ARF_tag_6,
//     input  wire [15:0]              RRF_D_ARF_tag_7,
//     input  wire                     arch_C,
//     input  wire                     arch_C_B,
//     input  wire [R_CZ_SIZE-1:0]     arch_C_tag,
//     input  wire                     arch_Z,
//     input  wire                     arch_Z_B,
//     input  wire [R_CZ_SIZE-1:0]     arch_Z_tag,
//     input  wire                     R_CZ_V_arch_C_tag,
//     input  wire                     R_CZ_D_arch_C_tag,
//     input  wire                     R_CZ_V_arch_Z_tag,
//     input  wire                     R_CZ_D_arch_Z_tag,
//     input  wire [15:0]              PR_I1,
//     input  wire                     PR_I1V,
//     input  wire                     PR_I1P,
//     input  wire [15:0]              PR_I1PC,
//     input  wire [5:0]              PR_I1_prev_IMM,
//     input  wire [15:0]              PR_I2,
//     input  wire                     PR_I2V,
//     input  wire                     PR_I2P,
//     input  wire [15:0]              PR_I2PC,
//     input  wire [5:0]              PR_I2_prev_IMM,

//     output reg                      loop,
//     output reg  [15:0]              I1_loop,
//     output reg                      I1V_loop,
//     output reg                      I1P_loop,
//     output reg  [15:0]              I1PC_loop,
//     output reg  [5:0]               I1IMM_loop,
//     output reg  [15:0]              I2_loop,
//     output reg                      I2V_loop,
//     output reg                      I2P_loop,
//     output reg  [15:0]              I2PC_loop,
//     output reg  [5:0]               I2IMM_loop,

//     output reg                      RS_AL_V1,
//     output reg  [RS_AL_ENTRY_SIZE-1:0] RS_AL_1,
//     output reg                      RS_AL_V2,
//     output reg  [RS_AL_ENTRY_SIZE-1:0] RS_AL_2,
//     output reg                      RS_LS_V1,
//     output reg  [RS_LS_ENTRY_SIZE-1:0] RS_LS_1,
//     output reg                      RS_LS_V2,
//     output reg  [RS_LS_ENTRY_SIZE-1:0] RS_LS_2,
//     output reg                      ROB_V1,
//     output reg  [ROB_ENTRY_SIZE-1:0] ROB_1,
//     output reg                      ROB_V2,
//     output reg  [ROB_ENTRY_SIZE-1:0] ROB_2,

//     output reg                      using_RRF_ptr_1,
//     output reg                      using_RRF_ptr_2,
//     output reg                      using_R_CZ_ptr_1,
//     output reg                      using_R_CZ_ptr_2,
//     output reg                      using_R_CZ_ptr_3,
//     output reg                      using_R_CZ_ptr_4,

//     output reg                      ARF_update_tag_1,
//     output reg  [2:0]               ARF_new_reg_1,
//     output reg  [RRF_SIZE-1:0]      ARF_new_tag_1,
//     output reg                      ARF_update_tag_2,
//     output reg  [2:0]               ARF_new_reg_2,
//     output reg  [RRF_SIZE-1:0]      ARF_new_tag_2,
//     output reg                      update_arch_C,
//     output reg  [R_CZ_SIZE-1:0]     new_C_tag,
//     output reg                      update_arch_Z,
//     output reg  [R_CZ_SIZE-1:0]     new_Z_tag,

//     output reg                      SB_reserve_1,
//     output reg                      SB_reserve_2
// );
