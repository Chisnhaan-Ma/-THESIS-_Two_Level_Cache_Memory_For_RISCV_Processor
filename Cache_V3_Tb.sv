`ifndef CACHE_V3_TB
`define CACHE_V3_TB
`include "cache_v3.sv"
`include "sram.sv"
`timescale 1ps/1ps

module Cache_V3_Tb ();
    // Clock and reset
    logic tb_clk;
    logic tb_reset;

    // CPU interface to cache
    logic         tb_mem_access;
    logic         tb_wr_en;
    logic [31:0]  tb_addr;
    logic [31:0]  tb_wdata;
    logic [31:0]  tb_rdata;
    logic         tb_hit;
    logic         tb_stall;
    // cache done flag
    logic         tb_cache_done;

    // SRAM interface (mocked)
    logic         tb_sram_enb;
    logic [31:0]  tb_sram_addr;
    logic         tb_sram_wr_en;
    logic [31:0]  tb_sram_wdata;
    logic [31:0]  tb_sram_rdata;
    logic         tb_sram_ready;

    cache cache_test (
        .i_clk          (tb_clk),
        .i_reset        (tb_reset),
        .i_mem_access   (tb_mem_access),
        .i_wr_en        (tb_wr_en),
        .i_addr         (tb_addr),
        .i_wdata        (tb_wdata),
        .o_rdata        (tb_rdata),
        .o_hit_debug    (tb_hit),
        .o_stall        (tb_stall),
        .o_cache_done   (tb_cache_done),
        .o_sram_enb     (tb_sram_enb),
        .o_sram_addr    (tb_sram_addr),
        .o_sram_wr_en   (tb_sram_wr_en),
        .o_sram_wdata   (tb_sram_wdata),
        .i_sram_rdata   (tb_sram_rdata),
        .i_sram_ready   (tb_sram_ready)
    );

    sram sram_test (
        .i_clk      (tb_clk),
        .i_reset    (tb_reset),
        .i_sram_enb (tb_sram_enb),
        .i_wr_en    (tb_sram_wr_en),
        .i_addr     (tb_sram_addr),
        .i_wdata    (tb_sram_wdata),
        .o_rdata    (tb_sram_rdata),
        .o_ready    (tb_sram_ready)
    );

    // ===================================
    always #5 tb_clk = ~tb_clk; //10 ps period = 100 MHz

    // ===================================
    task wait_cache_done();
        wait(tb_cache_done);
    endtask

    // ===================================
    task issue_access(input logic is_write, input logic [31:0] addr, input logic [31:0] wdata = 32'b0);
        tb_mem_access = 1;
        tb_wr_en = is_write;
        tb_addr = addr;
        tb_wdata = wdata;
        #10;
    endtask

    // ===================================
    // Test helper task: end access
    // ===================================
    task end_access();
        tb_mem_access = 0;
        #10;
    endtask
        integer cycle_count;
        logic writeback_detected;
        logic ram_read_detected;
        logic write_to_sram;
    // ===================================
    // Test stimuli
    // ===================================
    initial begin


        $dumpfile("cache_v3_tb.vcd");
        $dumpvars(0, Cache_V3_Tb);

        tb_clk = 0;
        tb_reset = 1;
        tb_mem_access = 0;
        
        #20;  // Wait for reset
        tb_reset = 0;
        #20;
        // ===================================
        // Procedure 1: READ HIT (1 cycle)
        // ===================================
        $display("------------------------------------------------------");
        $display("Procedure 1: READ HIT (1 cycle)");
        
        // First, do a READ MISS to populate cache
        $display("\n[SETUP] Pre-load cache with address 0x0100...");
        issue_access(1'b0, 32'h0000);
        wait_cache_done();
        $display("[Cycle 0-N] READ MISS: cache populating from SRAM");
        end_access();
        // Now READ HIT on same address
        $display("\n[TEST] Issue READ HIT on 0x0100...");
        issue_access(0, 32'h0000);
        wait_cache_done();
        if (tb_rdata == 32'h000070B7) begin
            $display("PROC 1: READ HIT PASSED: o_rdata = 0x%08h", tb_rdata);
        end 
        else begin
            $display("READ FAILED: o_rdata = 0x%08h, (expect 0x1111_1111)", tb_rdata);
        end
        end_access();
        #100;
        // ===================================
        // Procedure 2: WRITE HIT (1 cycle)
        // ===================================
        $display("------------------------------------------------------");
        $display(" Procedure 2: WRITE HIT (1 cycle)");
        
        $display("\n[TEST] Issue WRITE HIT on 0x0100 with data 0xDEAD_BEEF...");
        issue_access(1'b1, 32'h0100, 32'hDEAD_BEEF);
        wait_cache_done();
        if (tb_hit && !tb_stall) begin
            $display("[Cycle 1]  Write accepted, data marked dirty in cache");
        end 
        else begin
            $display("[Cycle 0]  FAILED: hit=%b, stall=%b, done=%b", tb_hit, tb_stall, tb_cache_done);
        end
        end_access();

        // Verify write by reading back
        $display("\n[VERIFY] READ back from 0x0100 to verify write...");
        issue_access(1'b0, 32'h0100);
        wait_cache_done();
        if (tb_rdata == 32'hDEAD_BEEF) begin
            $display("PROC 2: WRITE HIT PASSED: 0x%08h (write was stored in cache)", tb_rdata);
        end 
        else begin
            $display(" WRITE HIT FAILED: expected 0xDEAD_BEEF, got 0x%08h", tb_rdata);
        end
        end_access();

        #100;
        // ===================================
        // Procedure 3: READ MISS + CLEAN VICTIM (4 cycles)
        // ===================================
        $display("------------------------------------------------------");
        $display("Procedure 3: READ MISS + CLEAN VICTIM (4 cycles)");
        
        // Reset cache for clean state
        /*$display("\n[SETUP] Reset cache...");
        tb_reset = 1;
        #20;
        tb_reset = 0;
        #20;
        */
        $display("\n[TEST] Issue READ MISS on address 0x0200 (new address)...");
        cycle_count = 0;
        issue_access(1'b0, 32'h0004);
        wait_cache_done();

        if (tb_rdata == 32'h00008093) begin
            $display("PROC 3: READ MISS + CLEAN VICTIM PASSED: %0d cycles, data=0x%08h (from SRAM)", cycle_count, tb_rdata);
        end else begin
            $display(" READ MISS + CLEAN VICTIM Data mismatch: expected 0xAAAA_AAAA, got 0x%08h", tb_rdata);
        end
        end_access();

        // ===================================
        // Procedure 4: READ MISS + DIRTY VICTIM + WRITEBACK (5 cycles)
        // ===================================
        $display("\n[SETUP] Reset cache...");
        tb_reset = 1;
        #20;
        tb_reset = 0;
        #20;
        $display("------------------------------------------------------");
        $display("Procedure 4: READ MISS + DIRTY VICTIM + WRITEBACK");
        $display("------------------------------------------------------");

        // Setup: Fill all 4 ways in set 0 (index=0), then mark way 0 dirty
        $display("[SETUP] Pre-fill set 0 with 4 different addresses (all index=0)...");
        for (int way=0; way<4; way++) begin
            logic [31:0] test_addr;
            case(way)
                0: test_addr = 32'h0100;  // tag=0x40,  index=0
                1: test_addr = 32'h0200;  // tag=0x140, index=0
                2: test_addr = 32'h0300;  // tag=0x340, index=0
                3: test_addr = 32'h0400;  // tag=0x440, index=0
            endcase
            $display("[SETUP]   Way %0d: Reading from 0x%08h...", way, test_addr);
            issue_access(1'b0, test_addr);
            wait_cache_done();
            end_access();
        end
        $display("[SETUP] All 4 ways of set 0 are now filled. fifo_ptr[0] wrapped to 0");
        
        $display("[SETUP] WRITE to 0x0100 to mark way 0 as dirty (0xDEAD_BEEF)...");
        issue_access(1'b1, 32'h0100, 32'hDEAD_BEEF);
        wait_cache_done();
        $display("[Result] Way 0 of set 0 is now DIRTY");
        end_access();

        // Now trigger READ MISS with address that forces eviction of way 0 (dirty)
        // 0x0900: index=0 (same set), tag=0x240 (different) → evict victim (way 0, which is dirty)
        $display("\n[TEST] Issue READ MISS on 0x0900 (index=0, new tag=0x240)...");
        $display("[Expected: WRITEBACK dirty way 0, then READ 0x0900]");
        issue_access(1'b0, 32'h0500);
        wait_cache_done();
        //$display("sram_addr = %h| sram_wdata = %h|sram_rdata = %h ",tb_sram_addr, tb_sram_wdata, tb_sram_rdata);   

        if (tb_rdata == 32'h0000_0000) begin
            $display("PROC 4: READ MISS + DIRTY VICTIM + WRITEBACK PASSED: %0d cycles, data=0x%08h (from SRAM)", cycle_count, tb_rdata);
        end 
        else begin
            $display(" READ MISS + DIRTY VICTIM + WRITEBACK Data mismatch: expected 0x0000_0000, got 0x%08h", tb_rdata);
        end
        end_access();

        issue_access(1'b0, 32'h0100);
        wait_cache_done();
        if (tb_rdata == 32'hDEAD_BEEF) begin
            $display("PROC 4 VERIFY: READ BACK DIRTY DATA PASSED: o_rdata = 0x%08h", tb_rdata);
        end 
        else begin
            $display("READ BACK DIRTY DATA FAILED: o_rdata = 0x%08h, (expect 0xDEAD_BEEF)", tb_rdata);
        end
        end_access();

        #150;
        // ===================================
        // Procedure 5: STORE MISS + CLEAN VICTIM (4 cycles)
        // ===================================
        
        $display("------------------------------------------------------");
        $display("Procedure 5: CLEAN VICTIM (4 cycles)");
        

        // Reset cache for clean state
        $display("\n[SETUP] Reset cache for clean state...");
        tb_reset = 1;
        #20;
        tb_reset = 0;
        #20;

        $display("\n[TEST] Issue STORE MISS on address 0x0300 (new address)...");
        $display("[Write 0x5555_5555 to cache/SRAM]");
        issue_access(1'b1, 32'h0300, 32'h5555_5555);

        cycle_count = 0;
        write_to_sram = 0;

        while (!tb_cache_done && cycle_count < 20) begin
            @(posedge tb_clk);
            cycle_count++;

            if (tb_sram_enb && tb_sram_wr_en) begin
                $display("[Cycle %0d] RAM_WRITE to SRAM: addr=0x%08h, data=0x%08h", 
                         cycle_count, tb_sram_addr, tb_sram_wdata);
                write_to_sram = 1;
            end
        end
        #1;

        if (write_to_sram && cycle_count > 3) begin
            $display(" Procedure 5 PASSED: %0d cycles, STORE MISS completed", cycle_count);
        end else begin
            $display(" FAILED: write_detected=%b, cycles=%0d", write_to_sram, cycle_count);
        end
        end_access();

        // ===================================
        // Summary
        // ===================================
        #100;
        $display("Cache v3 - Procedure Verification Complete\n");
        $finish;
    end

endmodule
`endif
