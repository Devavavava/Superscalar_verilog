/*
RRF:
    table of 32 registers (P1 to P32) with 3 fields each : Busy (1 bit), Valid (1 bit), Data (16 bits)
    Input :
        clk, stall, flush (1 bit)
        From Decode     :   Whether the 2 empty positions are being used (in which case need to update them)
        From Execute    :   Write data 1/2/3 (1 bit), Register index 1/2/3 (5 bits), New data 1/2/3 (16 bits)
        From ROB        :   ARF write valid bit, ARF write index, RRF read index 
        From ARF        :   ARF_tag_1-7 (5 bits each) 
    Output :
        For Decode  :   2 empty positions, whether 2 positions are empty or not
                        Data and Valid bits for ARF_tag_1-7 
        For ARF     :   ARF write valid bit, ARF write index, ARF write data (2 of each) 
*/

module RRF (
    input  wire         clk,
    input  wire         stall,
    input  wire         flush,

    // From Decode
    input  wire         decode_use_slot1,
    input  wire         decode_use_slot2,

    // From Execute
    input  wire         write1_en,
    input  wire         write2_en,
    input  wire         write3_en,
    input  wire [6:0]   write1_idx,
    input  wire [6:0]   write2_idx,
    input  wire [6:0]   write3_idx,
    input  wire [15:0]  write1_data,
    input  wire [15:0]  write2_data,
    input  wire [15:0]  write3_data,

    // From ARF
    input  wire [6:0]   ARF_tag_1,
    input  wire [6:0]   ARF_tag_2,
    input  wire [6:0]   ARF_tag_3,
    input  wire [6:0]   ARF_tag_4,
    input  wire [6:0]   ARF_tag_5,
    input  wire [6:0]   ARF_tag_6,
    input  wire [6:0]   ARF_tag_7,

    // From ROB
    input  wire         rob_write_valid1,
    input  wire [2:0]   rob_write_index1,
    input  wire [6:0]   rob_rrf_read_idx1,
    input  wire         rob_write_valid2,
    input  wire [2:0]   rob_write_index2,
    input  wire [6:0]   rob_rrf_read_idx2,

    // To Decode
    output wire         two_empty_available,
    output reg  [6:0]   empty_pos1_idx,
    output reg  [6:0]   empty_pos2_idx,

    output wire [15:0]  RRF_data_1,
    output wire         RRF_valid_1,
    output wire [15:0]  RRF_data_2,
    output wire         RRF_valid_2,
    output wire [15:0]  RRF_data_3,
    output wire         RRF_valid_3,
    output wire [15:0]  RRF_data_4,
    output wire         RRF_valid_4,
    output wire [15:0]  RRF_data_5,
    output wire         RRF_valid_5,
    output wire [15:0]  RRF_data_6,
    output wire         RRF_valid_6,
    output wire [15:0]  RRF_data_7,
    output wire         RRF_valid_7,

    // To ARF
    output reg          ARF_write_valid1,
    output reg  [2:0]   ARF_write_index1,
    output reg  [15:0]  ARF_write_data1,
    output reg          ARF_write_valid2,
    output reg  [2:0]   ARF_write_index2,
    output reg  [15:0]  ARF_write_data2
);

// Internal RRF register file: 32 entries with Busy, Valid, and Data
reg         busy   [127:0];
reg         valid  [127:0];
reg [15:0]  data   [127:0];

// Empty slot detection
integer i;
reg [4:0] empty1, empty2;
reg empty_found1, empty_found2;
always @(*) begin
    empty_found1 = 0;
    empty_found2 = 0;
    empty1 = 0;
    empty2 = 0;
    for (i = 0; i < 128; i = i + 1) begin
        if (!busy[i]) begin
            if (!empty_found1) begin
                empty1 = i[6:0];
                empty_found1 = 1;
            end else if (!empty_found2) begin
                empty2 = i[6:0];
                empty_found2 = 1;
            end
        end
    end
end

assign two_empty_available = empty_found1 & empty_found2;
always @(*) begin
    empty_pos1_idx = empty1;
    empty_pos2_idx = empty2;
end

// Combined Writeback and ARF Write Logic
always @(posedge clk) begin
    if (!stall) begin
        if (flush) begin
            for (i = 0; i < 128; i = i + 1) begin
                busy[i]  <= 1'b0;
                valid[i] <= 1'b0;
                data[i]  <= 16'b0;
            end
        end else begin
            // Writeback from Execute
            if (write1_en) begin
                data[write1_idx]  <= write1_data;
                valid[write1_idx] <= 1;
            end
            if (write2_en) begin
                data[write2_idx]  <= write2_data;
                valid[write2_idx] <= 1;
            end
            if (write3_en) begin
                data[write3_idx]  <= write3_data;
                valid[write3_idx] <= 1;
            end

            // Mark used slots as busy
            if (decode_use_slot1) busy[empty1] <= 1;
            if (decode_use_slot2) busy[empty2] <= 1;

            // ARF write from ROB
            ARF_write_valid1 <= rob_write_valid1;
            ARF_write_index1 <= rob_write_index1;
            ARF_write_data1  <= data[rob_rrf_read_idx1];

            ARF_write_valid2 <= rob_write_valid2;
            ARF_write_index2 <= rob_write_index2;
            ARF_write_data2  <= data[rob_rrf_read_idx2];

            if (rob_write_valid1) begin
                busy[rob_rrf_read_idx1]  <= 1'b0;
                valid[rob_rrf_read_idx1] <= 1'b0;
            end
            if (rob_write_valid2) begin
                busy[rob_rrf_read_idx2]  <= 1'b0;
                valid[rob_rrf_read_idx2] <= 1'b0;
            end
        end
    end
end

// RRF read ports
assign RRF_data_1  = data[ARF_tag_1];
assign RRF_valid_1 = valid[ARF_tag_1];
assign RRF_data_2  = data[ARF_tag_2];
assign RRF_valid_2 = valid[ARF_tag_2];
assign RRF_data_3  = data[ARF_tag_3];
assign RRF_valid_3 = valid[ARF_tag_3];
assign RRF_data_4  = data[ARF_tag_4];
assign RRF_valid_4 = valid[ARF_tag_4];
assign RRF_data_5  = data[ARF_tag_5];
assign RRF_valid_5 = valid[ARF_tag_5];
assign RRF_data_6  = data[ARF_tag_6];
assign RRF_valid_6 = valid[ARF_tag_6];
assign RRF_data_7  = data[ARF_tag_7];
assign RRF_valid_7 = valid[ARF_tag_7];

endmodule


/*
ARF:
    table of 8 registers (R1 to R8) with 3 fields each : Busy (1 bit), Data (16 bits), Tag (5 bits)
    Input :
        clk, stall, flush (1 bit)
        From Decode :   Register index to be updated (3 bits), New tag (5 bits), Update tag signal (1 bit) (2 of each)
        From RRF    :   Register index to be updated (5 bits), New data (16 bits), Write data signal (1 bit) (2 of each)
    Output :
        For Decode  :   all busy bits, all tags, all data
        For RRF     :   ARF_tag_1-7 (5 bits each)  (same as all tags for Decode stage)
*/

module ARF (
    input  wire         clk,
    input  wire         stall,
    input  wire         reset,

    // From Decode
    input  wire [2:0]   decode_reg_idx1,
    input  wire [6:0]   decode_new_tag1,
    input  wire         decode_update_tag1,
    input  wire [2:0]   decode_reg_idx2,
    input  wire [6:0]   decode_new_tag2,
    input  wire         decode_update_tag2,

    // From RRF
    input  wire [2:0]   rrf_write_idx1,
    input  wire [15:0]  rrf_write_data1,
    input  wire         rrf_write_en1,
    input  wire [2:0]   rrf_write_idx2,
    input  wire [15:0]  rrf_write_data2,
    input  wire         rrf_write_en2,

    // To Decode
    output wire [7:0]   busy_bits,       // One bit per register
    output wire [15:0]  ARF_data_1,
    output wire [15:0]  ARF_data_2,
    output wire [15:0]  ARF_data_3,
    output wire [15:0]  ARF_data_4,
    output wire [15:0]  ARF_data_5,
    output wire [15:0]  ARF_data_6,
    output wire [15:0]  ARF_data_7,

    output wire [6:0]   ARF_tag_1,
    output wire [6:0]   ARF_tag_2,
    output wire [6:0]   ARF_tag_3,
    output wire [6:0]   ARF_tag_4,
    output wire [6:0]   ARF_tag_5,
    output wire [6:0]   ARF_tag_6,
    output wire [6:0]   ARF_tag_7

    // To RRF
    // output wire [6:0]   ARF_tag_1,
    // output wire [6:0]   ARF_tag_2,
    // output wire [6:0]   ARF_tag_3,
    // output wire [6:0]   ARF_tag_4,
    // output wire [6:0]   ARF_tag_5,
    // output wire [6:0]   ARF_tag_6,
    // output wire [6:0]   ARF_tag_7
);

// Internal registers
reg        busy  [7:0];
reg [15:0] data [7:0];
reg [6:0]  tag   [7:0];


// ARF tag outputs (same as tags for decode)
assign ARF_tag_1 = tag[1];
assign ARF_tag_2 = tag[2];
assign ARF_tag_3 = tag[3];
assign ARF_tag_4 = tag[4];
assign ARF_tag_5 = tag[5];
assign ARF_tag_6 = tag[6];
assign ARF_tag_7 = tag[7];

// ARF data outputs
assign ARF_data_1 = data[1];
assign ARF_data_2 = data[2];
assign ARF_data_3 = data[3];
assign ARF_data_4 = data[4];
assign ARF_data_5 = data[5];
assign ARF_data_6 = data[6];
assign ARF_data_7 = data[7];

// Main logic
integer j;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        for (j = 0; j < 8; j = j + 1) begin
            busy[j] <= 0;
            tag[j] <= 7'b0;
            data[j] <= 16'b0;
        end
    end else if (!stall) begin
        // Update from Decode - entry 1
        if (decode_update_tag1) begin
            busy[decode_reg_idx1] <= 1;
            tag[decode_reg_idx1] <= decode_new_tag1;
        end
        // Update from Decode - entry 2
        if (decode_update_tag2) begin
            busy[decode_reg_idx2] <= 1;
            tag[decode_reg_idx2] <= decode_new_tag2;
        end

        // Update from RRF - entry 1
        if (rrf_write_en1) begin
            data[rrf_write_idx1] <= rrf_write_data1;
            busy[rrf_write_idx1] <= 0;
        end
        // Update from RRF - entry 2
        if (rrf_write_en2) begin
            data[rrf_write_idx2] <= rrf_write_data2;
            busy[rrf_write_idx2] <= 0;
        end
    end
end

endmodule

// ROB and Decoder give input to the same register (in ARF), tag match would erase busy bit but since Decoder gave a new input busy should remain high