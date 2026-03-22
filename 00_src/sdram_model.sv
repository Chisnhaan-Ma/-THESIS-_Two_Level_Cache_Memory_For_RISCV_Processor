`ifndef SDRAM_MODEL
`define SDRAM_MODEL

// Behavioral SDR SDRAM model for ISSI IS42S16400-like interface.
// Scope: simulation model for sdram_controler.sv command flow.
// - Supports: ACTIVATE, READ, WRITE, PRECHARGE, AUTO REFRESH, MRS.
// - Data bus: 16-bit bidirectional with CAS latency delay.
// - Storage: sparse associative table to keep simulation memory light.

module sdram_model #(
    parameter int CAS_LATENCY_CYCLES = 2,
    parameter int MEM_SPARSE_ENTRIES = 65536,
    parameter bit ENABLE_CHECKS      = 1'b1,
    parameter bit ENABLE_DEBUG_PRINT = 1'b0
) (
    input  logic        i_clk,
    input  logic        i_reset,

    input  logic        i_dram_cke,
    input  logic        i_dram_cs_n,
    input  logic        i_dram_ras_n,
    input  logic        i_dram_cas_n,
    input  logic        i_dram_we_n,
    input  logic [1:0]  i_dram_ba,
    input  logic [11:0] i_dram_addr,
    input  logic        i_dram_ldqm,
    input  logic        i_dram_udqm,
    inout  wire [15:0]  io_dram_dq
);

    localparam int BANK_COUNT = 4;

    // Sparse memory backend: halfword address is {bank[1:0], row[11:0], col[7:0]}.
    logic [21:0] mem_addr_table  [0:MEM_SPARSE_ENTRIES-1];
    logic [15:0] mem_data_table  [0:MEM_SPARSE_ENTRIES-1];
    logic        mem_valid_table [0:MEM_SPARSE_ENTRIES-1];

    logic [11:0] active_row [0:BANK_COUNT-1];
    logic        bank_open  [0:BANK_COUNT-1];

    logic [15:0] dq_out;
    logic        dq_oe;
    logic [15:0] dq_in;

    logic [21:0] rd_pending_addr;
    logic [15:0] rd_pending_data;
    logic [15:0] rd_countdown;

    integer refresh_cmd_count;

    assign dq_in = io_dram_dq;
    assign io_dram_dq = dq_oe ? dq_out : 16'hzzzz;

    function automatic logic [21:0] make_hw_addr(
        input logic [1:0] bank,
        input logic [11:0] row,
        input logic [7:0] col
    );
        begin
            make_hw_addr = {bank, row, col};
        end
    endfunction

    function automatic logic [15:0] apply_dqm_mask(
        input logic [15:0] value,
        input logic        ldqm,
        input logic        udqm
    );
        logic [15:0] masked;
        begin
            masked = value;
            if (ldqm)
                masked[7:0] = 8'hzz;
            if (udqm)
                masked[15:8] = 8'hzz;
            apply_dqm_mask = masked;
        end
    endfunction

    function automatic logic [15:0] mem_read_hw(input logic [21:0] hw_addr);
        integer i;
        begin
            mem_read_hw = 16'h0000;
            for (i = 0; i < MEM_SPARSE_ENTRIES; i = i + 1) begin
                if (mem_valid_table[i] && mem_addr_table[i] == hw_addr) begin
                    mem_read_hw = mem_data_table[i];
                    i = MEM_SPARSE_ENTRIES;
                end
            end
        end
    endfunction

    task automatic mem_write_hw(input logic [21:0] hw_addr, input logic [15:0] hw_data);
        integer i;
        integer free_idx;
        begin : mem_write_blk
            free_idx = -1;
            for (i = 0; i < MEM_SPARSE_ENTRIES; i = i + 1) begin
                if (mem_valid_table[i] && mem_addr_table[i] == hw_addr) begin
                    mem_data_table[i] = hw_data;
                    disable mem_write_blk;
                end
                if (!mem_valid_table[i] && free_idx == -1)
                    free_idx = i;
            end

            if (free_idx == -1) begin
                $fatal(1, "sdram_model sparse table overflow (increase MEM_SPARSE_ENTRIES)");
            end

            mem_valid_table[free_idx] = 1'b1;
            mem_addr_table[free_idx]  = hw_addr;
            mem_data_table[free_idx]  = hw_data;
        end
    endtask

    always @(posedge i_clk or posedge i_reset) begin : model_ff
        logic [21:0] hw_addr;
        logic [15:0] old_data;
        logic [15:0] wr_data;
        integer      b;
        integer      i;

        if (i_reset) begin
            dq_oe           <= 1'b0;
            dq_out          <= 16'h0000;
            rd_pending_addr <= 22'd0;
            rd_pending_data <= 16'd0;
            rd_countdown    <= 16'd0;
            refresh_cmd_count <= 0;

            for (b = 0; b < BANK_COUNT; b = b + 1) begin
                active_row[b] <= 12'd0;
                bank_open[b]  <= 1'b0;
            end

            for (i = 0; i < MEM_SPARSE_ENTRIES; i = i + 1) begin
                mem_valid_table[i] <= 1'b0;
                mem_addr_table[i]  <= 22'd0;
                mem_data_table[i]  <= 16'd0;
            end
        end else begin
            // Default behavior: release data bus unless current cycle drives read data.
            dq_oe <= 1'b0;

            // Handle delayed read return according to CAS latency.
            if (rd_countdown > 0) begin
                rd_countdown <= rd_countdown - 16'd1;
                if (rd_countdown == 1) begin
                    dq_oe  <= 1'b1;
                    dq_out <= apply_dqm_mask(rd_pending_data, i_dram_ldqm, i_dram_udqm);
                    if (ENABLE_DEBUG_PRINT) begin
                        $display("[SDRAM_MODEL READ ] t=%0t addr=0x%06h data=0x%04h", $time, rd_pending_addr, rd_pending_data);
                    end
                end
            end

            if (i_dram_cke && !i_dram_cs_n) begin
                // PRECHARGE command
                if (!i_dram_ras_n && i_dram_cas_n && !i_dram_we_n) begin
                    if (i_dram_addr[10]) begin
                        for (b = 0; b < BANK_COUNT; b = b + 1)
                            bank_open[b] <= 1'b0;
                    end else begin
                        bank_open[i_dram_ba] <= 1'b0;
                    end
                end

                // AUTO REFRESH command
                if (!i_dram_ras_n && !i_dram_cas_n && i_dram_we_n) begin
                    refresh_cmd_count <= refresh_cmd_count + 1;
                    if (ENABLE_DEBUG_PRINT) begin
                        $display("[SDRAM_MODEL REFRESH] t=%0t count=%0d", $time, refresh_cmd_count + 1);
                    end
                end

                // LOAD MODE REGISTER command (stored for visibility only).
                if (!i_dram_ras_n && !i_dram_cas_n && !i_dram_we_n) begin
                    if (ENABLE_DEBUG_PRINT) begin
                        $display("[SDRAM_MODEL MRS ] t=%0t mode=0x%03h", $time, i_dram_addr);
                    end
                end

                // ACTIVATE command
                if (!i_dram_ras_n && i_dram_cas_n && i_dram_we_n) begin
                    active_row[i_dram_ba] <= i_dram_addr;
                    bank_open[i_dram_ba]  <= 1'b1;
                end

                // READ command
                if (i_dram_ras_n && !i_dram_cas_n && i_dram_we_n) begin
                    if (ENABLE_CHECKS && !bank_open[i_dram_ba]) begin
                        $fatal(1, "sdram_model READ to closed bank %0d", i_dram_ba);
                    end

                    hw_addr         = make_hw_addr(i_dram_ba, active_row[i_dram_ba], i_dram_addr[7:0]);
                    rd_pending_addr <= hw_addr;
                    rd_pending_data <= mem_read_hw(hw_addr);
                    rd_countdown    <= (CAS_LATENCY_CYCLES > 0) ? CAS_LATENCY_CYCLES[15:0] : 16'd0;

                    // Auto-precharge bit A10 is used by this controller policy.
                    if (i_dram_addr[10])
                        bank_open[i_dram_ba] <= 1'b0;
                end

                // WRITE command
                if (i_dram_ras_n && !i_dram_cas_n && !i_dram_we_n) begin
                    if (ENABLE_CHECKS && !bank_open[i_dram_ba]) begin
                        $fatal(1, "sdram_model WRITE to closed bank %0d", i_dram_ba);
                    end

                    hw_addr = make_hw_addr(i_dram_ba, active_row[i_dram_ba], i_dram_addr[7:0]);
                    old_data = mem_read_hw(hw_addr);
                    wr_data = old_data;

                    if (!i_dram_ldqm)
                        wr_data[7:0] = dq_in[7:0];
                    if (!i_dram_udqm)
                        wr_data[15:8] = dq_in[15:8];

                    mem_write_hw(hw_addr, wr_data);

                    if (ENABLE_DEBUG_PRINT) begin
                        $display("[SDRAM_MODEL WRITE] t=%0t addr=0x%06h wdata=0x%04h", $time, hw_addr, wr_data);
                    end

                    if (i_dram_addr[10])
                        bank_open[i_dram_ba] <= 1'b0;
                end
            end
        end
    end

endmodule

`endif
