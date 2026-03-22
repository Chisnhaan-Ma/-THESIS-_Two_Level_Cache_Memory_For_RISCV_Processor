`ifndef SDRAM_CONTROLER
`define SDRAM_CONTROLER

// SDRAM controller for ISSI IS42S16400 on Altera DE2.
// User side uses a simple request/ready handshake compatible with sram.sv.
// Each 32-bit transaction is split into 2 x 16-bit SDRAM accesses.
// Closed-page policy is used (READ/WRITE with auto-precharge).

module sdram_controler #(
    // System clock frequency used to convert microseconds to clock cycles.
    parameter int CLK_FREQ_HZ            = 50_000_000,
    // Power-up wait time before issuing SDRAM commands.
    parameter int INIT_WAIT_US           = 200,
    // Refresh period in cycles (7.8us target at 50MHz).
    parameter int REFRESH_INTERVAL_CYC   = 390,   // ~7.8us @ 50MHz
    // SDRAM timing parameters expressed in controller clock cycles.
    parameter int TRP_CYCLES             = 2,
    parameter int TRCD_CYCLES            = 2,
    parameter int TRFC_CYCLES            = 4,
    parameter int TMRD_CYCLES            = 2,
    parameter int CAS_LATENCY_CYCLES     = 2,
    parameter int WRITE_RECOVERY_CYCLES  = 2
) (
    // Global clock/reset.
    input  logic        i_clk,
    input  logic        i_reset,

    // User/cache-side request interface.
    // i_sram_enb: request valid (one 32-bit transaction).
    // i_wr_en: 1=write, 0=read.
    // i_addr: byte address from CPU/cache side.
    // i_wdata: write data for write requests.
    input  logic        i_sram_enb,
    input  logic        i_wr_en,
    input  logic [31:0] i_addr,
    input  logic [31:0] i_wdata,

    // User/cache-side response interface.
    // o_rdata valid when o_ready pulses high.
    output logic [31:0] o_rdata,
    // o_ready pulses 1 cycle when one 32-bit transaction completes.
    output logic        o_ready,

    // SDRAM physical interface (IS42S16400-compatible signaling).
    // Command encoding uses CS#/RAS#/CAS#/WE# combinations.
    output logic        o_dram_clk,
    output logic        o_dram_cke,
    output logic        o_dram_cs_n,
    output logic        o_dram_ras_n,
    output logic        o_dram_cas_n,
    output logic        o_dram_we_n,
    output logic [1:0]  o_dram_ba,
    output logic [11:0] o_dram_addr,
    output logic        o_dram_ldqm,
    output logic        o_dram_udqm,
    inout  wire [15:0]  io_dram_dq
);

    // Number of cycles to wait after reset before init command sequence.
    localparam int INIT_WAIT_CYCLES = (CLK_FREQ_HZ / 1_000_000) * INIT_WAIT_US;
    // Guard against invalid/non-positive refresh interval configuration.
    localparam int REFRESH_INTERVAL_SAFE = (REFRESH_INTERVAL_CYC > 0) ? REFRESH_INTERVAL_CYC : 1;

    // BL=1, sequential burst, CAS=2, standard op mode, single write burst.
    localparam logic [11:0] MODE_REG = 12'b0010_0010_0000;

    // FSM state definitions.
    // S_INIT_WAIT : wait initial power-up delay.
    // S_INIT_PRE  : issue PRECHARGE ALL command.
    // S_INIT_TRP  : wait tRP after precharge.
    // S_INIT_AR1  : issue AUTO REFRESH #1.
    // S_INIT_AR1W : wait tRFC after refresh #1.
    // S_INIT_AR2  : issue AUTO REFRESH #2.
    // S_INIT_AR2W : wait tRFC after refresh #2.
    // S_INIT_MRS  : load SDRAM mode register.
    // S_INIT_TMRD : wait tMRD after MRS.
    // S_IDLE      : idle state, accept new request or refresh.
    // S_REF_CMD   : issue periodic AUTO REFRESH command.
    // S_REF_WAIT  : wait tRFC for periodic refresh.
    // S_ACTIVATE  : issue ACTIVATE with selected bank/row.
    // S_TRCD_WAIT : wait tRCD before READ/WRITE.
    // S_RW_CMD    : issue READ or WRITE command with auto-precharge.
    // S_READ_WAIT : wait CAS latency for READ.
    // S_READ_CAP  : capture read data from DQ bus.
    // S_PRE_WAIT  : wait post-access recovery/precharge time.
    // S_NEXT_HALF : move from low-half to high-half access.
    // S_DONE      : transaction done, pulse o_ready.
    typedef enum logic [4:0] {
        S_INIT_WAIT   = 5'd0,
        S_INIT_PRE    = 5'd1,
        S_INIT_TRP    = 5'd2,
        S_INIT_AR1    = 5'd3,
        S_INIT_AR1W   = 5'd4,
        S_INIT_AR2    = 5'd5,
        S_INIT_AR2W   = 5'd6,
        S_INIT_MRS    = 5'd7,
        S_INIT_TMRD   = 5'd8,
        S_IDLE        = 5'd9,
        S_REF_CMD     = 5'd10,
        S_REF_WAIT    = 5'd11,
        S_ACTIVATE    = 5'd12,
        S_TRCD_WAIT   = 5'd13,
        S_RW_CMD      = 5'd14,
        S_READ_WAIT   = 5'd15,
        S_READ_CAP    = 5'd16,
        S_PRE_WAIT    = 5'd17,
        S_NEXT_HALF   = 5'd18,
        S_DONE        = 5'd19
    } state_t;

    // Current and next FSM state.
    state_t state, next_state;

    // init_done indicates controller can start normal refresh and requests.
    logic        init_done;
    // req_accept is one-cycle internal strobe when request is latched.
    logic        req_accept;

    // Latched user request fields (held during multi-cycle SDRAM transaction).
    logic [31:0] req_addr_reg;
    logic [31:0] req_wdata_reg;
    logic        req_wr_en_reg;

    // Read data assembly register for 2 x 16-bit halfword read.
    logic [31:0] read_data_reg;

    // Generic wait counter reused by timing wait states.
    logic [15:0] wait_cnt;
    // Periodic refresh cycle counter.
    logic [15:0] refresh_cnt;
    // Refresh request flag set by scheduler and consumed in S_IDLE.
    logic        refresh_pending;

    logic        half_sel; // 0: lower 16-bit, 1: upper 16-bit
    // Derived halfword address in SDRAM word space.
    logic [21:0] halfword_addr;
    // Decoded bank/row/column from halfword address.
    logic [1:0]  cur_bank;
    logic [11:0] cur_row;
    logic [7:0]  cur_col;

    // DQ output path and output-enable for bidirectional data bus.
    logic [15:0] dq_out;
    logic        dq_oe;
    // Sampled DQ input data.
    logic [15:0] dq_in;

    // Column address placed on SDRAM address bus for READ/WRITE.
    // A10 is forced to 1 to enable auto-precharge.
    logic [11:0] rw_col_addr;

    // SDRAM clock is driven directly from controller clock.
    assign o_dram_clk = i_clk;
    // Internal alias for inbound data bus.
    assign dq_in = io_dram_dq;
    // Tri-state DQ bus except during write command cycles.
    assign io_dram_dq = dq_oe ? dq_out : 16'hzzzz;

    // Normal operation starts at S_IDLE and later states.
    assign init_done = (state >= S_IDLE);
    // Request is accepted only in IDLE and when refresh is not pending.
    assign req_accept = (state == S_IDLE) && (!refresh_pending) && i_sram_enb;

    // 32-bit byte address -> 16-bit halfword address.
    // Mapping: [21:20]=bank, [19:8]=row, [7:0]=column.
    always @* begin
        halfword_addr = req_addr_reg[22:1] + {21'b0, half_sel};

        cur_bank = halfword_addr[21:20];
        cur_row  = halfword_addr[19:8];
        cur_col  = halfword_addr[7:0];
        rw_col_addr = {4'b0100, cur_col};
    end

    always @* begin
        next_state = state;

        case (state)
            S_INIT_WAIT: begin
                if (wait_cnt == 0)
                    next_state = S_INIT_PRE;
                else
                    next_state = S_INIT_WAIT;
            end
            S_INIT_PRE:   next_state = S_INIT_TRP;
            S_INIT_TRP: begin
                if (wait_cnt == 0)
                    next_state = S_INIT_AR1;
                else
                    next_state = S_INIT_TRP;
            end
            S_INIT_AR1:   next_state = S_INIT_AR1W;
            S_INIT_AR1W: begin
                if (wait_cnt == 0)
                    next_state = S_INIT_AR2;
                else
                    next_state = S_INIT_AR1W;
            end
            S_INIT_AR2:   next_state = S_INIT_AR2W;
            S_INIT_AR2W: begin
                if (wait_cnt == 0)
                    next_state = S_INIT_MRS;
                else
                    next_state = S_INIT_AR2W;
            end
            S_INIT_MRS:   next_state = S_INIT_TMRD;
            S_INIT_TMRD: begin
                if (wait_cnt == 0)
                    next_state = S_IDLE;
                else
                    next_state = S_INIT_TMRD;
            end

            S_IDLE: begin
                if (refresh_pending)
                    next_state = S_REF_CMD;
                else if (i_sram_enb)
                    next_state = S_ACTIVATE;
                else
                    next_state = S_IDLE;
            end

            S_REF_CMD:    next_state = S_REF_WAIT;
            S_REF_WAIT: begin
                if (wait_cnt == 0)
                    next_state = S_IDLE;
                else
                    next_state = S_REF_WAIT;
            end

            S_ACTIVATE:   next_state = S_TRCD_WAIT;
            S_TRCD_WAIT: begin
                if (wait_cnt == 0)
                    next_state = S_RW_CMD;
                else
                    next_state = S_TRCD_WAIT;
            end
            S_RW_CMD: begin
                if (req_wr_en_reg)
                    next_state = S_PRE_WAIT;
                else
                    next_state = S_READ_WAIT;
            end
            S_READ_WAIT: begin
                if (wait_cnt == 0)
                    next_state = S_READ_CAP;
                else
                    next_state = S_READ_WAIT;
            end
            S_READ_CAP:   next_state = S_PRE_WAIT;
            S_PRE_WAIT: begin
                if (wait_cnt == 0)
                    next_state = S_NEXT_HALF;
                else
                    next_state = S_PRE_WAIT;
            end
            S_NEXT_HALF: begin
                if (half_sel == 1'b1)
                    next_state = S_DONE;
                else
                    next_state = S_ACTIVATE;
            end
            S_DONE:       next_state = S_IDLE;

            default:      next_state = S_INIT_WAIT;
        endcase
    end

    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            state            <= S_INIT_WAIT;
            wait_cnt         <= (INIT_WAIT_CYCLES > 0) ? INIT_WAIT_CYCLES - 1 : 0;
            refresh_cnt      <= 16'd0;
            refresh_pending  <= 1'b0;

            req_addr_reg     <= 32'd0;
            req_wdata_reg    <= 32'd0;
            req_wr_en_reg    <= 1'b0;

            read_data_reg    <= 32'd0;
            half_sel         <= 1'b0;
        end else begin
            state <= next_state;

            // Refresh scheduler runs only after initialization is complete.
            if (init_done) begin
                if (state == S_REF_CMD) begin
                    refresh_cnt <= 16'd0;
                    refresh_pending <= 1'b0;
                end else if (refresh_cnt >= REFRESH_INTERVAL_SAFE - 1) begin
                    refresh_cnt <= 16'd0;
                    refresh_pending <= 1'b1;
                end else begin
                    refresh_cnt <= refresh_cnt + 16'd1;
                end
            end else begin
                refresh_cnt <= 16'd0;
                refresh_pending <= 1'b0;
            end

            if (req_accept) begin
                req_addr_reg  <= i_addr;
                req_wdata_reg <= i_wdata;
                req_wr_en_reg <= i_wr_en;
            end

            case (state)
                S_INIT_WAIT: if (wait_cnt != 0) wait_cnt <= wait_cnt - 16'd1;

                S_INIT_PRE:  wait_cnt <= (TRP_CYCLES > 0) ? TRP_CYCLES - 1 : 0;
                S_INIT_TRP:  if (wait_cnt != 0) wait_cnt <= wait_cnt - 16'd1;

                S_INIT_AR1:  wait_cnt <= (TRFC_CYCLES > 0) ? TRFC_CYCLES - 1 : 0;
                S_INIT_AR1W: if (wait_cnt != 0) wait_cnt <= wait_cnt - 16'd1;

                S_INIT_AR2:  wait_cnt <= (TRFC_CYCLES > 0) ? TRFC_CYCLES - 1 : 0;
                S_INIT_AR2W: if (wait_cnt != 0) wait_cnt <= wait_cnt - 16'd1;

                S_INIT_MRS:  wait_cnt <= (TMRD_CYCLES > 0) ? TMRD_CYCLES - 1 : 0;
                S_INIT_TMRD: if (wait_cnt != 0) wait_cnt <= wait_cnt - 16'd1;

                S_IDLE: begin
                    half_sel <= 1'b0;
                end

                S_REF_CMD: begin
                    wait_cnt <= (TRFC_CYCLES > 0) ? TRFC_CYCLES - 1 : 0;
                end

                S_REF_WAIT: begin
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 16'd1;
                end

                S_ACTIVATE: begin
                    wait_cnt <= (TRCD_CYCLES > 0) ? TRCD_CYCLES - 1 : 0;
                end

                S_TRCD_WAIT: begin
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 16'd1;
                end

                S_RW_CMD: begin
                    if (req_wr_en_reg)
                        wait_cnt <= (WRITE_RECOVERY_CYCLES > 0) ? WRITE_RECOVERY_CYCLES - 1 : 0;
                    else
                        wait_cnt <= (CAS_LATENCY_CYCLES > 0) ? CAS_LATENCY_CYCLES - 1 : 0;
                end

                S_READ_WAIT: begin
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 16'd1;
                end

                S_READ_CAP: begin
                    if (half_sel == 1'b0)
                        read_data_reg[15:0] <= dq_in;
                    else
                        read_data_reg[31:16] <= dq_in;

                    wait_cnt <= (TRP_CYCLES > 0) ? TRP_CYCLES - 1 : 0;
                end

                S_PRE_WAIT: begin
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 16'd1;
                end

                S_NEXT_HALF: begin
                    if (half_sel == 1'b0)
                        half_sel <= 1'b1;
                end

                default: begin
                end
            endcase
        end
    end

    always @* begin
        // Default command: NOP
        o_dram_cke  = 1'b1;
        o_dram_cs_n = 1'b0;
        o_dram_ras_n = 1'b1;
        o_dram_cas_n = 1'b1;
        o_dram_we_n  = 1'b1;
        o_dram_ba    = 2'b00;
        o_dram_addr  = 12'b0;
        o_dram_ldqm  = 1'b0;
        o_dram_udqm  = 1'b0;

        dq_oe  = 1'b0;
        dq_out = 16'h0000;

        o_rdata = read_data_reg;
        o_ready = 1'b0;

        case (state)
            S_INIT_PRE: begin
                // PRECHARGE ALL (A10=1)
                o_dram_ras_n = 1'b0;
                o_dram_cas_n = 1'b1;
                o_dram_we_n  = 1'b0;
                o_dram_addr[10] = 1'b1;
            end

            S_INIT_AR1, S_INIT_AR2, S_REF_CMD: begin
                o_dram_ras_n = 1'b0;
                o_dram_cas_n = 1'b0;
                o_dram_we_n  = 1'b1;
            end

            S_INIT_MRS: begin
                o_dram_ras_n = 1'b0;
                o_dram_cas_n = 1'b0;
                o_dram_we_n  = 1'b0;
                o_dram_ba    = 2'b00;
                o_dram_addr  = MODE_REG;
            end

            S_ACTIVATE: begin
                o_dram_ras_n = 1'b0;
                o_dram_cas_n = 1'b1;
                o_dram_we_n  = 1'b1;
                o_dram_ba    = cur_bank;
                o_dram_addr  = cur_row;
            end

            S_RW_CMD: begin
                o_dram_ba   = cur_bank;
                o_dram_addr = rw_col_addr;

                if (req_wr_en_reg) begin
                    o_dram_ras_n = 1'b1;
                    o_dram_cas_n = 1'b0;
                    o_dram_we_n  = 1'b0;
                    dq_oe = 1'b1;
                    dq_out = (half_sel == 1'b0) ? req_wdata_reg[15:0] : req_wdata_reg[31:16];
                end else begin
                    o_dram_ras_n = 1'b1;
                    o_dram_cas_n = 1'b0;
                    o_dram_we_n  = 1'b1;
                end
            end

            S_DONE: begin
                o_ready = 1'b1;
            end

            default: begin
            end
        endcase
    end

endmodule

`endif
