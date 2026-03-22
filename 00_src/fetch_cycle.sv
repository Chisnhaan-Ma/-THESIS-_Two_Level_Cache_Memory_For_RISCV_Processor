`ifndef FETCH_CYCLE
`define FETCH_CYCLE

`include "pc.sv"
`include "add_sub_32_bit.sv"
`include "inst_memory.sv"
`include "mux2_1.sv"

module fetch_cycle (
    input logic         i_fetch_clk,
    input logic         i_fetch_reset,

    // i_fetch_pc_sel chọn nhảy từ control unit
    input logic         i_fetch_pc_sel,                      
    input logic [31:0]  i_fetch_alu_data,  // địa chỉ nhảy từ Execute
	
	 // i_stall, i_flush
	input logic         i_stall,
    input logic         i_fetch_stall_cache,
	input logic         i_flush,
	 
    // Output to Decode
    output logic [31:0] o_fetch_pc_id,
    output logic [31:0] o_fetch_inst_id,
    output logic        o_fetch_insn_vld_id
);
    logic [31:0] reg_pc_in, reg_pc_out, reg_pc_add4_out, pc_reg;
    logic [31:0] inst, inst_reg;
    logic insn_vld_reg, insn_vld;
    logic pc_enable;
    assign pc_enable = ~i_stall & ~i_fetch_stall_cache;
    // pc
    pc pc_at_fetch (
        .i_clk          (i_fetch_clk),
        .i_reset        (i_fetch_reset),
        .i_pc_enable    (pc_enable), // Thêm enable để dừng pc khi i_stall
        .i_pc_data_in   (reg_pc_in),
        .o_pc_data_out  (reg_pc_out)
    );


    // Tính pc + 4
    add_sub_32_bit pc_add4_at_fetch (
        .A              (reg_pc_out),
        .B              (32'd4),
        .Sel            (1'b0),
        .Result         (reg_pc_add4_out)
    );

    // Chọn địa chỉ tiếp theo: nhảy hoặc +4
    mux_2_1 pc_taken_at_fetch (
        .data_0_i   (reg_pc_add4_out),
        .data_1_i   (i_fetch_alu_data),
        .sel_i      (i_fetch_pc_sel),
        .data_out_o (reg_pc_in)
    );

    inst_memory inst_memory_at_fetch (
        .i_addr     (reg_pc_out),
        .o_rdata    (inst)
    );
    // Pipeline register IF/ID
    always_ff @(posedge i_fetch_clk /*or posedge i_fetch_reset*/) begin
        if (i_fetch_reset) begin
            inst_reg     <= 32'b0;
            pc_reg       <= 32'b0;
            insn_vld_reg <= 0;
        end 
        else begin

            if (i_flush) begin
                inst_reg     <= 32'h00000013; // NOP khi i_flush
                pc_reg       <= 32'b0;
                insn_vld_reg <= 0;
            end 
            else begin
                inst_reg     <= inst;
                insn_vld_reg <= 1'b1;
            end

            if (~i_stall & ~i_fetch_stall_cache) begin
                pc_reg <= reg_pc_out; // Chỉ cập nhật pc nếu không i_stall
                
            end
            else inst_reg <= inst_reg;
        end
    end

    assign o_fetch_inst_id      = i_flush ? 1'b0 : inst_reg;
    assign o_fetch_pc_id        = pc_reg;
    assign o_fetch_insn_vld_id  = insn_vld_reg;
endmodule
`endif