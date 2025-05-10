module StoreBuffer(
    input wire CLK,
    input wire RST,
    // Decode Stage
    input wire clear_speculative,
    input wire reserve_1,
    input wire reserve_2,
    // Execute Stage
    input wire LS_W,
    input wire [4:0] LS_index,
    input wire [15:0] LS_addr,
    // Load/Store Stage for load enquiry
    input wire [15:0] LS_data,
    input wire [15:0] LS_search_addr,
    // Writeback Stage
    input wire pop_head,
    // Retiring Stage
    input wire [7:0] ROB_W,
    input wire [39:0] SB_index,
    
    // To decoder
    output wire [4:0] free_index_1,
    output wire [4:0] free_index_2,
    output wire stall,
    // To L1-D Cache
    output wire head_valid,
    output wire [15:0] head_addr,
    output wire [15:0] head_data,
    
    // For loads
    output wire LS_match,
    output wire [15:0] LS_search_data

);

    // Store buffer entries (32 entries)
    reg valid [0:31];
    reg executed [0:31];
    reg retired [0:31];
    reg [15:0] addr [0:31];
    reg [15:0] data [0:31];
    
    // Front and back pointers
    reg [4:0] head;
    reg [4:0] tail;
    
    // Count of valid entries
    reg [5:0] valid_count;
    
    // Internal signals for free entries
    reg [4:0] free_1, free_2;
    assign free_index_1 = free_1;
    assign free_index_2 = free_2;
    
    // Stall when fewer than 2 free entries
    assign stall = (valid_count > 30);
    
    // Head of queue signals
    assign head_valid = valid[head] && executed[head] && retired[head];
    assign head_addr = addr[head];
    assign head_data = data[head];

    // Internal signals for LS address search
    reg match_found;
    reg [15:0] match_data;
    assign LS_match = match_found;
    assign LS_search_data = match_data;
    
    // Find free entries
    integer i, j;
    always @(*) begin
        free_1 <= tail + 5'd1;
        free_2 <= tail + 5'd2;
    end
    // always @(*) begin
    //     free_1 = 5'h1F; // Default to invalid entry
    //     free_2 = 5'h1F;
        
    //     for (i = 0; i < 32; i = i + 1) begin
    //         if (!valid[i]) begin
    //             free_1 = i;
    //             break;
    //         end
    //     end
        
    //     for (j = i + 1; j < 32; j = j + 1) begin
    //         if (!valid[j]) begin
    //             free_2 = j;
    //             break;
    //         end
    //     end
        
    //     // If we couldn't find a second free entry by going forward,
    //     // wrap around and check from the beginning
    //     if (free_2 == 5'h1F && i < 32) begin
    //         for (j = 0; j < i; j = j + 1) begin
    //             if (!valid[j]) begin
    //                 free_2 = j;
    //                 break;
    //             end
    //         end
    //     end
    // end
    
    // Search for matching address
    always @(*) begin
        match_found = 0;
        match_data = 16'h0000;
        
        // Search from back (newest) to front (oldest)
        i = tail;
        for (j = 0; j < 32; j = j + 1) begin
            if (valid[i] && executed[i] && retired[i] && (addr[i] == LS_search_addr)) begin
                match_found = 1;
                match_data = data[i];
                break; // Take the most recent match
            end
            
            // Move towards front, with wrap-around
            i = (i == 0) ? 31 : i - 1;
            if (i == tail) break; // We've gone full circle
        end
    end
    
    // Main control logic
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            // Asynchronous RST
            for (i = 0; i < 32; i = i + 1) begin
                valid[i] <= 0;
                executed[i] <= 0;
                retired[i] <= 0;
                addr[i] <= 16'h0000;
                data[i] <= 16'h0000;
            end
            head <= 0;
            tail <= 0;
            valid_count <= 0;
        end else begin
            // Clear speculative entries
            if (clear_speculative) begin
                for (i = 0; i < 32; i = i + 1) begin
                    if (valid[i] && !retired[i]) begin
                        valid[i] <= 0;
                    end
                end
                
                // Update back pointer and valid count
                j = 0; // Counter for valid entries
                i = head;

                while (valid[i] && retired[i]) begin
                    i = (i + 1) % 32;
                    if (i == head) break;
                end
                if (i != head) begin
                    tail <= i - 1;
                end
                else begin
                    tail <= head == 5'b0 ? 5'd31 : head - 5'd1;
                end

                // while (j < 32) begin
                //     if (valid[i] && retired[i]) begin
                //         tail <= i;
                //     end
                //     i = (i + 1) % 32;
                //     if (i == head) break;
                //     j = j + 1;
                // end
                
                // // Recalculate valid count
                // valid_count <= 0;
                // for (i = 0; i < 32; i = i + 1) begin
                //     if (valid[i]) begin
                //         valid_count <= valid_count + 1;
                //     end
                // end
            end else begin
                // Reserve entry 1
                if (reserve_1) begin
                    valid[free_1] <= 1;
                    executed[free_1] <= 0;
                    retired[free_1] <= 0;
                    
                    // Update back pointer and valid count
                    tail <= free_1;
                    valid_count <= valid_count + 1;
                    
                    // If buffer was empty, update front too
                    if (valid_count == 0) begin
                        head <= free_1;
                    end
                end
                
                // Reserve entry 2
                if (reserve_2) begin
                    valid[free_2] <= 1;
                    executed[free_2] <= 0;
                    retired[free_2] <= 0;
                    
                    // Update back pointer and valid count
                    // Check if we already reserved entry 1
                    // if (!reserve_1) begin
                    //     tail <= free_2;
                    //     valid_count <= valid_count + 1;
                        
                    //     // If buffer was empty, update front too
                    //     // if (valid_count == 0) begin
                    //     //     head <= free_2;
                    //     // end
                    // end else begin
                    //     // We already reserved entry 1, so just update count
                        valid_count <= valid_count + 1;
                        tail <= free_2;
                    // end
                end
                
                // Update store entry
                if (LS_W) begin
                    addr[LS_index] <= LS_addr;
                    data[LS_index] <= LS_data;
                    executed[LS_index] <= 1;
                end
                
                // Mark entry as retired
                i = 0;
                for (i = 0; i < 8; i = i + 1) begin
                    if (ROB_W[i]) begin
                        retired[SB_index[5 * i + 4 +: 5 * i]] <= 1;
                    end
                end

                // Pop head of queue
                if (pop_head && head_valid) begin
                    valid[head] <= 0;
                    valid_count <= valid_count - 1;
                    
                    // Find new front (next valid entry)
                    if (head == tail) begin
                        head <= 0;
                        tail <= 0;
                    end else begin
                        head <= (head + 1) % 32;
                    end
                end
            end
        end
    end
endmodule