`include "full_adder.sv"
`ifndef ADD_SUB_32_BIT
`define ADD_SUB_32_BIT
module add_sub_32_bit (
    input  logic [31:0] A, B,   // Input A, B
    input  logic Sel,           // 0 = ADD, 1 = SUB
    output logic [31:0] Result, // Kết quả phép cộng 
    output logic Cout);         // Carry-out

    logic [31:0] B_mod;         
    logic Cin;                  // Carry-in
    logic [31:0] carry;         // Carry signals
    assign B_mod = (Sel) ? ~B : B;  // Bù 2 của B

    full_adder FA0(
	 A[0],
	 B_mod[0],
	 Sel,
	 Result[0],
	 carry[0]);

    // Generate 31 more full adders
    genvar i;
    generate
        for (i = 1; i < 32; i = i + 1) begin :adder_32
            full_adder FA (A[i], B_mod[i], carry[i-1], Result[i], carry[i]);
        end
    endgenerate

    assign Cout = carry[31];

endmodule
`endif