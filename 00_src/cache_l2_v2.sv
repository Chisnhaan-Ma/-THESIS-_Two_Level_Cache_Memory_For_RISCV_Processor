module cache_l2_v2 #(
    // IS61LV25616 is 256K x 16 -> 262144 halfwords -> 131072 words (32-bit).
    // Cache configuration
    // 8 sets, 32-way associative, 32-bit line size 
    // Total L2 memory = 8 * 32 * 4 bytes = 1024 bytes total.
    parameter int NUM_SET = 8,
    parameter int NUM_WAY = 32,
    parameter int RD_WAIT_TIME = 5  // Wait cycles for SRAM propagation (1 cycle = 10ns with 10ns clock)
) (
    // Clock/reset.
    input  logic         i_clk,            // System clock.
    input  logic         i_reset,          // Async reset, active high.

    // Request channel from upper level (CPU/L1 side).
    input  logic         i_req_valid,      // 1 when request fields are valid.
    input  logic         i_req_wr_en,      // 1=write, 0=read.
    input  logic [31:0]  i_req_addr,       // Byte address from requester.
    input  logic [31:0]  i_req_wdata,      // Write data for store.

    // Response/flow-control toward upper level.
    output logic [31:0]  o_resp_rdata,     // Returned read data (valid with o_resp_valid).
    output logic         o_resp_valid,     // One-cycle response valid pulse in RESP.
    output logic         o_stall,          // Back-pressure: 1 while request is being processed.
    output logic         o_hit_debug,      // Debug pulse: request hit at tag check stage.
    output logic         o_miss_debug,     // Debug pulse: request miss at tag check stage.

    // Backing-memory interface (L2 miss path)
    output logic         o_sram_enb,       // Transaction enable toward backing memory.
    output logic [31:0]  o_sram_addr,      // Line address for writeback/allocate.
    output logic         o_sram_wr_en,     // 1=writeback victim, 0=allocate/fetch line.
    output logic [31:0]  o_sram_wdata,     // Victim line data during writeback.
    input  logic [31:0]  i_sram_rdata,     // Refill line data returned from backing memory.
    input  logic         i_sram_ready,

    // External IS61LV25616 interface used as L2 data store.
    output logic         o_l2sram_ce_n,    // Chip enable (active low).
    output logic         o_l2sram_oe_n,    // Output enable (active low, read cycle).
    output logic         o_l2sram_we_n,    // Write enable (active low, write cycle).
    output logic         o_l2sram_lb_n,    // Lower byte enable (active low).
    output logic         o_l2sram_ub_n,    // Upper byte enable (active low).
    output logic [17:0]  o_l2sram_addr,    // Halfword address inside IS61.
    inout  wire  [15:0]  io_l2sram_dq       // Shared data bus (tri-stated when not driving).
);
    localparam int IDX_W   = $clog2(NUM_SET);
    localparam int WAY_W   = $clog2(NUM_WAY);
    localparam int TAG_W   = 32 - 2 - IDX_W;

    logic                  valid   [NUM_SET][NUM_WAY];
    logic                  dirty   [NUM_SET][NUM_WAY];
    logic [TAG_W-1:0]      tag_array [NUM_SET][NUM_WAY];
    logic [WAY_W-1:0]      fifo_ptr[NUM_SET];

    logic [31:0]           req_addr_reg;
    logic [31:0]           req_wdata_reg;
    logic                  req_wr_en_reg;

    logic [IDX_W-1:0]      req_index;
    logic [TAG_W-1:0]      req_tag;

    logic [NUM_WAY-1:0]    way_hit;
    logic                  hit;
    logic [WAY_W-1:0]      hit_way;
    logic [WAY_W-1:0]      victim_way;

    logic                  hit_on_req_reg;
    logic [WAY_W-1:0]      selected_way_reg;

    logic [31:0]           line_data_reg;
    logic [31:0]           write_word_reg;
    logic [31:0]           refill_data_reg;
    logic [31:0]           victim_data_reg;
    logic [31:0]           victim_addr_reg;
    logic [31:0]           resp_rdata_reg;
    logic                  write_from_refill_reg;

    logic [15:0]           l2sram_dq_out;
    logic                  l2sram_dq_oe;
    logic [15:0]           l2sram_dq_in;
    logic                  rd_wait_hi_reg;

    logic [$clog2(RD_WAIT_TIME+1)-1:0]  wait_counter;

    // FSM stages:
    // IDLE       : Wait for a new request, o_stall=0.
    // LOOKUP  : Compare request tag against all ways in indexed set.
    // RD_LO : Read lower 16-bit halfword from selected way.
    // RD_HI : Read upper 16-bit halfword from selected way.
    // RD_WAIT: Wait for SRAM propagation and capture current halfword.
    // RD_END: Assemble 32-bit line and decide hit-read/hit-write/miss-writeback.
    // WR_LO : Write lower 16-bit halfword into selected way.
    // WR_HI : Write upper 16-bit halfword and commit metadata update.
    // WRITEBACK  : Push dirty victim line to backing memory.
    // ALLOCATE   : Request refill line from backing memory.
    // REFILL: Prepare refill/merged-store data for SRAM write.
    // RESP       : Return response to requester and release stall.
    typedef enum logic [3:0] {
        IDLE        = 4'd0,
        LOOKUP   = 4'd1,
        RD_LO  = 4'd2,
        RD_HI  = 4'd3,
        RD_WAIT = 4'd11,
        RD_END = 4'd4,
        WR_LO  = 4'd5,
        WR_HI  = 4'd6,
        WRITEBACK   = 4'd7,
        ALLOCATE    = 4'd8,
        REFILL = 4'd9,
        RESP        = 4'd10
    } state_t;

    state_t state, next_state;

    function automatic logic [17:0] l2sram_half_addr(
        input logic [IDX_W-1:0] set_idx,
        input logic [WAY_W-1:0] way_idx,
        input logic             half_sel
    );
        begin
            // Full-chip mapping: [17:5]=way(13b), [4:1]=set(4b), [0]=halfword select.
            l2sram_half_addr = {way_idx, set_idx, half_sel};
        end
    endfunction

    assign l2sram_dq_in = io_l2sram_dq;
    assign io_l2sram_dq = l2sram_dq_oe ? l2sram_dq_out : 16'hzzzz;

    assign req_index  = req_addr_reg[IDX_W+1:2];
    assign req_tag    = req_addr_reg[31:IDX_W+2];
    assign victim_way = fifo_ptr[req_index];

    always @* begin
        for (int w = 0; w < NUM_WAY; w = w + 1)
            way_hit[w] = valid[req_index][w] && (tag_array[req_index][w] == req_tag);
    end

    assign hit = |way_hit;

    always @* begin
        hit_way = '0;
        for (int w = 0; w < NUM_WAY; w = w + 1)
            if (way_hit[w])
                hit_way = w[WAY_W-1:0];
    end

    assign o_hit_debug  = (state == LOOKUP) && hit;
    assign o_miss_debug = (state == LOOKUP) && !hit;

    always @* begin
        next_state = state;

        case (state)
            IDLE: begin
                if (i_req_valid)
                    next_state = LOOKUP;
            end

            LOOKUP: begin
                if (hit)
                    next_state = RD_LO;
                else if (valid[req_index][victim_way] && dirty[req_index][victim_way])
                    next_state = RD_LO;
                else
                    next_state = ALLOCATE;
            end

            RD_LO: begin
                next_state = RD_WAIT;
            end

            RD_HI: begin
                next_state = RD_WAIT;
            end

            RD_WAIT: begin
                if (wait_counter == 0) begin
                    if (rd_wait_hi_reg)
                        next_state = RD_END;
                    else
                        next_state = RD_HI;
                end else
                    next_state = RD_WAIT;
            end

            RD_END: begin
                if (hit_on_req_reg) begin
                    if (req_wr_en_reg)
                        next_state = WR_LO;
                    else
                        next_state = RESP;
                end else begin
                    next_state = WRITEBACK;
                end
            end

            WR_LO: begin
                next_state = WR_HI;
            end

            WR_HI: begin
                next_state = RESP;
            end

            WRITEBACK: begin
                if (i_sram_ready)
                    next_state = ALLOCATE;
            end

            ALLOCATE: begin
                if (i_sram_ready)
                    next_state = REFILL;
            end

            REFILL: begin
                next_state = WR_LO;
            end

            RESP: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            state <= IDLE;
            req_addr_reg <= 32'b0;
            req_wdata_reg <= 32'b0;
            req_wr_en_reg <= 1'b0;

            hit_on_req_reg <= 1'b0;
            selected_way_reg <= '0;

            line_data_reg <= 32'b0;
            write_word_reg <= 32'b0;
            refill_data_reg <= 32'b0;
            victim_data_reg <= 32'b0;
            victim_addr_reg <= 32'b0;
            resp_rdata_reg <= 32'b0;
            write_from_refill_reg <= 1'b0;
            wait_counter <= '0;
            rd_wait_hi_reg <= 1'b0;

            for (int s = 0; s < NUM_SET; s = s + 1) begin
                fifo_ptr[s] <= '0;
                for (int w = 0; w < NUM_WAY; w = w + 1) begin
                    valid[s][w] <= 1'b0;
                    dirty[s][w] <= 1'b0;
                    tag_array[s][w] <= '0;
                end
            end
        end else begin
            state <= next_state;

            if (state == IDLE && i_req_valid) begin
                req_addr_reg <= i_req_addr;
                req_wdata_reg <= i_req_wdata;
                req_wr_en_reg <= i_req_wr_en;
            end

            if (state == LOOKUP) begin
                hit_on_req_reg <= hit;

                if (hit) begin
                    selected_way_reg <= hit_way;
                end else begin
                    selected_way_reg <= victim_way;
                    victim_addr_reg <= {tag_array[req_index][victim_way], req_index, 2'b00};
                end
            end

            if (state == RD_WAIT && wait_counter == 0) begin
                if (rd_wait_hi_reg)
                    line_data_reg[31:16] <= l2sram_dq_in;
                else
                    line_data_reg[15:0] <= l2sram_dq_in;
            end

            if (state == RD_LO && next_state == RD_WAIT) begin
                wait_counter <= RD_WAIT_TIME;
                rd_wait_hi_reg <= 1'b0;
            end else if (state == RD_HI && next_state == RD_WAIT) begin
                wait_counter <= RD_WAIT_TIME;
                rd_wait_hi_reg <= 1'b1;
            end else if (state == RD_WAIT && wait_counter > 0) begin
                wait_counter <= wait_counter - 1'b1;
            end

            if (state == RD_END) begin
                if (hit_on_req_reg) begin
                    if (req_wr_en_reg) begin
                        write_word_reg <= req_wdata_reg;
                        write_from_refill_reg <= 1'b0;
                    end else begin
                        resp_rdata_reg <= line_data_reg;
                    end
                end else begin
                    victim_data_reg <= line_data_reg;
                end
            end

            if (state == ALLOCATE && i_sram_ready) begin
                refill_data_reg <= i_sram_rdata;
                write_word_reg <= req_wr_en_reg
                    ? req_wdata_reg
                    : i_sram_rdata;
                write_from_refill_reg <= 1'b1;
            end

            if (state == WR_HI) begin
                if (write_from_refill_reg) begin
                    tag_array[req_index][selected_way_reg] <= req_tag;
                    valid[req_index][selected_way_reg] <= 1'b1;
                    dirty[req_index][selected_way_reg] <= req_wr_en_reg;
                    fifo_ptr[req_index] <= fifo_ptr[req_index] + 1'b1;

                    if (!req_wr_en_reg)
                        resp_rdata_reg <= refill_data_reg;
                end else begin
                    dirty[req_index][selected_way_reg] <= 1'b1;
                end
            end
        end
    end

// synopsys translate_off
    always @(posedge i_clk) begin
        if (!i_reset) begin
            if (state == LOOKUP) begin
                if (hit) begin
                    $display("[L2 HIT ] t=%0t addr=0x%08h set=%0d way=%0d %s req_wdata=0x%08h",
                        $time, req_addr_reg, req_index, hit_way,
                        req_wr_en_reg ? "WRITE" : "READ",
                        req_wdata_reg);
                end else begin
                    $display("[L2 MISS] t=%0t addr=0x%08h set=%0d victim_way=%0d %s req_wdata=0x%08h -> evict_addr=0x%08h",
                        $time, req_addr_reg, req_index, victim_way,
                        req_wr_en_reg ? "WRITE" : "READ",
                        req_wdata_reg,
                        {tag_array[req_index][victim_way], req_index, 2'b00});
                end
            end

            if (state == RD_END) begin
                if (hit_on_req_reg) begin
                    if (req_wr_en_reg) begin
                        $display("[L2 HIT-DATA ] t=%0t addr=0x%08h WRITE old_line=0x%08h new_line=0x%08h",
                            $time, req_addr_reg, line_data_reg, req_wdata_reg);
                    end else begin
                        $display("[L2 HIT-DATA ] t=%0t addr=0x%08h READ rdata=0x%08h",
                            $time, req_addr_reg, line_data_reg);
                    end
                end else begin
                    $display("[L2 VICTIM  ] t=%0t evict_addr=0x%08h victim_data=0x%08h",
                        $time, victim_addr_reg, line_data_reg);
                end
            end

            if (state == ALLOCATE && i_sram_ready) begin
                $display("[L2 REFILL ] t=%0t addr=0x%08h from_main=0x%08h req_wdata=0x%08h final_line=0x%08h",
                    $time, req_addr_reg, i_sram_rdata, req_wdata_reg,
                    (req_wr_en_reg ? req_wdata_reg : i_sram_rdata));
            end
        end
    end
// synopsys translate_on

    always @* begin
        // Backing-memory defaults.
        o_sram_enb   = 1'b0;
        o_sram_addr  = 32'b0;
        o_sram_wr_en = 1'b0;
        o_sram_wdata = 32'b0;

        // Response defaults.
        o_stall      = 1'b1;
        o_resp_valid = 1'b0;
        o_resp_rdata = 32'b0;

        // External IS61 defaults: deselect chip.
        o_l2sram_ce_n = 1'b1;
        o_l2sram_oe_n = 1'b1;
        o_l2sram_we_n = 1'b1;
        o_l2sram_lb_n = 1'b1;
        o_l2sram_ub_n = 1'b1;
        o_l2sram_addr = 18'b0;
        l2sram_dq_oe  = 1'b0;
        l2sram_dq_out = 16'b0;

        case (state)
            IDLE: begin
                o_stall = 1'b0;
            end

            RD_LO: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b0;
                o_l2sram_we_n = 1'b1;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b0);
            end

            RD_HI: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b0;
                o_l2sram_we_n = 1'b1;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b1);
            end

            RD_WAIT: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b0;
                o_l2sram_we_n = 1'b1;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, rd_wait_hi_reg);
            end

            WR_LO: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b1;
                o_l2sram_we_n = 1'b0;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b0);
                l2sram_dq_oe  = 1'b1;
                l2sram_dq_out = write_word_reg[15:0];
            end

            WR_HI: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b1;
                o_l2sram_we_n = 1'b0;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b1);
                l2sram_dq_oe  = 1'b1;
                l2sram_dq_out = write_word_reg[31:16];
            end

            WRITEBACK: begin
                o_sram_enb   = 1'b1;
                o_sram_addr  = victim_addr_reg;
                o_sram_wr_en = 1'b1;
                o_sram_wdata = victim_data_reg;
            end

            ALLOCATE: begin
                o_sram_enb   = 1'b1;
                o_sram_addr  = req_addr_reg;
                o_sram_wr_en = 1'b0;
            end

            RESP: begin
                o_stall      = 1'b0;
                o_resp_valid = 1'b1;
                if (!req_wr_en_reg)
                    o_resp_rdata = resp_rdata_reg;
            end

            default: begin
            end
        endcase
    end

endmodule
