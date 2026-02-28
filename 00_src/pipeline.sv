`ifndef PIPILINE
`define PIPELINE
`include "fetch_cycle.sv"
`include "decode_cycle.sv"
`include "execute_cycle.sv"
`include "memory_cycle.sv"
`include "writeback_cycle.sv"
`include "branch_taken.sv"
`include "forward_unit.sv"
`include "hazard_detection.sv"
module pipelined (
    input logic i_clk,
    input logic i_reset,

    // Input IO 
    input  logic [31:0] i_io_sw,

    // Output LED, HEX, LCD
    output logic [31:0] o_io_ledr, 
    output logic [31:0] o_io_ledg,
    output logic [6:0]  o_io_hex0, 
    output logic [6:0]  o_io_hex1, 
    output logic [6:0]  o_io_hex2,   
    output logic [6:0]  o_io_hex3, 
    output logic [6:0]  o_io_hex4, 
    output logic [6:0]  o_io_hex5, 
    output logic [6:0]  o_io_hex6,   
    output logic [6:0]  o_io_hex7, 
    output logic [31:0] o_io_lcd,

    // Output debug signals
    output logic        o_insn_vld,
    output logic [31:0] o_pc_debug,
    output logic        o_ctrl,
    output logic        o_mispred,
    // Debug: cache hit propagated from cache -> LSU -> MEM -> top
    output logic        o_cache_hit_debug,
    // Debug: cache miss propagated from cache -> LSU -> MEM -> top
    output logic        o_cache_miss_debug
);
logic Stall;
logic flush;
logic        o_cache_done;
//Input fetch for jump
logic           pc_sel;
logic [31:0]    o_mem_alu_data;

//Output fetch -> Input decode
logic [31:0]    pc_decode;
logic [31:0]    inst_decode;
logic           insn_vld_decode;

//Output writeback -> Input decode
logic [31:0]    rd_data_decode;
logic [4:0]     rd_addr_decode;
logic           rd_wren_decode;

//Output decode -> input execute
logic [31:0]    inst_execute;
logic [31:0]    pc_execute;
logic           asel_execute;
logic           bsel_execute;
logic [31:0]    rs1_data_execute;
logic [31:0]    rs2_data_execute;
logic [31:0]    imm_out_execute;
logic [3:0]     alu_op_execute;
logic           br_un_execute;
logic           lsu_wren_execute;
logic [2:0]     slt_sl_execute;
logic [1:0]     wb_sel_execute;
logic           rd_wren_execute;
logic           insn_vld_execute;
logic           ctrl_execute;

//Ouput execute -> input memory
logic           br_equal_mem;
logic           br_less_mem;
logic [31:0]    alu_data_mem;
logic [31:0]    pc_mem;
logic [31:0]    rs2_data_mem;
logic [31:0]    inst_mem;
logic           lsu_wren_mem;
logic [2:0]     slt_sl_mem;
logic [1:0]     wb_sel_mem;
logic           rd_wren_mem;
logic           insn_vld_mem;
logic           ctrl_mem;
           

//Outpit memory -> input Writeback
logic [31:0]    pc_add4_wb;
logic [31:0]    alu_data_wb;
logic [31:0]    inst_wb;
logic [1:0]     wb_sel_wb;
logic           rd_wren_wb;
logic [31:0]    ld_data_wb;
logic [31:0]    pc_debug_wb;
logic [2:0]     slt_sl_wb;

//Fix load hazard
logic [4:0]     rs1_addr_decode;
logic [4:0]     rs2_addr_decode;
logic [4:0]     rd_addr_mem;
logic [4:0]     rd_addr_wb;
logic [1:0]     fwd_operand_a;
logic [1:0]     fwd_operand_b;
logic [1:0]     fwd_rs2;
logic [1:0]     fwd_brc_a;
logic [1:0]     fwd_brc_b;
logic X;
logic [31:0] o_execute_alu_data_decode;
logic ctrl_wb;
logic stall_cache;
logic cache_hit_debug;
logic cache_miss_debug;
    fetch_cycle fetch_top(
        .i_fetch_clk        (i_clk),
        .i_fetch_reset      (i_reset),

        .i_fetch_pc_sel     (pc_sel),
        .i_fetch_alu_data   (alu_data_mem /*o_mem_alu_data*/),
        .i_stall            (Stall),
        .i_flush            (flush),
        .i_fetch_stall_cache (stall_cache),

        .o_fetch_inst_id    (inst_decode),
        .o_fetch_pc_id      (pc_decode),
        .o_fetch_insn_vld_id(insn_vld_decode)
    );

    decode_cycle decoce_top(
        .i_decode_clk           (i_clk),
        .i_decode_reset         (i_reset),
        
        .i_decode_inst          (inst_decode),
        .i_decode_pc            (pc_decode),

        .i_decode_rd_addr       (rd_addr_decode),
        .i_decode_rd_data       (rd_data_decode),
        .i_decode_rd_wren       (rd_wren_decode),

        .i_decode_flush         (flush),
        .i_decode_stall         (Stall),
        .i_decode_stall_cache   (stall_cache),
        .i_decode_insn_vld      (insn_vld_decode),

        .i_decode_alu_data_execute (o_execute_alu_data_decode),

        .o_decode_inst_ex       (inst_execute),
        .o_decode_pc_ex         (pc_execute),
        .o_decode_ctrl          (ctrl_execute),

        .o_decode_asel_ex       (asel_execute),
        .o_decode_bsel_ex       (bsel_execute),
        .o_decode_rs1_data_ex   (rs1_data_execute),
        .o_decode_rs2_data_ex   (rs2_data_execute),
        .o_decode_imm_out_ex    (imm_out_execute),
        .o_decode_alu_op_ex     (alu_op_execute),
        .o_decode_br_un_ex      (br_un_execute),

        .o_decode_lsu_wren_ex   (lsu_wren_execute),
        .o_decode_slt_sl_ex     (slt_sl_execute),
        .o_decode_wb_sel_ex     (wb_sel_execute),
        .o_decode_rd_wren_ex    (rd_wren_execute),
        .o_insn_vld_ctrl        (insn_vld_execute),
        .o_decode_rs1_addr_hazard(rs1_addr_decode),
        .o_decode_rs2_addr_hazard(rs2_addr_decode)
        
    );

    execute_cycle execute_top(
        .i_execute_clk           (i_clk),
        .i_execute_reset         (i_reset),

        .i_execute_pc           (pc_execute),
        .i_execute_inst         (inst_execute),
        .i_execute_ctrl         (ctrl_execute),

        .i_execute_lsu_wren     (lsu_wren_execute),
        .i_execute_slt_sl       (slt_sl_execute),
        
        .i_execute_wb_sel       (wb_sel_execute),
        .i_execute_rd_wren      (rd_wren_execute),

        .i_execute_asel         (asel_execute),
        .i_execute_bsel         (bsel_execute),
        .i_execute_rs1_data     (rs1_data_execute),
        .i_execute_rs2_data     (rs2_data_execute),
        .i_execute_imm_out      (imm_out_execute),
        .i_execute_alu_op       (alu_op_execute),
        .i_execute_br_un        (br_un_execute),    
        .i_execute_insn_vld     (insn_vld_execute),

        .flush                  (flush),
        //.i_stall                (Stall),
        .i_execute_cache_done (o_cache_done),
        .i_execute_stall_cache  (stall_cache),

        .i_execute_fwd_operand_a(fwd_operand_a),
        .i_execute_fwd_operand_b(fwd_operand_b),
        
        .i_execute_fwd_alu_data (alu_data_mem),
        .i_execute_fwd_wb_data  (rd_data_decode),

        .o_execute_br_equal_mem (br_equal_mem),
        .o_execute_br_less_mem  (br_less_mem),
        .o_execute_alu_data     (alu_data_mem),

        .o_execute_pc_mem       (pc_mem),
        .o_execute_rs2_data_mem (rs2_data_mem),
        .o_execute_inst_mem     (inst_mem),
        .o_execute_insn_vld_mem (insn_vld_mem),
        .o_execute_ctrl         (ctrl_mem),

        .o_execute_lsu_wren_mem (lsu_wren_mem),
        .o_execute_slt_sl_mem   (slt_sl_mem),
        
        .o_execute_wb_sel_mem   (wb_sel_mem),
        .o_execute_rd_wren_mem  (rd_wren_mem),

        .o_execute_inst_fwd     (),

        .o_execute_alu_data_decode (o_execute_alu_data_decode)
    );

    memory_cycle memory_top(
        .i_clk                  (i_clk),
        .i_reset                (i_reset),      

        .i_mem_inst             (inst_mem),

        .i_mem_pc               (pc_mem),
        .i_mem_rs2_data         (rs2_data_mem),
        .i_mem_br_equal         (br_equal_mem),
        .i_mem_br_less          (br_less_mem),
        .i_mem_alu_data         (alu_data_mem),

        .i_mem_lsu_wren         (lsu_wren_mem),
        .i_mem_slt_sl           (slt_sl_mem),
        .i_mem_insn_vld         (insn_vld_mem),
        .i_mem_ctrl             (ctrl_mem),

        .i_mem_wb_sel           (wb_sel_mem),
        .i_mem_rd_wren          (rd_wren_mem),

        .i_io_sw                (i_io_sw),

        .o_mem_pc_add4_wb       (pc_add4_wb),
        .o_mem_alu_data_wb      (alu_data_wb),
        .o_mem_insn_vld_wb      (insn_vld_wb),

        .o_mem_ld_data_wb       (ld_data_wb),
        .o_mem_io_ledr_wb       (o_io_ledr),
        .o_mem_io_ledg_wb       (o_io_ledg),
        .o_mem_io_hex0_wb       (o_io_hex0),
        .o_mem_io_hex1_wb       (o_io_hex1),
        .o_mem_io_hex2_wb       (o_io_hex2),
        .o_mem_io_hex3_wb       (o_io_hex3),
        .o_mem_io_hex4_wb       (o_io_hex4),
        .o_mem_io_hex5_wb       (o_io_hex5),
        .o_mem_io_hex6_wb       (o_io_hex6),
        .o_mem_io_hex7_wb       (o_io_hex7),
        .o_mem_io_lcd_wb        (o_io_lcd),

        .o_mem_inst_wb          (inst_wb),

        .o_mem_wb_sel_wb        (wb_sel_wb),
        .o_mem_rd_wren_wb       (rd_wren_wb),

        .o_mem_rd_addr_fwd      (rd_addr_mem),
        .o_mem_pc_debug         (pc_debug_wb),
        .o_mem_ctrl             (ctrl_wb),
        .o_mem_stall_cache       (stall_cache),
        .o_mem_cache_done        (o_cache_done),
        .o_mem_cache_hit_debug   (cache_hit_debug),
        .o_mem_cache_miss_debug  (cache_miss_debug),
        .o_mem_slt_sl_wb          (slt_sl_wb)
    );

    writeback_cycle writeback_top(
        .i_wb_inst          (inst_wb),

        .i_wb_pc_add4       (pc_add4_wb),
        .i_wb_alu_data      (alu_data_wb),
        
        .i_wb_ld_data       (ld_data_wb),

        .i_wb_wb_sel        (wb_sel_wb),
        .i_wb_rd_wren       (rd_wren_wb),
        .i_wb_slt_sl        (slt_sl_wb),

        .o_wb_data_wb       (rd_data_decode),
        .o_wb_rd_addr       (rd_addr_decode),
        .o_wb_rd_wren       (rd_wren_decode),

        .o_wb_rd_data_fwd   (rd_addr_wb),
        .o_wb_ctrl          (X)
    );
    //assign Stall = 0; // temporary disable hazard detection
    hazard_detection hazard_load_top(
        .i_hazard_inst_execute      (inst_execute),
        .i_hazard_rs1_addr_decode   (rs1_addr_decode),
        .i_hazard_rs2_addr_decode   (rs2_addr_decode),
        .i_hazard_wb_sel_execute    (wb_sel_execute),
        .i_hazard_rd_wren_execute   (rd_wren_execute),
        .i_hazard_inst_decode       (inst_decode),
        .Stall                      (Stall)
    );

    branch_taken branch_taken_top(
        .i_br_less_mem              (br_less_mem),
        .i_br_equal_mem             (br_equal_mem),
        .i_inst_mem                 (inst_mem),
        .o_pc_sel                   (pc_sel),
        .flush                      (flush)
    );

    forward forward_top(
        .i_fwd_inst_execute         (inst_execute),
        .i_fwd_rd_addr_at_mem       (rd_addr_mem),
        .i_fwd_rd_addr_at_wb        (rd_addr_wb),
        .i_fwd_rd_wren_at_mem       (rd_wren_mem),
        .i_fwd_rd_wren_at_wb        (rd_wren_wb),
        .o_fwd_operand_a_execute    (fwd_operand_a),
        .o_fwd_operand_b_execute    (fwd_operand_b)
  
    );

    always_ff @ (negedge i_clk) begin
        //$display(" INST_WB = %h, PC_DEBUG = %h, load_data = %h, data_writeback = %h, stall = %h",inst_wb, o_pc_debug, ld_data_wb, rd_data_decode, Stall);
       if (insn_vld_wb)
       $display("INST_WB = %h, PC_DEBUG = %h, INSN_VLD = %h, RD_WREN = %h, RD_ADDR = %h, WB_DATA = %h, time = %d", inst_wb, o_pc_debug, insn_vld_wb, rd_wren_decode,rd_addr_decode, rd_data_decode, $time);
    end
    
    always_ff @ (posedge i_clk) begin
            o_mispred  <= flush;
    end
           
    assign o_insn_vld = insn_vld_wb;
    assign o_pc_debug = (o_insn_vld) ? pc_debug_wb : 32'b0;
    assign o_ctrl = ctrl_wb;
    assign o_cache_hit_debug = cache_hit_debug;
    assign o_cache_miss_debug = cache_miss_debug;
endmodule
`endif
