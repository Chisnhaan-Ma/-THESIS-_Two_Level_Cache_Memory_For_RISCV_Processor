`ifndef FULL_ADDER
`define FULL_ADDER
module full_adder (
    input  logic A,
	input logic B,
	input logic Cin,
    output logic Sum,
	output logic Cout);
	 
    assign Sum  = A ^ B ^ Cin;
    assign Cout = (A & B) | (Cin & (A ^ B));
endmodule
`endif