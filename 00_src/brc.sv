`ifndef BRC
`define BRC
`include "add_sub_32_bit.sv"
module  brc (
	//  input
	input  logic  [31:0]  i_rs1_data,
	input  logic  [31:0]  i_rs2_data,
	input  logic          i_br_un,
	//  output
	output  logic  o_br_less,
	output  logic  o_br_equal
);
    logic [31:0] Diff;  // Kết quả phép trừ rs1 - rs2
    logic Cout;         // Carry-out từ add_sub_32_bit

    add_sub_32_bit subtractor (
        .A          (i_rs1_data),
        .B          (i_rs2_data),
        .Sel        (1'b1),   // SUB
        .Result     (Diff),
        .Cout       (Cout)
    );

    // o_br_equal
    always @(*) begin
        if (Diff == 32'b0)
            o_br_equal = 1'b1;
        else
            o_br_equal = 1'b0;
    end

    // o_br_less
    always @(*) begin
        if (i_br_un)  // Unsigned
            o_br_less = ~Cout;
        else       // Signed
            o_br_less = Diff[31];
    end

endmodule
`endif 