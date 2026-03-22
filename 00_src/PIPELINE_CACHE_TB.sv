`ifndef PIPELINE_TB
`define PIPELINE_TB
`include "pipeline.sv"
`include "sram_model.sv"
`timescale 1ps/1ps

module Pipeline_Cache_Tb ();
    logic tb_clk;
    logic tb_reset;
    logic [31:0] tb_io_sw;

    logic        tb_l2sram_ce_n;
    logic        tb_l2sram_oe_n;
    logic        tb_l2sram_we_n;
    logic        tb_l2sram_lb_n;
    logic        tb_l2sram_ub_n;
    logic [17:0] tb_l2sram_addr;
    wire  [15:0] tb_l2sram_dq;

    pipelined pipeline_cache_test (
        .i_clk(tb_clk),
        .i_reset(tb_reset),
        .i_io_sw(tb_io_sw),
        .o_l2sram_ce_n(tb_l2sram_ce_n),
        .o_l2sram_oe_n(tb_l2sram_oe_n),
        .o_l2sram_we_n(tb_l2sram_we_n),
        .o_l2sram_lb_n(tb_l2sram_lb_n),
        .o_l2sram_ub_n(tb_l2sram_ub_n),
        .o_l2sram_addr(tb_l2sram_addr),
        .io_l2sram_dq(tb_l2sram_dq)
    );

    sram_model u_l2_sram_model (
        .i_ce_n(tb_l2sram_ce_n),
        .i_oe_n(tb_l2sram_oe_n),
        .i_we_n(tb_l2sram_we_n),
        .i_lb_n(tb_l2sram_lb_n),
        .i_ub_n(tb_l2sram_ub_n),
        .i_addr(tb_l2sram_addr),
        .io_dq(tb_l2sram_dq)
    );

   // Clock generation
    always #5 tb_clk = ~tb_clk;
	
    initial begin
        $dumpfile("wave.vcd");      // file VCD sẽ sinh ra
        $dumpvars(0, Pipeline_Cache_Tb); //tên module testbench top-level
        tb_clk = 0;
        tb_reset = 1;    // Reset để PC = 0
        #7ps;
        force  tb_reset = 0; 
        force  tb_io_sw = 32'ha;
        #2000000ps;
        $finish;  
    end

endmodule

`endif