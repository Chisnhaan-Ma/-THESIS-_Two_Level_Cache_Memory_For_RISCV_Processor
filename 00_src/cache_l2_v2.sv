module cache_l2_v2 #(
    // IS61LV25616 is 256K x 16 -> 262144 halfwords -> 131072 words (32-bit).
    // With line size = 1 word and 8 ways, full utilization requires 16384 sets.
    parameter int NUM_SET = 16384,
    parameter int NUM_WAY = 8
) (
    input  logic         i_clk,
    input  logic         i_reset,

    input  logic         i_req_valid,
    input  logic         i_req_wr_en,
    input  logic  [3:0]  i_req_byte_mask,
    input  logic [31:0]  i_req_addr,
    input  logic [31:0]  i_req_wdata,

    output logic [31:0]  o_resp_rdata,
    output logic         o_resp_valid,
    output logic         o_stall,
    output logic         o_hit_debug,
    output logic         o_miss_debug,

    // Backing-memory interface (L2 miss path)
    output logic         o_sram_enb,
    output logic [31:0]  o_sram_addr,
    output logic         o_sram_wr_en,
    output logic [31:0]  o_sram_wdata,
    input  logic [31:0]  i_sram_rdata,
    input  logic         i_sram_ready,

    // External IS61LV25616 interface used as L2 data store.
    output logic         o_l2sram_ce_n,
    output logic         o_l2sram_oe_n,
    output logic         o_l2sram_we_n,
    output logic         o_l2sram_lb_n,
    output logic         o_l2sram_ub_n,
    output logic [17:0]  o_l2sram_addr,
    inout  wire [15:0]   io_l2sram_dq
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
    logic [3:0]            req_byte_mask_reg;
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

    typedef enum logic [3:0] {
        S_IDLE        = 4'd0,
        S_TAG_CHECK   = 4'd1,
        S_DATA_RD_LO  = 4'd2,
        S_DATA_RD_HI  = 4'd3,
        S_DATA_RD_END = 4'd4,
        S_DATA_WR_LO  = 4'd5,
        S_DATA_WR_HI  = 4'd6,
        S_WRITEBACK   = 4'd7,
        S_ALLOCATE    = 4'd8,
        S_REFILL_PREP = 4'd9,
        S_RESP        = 4'd10
    } state_t;

    state_t state, next_state;

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

    function automatic logic [17:0] l2sram_half_addr(
        input logic [IDX_W-1:0] set_idx,
        input logic [WAY_W-1:0] way_idx,
        input logic             half_sel
    );
        begin
            // Full-chip mapping: [17:15]=way, [14:1]=set, [0]=halfword select.
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

    assign o_hit_debug  = (state == S_TAG_CHECK) && hit;
    assign o_miss_debug = (state == S_TAG_CHECK) && !hit;

    always @* begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (i_req_valid)
                    next_state = S_TAG_CHECK;
            end

            S_TAG_CHECK: begin
                if (hit)
                    next_state = S_DATA_RD_LO;
                else if (valid[req_index][victim_way] && dirty[req_index][victim_way])
                    next_state = S_DATA_RD_LO;
                else
                    next_state = S_ALLOCATE;
            end

            S_DATA_RD_LO: begin
                next_state = S_DATA_RD_HI;
            end

            S_DATA_RD_HI: begin
                next_state = S_DATA_RD_END;
            end

            S_DATA_RD_END: begin
                if (hit_on_req_reg) begin
                    if (req_wr_en_reg)
                        next_state = S_DATA_WR_LO;
                    else
                        next_state = S_RESP;
                end else begin
                    next_state = S_WRITEBACK;
                end
            end

            S_DATA_WR_LO: begin
                next_state = S_DATA_WR_HI;
            end

            S_DATA_WR_HI: begin
                next_state = S_RESP;
            end

            S_WRITEBACK: begin
                if (i_sram_ready)
                    next_state = S_ALLOCATE;
            end

            S_ALLOCATE: begin
                if (i_sram_ready)
                    next_state = S_REFILL_PREP;
            end

            S_REFILL_PREP: begin
                next_state = S_DATA_WR_LO;
            end

            S_RESP: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            state <= S_IDLE;
            req_addr_reg <= 32'b0;
            req_wdata_reg <= 32'b0;
            req_byte_mask_reg <= 4'b0;
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

            if (state == S_IDLE && i_req_valid) begin
                req_addr_reg <= i_req_addr;
                req_wdata_reg <= i_req_wdata;
                req_byte_mask_reg <= i_req_byte_mask;
                req_wr_en_reg <= i_req_wr_en;
            end

            if (state == S_TAG_CHECK) begin
                hit_on_req_reg <= hit;

                if (hit) begin
                    selected_way_reg <= hit_way;
                end else begin
                    selected_way_reg <= victim_way;
                    victim_addr_reg <= {tag_array[req_index][victim_way], req_index, 2'b00};
                end
            end

            if (state == S_DATA_RD_LO) begin
                line_data_reg[15:0] <= l2sram_dq_in;
            end

            if (state == S_DATA_RD_HI) begin
                line_data_reg[31:16] <= l2sram_dq_in;
            end

            if (state == S_DATA_RD_END) begin
                if (hit_on_req_reg) begin
                    if (req_wr_en_reg) begin
                        write_word_reg <= write_with_mask(line_data_reg, req_wdata_reg, req_byte_mask_reg);
                        write_from_refill_reg <= 1'b0;
                    end else begin
                        resp_rdata_reg <= line_data_reg;
                    end
                end else begin
                    victim_data_reg <= line_data_reg;
                end
            end

            if (state == S_ALLOCATE && i_sram_ready) begin
                refill_data_reg <= i_sram_rdata;
                write_word_reg <= req_wr_en_reg
                    ? write_with_mask(i_sram_rdata, req_wdata_reg, req_byte_mask_reg)
                    : i_sram_rdata;
                write_from_refill_reg <= 1'b1;
            end

            if (state == S_DATA_WR_HI) begin
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
            S_IDLE: begin
                o_stall = 1'b0;
            end

            S_DATA_RD_LO: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b0;
                o_l2sram_we_n = 1'b1;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b0);
            end

            S_DATA_RD_HI: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b0;
                o_l2sram_we_n = 1'b1;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b1);
            end

            S_DATA_WR_LO: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b1;
                o_l2sram_we_n = 1'b0;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b0);
                l2sram_dq_oe  = 1'b1;
                l2sram_dq_out = write_word_reg[15:0];
            end

            S_DATA_WR_HI: begin
                o_l2sram_ce_n = 1'b0;
                o_l2sram_oe_n = 1'b1;
                o_l2sram_we_n = 1'b0;
                o_l2sram_lb_n = 1'b0;
                o_l2sram_ub_n = 1'b0;
                o_l2sram_addr = l2sram_half_addr(req_index, selected_way_reg, 1'b1);
                l2sram_dq_oe  = 1'b1;
                l2sram_dq_out = write_word_reg[31:16];
            end

            S_WRITEBACK: begin
                o_sram_enb   = 1'b1;
                o_sram_addr  = victim_addr_reg;
                o_sram_wr_en = 1'b1;
                o_sram_wdata = victim_data_reg;
            end

            S_ALLOCATE: begin
                o_sram_enb   = 1'b1;
                o_sram_addr  = req_addr_reg;
                o_sram_wr_en = 1'b0;
            end

            S_RESP: begin
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
