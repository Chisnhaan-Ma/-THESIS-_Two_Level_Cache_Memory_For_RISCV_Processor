
`ifndef ALU
`define ALU

`include "add_sub_32_bit.sv"
`include "shift_right_logical.sv"
`include "shift_left_logical.sv"
`include "shift_right_arithmetic.sv"
`include "slt_sltu.sv"

module alu(
	//  input
	input  logic  [31:0]  i_operand_a,
	input  logic  [31:0]  i_operand_b,
    input  logic   [3:0]  i_alu_op,
	//  output
	output  logic  [31:0]  o_alu_data
);
    logic [31:0] add_sub_out, sll_out, srl_out, sra_out;
    logic [31:0] slt_out, sltu_out;

    // Instance các module cần dùng
	 // ADD, SUB
    add_sub_32_bit add_sub_alu( 
	 .A(i_operand_a),
	 .B(i_operand_b),
	 .Sel(i_alu_op[3]),
	 .Result(add_sub_out)); 
	 
	 // SLL
    shift_left_logical sll_alu(
	 .data_in(i_operand_a),
	 .shift_amt(i_operand_b[4:0]),
	 .data_out(sll_out)); // SLL

	 // SRL
    shift_right_logical srl_alu(
	 .data_in(i_operand_a), 
	 .shift_amt(i_operand_b[4:0]),
	 .data_out(srl_out)); 
	 
	 // SRA
    shift_right_arithmetic sra_alu(
	 .data_in(i_operand_a), 
	 .shift_amt(i_operand_b[4:0]),
	 .data_out(sra_out)); 
	 
	 // SLT
    slt_sltu slt_alu(
	 .A(i_operand_a), 
	 .B(i_operand_b), 
	 .Sel(1'b0),
	 .Result(slt_out));  
	 
	 // SLT
    slt_sltu sltu_alu(
	 .A(i_operand_a),
	 .B(i_operand_b), 
	 .Sel(1'b1), 
	 .Result(sltu_out));  

    always_comb begin
        case (i_alu_op)
            4'b0000: o_alu_data = add_sub_out;  			  // ADD
            4'b1000: o_alu_data = add_sub_out;  			  // SUB
            4'b0001: o_alu_data = sll_out;      			  // SLL
            4'b0010: o_alu_data = slt_out;  				  // SLT (1 bit)
            4'b0011: o_alu_data = sltu_out;                   // SLTU (1 bit)
            4'b0100: o_alu_data = i_operand_a ^ i_operand_b;  // XOR
            4'b0101: o_alu_data = srl_out;                    // SRL
            4'b1101: o_alu_data = sra_out;                    // SRA
            4'b0110: o_alu_data = i_operand_a | i_operand_b;  // OR
            4'b0111: o_alu_data = i_operand_a & i_operand_b;  // AND
			4'b1111: o_alu_data = i_operand_b; 				  //Cho lệnh LUI
            default: o_alu_data = 32'bz;  
        endcase
    end
endmodule
`endif
