module cache (
    input  logic         i_clk,
    input  logic         i_reset,

    input  logic         i_mem_access,   // = 1 if load/store, 0 = no access
    input  logic         i_wr_en,        // 1 = write, 0 = read
    input  logic  [3:0]  i_byte_mask,     // byte enable for write
    input  logic [31:0]  i_addr,
    input  logic [31:0]  i_wdata,
    output logic [31:0]  o_rdata,
    output logic         o_hit_debug,
    output logic         o_miss_debug,
    output logic         o_stall,        // stall CPU
    output logic         o_cache_done,   

    // ============================
    // SRAM INTERFACE
    // ============================
    output logic         o_sram_enb,
    output logic [31:0]  o_sram_addr,
    output logic         o_sram_wr_en,
    output logic [31:0]  o_sram_wdata,
    input  logic [31:0]  i_sram_rdata,
    input  logic         i_sram_ready
);
    localparam int NUM_SET = 4;
    localparam int NUM_WAY = 16;  

    localparam SW = 3'b010;
    localparam SB = 3'b000;
    localparam SH = 3'b001;
    localparam LW = 3'b101;
    localparam LB = 3'b011;
    localparam LH = 3'b100;
    localparam LBU = 3'b110;
    localparam LHU = 3'b111;
    // ---------------------------
    // TAG + INDEX
    // ---------------------------
    logic [31:0] req_addr_reg;
    logic [31:0] req_wdata_reg;
    logic        req_wr_en_reg;
    logic [3:0]  req_byte_mask_reg;

    logic [1:0] index;
    assign index = req_addr_reg[3:2];

    logic [27:0] tag;
    assign tag  = req_addr_reg[31:4];

    // ---------------------------
    // CACHE STORAGE
    // ---------------------------
    logic valid   [NUM_SET][NUM_WAY];
    logic dirty   [NUM_SET][NUM_WAY];
    logic [27:0] tag_array [NUM_SET][NUM_WAY];
    logic [31:0] data_array[NUM_SET][NUM_WAY];
    logic [$clog2(NUM_WAY)-1:0] fifo_ptr[NUM_SET];

    logic dirty_debug;
    logic stall;

    function automatic logic [31:0] write_with_mask(
        input logic [31:0] old_data,
        input logic [31:0] new_data,
        input logic [3:0]  byte_mask
    );
        begin
            case (byte_mask)
                4'b0001: write_with_mask = {old_data[31:8],  new_data[7:0]};
                4'b0010: write_with_mask = {old_data[31:16], new_data[15:8],  old_data[7:0]};
                4'b0100: write_with_mask = {old_data[31:24], new_data[23:16], old_data[15:0]};
                4'b1000: write_with_mask = {new_data[31:24], old_data[23:0]};
                4'b0011: write_with_mask = {old_data[31:16], new_data[15:0]};
                4'b1100: write_with_mask = {new_data[31:16], old_data[15:0]};
                4'b1111: write_with_mask = new_data;
                default: write_with_mask = old_data;
            endcase
        end
    endfunction
    // HIT CHECK (ONLY WHEN i_mem_access=1)
    // ---------------------------
    logic [NUM_WAY-1:0] way_hit;

    always_comb begin
        for (int w=0; w<NUM_WAY; w++)
            way_hit[w] = valid[index][w] && (tag_array[index][w] == tag);
    end

    logic hit;
    assign hit = |way_hit;
    logic [$clog2(NUM_WAY)-1:0] hit_way;
    always_comb begin
        hit_way = '0;
        for (int w=0; w<NUM_WAY; w++)
            if (way_hit[w]) hit_way = w;
    end

    // -----------------------------------
    // MISS INFO LATCH REGISTERS
    // -----------------------------------
    logic [31:0]  miss_addr_reg;
    logic [31:0]  miss_wdata_reg;
    logic         miss_wr_en_reg;
    logic [$clog2(NUM_WAY)-1:0] victim_way_reg;
    logic [1:0]   miss_index_reg;
    logic [27:0]  miss_tag_reg;
    logic [31:0]  victim_addr_reg;  // Address of victim line for writeback
    logic         victim_dirty_reg;  // Latch victim's dirty bit at CHECK_CACHE time
    logic         need_writeback_reg; // Latch writeback decision at CHECK_CACHE time
    logic [1:0]   hit_index_reg;
    logic [$clog2(NUM_WAY)-1:0] hit_way_reg;
    logic         output_from_hit_reg;

    // Select victim way using FIFO pointer
    logic [$clog2(NUM_WAY)-1:0] victim_way;
    assign victim_way = fifo_ptr[index];

    // Check if victim way is dirty
    logic victim_is_dirty;
    assign victim_is_dirty = dirty[index][victim_way];

    // -----------------------------------
    // FSM
    // -----------------------------------
    typedef enum logic [3:0] {
        IDLE          = 4'b0000,
        CHECK_CACHE   = 4'b0001,
        WRITEBACK_L2  = 4'b0010,
        L2_READ       = 4'b0011,
        UPDATE_CACHE  = 4'b0101,
        OUTPUT_DATA   = 4'b0110
    } state_t;

    state_t current_state, next_state;

    //assign hit = (current_state == CHECK_CACHE) && (|way_hit);
    assign o_hit_debug = hit && (current_state == CHECK_CACHE);
    assign o_miss_debug = (!hit) && (current_state == CHECK_CACHE);
    assign o_stall = stall;//|~(current_state == IDLE);
    always_comb begin
        case(current_state)
            IDLE: begin
                if (!i_mem_access)
                    next_state = IDLE;
                else
                    next_state = CHECK_CACHE;
            end
            CHECK_CACHE: begin
                if (hit) begin
                    //$display("CACHE HIT ADDR: %h, TIME = %d", i_addr, $time);
                    next_state = OUTPUT_DATA;  // Hit response goes through OUTPUT_DATA
                    //$display("HIT ADDR = %h", req_addr_reg);
                    /*
                    if (i_mem_access == 1'b1)
                        next_state = CHECK_CACHE;      // Hit response goes through OUTPUT_DATA
                    else
                        next_state = IDLE;
                    */
                end
                else begin
                    // Miss detected: check if victim is dirty
                    // CRITICAL: victim_way points to the FIFO victim for this set
                    // Check CURRENT victim_way's dirty bit at THIS cycle
                    if (dirty[index][victim_way]) begin
                        next_state = WRITEBACK_L2;  // Writeback dirty victim to L2 first
                        //$display("MISS DIRTY");
                    end
                    else begin
                        next_state = L2_READ;       // Always read allocate from L2 on miss
                        //$display("READ MISS CLEAN");
                    end
                    //$display("MISS ADDR = %h", miss_addr_reg);
                end
            end
            WRITEBACK_L2: begin
                // Writing dirty victim to L2
                // Use LATCHED victim_dirty_reg (captured at CHECK_CACHE time)
                if(i_sram_ready) begin
                    // After writeback, request line from L2
                    next_state = L2_READ;
                end else
                    next_state = WRITEBACK_L2;  // Wait for L2 ready
            end
            L2_READ: begin
                // Reading missed line from L2
                if(i_sram_ready)
                    next_state = UPDATE_CACHE;
                else
                    next_state = L2_READ;
            end
            UPDATE_CACHE: begin
                next_state = OUTPUT_DATA;
            end
            OUTPUT_DATA: begin
                //if (i_mem_access == 1'b0)
                    next_state = IDLE;
                //else
                //    next_state = CHECK_CACHE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // -----------------------------------
    // SEQUENTIAL: FSM STATE + CACHE UPDATE + MISS LATCH
    // -----------------------------------
    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            current_state <= IDLE;
            req_addr_reg <= 32'b0;
            req_wdata_reg <= 32'b0;
            req_wr_en_reg <= 1'b0;
            req_byte_mask_reg <= 4'b0;
            miss_addr_reg  <= 32'b0;
            miss_wdata_reg <= 32'b0;
            miss_wr_en_reg <= 1'b0;
            victim_way_reg <= {$clog2(NUM_WAY){1'b0}};
            miss_index_reg <= 2'b0;
            miss_tag_reg   <= 28'b0;
            victim_addr_reg<= 32'b0;
            victim_dirty_reg <= 1'b0;
            need_writeback_reg <= 1'b0;
            hit_index_reg <= 2'b0;
            hit_way_reg <= {$clog2(NUM_WAY){1'b0}};
            output_from_hit_reg <= 1'b0;
            
            // Reset cache storage
            for (int s=0; s<NUM_SET; s++) begin
                fifo_ptr[s] <= '0;
                for (int w=0; w<NUM_WAY; w++) begin
                    valid[s][w] <= 1'b0;
                    dirty[s][w] <= 1'b0;
                    dirty_debug <= 0;
                    tag_array[s][w] <= 28'b0;
                    data_array[s][w] <= 32'b0;
                end
            end
        end 
        else begin
            current_state <= next_state;

            if (current_state == IDLE && i_mem_access) begin
                req_addr_reg <= i_addr;
                req_wdata_reg <= i_wdata;
                req_wr_en_reg <= i_wr_en;
                req_byte_mask_reg <= i_byte_mask;
            end

            if (current_state == CHECK_CACHE && hit) begin
                hit_index_reg <= index;
                hit_way_reg <= hit_way;
                output_from_hit_reg <= 1'b1;
            end

            // ===================================================
            // LATCH MISS INFO: when CHECK_CACHE detects miss
            // ===================================================
            if (current_state == CHECK_CACHE && !hit) begin
                
                miss_addr_reg  <= req_addr_reg;
                miss_wdata_reg <= req_wdata_reg;
                miss_wr_en_reg <= req_wr_en_reg;  
                victim_way_reg <= victim_way;
                miss_index_reg <= index;
                miss_tag_reg   <= tag;
                
                victim_dirty_reg <= dirty[index][victim_way];  // Latch victim's dirty bit NOW
                need_writeback_reg <= dirty[index][victim_way];  // Latch writeback decision NOW
                //victim address: victim_tag || index
                victim_addr_reg <= {tag_array[index][victim_way], index};
                output_from_hit_reg <= 1'b0;
            end

            // ===================================================
            // UPDATE CACHE: Sync cache with SRAM
            // ===================================================
            if (current_state == UPDATE_CACHE) begin
                // Update victim cache line with SRAM data
                tag_array[miss_index_reg][victim_way_reg]  <= miss_tag_reg;
                valid[miss_index_reg][victim_way_reg]      <= 1'b1;

                // Set dirty based on operation type
                if (miss_wr_en_reg) begin
                    // STORE operation: overwrite with write data and mark dirty
                    data_array[miss_index_reg][victim_way_reg] <= write_with_mask(i_sram_rdata, miss_wdata_reg, req_byte_mask_reg);
                    dirty[miss_index_reg][victim_way_reg]      <= 1'b1;
                    dirty_debug <= 1;
                end else begin
                    // LOAD operation: data from SRAM, mark clean
                    data_array[miss_index_reg][victim_way_reg] <= i_sram_rdata;
                    dirty[miss_index_reg][victim_way_reg]      <= 1'b0;
                    dirty_debug <= 0;
                end

                // Increment FIFO pointer for next victim selection
                fifo_ptr[miss_index_reg] <= fifo_ptr[miss_index_reg] + 1;
            end

            // ===================================================
            // WRITE HIT: Update cache on write hits
            // ===================================================
            if (current_state == CHECK_CACHE && hit && req_wr_en_reg) begin
                // Write hit: update data and mark dirty
                dirty[index][hit_way]      <= 1'b1;
                dirty_debug <= 1;
                data_array[index][hit_way] <= write_with_mask(data_array[index][hit_way], req_wdata_reg, req_byte_mask_reg);
            end
        end
    end

    // -----------------------------------
    // FSM OUTPUT (COMBINATIONAL)
    // -----------------------------------
    always_comb begin
        case(current_state)
            IDLE: begin
                // Idle: no activity
                stall = 1'b0;
                o_sram_enb = 1'b0;
                o_sram_addr = 32'b0;
                o_sram_wr_en = 1'b0;
                o_sram_wdata = 32'b0;
                o_cache_done = 1'b0;
                o_rdata = 32'b0;
            end

            CHECK_CACHE: begin
                stall        = 1'b1;
                o_sram_enb   = 1'b0; // No SRAM access in CHECK_CACHE
                o_sram_addr  = 32'b0;
                o_sram_wr_en = 1'b0;
                o_sram_wdata = 32'b0;
                o_cache_done = 1'b0;
                //o_rdata      = 32'b0; // Default read data
            end

            WRITEBACK_L2: begin
                // Write dirty victim back to L2
                stall      = 1'b1;
                o_sram_enb   = 1'b1;
                o_sram_addr  = victim_addr_reg;  // Victim's original address
                o_sram_wr_en = 1'b1;             // Write mode
                o_sram_wdata = data_array[miss_index_reg][victim_way_reg];  // Victim data
                //$display("WRITEBACK ADDR: %h, DATA: %h, TIME = %d", victim_addr_reg, data_array[miss_index_reg][victim_way_reg], $time);
            end

            L2_READ: begin
                // LOAD missed line from L2
                stall      = 1'b1;
                o_sram_enb   = 1'b1;
                o_sram_addr  = miss_addr_reg;
                o_sram_wr_en = 1'b0;  // Read mode
                o_sram_wdata = 32'b0;
                //$display("RAM READ ADDR: %h, TIME = %d", miss_addr_reg, $time);
            end

            UPDATE_CACHE: begin
                // Update cache from SRAM: stall for 1 cycle
                stall = 1'b1;
                o_sram_enb   = 1'b0; // No SRAM access here
                o_sram_addr  = miss_addr_reg;
                o_sram_wr_en = 1'b0;  
                o_sram_wdata = 32'b0;
                //$display("UPDATE CACHE FROM SRAM ADDR: %h, DATA: %h, TIME = %d", miss_addr_reg, i_sram_rdata, $time);
            end

            OUTPUT_DATA: begin
                // Data ready: return to IDLE next cycle
                stall = 1'b1;
                o_sram_enb   = 1'b0; // No SRAM access here
                o_sram_addr  = miss_addr_reg;
                o_sram_wr_en = 1'b0;  
                o_sram_wdata = 32'b0;
                o_cache_done = 1'b1;
                // Return data based on path reaching OUTPUT_DATA
                if (output_from_hit_reg)
                    o_rdata = data_array[hit_index_reg][hit_way_reg];
                else
                    o_rdata = data_array[miss_index_reg][victim_way_reg];
            end

            default: begin
                stall = 1'b0;
                o_sram_enb   = 1'b0;
                o_sram_addr  = 32'b0;
                o_sram_wr_en = 1'b0;
                o_sram_wdata = 32'b0;
                o_rdata      = 32'b0;
                o_cache_done = 1'b0;
            end
        endcase
        
    end

endmodule
