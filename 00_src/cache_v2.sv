module cache_v2 (
    input  logic         i_clk,
    input  logic         i_reset,

    input  logic         i_mem_access,
    input  logic         i_wr_en,
    input  logic  [3:0]  i_byte_mask,
    input  logic [31:0]  i_addr,
    input  logic [31:0]  i_wdata,
    output logic [31:0]  o_rdata,
    output logic         o_hit_debug,
    output logic         o_miss_debug,
    output logic         o_stall,
    output logic         o_cache_done,

    output logic         o_cache_l2_enb,
    output logic [31:0]  o_cache_l2_addr,
    output logic         o_cache_l2_wr_en,
    output logic [31:0]  o_cache_l2_wdata,
    input  logic [31:0]  i_cache_l2_rdata,
    input  logic         i_cache_l2_ready
);
    // Cache configuration
    // 4 sets, 16-way associative, 32-bit line size
    // Total cache size = 4 sets * 16 ways * 4 bytes = 256 bytes
    localparam int NUM_SET = 4;
    localparam int NUM_WAY = 16;
    localparam int INDEX_BITS = $clog2(NUM_SET);
    localparam int TAG_BITS = 32 - INDEX_BITS - 2;

    logic [31:0] req_addr_reg;
    logic [31:0] req_wdata_reg;
    logic        req_wr_en_reg;
    logic [3:0]  req_byte_mask_reg;

    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;
    assign index = req_addr_reg[2 +: INDEX_BITS];
    assign tag   = req_addr_reg[31 -: TAG_BITS];

    logic valid   [NUM_SET][NUM_WAY];
    logic dirty   [NUM_SET][NUM_WAY];
    logic [TAG_BITS-1:0] tag_array [NUM_SET][NUM_WAY];
    logic [31:0] data_array[NUM_SET][NUM_WAY];
    logic [$clog2(NUM_WAY)-1:0] fifo_ptr[NUM_SET];

    logic stall;

    logic [NUM_WAY-1:0] way_hit;
    logic hit;
    logic [$clog2(NUM_WAY)-1:0] hit_way;

    logic [31:0]  miss_addr_reg;
    logic [31:0]  miss_wdata_reg;
    logic         miss_wr_en_reg;
    logic [3:0]   miss_byte_mask_reg;
    logic [$clog2(NUM_WAY)-1:0] victim_way_reg;
    logic [INDEX_BITS-1:0] miss_index_reg;
    logic [TAG_BITS-1:0]  miss_tag_reg;
    logic [31:0]  victim_addr_reg;
    logic [INDEX_BITS-1:0] hit_index_reg;
    logic [$clog2(NUM_WAY)-1:0] hit_way_reg;
    logic         output_from_hit_reg;
    logic         allocate_wait_reg;
    logic [31:0]  refill_data_reg;

    logic [$clog2(NUM_WAY)-1:0] victim_way;
    assign victim_way = fifo_ptr[index];

    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        LOOKUP    = 3'b001,
        WRITEBACK = 3'b010,
        ALLOCATE  = 3'b011,
        REFILL    = 3'b100,
        RESPONE   = 3'b101
    } state_t;

    state_t current_state, next_state;

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

    always_comb begin
        for (int w = 0; w < NUM_WAY; w++)
            way_hit[w] = valid[index][w] && (tag_array[index][w] == tag);
    end

    assign hit = |way_hit;

    always_comb begin
        hit_way = '0;
        for (int w = 0; w < NUM_WAY; w++)
            if (way_hit[w]) hit_way = w;
    end

    assign o_hit_debug  = (current_state == LOOKUP) && hit;
    assign o_miss_debug = (current_state == LOOKUP) && !hit;
    assign o_stall = stall;

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (i_mem_access)
                    next_state = LOOKUP;
            end

            LOOKUP: begin
                if (hit)
                    next_state = RESPONE;
                else if (valid[index][victim_way] && dirty[index][victim_way])
                    next_state = WRITEBACK;
                else
                    next_state = ALLOCATE;
            end

            WRITEBACK: begin
                if (i_cache_l2_ready)
                    next_state = ALLOCATE;
            end

            ALLOCATE: begin
                // Ignore stale ready pulse from prior WRITEBACK response.
                if (allocate_wait_reg && i_cache_l2_ready)
                    next_state = REFILL;
            end

            REFILL: begin
                next_state = RESPONE;
            end

            RESPONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            current_state <= IDLE;
            req_addr_reg <= 32'b0;
            req_wdata_reg <= 32'b0;
            req_wr_en_reg <= 1'b0;
            req_byte_mask_reg <= 4'b0;

            miss_addr_reg <= 32'b0;
            miss_wdata_reg <= 32'b0;
            miss_wr_en_reg <= 1'b0;
            miss_byte_mask_reg <= 4'b0;
            victim_way_reg <= '0;
            miss_index_reg <= '0;
            miss_tag_reg <= '0;
            victim_addr_reg <= 32'b0;

            hit_index_reg <= '0;
            hit_way_reg <= '0;
            output_from_hit_reg <= 1'b0;
            allocate_wait_reg <= 1'b0;
            refill_data_reg <= 32'b0;

            for (int s = 0; s < NUM_SET; s++) begin
                fifo_ptr[s] <= '0;
                for (int w = 0; w < NUM_WAY; w++) begin
                    valid[s][w] <= 1'b0;
                    dirty[s][w] <= 1'b0;
                    tag_array[s][w] <= '0;
                    data_array[s][w] <= 32'b0;
                end
            end
        end else begin
            current_state <= next_state;

            if (current_state != ALLOCATE)
                allocate_wait_reg <= 1'b0;
            else if (!allocate_wait_reg)
                allocate_wait_reg <= 1'b1;

            if (current_state == IDLE && i_mem_access) begin
                req_addr_reg <= i_addr;
                req_wdata_reg <= i_wdata;
                req_wr_en_reg <= i_wr_en;
                req_byte_mask_reg <= i_byte_mask;
            end

            if (current_state == LOOKUP && hit) begin
                hit_index_reg <= index;
                hit_way_reg <= hit_way;
                output_from_hit_reg <= 1'b1;
            end

            if (current_state == LOOKUP && !hit) begin
                miss_addr_reg <= req_addr_reg;
                miss_wdata_reg <= req_wdata_reg;
                miss_wr_en_reg <= req_wr_en_reg;
                miss_byte_mask_reg <= req_byte_mask_reg;
                victim_way_reg <= victim_way;
                miss_index_reg <= index;
                miss_tag_reg <= tag;
                victim_addr_reg <= {tag_array[index][victim_way], index, 2'b00};
                output_from_hit_reg <= 1'b0;
            end

            // Capture refill data when ready signal is asserted
            if ((current_state == WRITEBACK || current_state == ALLOCATE) && i_cache_l2_ready) begin
                refill_data_reg <= i_cache_l2_rdata;
            end

            if (current_state == REFILL) begin
                tag_array[miss_index_reg][victim_way_reg] <= miss_tag_reg;
                valid[miss_index_reg][victim_way_reg] <= 1'b1;

                if (miss_wr_en_reg) begin
                    data_array[miss_index_reg][victim_way_reg] <= write_with_mask(refill_data_reg, miss_wdata_reg, miss_byte_mask_reg);
                    dirty[miss_index_reg][victim_way_reg] <= 1'b1;
                end else begin
                    data_array[miss_index_reg][victim_way_reg] <= refill_data_reg;
                    dirty[miss_index_reg][victim_way_reg] <= 1'b0;
                end

                fifo_ptr[miss_index_reg] <= fifo_ptr[miss_index_reg] + 1'b1;
            end

            if (current_state == LOOKUP && hit && req_wr_en_reg) begin
                data_array[index][hit_way] <= write_with_mask(data_array[index][hit_way], req_wdata_reg, req_byte_mask_reg);
                dirty[index][hit_way] <= 1'b1;
            end
        end
    end


     always_comb begin
        /*
        stall = 1'b0;
        o_cache_l2_enb = 1'b0;
        o_cache_l2_addr = 32'b0;
        o_cache_l2_wr_en = 1'b0;
        o_cache_l2_wdata = 32'b0;
        o_cache_done = 1'b0;
        o_rdata = 32'b0;
        */
        case (current_state)
            IDLE: begin
                stall = 1'b0;
                o_cache_l2_enb = 1'b0;
                o_cache_l2_addr = 32'b0;
                o_cache_l2_wr_en = 1'b0;
                o_cache_l2_wdata = 32'b0;
                o_cache_done = 1'b0;
                o_rdata = data_array[index][hit_way];
            end

            LOOKUP: begin
                stall = 1'b1;
                o_cache_l2_enb = 1'b0;
                o_cache_l2_addr = 32'b0;
                o_cache_l2_wr_en = 1'b0;
                o_cache_l2_wdata = 32'b0;
                o_cache_done = 1'b0;
                o_rdata = data_array[index][hit_way];
            end

            WRITEBACK: begin
                stall = 1'b1;
                o_cache_l2_enb = 1'b1;
                o_cache_l2_addr = victim_addr_reg;
                o_cache_l2_wr_en = 1'b1;
                o_cache_l2_wdata = data_array[miss_index_reg][victim_way_reg];
                o_cache_done = 1'b0;
                o_rdata = 0;
            end

            ALLOCATE: begin
                stall = 1'b1;
                o_cache_l2_enb = 1'b1;
                o_cache_l2_addr = miss_addr_reg;
                o_cache_l2_wr_en = 1'b0;
                o_cache_l2_wdata = 32'b0;
                o_cache_done = 1'b0;
                o_rdata = data_array[index][hit_way];
            end

            REFILL: begin
                stall = 1'b1;
                o_cache_l2_enb = 1'b0;
                o_cache_l2_addr = 32'b0;
                o_cache_l2_wr_en = 1'b0;
                o_cache_l2_wdata = 32'b0;
                o_cache_done = 1'b0;
                o_rdata = data_array[index][hit_way];
            end

            RESPONE: begin
                stall = 1'b1;
                o_cache_done = 1'b1;
					 o_cache_l2_enb = 1'b0;
					 o_cache_l2_addr = 32'b0;
					 o_cache_l2_wdata = 32'b0;
					 o_cache_l2_wr_en = 1'b0;
                if (output_from_hit_reg)
                    o_rdata = data_array[hit_index_reg][hit_way_reg];
                else
                    o_rdata = data_array[miss_index_reg][victim_way_reg];
            end

            default: begin
            end
        endcase
    end

    // Simulation-only debug output (not synthesized)
`ifndef SYNTHESIS
    always @(posedge i_clk) begin
        if (!i_reset) begin
            if (current_state == LOOKUP && way_hit[hit_way]) begin
                $display("[L1 HIT ] t=%0t addr=0x%08h set=%0d way=%0d %s req_wdata=0x%08h line_data=0x%08h",
                    $time, req_addr_reg, index, hit_way,
                    req_wr_en_reg ? "WRITE" : "READ",
                    req_wdata_reg, data_array[index][hit_way]);
            end
            
            if (current_state == LOOKUP && !hit) begin
                $display("[L1 MISS] t=%0t addr=0x%08h set=%0d victim_way=%0d %s req_wdata=0x%08h -> evict_addr=0x%08h evict_data=0x%08h",
                    $time, req_addr_reg, index, victim_way,
                    req_wr_en_reg ? "WRITE" : "READ",
                    req_wdata_reg,
                    {tag_array[index][victim_way], index, 2'b00},
                    data_array[index][victim_way]);
                if (valid[index][victim_way]) begin
                    $display("[L1 REPL] t=%0t set=%0d way=%0d dirty=%0b evict_addr=0x%08h evict_data=0x%08h",
                        $time, index, victim_way, dirty[index][victim_way],
                        {tag_array[index][victim_way], index, 2'b00},
                        data_array[index][victim_way]);
                end
            end
            
            if (current_state == REFILL) begin
                if (miss_wr_en_reg) begin
                    $display("[L1 REFILL] t=%0t addr=0x%08h set=%0d way=%0d WRITE refill=0x%08h req_wdata=0x%08h final_line=0x%08h",
                        $time, miss_addr_reg, miss_index_reg, victim_way_reg,
                        refill_data_reg, miss_wdata_reg,
                        write_with_mask(refill_data_reg, miss_wdata_reg, miss_byte_mask_reg));
                end else begin
                    $display("[L1 REFILL] t=%0t addr=0x%08h set=%0d way=%0d READ refill=0x%08h",
                        $time, miss_addr_reg, miss_index_reg, victim_way_reg, refill_data_reg);
                end
            end
        end
    end
`endif

endmodule
