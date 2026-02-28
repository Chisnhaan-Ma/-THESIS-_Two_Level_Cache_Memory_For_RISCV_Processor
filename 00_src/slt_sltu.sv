// Author: Nhan Ma C
`ifndef SLT_SLTU
`define SLT_SLTU 
`include "add_sub_32_bit.sv"
module slt_sltu (
    input  logic [31:0] A, B,  // Input A, B
    input  logic Sel,          // 0 = SLT (có dấu), 1 = SLTU (không dấu)
    output logic [31:0] Result); // Kết quả

    logic [31:0] diff_out;  // Kết quả phép trừ A - B
    logic carry_out;        // Carry/Borrow từ phép trừ

    add_sub_32_bit SUB(
        .A(A),
        .B(B), 
        .Sel(1'b1), 
        .Result(diff_out),
        .Cout(carry_out)
    );

    // So sánh
    always_comb begin
        if (Sel == 1'b0) begin  // SLT (có dấu)
            // Nếu khác dấu: A<0 && B>=0 → 1; B<0 && A>=0 → 0
            // Nếu cùng dấu: dùng bit dấu của (A - B)
            if (A[31] != B[31])
                Result = {31'b0, A[31]};
            else
                Result = {31'b0, diff_out[31]};
        end 
        else begin  // SLTU (không dấu)
            Result = {31'b0, ~carry_out}; // carry_out=1 nghĩa là A>=B
        end
    end

endmodule
`endif 