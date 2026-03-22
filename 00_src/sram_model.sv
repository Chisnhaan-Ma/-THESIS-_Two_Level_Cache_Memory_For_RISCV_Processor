// ============================================================
//  IS61LV25616AL — Behavioral simulation model
//  256K × 16-bit asynchronous SRAM (ISSI IS61LV25616AL-10)
//
//  Connects directly to cache_l2_v2 external SRAM interface:
//    cache_l2_v2 port      →  this module port
//    o_l2sram_ce_n         →  i_ce_n
//    o_l2sram_oe_n         →  i_oe_n
//    o_l2sram_we_n         →  i_we_n
//    o_l2sram_lb_n         →  i_lb_n
//    o_l2sram_ub_n         →  i_ub_n
//    o_l2sram_addr [17:0]  →  i_addr
//    io_l2sram_dq  [15:0]  →  io_dq
//
//  Address mapping (matches cache_l2_v2::l2sram_half_addr):
//    [17:5]  way index  (13 bits, NUM_WAY=8192)
//    [4:1]   set index  (4  bits, NUM_SET=16)
//    [0]     half-word select (0=lower 16 b, 1=upper 16 b of 32-bit line)
// ============================================================
`timescale 1ps/1ps

module sram_model #(
    parameter int  MEM_DEPTH      = 1024, //262144,  // 2^18 half-word locations (256K×16)
    parameter int  ACCESS_TIME_NS = 10,      // tAA: address → valid output (ns)
    parameter      INIT_FILE      = ""       // Optional hex image ($readmemh)
) (
    input  logic         i_ce_n,   // Chip Enable   (active low)
    input  logic         i_oe_n,   // Output Enable (active low)
    input  logic         i_we_n,   // Write Enable  (active low)
    input  logic         i_lb_n,   // Lower Byte    (active low, DQ[7:0])
    input  logic         i_ub_n,   // Upper Byte    (active low, DQ[15:8])
    input  logic [17:0]  i_addr,   // 18-bit half-word address [A17:A0]
    inout  wire  [15:0]  io_dq     // 16-bit bidirectional data bus
);

    // -------------------------------------------------------------------
    //  Memory array: 256K × 16-bit
    // -------------------------------------------------------------------
    logic [15:0] mem [0:MEM_DEPTH-1];

    initial begin : mem_init
        integer i;
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            for (i = 0; i < MEM_DEPTH; i = i + 1)
                mem[i] = 16'h0000;
        end
    end

    // -------------------------------------------------------------------
    //  Write path
    //  For this cache controller, WE_n stays low across WR_LO/WR_HI and
    //  address/data change between the two halfword writes. Model writes
    //  whenever write controls are active so both halves are captured.
    // -------------------------------------------------------------------
    always @(i_ce_n or i_we_n or i_lb_n or i_ub_n or i_addr or io_dq) begin
        if (!i_ce_n && !i_we_n) begin
            if (!i_lb_n) mem[i_addr][7:0]  = io_dq[7:0];
            if (!i_ub_n) mem[i_addr][15:8] = io_dq[15:8];
        end
    end

    // -------------------------------------------------------------------
    //  Read / output path
    //  Output enabled when CE_n=0, OE_n=0, WE_n=1.
    //  DQ bus is Hi-Z otherwise (CE_n=HI | OE_n=HI | WE_n=LO).
    //  Model tAA on data path only, then gate onto bus by read controls.
    // -------------------------------------------------------------------
    logic [15:0] dq_raw;
    wire  [15:0] dq_delayed;
    wire         read_active;

    assign read_active = (!i_ce_n && !i_oe_n && i_we_n);

    always @* begin
        dq_raw = mem[i_addr];
    end

    // Apply tAA delay from internal cell to output data bus.
    assign #(ACCESS_TIME_NS) dq_delayed = dq_raw;

    // Byte-select masking on delayed data.
    wire [15:0] dq_masked;
    assign dq_masked[7:0]  = (!i_lb_n) ? dq_delayed[7:0]  : 8'hzz;
    assign dq_masked[15:8] = (!i_ub_n) ? dq_delayed[15:8] : 8'hzz;

    // Gate delayed data to tri-state bus during active read.
    assign io_dq = read_active ? dq_masked : 16'hzzzz;

    // -------------------------------------------------------------------
    //  Simulation-only sanity checks
    // -------------------------------------------------------------------
`ifndef SYNTHESIS
    // Warn if WE_n is asserted while chip is not selected
    always @(negedge i_we_n) begin
        if (i_ce_n)
            $display("[SRAM_MODEL @%0t] WARNING: WE_n asserted while CE_n=1 (chip not selected)", $time);
    end

    // Warn on out-of-range address
    always @(i_addr) begin
        if ({1'b0, i_addr} >= MEM_DEPTH)
            $display("[SRAM_MODEL @%0t] WARNING: address 0x%05h out of range (depth=%0d)", $time, i_addr, MEM_DEPTH);
    end

    // Display write operations
    always @* begin
        if (!i_ce_n && !i_we_n) begin
            if (!i_lb_n || !i_ub_n) begin
                $display("[SRAM_MODEL WRITE] @%0t addr=0x%05h data_in[15:0]=0x%04h LB=%b UB=%b", 
                    $time, i_addr, io_dq, !i_lb_n, !i_ub_n);
            end
        end
    end

    // Display read operations (show both memory cell value and actual io_dq bus)
    always @* begin
        if (!i_ce_n && !i_oe_n && i_we_n) begin
            $display("[SRAM_MODEL READ] @%0t addr=0x%05h mem=0x%04h io_dq=0x%04h CE_n=%b OE_n=%b WE_n=%b LB_n=%b UB_n=%b", 
                $time, i_addr, mem[i_addr], io_dq, i_ce_n, i_oe_n, i_we_n, i_lb_n, i_ub_n);
        end
    end
`endif

endmodule
