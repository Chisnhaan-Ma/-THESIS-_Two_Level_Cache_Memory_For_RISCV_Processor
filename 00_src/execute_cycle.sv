`include "brc.sv"
`include "mux3_1.sv"
`include "mux2_1.sv"
`include "alu.sv"
//chưa add insn valid///////
module execute_cycle(
    input logic         i_execute_clk,
    input logic         i_execute_reset,

    // Input từ Decode PC, inst giữ nguyên
    input logic [31:0]  i_execute_pc, 
    input logic [31:0]  i_execute_inst,
    input logic         i_execute_insn_vld,
    input logic         i_execute_ctrl,

    // Input từ Decode, giữ hộ MEM control
    input logic         i_execute_lsu_wren,
    input logic [2:0]   i_execute_slt_sl,

    // Input từ Decode, giữ hộ Writeback control
    input logic [1:0]   i_execute_wb_sel,
    input logic         i_execute_rd_wren,

    // Input từ Decode được sử dụng trong Execute
    input logic         i_execute_asel,
    input logic         i_execute_bsel,
    input logic [31:0]  i_execute_rs1_data,
    input logic [31:0]  i_execute_rs2_data,
    input logic [31:0]  i_execute_imm_out,
    input logic [3:0]   i_execute_alu_op,
    input logic         i_execute_br_un,

    // Input từ MEM cho flush
    input logic         flush,
    input logic         i_stall,
    input logic         i_execute_stall_cache,
    input logic         i_execute_cache_done,

    // Input từ Forwarding control
    input logic [1:0]   i_execute_fwd_operand_a,
    input logic [1:0]   i_execute_fwd_operand_b,

    // Data forwarding từ MEM và WriteBack
    input logic [31:0]  i_execute_fwd_alu_data,
    input logic [31:0]  i_execute_fwd_wb_data,

    // Outputs tới MEM giá trị tính được từ Execute
    output logic        o_execute_br_equal_mem,
    output logic        o_execute_br_less_mem,
    output logic [31:0] o_execute_alu_data,

    // Output tới MEM các giá trị giữ hộ
    output logic [31:0] o_execute_pc_mem,
    output logic [31:0] o_execute_rs2_data_mem,
    output logic [31:0] o_execute_inst_mem,
    output logic        o_execute_insn_vld_mem,
    output logic        o_execute_ctrl,

    // Output to Execute MEM control
    output logic        o_execute_lsu_wren_mem,
    output logic [2:0]  o_execute_slt_sl_mem,

    // Output to Execute Writeback control
    output logic [1:0]  o_execute_wb_sel_mem,
    output logic        o_execute_rd_wren_mem,

    // Output rs1 và rs2 để forward
    output logic [31:0] o_execute_inst_fwd,

    //Output to decode để forward
    output logic  [31:0] o_execute_alu_data_decode
);

    logic [31:0] alu_data;
    logic [31:0] forward_a_out;
    logic [31:0] forward_b_out;

    logic [31:0] pc_reg;
    logic [31:0] inst_reg, inst_tmp;;
    logic [31:0] rs2_data;
    logic [31:0] rs2_data_reg;
    logic [31:0] alu_data_reg;
    logic br_equal_reg, br_equal;
    logic br_less_reg, br_less;
    logic wren_reg;
    logic [2:0] slt_sl_reg;
    logic [1:0] wb_sel_reg;
    logic rd_wren_reg;
    logic [31:0] asel_out, bsel_out;
    logic [31:0]brc_operand_a_out, brc_operand_b_out;
    logic insn_vld_reg;
    logic ctrl_reg;
    assign o_execute_inst_fwd = i_execute_inst;

    mux_3_1 mux_forward_operand_a (
        .data_0_i       (i_execute_rs1_data),
        .data_1_i       (i_execute_fwd_alu_data),
        .data_2_i       (i_execute_fwd_wb_data),
        .sel_i          (i_execute_fwd_operand_a),
        .data_out_o     (forward_a_out)
    );

    mux_3_1 mux_forward_operand_b (
        .data_0_i       (i_execute_rs2_data),
        .data_1_i       (i_execute_fwd_alu_data),
        .data_2_i       (i_execute_fwd_wb_data),
        .sel_i          (i_execute_fwd_operand_b),
        .data_out_o     (forward_b_out)
    );

    mux_2_1 mux_asel (
        .data_0_i       (forward_a_out),
        .data_1_i       (i_execute_pc),
        .sel_i          (i_execute_asel),
        .data_out_o     (asel_out)
    );

    mux_2_1 mux_bsel (
        .data_0_i       (forward_b_out),
        .data_1_i       (i_execute_imm_out),
        .sel_i          (i_execute_bsel),
        .data_out_o     (bsel_out)
    );

    // Branch comparator
    brc brc_at_execute (
        .i_br_un        (i_execute_br_un),
        .i_rs1_data     (forward_a_out),
        .i_rs2_data     (forward_b_out),
        .o_br_equal     (br_equal),
        .o_br_less      (br_less)
    );

    // ALU
    alu alu_at_execute(
        .i_operand_a    (asel_out),
        .i_operand_b    (bsel_out), 
        .o_alu_data     (alu_data),
        .i_alu_op       (i_execute_alu_op)
    );

    // Pipeline registers
    always_ff @ (posedge i_execute_clk) begin
        
        if (i_execute_reset) begin
            pc_reg          <= 32'd0;
            inst_reg        <= 32'h00000013; // NOP
            rs2_data_reg    <= 32'd0;
            alu_data_reg    <= 32'd0;
            wren_reg        <= 0;
            slt_sl_reg      <= 0;
            wb_sel_reg      <= 0;
            rd_wren_reg     <= 0;
            br_equal_reg    <= 0;
            br_less_reg     <= 0;
            insn_vld_reg    <= 0;
            ctrl_reg <= 1'b0;    
        end 
        /*
        else if (i_execute_stall_cache) begin
            // Khi i_stall: Giữ lại toàn bộ dữ liệu cũ, nhưng chèn NOP
            inst_reg     <= inst_reg; //i_execute_inst;//inst_reg; // NOP khi i_stall
            //$display("Stall inst_reg: %h", inst_reg);
        end
        */
		else if (flush) begin
			pc_reg       <= 32'b0;//i_execute_pc; //pc_reg;
            inst_reg     <= 32'h00000013; // NOP khi i_flush
            rs2_data_reg <= 32'd0;
            alu_data_reg <= 32'd0;
            wren_reg     <= 0;
            slt_sl_reg   <= 0;
            wb_sel_reg   <= 0;
            rd_wren_reg  <= 0;
            br_equal_reg <= 0;
            br_less_reg  <= 0;
            insn_vld_reg <= 0;
            ctrl_reg <= i_execute_ctrl;    
          end	

		else if (!i_execute_stall_cache) begin
            pc_reg       <= i_execute_pc;
            inst_reg     <= i_execute_inst;
            rs2_data_reg <= forward_b_out;
            alu_data_reg <= alu_data;
            wren_reg     <= i_execute_lsu_wren;
            slt_sl_reg   <= i_execute_slt_sl;
            wb_sel_reg   <= i_execute_wb_sel;
            rd_wren_reg  <= i_execute_rd_wren;
            br_equal_reg <= br_equal;
            br_less_reg  <= br_less;
            insn_vld_reg <= i_execute_insn_vld;
            ctrl_reg     <= i_execute_ctrl;
        end
        else;
    end

    assign o_execute_alu_data       = alu_data_reg;
    assign o_execute_pc_mem         = /*i_execute_stall_cache ? 32'h00000013 :*/ pc_reg;
    assign o_execute_rs2_data_mem   = /*i_execute_stall_cache ? 32'h00000013 :*/ rs2_data_reg;
    assign o_execute_inst_mem       = i_execute_stall_cache ? 32'h00000013 : inst_reg;
    assign o_execute_lsu_wren_mem   = /*i_execute_stall_cache ? 1'b0 :*/ wren_reg;
    assign o_execute_slt_sl_mem     = /*i_execute_stall_cache ? 1'b0 :*/ slt_sl_reg;
    assign o_execute_wb_sel_mem     = /*i_execute_stall_cache ? 1'b0 :*/ wb_sel_reg;
    assign o_execute_rd_wren_mem    = /*i_execute_stall_cache ? 1'b0 :*/ rd_wren_reg;
    assign o_execute_br_equal_mem   = /*i_execute_stall_cache ? 1'b0 :*/ br_equal_reg;
    assign o_execute_br_less_mem    = /*i_execute_stall_cache ? 1'b0 :*/ br_less_reg;  
    assign o_execute_insn_vld_mem   = /*i_execute_stall_cache ? 1'b0 :*/ insn_vld_reg;
    assign o_execute_alu_data_decode= /*i_execute_stall_cache ? 32'h00000013 :*/ alu_data;
    assign o_execute_ctrl           = /*i_execute_stall_cache ? 1'b0 :*/ ctrl_reg;
endmodule