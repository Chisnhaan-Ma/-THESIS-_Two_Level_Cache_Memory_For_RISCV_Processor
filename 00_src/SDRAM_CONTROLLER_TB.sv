`include "sdram_controler.sv"
`timescale 1ns/1ps

module SDRAM_CONTROLLER_TB;
    localparam int CLK_PERIOD_NS = 20; // 50 MHz
    localparam int CAS_LATENCY = 2;
    localparam int REFRESH_INTERVAL = 64;
    localparam int MEM_SPARSE_ENTRIES = 16348;

    logic        tb_clk;
    logic        tb_reset;

    logic        tb_sram_enb;
    logic        tb_wr_en;
    logic [31:0] tb_addr;
    logic [31:0] tb_wdata;
    logic [31:0] tb_rdata;
    logic        tb_ready;

    logic        dram_clk;
    logic        dram_cke;
    logic        dram_cs_n;
    logic        dram_ras_n;
    logic        dram_cas_n;
    logic        dram_we_n;
    logic [1:0]  dram_ba;
    logic [11:0] dram_addr;
    logic        dram_ldqm;
    logic        dram_udqm;
    tri   [15:0] dram_dq;

    logic [15:0] mem_dq_out;
    logic        mem_dq_oe;

    // Icarus-friendly sparse SDRAM model: parallel address/data/valid tables.
    logic [21:0] mem_addr_table  [0:MEM_SPARSE_ENTRIES-1];
    logic [15:0] mem_data_table  [0:MEM_SPARSE_ENTRIES-1];
    logic        mem_valid_table [0:MEM_SPARSE_ENTRIES-1];

    logic [11:0] active_row [0:3];
    logic        bank_open  [0:3];

    logic [21:0] rd_pending_addr;
    int          rd_countdown;

    int unsigned refresh_cmd_count;

    assign dram_dq = mem_dq_oe ? mem_dq_out : 16'hzzzz;

    sdram_controler #(
        .CLK_FREQ_HZ(50_000_000),
        .INIT_WAIT_US(1),
        .REFRESH_INTERVAL_CYC(REFRESH_INTERVAL),
        .TRP_CYCLES(2),
        .TRCD_CYCLES(2),
        .TRFC_CYCLES(4),
        .TMRD_CYCLES(2),
        .CAS_LATENCY_CYCLES(CAS_LATENCY),
        .WRITE_RECOVERY_CYCLES(2)
    ) dut (
        .i_clk(tb_clk),
        .i_reset(tb_reset),
        .i_sram_enb(tb_sram_enb),
        .i_wr_en(tb_wr_en),
        .i_addr(tb_addr),
        .i_wdata(tb_wdata),
        .o_rdata(tb_rdata),
        .o_ready(tb_ready),
        .o_dram_clk(dram_clk),
        .o_dram_cke(dram_cke),
        .o_dram_cs_n(dram_cs_n),
        .o_dram_ras_n(dram_ras_n),
        .o_dram_cas_n(dram_cas_n),
        .o_dram_we_n(dram_we_n),
        .o_dram_ba(dram_ba),
        .o_dram_addr(dram_addr),
        .o_dram_ldqm(dram_ldqm),
        .o_dram_udqm(dram_udqm),
        .io_dram_dq(dram_dq)
    );

    function automatic logic [21:0] to_halfword_addr(input logic [31:0] byte_addr, input logic half_sel);
        to_halfword_addr = byte_addr[22:1] + {21'd0, half_sel};
    endfunction

    function automatic logic [21:0] make_hw_addr(
        input logic [1:0] bank,
        input logic [11:0] row,
        input logic [7:0] col
    );
        make_hw_addr = {bank, row, col};
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
                if (!mem_valid_table[i] && free_idx == -1) begin
                    free_idx = i;
                end
            end

            if (free_idx == -1) begin
                $fatal(1, "Sparse SDRAM model overflow (increase MEM_SPARSE_ENTRIES)");
            end

            mem_valid_table[free_idx] = 1'b1;
            mem_addr_table[free_idx]  = hw_addr;
            mem_data_table[free_idx]  = hw_data;
        end
    endtask

    task automatic wait_ready_with_timeout(input int unsigned timeout_cycles);
        int unsigned cycles;
        begin
            cycles = 0;
            while (!tb_ready && cycles < timeout_cycles) begin
                @(posedge tb_clk);
                cycles = cycles + 1;
            end
            if (!tb_ready) begin
                $fatal(1, "Timeout waiting for o_ready after %0d cycles", timeout_cycles);
            end
        end
    endtask

    task automatic issue_request(
        input logic is_write,
        input logic [31:0] addr,
        input logic [31:0] data,
        output logic [31:0] read_data
    );
        begin
            tb_wr_en    <= is_write;
            tb_addr     <= addr;
            tb_wdata    <= data;
            tb_sram_enb <= 1'b1;
            @(posedge tb_clk);
            tb_sram_enb <= 1'b0;

            wait_ready_with_timeout(400);
            read_data = tb_rdata;
            @(posedge tb_clk);
        end
    endtask

    task automatic check_read(input logic [31:0] addr, input logic [31:0] expected);
        logic [31:0] got;
        begin
            issue_request(1'b0, addr, 32'd0, got);
            if (got !== expected) begin
                $fatal(1, "READ mismatch at 0x%08h: got=0x%08h expected=0x%08h", addr, got, expected);
            end
            $display("[PASS] READ 0x%08h -> 0x%08h", addr, got);
        end
    endtask

    task automatic check_write_then_read(
        input logic [31:0] addr,
        input logic [31:0] wdata
    );
        logic [31:0] got;
        begin
            issue_request(1'b1, addr, wdata, got);
            issue_request(1'b0, addr, 32'd0, got);
            if (got !== wdata) begin
                $fatal(1, "WRITE/READ mismatch at 0x%08h: got=0x%08h expected=0x%08h", addr, got, wdata);
            end
            $display("[PASS] WRITE/READ 0x%08h -> 0x%08h", addr, got);
        end
    endtask

    always #(CLK_PERIOD_NS/2) tb_clk = ~tb_clk;

    always_ff @(posedge tb_clk) begin : sdram_model
        logic [21:0] wr_hw_addr;
        logic [21:0] rd_hw_addr;
        integer      i;

        if (tb_reset) begin
            mem_dq_oe         <= 1'b0;
            mem_dq_out        <= 16'h0000;
            rd_countdown      <= 0;
            refresh_cmd_count <= 0;

            for (i = 0; i < MEM_SPARSE_ENTRIES; i = i + 1) begin
                mem_valid_table[i] <= 1'b0;
                mem_addr_table[i]  <= 22'd0;
                mem_data_table[i]  <= 16'd0;
            end

            bank_open[0] <= 1'b0;
            bank_open[1] <= 1'b0;
            bank_open[2] <= 1'b0;
            bank_open[3] <= 1'b0;

            active_row[0] <= 12'd0;
            active_row[1] <= 12'd0;
            active_row[2] <= 12'd0;
            active_row[3] <= 12'd0;
        end else begin
            mem_dq_oe <= 1'b0;

            if (rd_countdown > 0) begin
                rd_countdown <= rd_countdown - 1;
                if (rd_countdown == 1) begin
                    mem_dq_oe  <= 1'b1;
                        mem_dq_out <= mem_read_hw(rd_pending_addr);
                end
            end

            if (!dram_cs_n) begin
                // ACTIVATE
                if (!dram_ras_n && dram_cas_n && dram_we_n) begin
                    active_row[dram_ba] <= dram_addr;
                    bank_open[dram_ba]  <= 1'b1;
                end

                // READ
                if (dram_ras_n && !dram_cas_n && dram_we_n) begin
                    if (!bank_open[dram_ba]) begin
                        $fatal(1, "READ issued to closed bank %0d", dram_ba);
                    end
                    rd_hw_addr      = make_hw_addr(dram_ba, active_row[dram_ba], dram_addr[7:0]);
                    rd_pending_addr <= rd_hw_addr;
                    rd_countdown    <= CAS_LATENCY;
                end

                // WRITE
                if (dram_ras_n && !dram_cas_n && !dram_we_n) begin
                    if (!bank_open[dram_ba]) begin
                        $fatal(1, "WRITE issued to closed bank %0d", dram_ba);
                    end
                    wr_hw_addr = make_hw_addr(dram_ba, active_row[dram_ba], dram_addr[7:0]);
                    mem_write_hw(wr_hw_addr, dram_dq);
                end

                // AUTO REFRESH
                if (!dram_ras_n && !dram_cas_n && dram_we_n) begin
                    refresh_cmd_count <= refresh_cmd_count + 1;
                end
            end
        end
    end

    initial begin
        logic [31:0] rdata;
        logic [21:0] hw0;
        logic [21:0] hw1;

        $display("=== SDRAM_CONTROLLER_TB start ===");

        tb_clk      = 1'b0;
        tb_reset    = 1'b1;
        tb_sram_enb = 1'b0;
        tb_wr_en    = 1'b0;
        tb_addr     = 32'd0;
        tb_wdata    = 32'd0;

        // Preload one location in backing SDRAM model.
        hw0 = to_halfword_addr(32'h0000_1000, 1'b0);
        hw1 = to_halfword_addr(32'h0000_1000, 1'b1);
        mem_write_hw(hw0, 16'hBEEF);
        mem_write_hw(hw1, 16'hCAFE);

        repeat (5) @(posedge tb_clk);
        tb_reset <= 1'b0;

        // Wait through init sequence.
        repeat (120) @(posedge tb_clk);

        check_read(32'h0000_1000, 32'hCAFE_BEEF);
        check_write_then_read(32'h0000_1004, 32'h1234_5678);
        check_write_then_read(32'h0012_3400, 32'hA5A5_5A5A);

        // Wait long enough for at least one periodic refresh and re-test access.
        repeat (REFRESH_INTERVAL + 30) @(posedge tb_clk);
        issue_request(1'b0, 32'h0000_1004, 32'd0, rdata);
        if (rdata !== 32'h1234_5678) begin
            $fatal(1, "Data lost after refresh period: got=0x%08h", rdata);
        end
        if (refresh_cmd_count == 0) begin
            $fatal(1, "No AUTO REFRESH command observed");
        end

        $display("[PASS] Refresh observed: %0d command(s)", refresh_cmd_count);
        $display("=== SDRAM_CONTROLLER_TB PASSED ===");
        $finish;
    end

endmodule
