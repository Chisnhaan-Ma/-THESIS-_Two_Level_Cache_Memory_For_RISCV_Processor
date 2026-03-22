module cache_l2 (
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

    output logic         o_sram_enb,
    output logic [31:0]  o_sram_addr,
    output logic         o_sram_wr_en,
    output logic [31:0]  o_sram_wdata,
    input  logic [31:0]  i_sram_rdata,
    input  logic         i_sram_ready
);
    localparam int NUM_SET = 16;
    localparam int NUM_WAY = 8;

    logic valid   [NUM_SET][NUM_WAY];
    logic dirty   [NUM_SET][NUM_WAY];
    logic [25:0] tag_array [NUM_SET][NUM_WAY];
    logic [31:0] data_array[NUM_SET][NUM_WAY];
    logic [$clog2(NUM_WAY)-1:0] fifo_ptr[NUM_SET];

    logic [31:0] req_addr_reg;
    logic [31:0] req_wdata_reg;
    logic [3:0]  req_byte_mask_reg;
    logic        req_wr_en_reg;

    logic [3:0]  req_index;
    logic [25:0] req_tag;

    logic [NUM_WAY-1:0] way_hit;
    logic hit;
    logic [$clog2(NUM_WAY)-1:0] hit_way;
    logic [$clog2(NUM_WAY)-1:0] victim_way;

    logic [31:0] victim_addr_reg;
    logic [31:0] refill_data_reg;
    logic        hit_on_req;

    typedef enum logic [2:0] {
        S_IDLE      = 3'b000,
        S_LOOKUP    = 3'b001,
        S_WRITEBACK = 3'b010,
        S_ALLOCATE  = 3'b011,
        S_REFILL    = 3'b100,
        S_RESP      = 3'b101
    } state_t;

    state_t state, next_state;

    function automatic logic [31:0] write_with_mask(
        input logic [31:0] old_data,
        input logic [31:0] new_data,
        input logic [3:0]  byte_mask
    );
        begin
            case (byte_mask)
                4'b0001: write_with_mask = {old_data[31:8], new_data[7:0]};
                4'b0010: write_with_mask = {old_data[31:16], new_data[15:8], old_data[7:0]};
                4'b0100: write_with_mask = {old_data[31:24], new_data[23:16], old_data[15:0]};
                4'b1000: write_with_mask = {new_data[31:24], old_data[23:0]};
                4'b0011: write_with_mask = {old_data[31:16], new_data[15:0]};
                4'b1100: write_with_mask = {new_data[31:16], old_data[15:0]};
                4'b1111: write_with_mask = new_data;
                default: write_with_mask = old_data;
            endcase
        end
    endfunction

    assign req_index  = req_addr_reg[5:2];
    assign req_tag    = req_addr_reg[31:6];
    assign victim_way = fifo_ptr[req_index];

    always_comb begin
        for (int w = 0; w < NUM_WAY; w++)
            way_hit[w] = valid[req_index][w] && (tag_array[req_index][w] == req_tag);
    end

    assign hit = |way_hit;

    always_comb begin
        hit_way = '0;
        for (int w = 0; w < NUM_WAY; w++)
            if (way_hit[w]) hit_way = w;
    end

    assign o_hit_debug  = (state == S_LOOKUP) && hit;
    assign o_miss_debug = (state == S_LOOKUP) && !hit;

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (i_req_valid)
                    next_state = S_LOOKUP;
            end

            S_LOOKUP: begin
                if (hit)
                    next_state = S_RESP;
                else if (dirty[req_index][victim_way])
                    next_state = S_WRITEBACK;
                else
                    next_state = S_ALLOCATE;
            end

            S_WRITEBACK: begin
                if (i_sram_ready)
                    next_state = S_ALLOCATE;
            end

            S_ALLOCATE: begin
                if (i_sram_ready)
                    next_state = S_REFILL;
            end

            S_REFILL: begin
                next_state = S_RESP;
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
            victim_addr_reg <= 32'b0;
            refill_data_reg <= 32'b0;
            hit_on_req <= 1'b0;

            for (int s = 0; s < NUM_SET; s++) begin
                fifo_ptr[s] <= '0;
                for (int w = 0; w < NUM_WAY; w++) begin
                    valid[s][w] <= 1'b0;
                    dirty[s][w] <= 1'b0;
                    tag_array[s][w] <= 26'b0;
                    data_array[s][w] <= 32'b0;
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

            if (state == S_LOOKUP) begin
                hit_on_req <= hit;
                victim_addr_reg <= {tag_array[req_index][victim_way], req_index, 2'b00};

                if (hit && req_wr_en_reg) begin
                    data_array[req_index][hit_way] <= write_with_mask(data_array[req_index][hit_way], req_wdata_reg, req_byte_mask_reg);
                    dirty[req_index][hit_way] <= 1'b1;
                end
            end

            if (state == S_ALLOCATE && i_sram_ready) begin
                refill_data_reg <= i_sram_rdata;
            end

            if (state == S_REFILL) begin
                tag_array[req_index][victim_way] <= req_tag;
                valid[req_index][victim_way] <= 1'b1;
                fifo_ptr[req_index] <= fifo_ptr[req_index] + 1'b1;

                if (req_wr_en_reg) begin
                    data_array[req_index][victim_way] <= write_with_mask(refill_data_reg, req_wdata_reg, req_byte_mask_reg);
                    dirty[req_index][victim_way] <= 1'b1;
                end else begin
                    data_array[req_index][victim_way] <= refill_data_reg;
                    dirty[req_index][victim_way] <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        o_stall = 1'b1;
        o_resp_valid = 1'b0;
        o_resp_rdata = 32'b0;

        o_sram_enb = 1'b0;
        o_sram_addr = 32'b0;
        o_sram_wr_en = 1'b0;
        o_sram_wdata = 32'b0;

        case (state)
            S_IDLE: begin
                o_stall = 1'b0;
            end

            S_WRITEBACK: begin
                o_sram_enb = 1'b1;
                o_sram_addr = victim_addr_reg;
                o_sram_wr_en = 1'b1;
                o_sram_wdata = data_array[req_index][victim_way];
            end

            S_ALLOCATE: begin
                o_sram_enb = 1'b1;
                o_sram_addr = req_addr_reg;
                o_sram_wr_en = 1'b0;
            end

            S_RESP: begin
                o_stall = 1'b0;
                o_resp_valid = 1'b1;
                if (!req_wr_en_reg) begin
                    if (hit_on_req)
                        o_resp_rdata = data_array[req_index][hit_way];
                    else
                        o_resp_rdata = data_array[req_index][victim_way];
                end
            end

            default: begin
            end
        endcase
    end

endmodule
