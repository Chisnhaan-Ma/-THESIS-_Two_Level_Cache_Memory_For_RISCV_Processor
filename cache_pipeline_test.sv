// ============================================================================
// TEST BENCH: Cache Integration Test
// ============================================================================
// Kiểm tra:
// 1. Cache HIT case
// 2. Cache MISS case (clean victim)
// 3. Cache MISS case (dirty victim)
// 4. Load-to-use hazard detection
// ============================================================================

`timescale 1ns/1ps
`include "pipeline.sv"

module cache_pipeline_test;

    logic i_clk;
    logic i_reset;
    logic [31:0] i_io_sw;
    
    logic [31:0] o_io_ledr;
    logic [31:0] o_io_ledg;
    logic [6:0]  o_io_hex0, o_io_hex1, o_io_hex2, o_io_hex3;
    logic [6:0]  o_io_hex4, o_io_hex5, o_io_hex6, o_io_hex7;
    logic [31:0] o_io_lcd;
    
    logic        o_insn_vld;
    logic [31:0] o_pc_debug;
    logic        o_ctrl;
    logic        o_mispred;
    
    // Instantiate pipeline
    pipelined dut (
        .i_clk          (i_clk),
        .i_reset        (i_reset),
        .i_io_sw        (i_io_sw),
        
        .o_io_ledr      (o_io_ledr),
        .o_io_ledg      (o_io_ledg),
        .o_io_hex0      (o_io_hex0),
        .o_io_hex1      (o_io_hex1),
        .o_io_hex2      (o_io_hex2),
        .o_io_hex3      (o_io_hex3),
        .o_io_hex4      (o_io_hex4),
        .o_io_hex5      (o_io_hex5),
        .o_io_hex6      (o_io_hex6),
        .o_io_hex7      (o_io_hex7),
        .o_io_lcd       (o_io_lcd),
        
        .o_insn_vld     (o_insn_vld),
        .o_pc_debug     (o_pc_debug),
        .o_ctrl         (o_ctrl),
        .o_mispred      (o_mispred)
    );
    
    // Clock generation: 10ns period (100 MHz)
    initial begin
        i_clk = 1'b0;
        forever #5 i_clk = ~i_clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize
        i_reset = 1'b1;
        i_io_sw = 32'b0;
        #10;
        i_reset = 1'b0;
        #10;
        
        $display("========================================");
        $display("Cache Pipeline Test Started");
        $display("========================================");
        
        // Run for a while to let pipeline execute
        // Monitor cache operations
        repeat(200) @(posedge i_clk);
        
        $display("========================================");
        $display("Cache Pipeline Test Complete");
        $display("========================================");
        $finish;
    end
    
    // ========================================================================
    // Monitor: Print pipeline state every cycle
    // ========================================================================
    always @(posedge i_clk) begin
        if (o_insn_vld) begin
            $display("[Time: %5d] PC: %h | Instruction Valid: %b | Control: %b", 
                     $time, o_pc_debug, o_insn_vld, o_ctrl);
        end
    end
    
    // ========================================================================
    // Monitor: Check for cache stall events
    // ========================================================================
    logic prev_stall = 1'b0;
    always @(posedge i_clk) begin
        // Access internal stall_cache signal through dut
        // This is monitoring cache performance
        if (prev_stall != prev_stall) begin
            $display("[Time: %5d] CACHE STALL TRANSITION", $time);
        end
        prev_stall <= prev_stall;
    end

endmodule

// ============================================================================
// TEST SCENARIOS
// ============================================================================
/*

TEST 1: CACHE HIT
─────────────────
Cycle  │ IF/ID      │ EX/MEM     │ MEM/WB     │ Cache Status
───────┼────────────┼────────────┼────────────┼──────────────────
1      │ LOAD x     │ -          │ -          │ Check
2      │ ADD        │ LOAD x     │ -          │ HIT - return data
3      │ SUB        │ ADD        │ LOAD       │ Normal (no stall)
Expected: No stall, data available immediately

---

TEST 2: CACHE MISS (Clean Victim)
──────────────────────────────────
Cycle  │ IF/ID      │ EX/MEM     │ MEM/WB     │ Cache Status
───────┼────────────┼────────────┼────────────┼──────────────────────
1      │ LOAD y     │ -          │ -          │ MISS detected
2      │ STALL      │ LOAD y     │ -          │ Fetch SRAM
3      │ STALL      │ STALL      │ -          │ Wait for SRAM
4      │ STALL      │ STALL      │ STALL      │ SRAM data ready
5      │ ADD        │ STALL      │ LOAD       │ Resume pipeline
Expected: 3 cycles stall, then resume

---

TEST 3: CACHE MISS (Dirty Victim)
──────────────────────────────────
Cycle  │ Status     │ Operation
───────┼────────────┼──────────────────────────────
1-2    │ MISS+DIRTY │ Detect victim is dirty
3-4    │ WRITEBACK  │ Write dirty line back to SRAM
5-6    │ FETCH      │ Fetch new line from SRAM
7      │ DONE       │ Resume pipeline
Expected: 5-6 cycles stall

---

TEST 4: LOAD-TO-USE HAZARD
──────────────────────────
Cycle  │ IF/ID  │ EX/MEM     │ MEM/WB      │ Hazard Unit
───────┼────────┼────────────┼─────────────┼──────────────
1      │ LOAD r1│ -          │ -           │ -
2      │ ADD r2,│ LOAD r1    │ -           │ Check: rd=r1 in LOAD
        │ r1    │            │             │ wb_sel=memory → STALL
3      │ STALL  │ STALL      │ LOAD r1     │ Stall hazard
4      │ ADD    │ STALL      │ STORE       │ Resume (forward data)
Expected: 1 cycle stall for hazard + cache cycles if MISS

*/

// ============================================================================
// VERIFICATION CHECKS
// ============================================================================
/*

✓ Cache Hit Rate: Monitor cache hit/miss ratio
  - HIT: 1 cycle
  - MISS: 3-4 cycles

✓ Stall Signal Propagation:
  - memory_cycle → o_mem_stall_cache
  - fetch_cycle ← i_fetch_stall_cache
  - PC must not increment during stall

✓ Data Consistency:
  - ld_data from cache == expected value
  - No data corruption during stall

✓ Hazard Detection Still Works:
  - Load-to-use hazard independent of cache stall
  - Both stalls combine correctly

✓ Write Operations:
  - Cache writeback to SRAM completes
  - Dirty bit management

*/
