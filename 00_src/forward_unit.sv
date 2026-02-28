module forward(
    input logic [31:0]  i_fwd_inst_execute,
    input logic [4:0]   i_fwd_rd_addr_at_mem,
    input logic [4:0]   i_fwd_rd_addr_at_wb,
    input logic         i_fwd_rd_wren_at_mem,
    input logic         i_fwd_rd_wren_at_wb,
    output logic [1:0]  o_fwd_operand_a_execute,
    output logic [1:0]  o_fwd_operand_b_execute
);
//logic [6:0] opcode_EX;
    logic [4:0] rs1_addr_execute; 
    logic [4:0] rs2_addr_execute;
    logic [6:0] opcode_fwd;
    // Tách rs1 và rs2 từ instruction 
    assign rs1_addr_execute = i_fwd_inst_execute[19:15];
    assign rs2_addr_execute = i_fwd_inst_execute[24:20];
    assign opcode_fwd       = i_fwd_inst_execute[6:0];

    always @ (*) begin
            //---------- Forward operand a ALU -----------------------
            if ((i_fwd_rd_addr_at_mem != 5'd0) && (i_fwd_rd_addr_at_mem == rs1_addr_execute)&&(i_fwd_rd_wren_at_mem))
                o_fwd_operand_a_execute = 2'b01;  // Forward từ MEM
                
            else if ((i_fwd_rd_addr_at_wb != 5'd0) && (i_fwd_rd_addr_at_wb == rs1_addr_execute)&&(i_fwd_rd_wren_at_wb))
                o_fwd_operand_a_execute = 2'b10;  // Forward từ WB
                
            else o_fwd_operand_a_execute = 2'b00;

            //-------------Forward operand b ALU -----------------------
            if ((i_fwd_rd_addr_at_mem != 5'd0) && (i_fwd_rd_addr_at_mem == rs2_addr_execute)&&(i_fwd_rd_wren_at_mem))
                o_fwd_operand_b_execute = 2'b01;  // Forward từ MEM

            else if ((i_fwd_rd_addr_at_wb != 5'd0) && (i_fwd_rd_addr_at_wb == rs2_addr_execute)&&(i_fwd_rd_wren_at_wb))
                o_fwd_operand_b_execute = 2'b10;  // Forward từ WB

            else o_fwd_operand_b_execute = 2'b00;
    end

endmodule