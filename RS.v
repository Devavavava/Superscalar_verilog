/*
RS Arithmetic Logical :
    Table of 32 RS entries : 
        1. Valid bit
        2. OP Code + C/Z valid
        3. Operand 1 + valid bit
        4. Operand 2 + valid bit
        5. Immediate
        6. Neg of Operand 2 + C/Z conditions
        7. C flag + C Valid
        8. Z flag + Z Valid
        9. Destination
        10. Prev Destination
        11. C dest
        12. Z dest
        13. Branch Prediction - T/NT
        14. PC
        15. ROB index
        16. ARF destination
        17. Ready
    Inputs :
        clk reset stall
        From decoder : valid bit + all data (x2)
        From ALU1/2 : ALU1/2_D_W, ALU1/2_D, ALU1/2_D_RR - update all ALU1/2_D_RR with ALU1/2_D and update valid bits
        From LS : LS_D_W, LS_D, LS_D_RR - update all LS_D_RR with LS_D and update valid bits
    Outputs :
        stall - Do I have >=2 empty slots? if not stall Fetch & Decode
        ALU1_V - issuing to ALU1?
        ALU1_... {
            input   [3:0]   opcode,
            input   [15:0]  opr1,
            input   [15:0]  opr2,
            input   [15:0]  imm,
            input           carry,
            input           zero,
            input           neg_opr2,
            input   [1:0]   CZ_cond,
            input   [6:0]   dest,
            input   [2:0]   arch_dest,
            input   [15:0]  prev_dest,
            input   [15:0]  PC,
            input   [7:0]   C_dest,
            input   [7:0]   Z_dest,
            input           branch_pred,
            input   [6:0]   ROB_index_in,
        } /refer decoder for exact places of each/
        similarly for ALU2
        Careful: Dynamically decide which entries are eligible for execution, depends on opcode as each requires different operands/CZ Flags
*/

module RS_ArithmeticLogical #(
    parameter RS_AL_ENTRY_SIZE = 145
    ) (
    input  wire         clk,
    input  wire         reset,
    input  wire         stall,
    input  wire         flush,

    // From Decoder (2 entries)
    input  wire         RS_AL_V1,
    input  wire [RS_AL_ENTRY_SIZE-1:0] RS_AL_1,
    input  wire         RS_AL_V2,
    input  wire [RS_AL_ENTRY_SIZE-1:0] RS_AL_2,

    // From ALU1
    input  wire         ALU1_D_W,
    input  wire [15:0]  ALU1_D,
    input  wire [6:0]   ALU1_D_RR,

    // From ALU2
    input  wire         ALU2_D_W,
    input  wire [15:0]  ALU2_D,
    input  wire [6:0]   ALU2_D_RR,

    // From LS
    input  wire         LS_D_W,
    input  wire [15:0]  LS_D,
    input  wire [6:0]   LS_D_RR,

    // Outputs
    output wire         rs_stall, // Fetch/decode stall signal

    // To ALU1
    output wire         ALU1_V,
    output wire [3:0]   ALU1_opcode,
    output wire [15:0]  ALU1_opr1,
    output wire [15:0]  ALU1_opr2,
    output wire [15:0]  ALU1_imm,
    output wire         ALU1_carry,
    output wire         ALU1_zero,
    output wire         ALU1_neg_opr2,
    output wire [1:0]   ALU1_CZ_cond,
    output wire [6:0]   ALU1_dest,
    output wire [2:0]   ALU1_arch_dest,
    output wire [15:0]  ALU1_prev_dest,
    output wire [15:0]  ALU1_PC,
    output wire [7:0]   ALU1_C_dest,
    output wire [7:0]   ALU1_Z_dest,
    output wire         ALU1_branch_pred,
    output wire [6:0]   ALU1_ROB_index,

    // To ALU2 (same format as ALU1)
    output wire         ALU2_V,
    output wire [3:0]   ALU2_opcode,
    output wire [15:0]  ALU2_opr1,
    output wire [15:0]  ALU2_opr2,
    output wire [15:0]  ALU2_imm,
    output wire         ALU2_carry,
    output wire         ALU2_zero,
    output wire         ALU2_neg_opr2,
    output wire [1:0]   ALU2_CZ_cond,
    output wire [6:0]   ALU2_dest,
    output wire [2:0]   ALU2_arch_dest,
    output wire [15:0]  ALU2_prev_dest,
    output wire [15:0]  ALU2_PC,
    output wire [7:0]   ALU2_C_dest,
    output wire [7:0]   ALU2_Z_dest,
    output wire         ALU2_branch_pred,
    output wire [6:0]   ALU2_ROB_index
);

// Internal storage
reg         valid       [31:0];
reg [3:0]   opcode      [31:0];
reg         opr1_valid  [31:0];
reg [15:0]  opr1        [31:0];
reg         opr2_valid  [31:0];
reg [15:0]  opr2        [31:0];
reg [15:0]  imm         [31:0];
reg         carry_valid [31:0];
reg         carry       [31:0];
reg         zero_valid  [31:0];
reg         zero        [31:0];
reg [1:0]   cz_cond     [31:0];
reg         neg_opr2    [31:0];
reg [6:0]   dest        [31:0];
reg [2:0]   arch_dest   [31:0];
reg [15:0]  prev_dest   [31:0];
reg [7:0]   c_dest      [31:0];
reg [7:0]   z_dest      [31:0];
reg         branch_pred [31:0];
reg [15:0]  pc          [31:0];
reg [6:0]   rob_index   [31:0];
reg         ready       [31:0];

// Additional logic to be constructed

endmodule


/*
RS Load Store :
    Table of 32 RS entries : 
        1. Valid bit
        2. Load/Store bit
        3. Base
        4. Base valid bit
        5. Offset
        6. Source (Data or Tag)
        7. Source valid bit
        8. Store Buffer index
        9. RR address
        10. ROB index
        11. ARF destination
        12. is LMSM
    Inputs :
        clk reset stall
        From decoder : valid bit + all data (x2)
        From ALU1/2 : ALU1/2_D_W, ALU1/2_D, ALU1/2_D_RR - update all ALU1/2_D_RR with ALU1/2_D and update valid bits
        From LS : LS_D_W, LS_D, LS_D_RR - update all LS_D_RR with LS_D and update valid bits
    Outputs :
        stall - do I have >=2 empty slots?
        LS_V1 - issuing to LS_Unit?
        LS - {
            input wire        Load_Store, // 0 for Load, 1 for Store
            input wire [15:0] Base,
            input wire [15:0] Offset,
            input wire [15:0] Source_Data,
            input wire [6:0]  dest,
            input wire [2:0]  arch_dest,
            input wire [7:0]  Z_dest,
            input wire [4:0]  SB_index,
            input wire [6:0]  ROB_index,
            input wire        is_LMSM,
        } /refer to decoder/

        /will be a Queue, FIFO/
*/

module RS_LoadStore #(
    parameter RS_LS_ENTRY_SIZE = 75
    ) (
    input  wire         clk,
    input  wire         reset,
    input  wire         stall,
    input  wire         flush,

    // From Decoder (2 entries)
    input  wire         RS_LS_V1,
    input  wire [RS_LS_ENTRY_SIZE-1:0] RS_LS_1,
    input  wire         RS_LS_V2,
    input  wire [RS_LS_ENTRY_SIZE-1:0] RS_LS_2,

    // From ALU1
    input  wire         ALU1_D_W,
    input  wire [15:0]  ALU1_D,
    input  wire [6:0]   ALU1_D_RR,

    // From ALU2
    input  wire         ALU2_D_W,
    input  wire [15:0]  ALU2_D,
    input  wire [6:0]   ALU2_D_RR,

    // From LS
    input  wire         LS_D_W,
    input  wire [15:0]  LS_D,
    input  wire [6:0]   LS_D_RR,

    // Outputs
    output wire         rs_stall,  // If < 2 slots available

    // To Load/Store Unit
    output wire         LS_V1,
    output wire         Load_Store,
    output wire [15:0]  Base,
    output wire [15:0]  Offset,
    output wire [15:0]  Source_Data,
    output wire [6:0]   dest,
    output wire [2:0]   arch_dest_ls,
    output wire [7:0]   Z_dest,
    output wire [4:0]   SB_index,
    output wire [6:0]   ROB_index,
    output wire         is_LMSM
);

// Internal storage
reg         valid       [31:0];
reg         load_store  [31:0];
reg [15:0]  base        [31:0];
reg         base_valid  [31:0];
reg [15:0]  offset      [31:0];
reg [15:0]  source_data [31:0];
reg         source_valid[31:0];
reg [4:0]   sb_index    [31:0];
reg [6:0]   rr_addr     [31:0];
reg [6:0]   rob_index_r [31:0];
reg [2:0]   arch_dest   [31:0];
reg [7:0]   z_dest      [31:0];
reg         is_lmsm     [31:0];

// Additional logic to be implemented
// - Entry insertion (from decoder)
// - Operand/tag broadcast update (from ALU/LS)
// - Issue logic (determine ready entries to issue to LS)
// - rs_stall output based on # of free entries

endmodule
