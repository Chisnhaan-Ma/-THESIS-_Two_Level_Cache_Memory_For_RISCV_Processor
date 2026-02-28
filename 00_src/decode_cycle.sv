`ifndef DECODE_CYCLE
`define DECODE_CYCLE
`include "regfile.sv"
`include "imm_gen.sv"
`include "control_unit_new.sv"
`include "mux2_1.sv"
module decode_cycle(
    input logic         i_decode_clk,
    input logic         i_decode_reset,

    // Input từ Fetch
    input logic [31:0]  i_decode_pc,
    input logic [31:0]  i_decode_inst,

    // Input từ Writeback
    input logic [31:0]  i_decode_rd_data,
    input logic [4:0]   i_decode_rd_addr,
    input logic         i_decode_rd_wren,
	
	// i_decode_flush
    input logic         i_decode_flush,
    input logic         i_decode_stall,
    input logic         i_decode_stall_cache,
    input logic         i_decode_insn_vld,

    //Input alu data for forwarding
    input logic  [31:0] i_decode_alu_data_execute,

    // Output tới Ex giá trị PC và inst
    output logic [31:0] o_decode_inst_ex,
    output logic [31:0] o_decode_pc_ex,


    // Output to Execute EX_control
    output logic        o_decode_asel_ex,
    output logic        o_decode_bsel_ex,
    output logic [31:0] o_decode_rs1_data_ex,
    output logic [31:0] o_decode_rs2_data_ex,
    output logic [31:0] o_decode_imm_out_ex,
    output logic [3:0]  o_decode_alu_op_ex,
    output logic        o_decode_br_un_ex,

    // Output to Execute MEM control
    output logic        o_decode_lsu_wren_ex,
    output logic [2:0]  o_decode_slt_sl_ex,

    // Output to Execute Writeback control
    output logic [1:0]  o_decode_wb_sel_ex,
    output logic        o_decode_rd_wren_ex,

    // Output instruction valid
    output logic        o_insn_vld_ctrl,
	 
	// Output để fix load hazard
	output logic [4:0]  o_decode_rs1_addr_hazard,
	output logic [4:0]  o_decode_rs2_addr_hazard,

    output logic o_decode_ctrl
);
    // Signal Imm_Gen
    logic [31:0]        imm_out, imm_out_reg;
    logic [2:0]         imm_sel;

    // Signal Regfile
    logic [31:0]        data_1, data_2;
    logic [31:0]        data_1_reg, data_2_reg;

    //Signal Control Unit
    logic [3:0] alu_op, alu_op_reg;
    logic       br_un,  br_un_reg; 
    logic       wren,   wren_reg;
    logic [2:0] slt_sl, slt_sl_reg;
    logic [1:0] wb_sel, wb_sel_reg;
    logic       rd_wren,rd_wren_reg;
    logic       asel,   asel_reg;
    logic       bsel,   bsel_reg;

    logic       insn_vld_ctrl, insn_vld_ctrl_reg;

    logic [31:0] pc_reg, inst_reg;
    logic ctrl_reg, ctrl;

    //For decode forwarding
    logic [4:0] rd_addr_execute;
    logic [4:0] rs1_addr_decode;
    logic [4:0] rs2_addr_decode;
    logic sel_forward_decode;

    assign rd_addr_execute = o_decode_inst_ex[11:7];
    assign rs1_addr_decode = i_decode_inst[19:15];
    assign rs2_addr_decode = i_decode_inst[24:20];

    regfile regfile_at_decode (
        .i_clk      (i_decode_clk),
        .i_reset    (i_decode_reset),
        .i_rs1_addr (rs1_addr_decode),
        .i_rs2_addr (rs2_addr_decode),
        .i_rd_addr  (i_decode_rd_addr),
        .i_rd_data  (i_decode_rd_data),
        .i_rd_wren  (i_decode_rd_wren),
        .o_rs1_data (data_1),
        .o_rs2_data (data_2)
    );
/*
Control unit của pipeline khác với của single cycle, dự đoán luôn nhảy
 -> bỏ các tín hiệu liên quan đến nhảy */
    control_unit_new control_unit_at_decode (
        .i_inst         (i_decode_inst),
        .o_imm_sel      (imm_sel),
        .o_rd_wren      (rd_wren),
        .o_br_un        (br_un),
        .o_bsel         (bsel),
        .o_asel         (asel),
        .o_alu_op       (alu_op),
        .o_wren         (wren),
        .o_slt_sl       (slt_sl),
        .o_wb_sel       (wb_sel),
        .o_ctrl         (ctrl)
    );

    imm_gen imm_gen_at_decode (
        .i_inst         (i_decode_inst),
        .i_imm_sel      (imm_sel),
        .o_imm_out      (imm_out)
    );

    always_ff @(posedge i_decode_clk ) begin
        if (i_decode_reset) begin
            imm_out_reg   <= 32'b0;
            data_1_reg    <= 32'b0;
            data_2_reg    <= 32'b0;
            pc_reg        <= 32'b0;
            inst_reg      <= 32'h00000013; // NOP
            alu_op_reg    <= 4'b0;
            br_un_reg     <= 1'b0;
            wren_reg      <= 1'b0;
            slt_sl_reg    <= 3'b0;
            wb_sel_reg    <= 2'b0;
            rd_wren_reg   <= 1'b0;
            asel_reg      <= 1'b0;
            bsel_reg      <= 1'b0;
            insn_vld_ctrl_reg <= 1'b0;
            ctrl_reg <= 0;
        end 
		else if (i_decode_stall) begin
            // Khi i_decode_stall: Giữ lại toàn bộ dữ liệu cũ, nhưng chèn NOP
            inst_reg      <= 32'h00000013; // chỉ thay đổi instruction
            insn_vld_ctrl_reg <= 1'b0;
        end 
        else if (i_decode_stall_cache) begin
            // Khi i_stall: Giữ lại toàn bộ dữ liệu cũ, nhưng chèn NOP
            //inst_reg     <= inst_reg;  // NOP khi i_stall
            //insn_vld_reg <= 1'b0;
        end
		  else if (i_decode_flush) begin
			imm_out_reg   <= 32'b0;
            data_1_reg    <= 32'b0;
            data_2_reg    <= 32'b0;
            pc_reg        <= i_decode_pc;
            inst_reg      <= 32'h00000013; // NOP
            alu_op_reg    <= 4'b0;
            br_un_reg     <= 1'b0;
            wren_reg      <= 1'b0;
            slt_sl_reg    <= 3'b0;
            wb_sel_reg    <= 2'b0;
            rd_wren_reg   <= 1'b0;
            asel_reg      <= 1'b0;
            insn_vld_ctrl_reg <= 1'b0;
            ctrl_reg      <= ctrl;
		  end
		  else begin
            imm_out_reg   <= imm_out;
            data_1_reg    <= data_1;
            data_2_reg    <= data_2;
            pc_reg        <= i_decode_pc;
            inst_reg      <= i_decode_inst;
            alu_op_reg    <= alu_op;
            br_un_reg     <= br_un;
            wren_reg      <= wren;
            slt_sl_reg    <= slt_sl;
            wb_sel_reg    <= wb_sel;
            rd_wren_reg   <= rd_wren;
            asel_reg      <= asel;
            bsel_reg      <= bsel;
            insn_vld_ctrl_reg <= i_decode_insn_vld; //insn_vld_ctrl;
            ctrl_reg      <= ctrl;
        end
    end

    assign o_decode_pc_ex       = (i_decode_flush) ? 32'b0: pc_reg;
    assign o_decode_rs1_data_ex = data_1_reg;
    assign o_decode_rs2_data_ex = data_2_reg;
    assign o_decode_imm_out_ex  = imm_out_reg;
    assign o_decode_inst_ex     = (i_decode_stall_cache) ? 32'h00000013 : inst_reg;
    assign o_decode_alu_op_ex   = alu_op_reg;
    assign o_decode_br_un_ex    = br_un_reg;
    assign o_decode_lsu_wren_ex = wren_reg;
    assign o_decode_slt_sl_ex   = slt_sl_reg;
    assign o_decode_wb_sel_ex   = wb_sel_reg;
    assign o_decode_rd_wren_ex  = rd_wren_reg;
    assign o_decode_asel_ex     = asel_reg;
    assign o_decode_bsel_ex     = bsel_reg;
	assign o_insn_vld_ctrl      = insn_vld_ctrl_reg;
	// fix load hazard
	assign o_decode_rs1_addr_hazard = i_decode_inst[19:15];
	assign o_decode_rs2_addr_hazard = i_decode_inst[24:20];
    assign o_decode_ctrl = ctrl_reg;
endmodule
`endif