/* Description: Reorder Buffer (ROB) module
    Table of 128 entries:
    Each entry is 68 bits wide.
    1. Valid bit / Busy Bit                 : 1 bit
    2. PC                                   : 16 bits
    3. Destination Architectural Register   : 3 bits
    4. Destination Renamed Register         : 7 bits
    5. Carry Writeback                      : 1 bit
    6. Carry Writeback Address              : 8 bits
    7. Zero Writeback                       : 1 bit
    8. Zero Writeback Address               : 8 bits
    9. Valid / Execute                      : 1 bit
    10. Mispredicted Branch                 : 1 bit
    11. Correct Branch Address              : 16 bits
    12. Store Buffer Index                  : 5 bits

*/
module ROB #(parameter ROB_ENTRY_SIZE = 44, 
             parameter ROB_INDEX_SIZE = 7,
             parameter RRF_SIZE = 7,
             parameter R_CZ_SIZE = 8,
             parameter SB_SIZE = 5,
             parameter ROB_SIZE = 128
             ) (
    // Main Control Signals
    input wire CLK,
    input wire Flush,
    input wire RST,
    // From Decoder
    input wire Dispatch1_V,
    input wire [ROB_ENTRY_SIZE-1:0] Dispatch1,
    input wire Dispatch2_V,
    input wire [ROB_ENTRY_SIZE-1:0] Dispatch2,

    // From ALU1
    input wire ALU1_mispred;
    input wire [15:0] ALU1_new_PC;
    input wire ALU1_valid;
    input wire [ROB_INDEX_SIZE-1:0] ALU1_index;

    // From ALU2
    input wire ALU2_mispred;
    input wire [15:0] ALU2_new_PC;
    input wire ALU2_valid;
    input wire [ROB_INDEX_SIZE-1:0] ALU2_index;

    // From Load/Store Unit
    input wire LSU_mispred;
    input wire [15:0] LSU_new_PC;
    input wire LSU_valid;
    input wire [ROB_INDEX_SIZE-1:0] LSU_index;

    // From Store Buffer
    input wire SB_Addr1;
    input wire SB_Addr2;
    // To RRF
    output reg ROB_Retire1_V,
    output reg [2:0] ROB_Retire1_ARF_Addr,
    output reg [RRF_SIZE-1:0] ROB_Retire1_RRF_Addr,
    output reg ROB_Retire2_V,
    output reg [2:0] ROB_Retire2_ARF_Addr,
    output reg [RRF_SIZE-1:0] ROB_Retire2_RRF_Addr,

    // To R_CZ
    output reg ROB_Retire1_C_V,
    output reg ROB_Retire1_Z_V,
    output reg [R_CZ_SIZE-1:0] ROB_Retire1_C_Addr,
    output reg [R_CZ_SIZE-1:0] ROB_Retire1_Z_Addr,

    output reg ROB_Retire2_C_V,
    output reg ROB_Retire2_Z_V,
    output reg [R_CZ_SIZE-1:0] ROB_Retire2_C_Addr,
    output reg [R_CZ_SIZE-1:0] ROB_Retire2_Z_Addr,
    // Unclear about the Carry and Zero flag which is supposed to be an output because aren't they stored in CZ_RR.
    // To Store Buffer
    output reg ROB_Retire1_SB_V,
    output reg [SB_SIZE-1:0] ROB_Retire1_SB_Addr,
    // output reg [15:0] ROB_Retire1_HeadPC,
    output reg ROB_Retire2_SB_V,
    output reg [SB_SIZE-1:0] ROB_Retire2_SB_Addr,
    // output reg [15:0] ROB_Retire2_HeadPC,

    // To Decoder
    output wire [ROB_INDEX_SIZE-1:0] ROB_index_1,
    output wire [ROB_INDEX_SIZE-1:0] ROB_index_2,

    // Stall output in case of ROB full
    output wire ROB_stall,
);

// Internal registers
reg                 valid       [ROB_SIZE - 1:0]; // Valid bits for each entry
reg [15:0]          PC          [ROB_SIZE - 1:0]; // Program Counter for each entry
reg [2:0]           ARF_Addr    [ROB_SIZE - 1:0]; // Destination ARF address
reg [RRF_SIZE-1:0]  RRF_Addr    [ROB_SIZE - 1:0]; // Destination RRF address
reg                 C_W         [ROB_SIZE - 1:0]; // Carry Writeback
reg [R_CZ_SIZE-1:0] C_Addr      [ROB_SIZE - 1:0]; // Carry Writeback Address
reg                 Z_W         [ROB_SIZE - 1:0]; // Zero Writeback
reg [R_CZ_SIZE-1:0] Z_Addr      [ROB_SIZE - 1:0]; // Zero Writeback Address
reg                 Instr_Valid [ROB_SIZE - 1:0]; // Instruction Valid bit
reg                 Mispredicted_Branch [ROB_SIZE - 1:0]; // Mispredicted Branch
reg [15:0]          Correct_Branch_Addr [ROB_SIZE - 1:0]; // Correct Branch Address
reg [SB_SIZE-1:0]   SB_Addr     [ROB_SIZE - 1:0]; // Store Buffer Address

integer i;

// Count free entries in ROB
integer free_entries;
always @(*) begin
    free_entries = 0;
    for (i = 0; i < ROB_SIZE; i = i + 1) begin
        if (!valid[i]) begin
            free_entries = free_entries + 1;
        end
    end
end
// Check if ROB is full
assign ROB_stall = (free_entries < 2);

reg [6:0] ROB_Head_Pointer;
reg [6:0] ROB_Retire_Pointer;

assign ROB_index_1 = ROB_Head_Pointer;
assign ROB_index_2 = ROB_Head_Pointer + 6'd1;

always @(posedge CLK or posedge RST) begin
    if(RST or Flush) begin
        for (i = 0; i < ROB_SIZE; i = i + 1) begin
            valid[i] = 1'b0;
            PC[i] = 16'b0;
            ARF_Addr[i] = 3'b0;
            RRF_Addr[i] = 7'b0;
            C_W[i] = 1'b0;
            C_Addr[i] = 8'b0;
            Z_W[i] = 1'b0;
            Z_Addr[i] = 8'b0;
            Instr_Valid[i] = 1'b0;
            Mispredicted_Branch[i] = 1'b0;
            Correct_Branch_Addr[i] = 16'b0;
            SB_Addr[i] = 5'b0;
        end
        ROB_Head_Pointer = 7'b0;
        ROB_Retire1_V = 1'b0;
        ROB_Retire2_V = 1'b0;
        ROB_Retire1_C_V = 1'b0;
        ROB_Retire2_C_V = 1'b0;
        ROB_Retire1_Z_V = 1'b0;
        ROB_Retire2_Z_V = 1'b0;
        ROB_Retire1_SB_V = 1'b0;
        ROB_Retire2_SB_V = 1'b0;
    end
    else
    begin
        // Adding dispatched instructions to the ROB
        if(Dispatch1_V && ~valid[ROB_Head_Pointer]) begin
            valid[ROB_Head_Pointer] = 1'b1;
            PC[ROB_Head_Pointer] = Dispatch1[33:18];
            ARF_Addr[ROB_Head_Pointer] = Dispatch1[43:41];
            RRF_Addr[ROB_Head_Pointer] = Dispatch1[40:34];
            C_W[ROB_Head_Pointer] = Dispatch1[17];
            C_Addr[ROB_Head_Pointer] = Dispatch1[16:9];
            Z_W[ROB_Head_Pointer] = Dispatch1[8];
            Z_Addr[ROB_Head_Pointer] = Dispatch1[7:0];
            Instr_Valid[ROB_Head_Pointer] = 1'b0;
            Mispredicted_Branch[ROB_Head_Pointer] = 1'b0;
            Correct_Branch_Addr[ROB_Head_Pointer] = 16'b0;
            SB_Addr[ROB_Head_Pointer] = SB_Addr1;
        end
        if(Dispatch2_V && ~valid[ROB_Head_Pointer + 6'd1]) begin
            valid[ROB_Head_Pointer + 6'd1] = 1'b1;
            PC[ROB_Head_Pointer + 6'd1] = Dispatch2[33:18];
            ARF_Addr[ROB_Head_Pointer + 6'd1] = Dispatch2[43:41];
            RRF_Addr[ROB_Head_Pointer + 6'd1] = Dispatch2[40:34];
            C_W[ROB_Head_Pointer + 6'd1] = Dispatch2[17];
            C_Addr[ROB_Head_Pointer + 6'd1] = Dispatch2[16:9];
            Z_W[ROB_Head_Pointer + 6'd1] = Dispatch2[8];
            Z_Addr[ROB_Head_Pointer + 6'd1] = Dispatch2[7:0];
            Instr_Valid[ROB_Head_Pointer + 6'd1] = 1'b0;
            Mispredicted_Branch[ROB_Head_Pointer + 6'd1] = 1'b0;
            Correct_Branch_Addr[ROB_Head_Pointer + 6'd1] = 16'b0;
            SB_Addr[ROB_Head_Pointer + 6'd1] = SB_Addr2;
        end
        // Updating validity and branch information
        if(ALU1_valid) begin
            Instr_Valid[ALU1_index] = 1'b1;
            Mispredicted_Branch[ALU1_index] = ALU1_mispred;
            Correct_Branch_Addr[ALU1_index] = ALU1_new_PC;
        end
        if(ALU2_valid) begin
            Instr_Valid[ALU2_index] = 1'b1;
            Mispredicted_Branch[ALU2_index] = ALU2_mispred;
            Correct_Branch_Addr[ALU2_index] = ALU2_new_PC;
        end
        if(LSU_valid) begin
            Instr_Valid[LSU_index] = 1'b1;
            Mispredicted_Branch[LSU_index] = LSU_mispred;
            Correct_Branch_Addr[LSU_index] = LSU_new_PC;
        end
        // Retiring instructions
        if(Instr_Valid[ROB_Retire_Pointer]) begin
            ROB_Retire1_V = 1'b1;
            ROB_Retire1_ARF_Addr = ARF_Addr[ROB_Retire_Pointer];
            ROB_Retire1_RRF_Addr = RRF_Addr[ROB_Retire_Pointer];
            ROB_Retire1_C_V = C_W[ROB_Retire_Pointer];
            ROB_Retire1_C_Addr = C_Addr[ROB_Retire_Pointer];
            ROB_Retire1_Z_V = Z_W[ROB_Retire_Pointer];
            ROB_Retire1_Z_Addr = Z_Addr[ROB_Retire_Pointer];
            ROB_Retire1_SB_V = ~PC[ROB_Retire_Pointer][15] & PC[ROB_Retire_Pointer][14] & ~PC[ROB_Retire_Pointer][13] & PC[ROB_Retire_Pointer][12];
            ROB_Retire1_SB_Addr = SB_Addr[ROB_Retire_Pointer];
            ROB_Retire1_HeadPC = PC[ROB_Head_Pointer + 6'd1];
            valid[ROB_Retire_Pointer] = 1'b0;
        end
        if(Instr_Valid[ROB_Retire_Pointer + 6'd1]) begin
            ROB_Retire2_V = 1'b1;
            ROB_Retire2_ARF_Addr = ARF_Addr[ROB_Retire_Pointer + 6'd1];
            ROB_Retire2_RRF_Addr = RRF_Addr[ROB_Retire_Pointer + 6'd1];
            ROB_Retire2_C_V = C_W[ROB_Retire_Pointer + 6'd1];
            ROB_Retire2_C_Addr = C_Addr[ROB_Retire_Pointer + 6'd1];
            ROB_Retire2_Z_V = Z_W[ROB_Retire_Pointer + 6'd1];
            ROB_Retire2_Z_Addr = Z_Addr[ROB_Retire_Pointer + 6'd1];
            ROB_Retire2_SB_V = ~PC[ROB_Retire_Pointer][15] & PC[ROB_Retire_Pointer][14] & ~PC[ROB_Retire_Pointer][13] & PC[ROB_Retire_Pointer][12];
            ROB_Retire2_SB_Addr = SB_Addr[ROB_Retire_Pointer + 6'd1];
            ROB_Retire2_HeadPC = PC[ROB_Head_Pointer + 6'd1];
            valid[ROB_Retire_Pointer + 6'd1] = 1'b0;
        end
        // Update the retire pointer
        if(ROB_Retire1_V && ROB_Retire2_V) begin
            ROB_Retire_Pointer = ROB_Retire_Pointer + 6'd2;
        end
        else if(ROB_Retire1_V || ROB_Retire2_V) begin
            ROB_Retire_Pointer = ROB_Retire_Pointer + 6'd1;
        end
        // Update the head pointer
        if(Dispatch1_V && Dispatch2_V) begin
            ROB_Head_Pointer = ROB_Head_Pointer + 6'd2;
        end
        else if(Dispatch1_V || Dispatch2_V) begin
            ROB_Head_Pointer = ROB_Head_Pointer + 6'd1;
        end
    end
end

endmodule