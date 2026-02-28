`ifndef CONTROL_UNIT
`define CONTROL_UNIT
///Control Unit//////
module control_unit_new(
	input logic [31:0]i_inst,
	output logic o_insn_vld_ctrl,
	output logic [2:0]o_imm_sel,
	output logic o_rd_wren,
	output logic o_br_un,
	output logic o_bsel,
	output logic o_asel,
	output logic [3:0]o_alu_op,
	output logic o_wren,
	output logic [2:0] o_slt_sl,
	output logic [1:0]o_wb_sel,
	output logic o_ctrl);
	
	logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

   assign opcode = i_inst[6:0];
   assign funct3 = i_inst[14:12];
	
    always @(*) begin
    	// Giá trị mặc định
        o_imm_sel  = 3'b000;
		o_rd_wren  = 1'b0;
        o_br_un    = 1'b0;
        o_bsel     = 1'b0;
        o_asel     = 1'b0;
        o_alu_op   = 4'b0000;
        o_wren     = 1'b0;
        o_wb_sel   = 2'b00;
		o_slt_sl   = 3'b0;
		o_ctrl     = 1'b0;
		case (opcode)
			7'b0110011: begin  // R-type 
				o_insn_vld_ctrl = 1'b1; 
				o_rd_wren  		= 1'b1;		// cho phép ghi reg file
				o_wb_sel   		= 2'b1; 	// chọn write back từ ngõ ra ALU
				o_asel    		= 1'b0; 	// chọn A từ rs1
				o_bsel    		= 1'b0; 	// chọn B từ rs2s
				o_imm_sel 	 	= 3'b000;	// Imm_Gen theo I type
				o_br_un    		= 1'b0;
				o_wren   		= 1'b0;
				o_slt_sl 		= 3'b0;
				case(funct3)
					3'b000: o_alu_op = (i_inst[30]) ? 4'b1000 : 4'b0000; // SUB nếu i_inst[30] = 1, ADD nếu i_inst[30] = 0
					3'b001: o_alu_op = 4'b0001; // SLL
					3'b010: o_alu_op = 4'b0010; // SLT
					3'b011: o_alu_op = 4'b0011; // SLTU
					3'b100: o_alu_op = 4'b0100; // XOR
					3'b101: o_alu_op = (i_inst[30]) ? 4'b1101 : 4'b0101; // SRA nếu i_inst[30] = 1, SRL nếu i_inst[30] = 0
					3'b110: o_alu_op = 4'b0110; // OR
					3'b111: o_alu_op = 4'b0111; // AND
					default: begin
						o_insn_vld_ctrl =  1'b0;
						o_alu_op = 4'b0000; // Mặc định là ADD
					end
				endcase
			end
			

			7'b0010011: begin  // I-type
				o_slt_sl 		= 3'b000; 
				o_insn_vld_ctrl = 1'b1; 
				o_rd_wren  		= 1'b1;//cho phép ghi reg file
				o_wb_sel   		= 2'b1;// chọn write back từ ngõ ra ALU
				o_asel    		= 1'b0;// chọn A từ rs1
				o_bsel    		= 1'b1;//chọn B từ rs2
				o_imm_sel 		= 3'b000;// Imm_Gen theo I type
				o_wren   		= 1'b0;	// Cho phép đọc đọc DMEM
				o_br_un    		= 1'b0;
				case(funct3)
					3'b000: o_alu_op = 4'b0000; // ADDI
					3'b001: o_alu_op = 4'b0001; // SLLI
					3'b010: o_alu_op = 4'b0010; // SLTI
					3'b011: o_alu_op = 4'b0011; // SLTUI
					3'b100: o_alu_op = 4'b0100; // XORI
					3'b101: o_alu_op = (i_inst[30]) ? 4'b1101 : 4'b0101; // SRAI nếu i_inst[30] = 1, SRLI nếu i_inst[30] = 0
					3'b110: o_alu_op = 4'b0110; // ORI
					3'b111: o_alu_op = 4'b0111; // ANDI
					default: begin
						o_insn_vld_ctrl =  1'b0;
						o_alu_op = 4'b0000; // Mặc định là ADD
					end
				endcase																							
			end
				
			7'b0000011: begin  // Load
				o_insn_vld_ctrl = 1'b1; 
				o_rd_wren  		= 1'b1; 	// Cho phép ghi lại vào regfile
				o_wb_sel   		= 2'b0; 	// Lấy dữ liệu từ DMEM
				o_asel    		= 1'b0; 	// Chọn Rs1 + Imm_Gen
				o_bsel    		= 1'b1; 	// Chọn Imm_Gen
				o_imm_sel 		= 3'b000;	// Imm_Gen theo I type
				o_alu_op 		= 4'b0000;	// Thực hiện phép cộng
				o_wren   		= 1'b0;		// Cho phép đọc đọc DMEM
				o_br_un    		= 1'b0;
				case(funct3)
					3'b000: o_slt_sl = 3'b011; // lb
					3'b001: o_slt_sl = 3'b100; // lh
					3'b010: o_slt_sl = 3'b101; // lw
					3'b100: o_slt_sl = 3'b110; // lbu
					3'b101: o_slt_sl = 3'b111; // lhu	
					default: begin
						o_insn_vld_ctrl =  1'b0;
						//o_load_type = 3'bz;
						o_slt_sl = 3'b101; 
					end
				endcase
			end
			
			7'b0100011: begin //	S-type
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b001;	// Imm_Gen theo S type
				o_rd_wren 		= 1'b0; 	//không cho ghi lại vào reg file
				o_asel 			= 1'b0; 	//chọn A là rs1 
				o_bsel 			= 1'b1; 	//chọn B là Imm_Gen theo S type
				o_wren 			= 1'b1; 	//cho phép đọc và ghi DMEM
				o_alu_op 		= 4'b0000;	// Thực hiện phép cộng
				o_wb_sel 		= 2'b11; 	//write back là tùy định vì không ghi ngược lại vào regfile
				o_br_un    		= 1'b0;
				case (funct3)
					3'b000: o_slt_sl = 3'b000; // sb
					3'b001: o_slt_sl = 3'b001; // sh
					3'b010: o_slt_sl = 3'b010; // sw
					default begin
						o_slt_sl = 3'b010; // sw
						o_insn_vld_ctrl =  1'b0;
            		end
          		endcase
			end
			
			7'b1100011: begin	// B-type
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b010;	// Imm_Gen theo B type
				o_rd_wren 		= 1'b0;		// Không ghi lại vào reg file
				o_asel 			= 1'b1;		// A chọn PC hiện hành
				o_bsel 			= 1'b1;		// B chọn imm_Gen theo B type
				o_alu_op 		= 4'b0000;	// ALU thực hiện phép cộng
				o_wren 			= 1'b0;		// Cho phép đọc DMEM
				o_wb_sel 		= 2'b11; 	// write back là tùy định vì không ghi ngược lại vào regfile
				o_slt_sl 		= 3'b0;
				o_ctrl 			= 1'b1;
				case(funct3)
					3'b000: begin o_br_un = 1'b1;	end //BEQ
					3'b001: begin o_br_un = 1'b1; 	end //BNE
					3'b100: begin o_br_un = 1'b0;	end //BLT
					3'b101: begin o_br_un = 1'b0;   end //BGE
					3'b110: begin o_br_un = 1'b1;	end //BLTU
					3'b111: begin o_br_un = 1'b1;	end //BGEU
					default: begin
						o_br_un = 0;
						o_insn_vld_ctrl =  1'b0;
					end
				endcase
			end
			
			7'b1101111: begin // J-type JAL
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b011;   // Imm_Gen theo J Type
				o_rd_wren 		= 1'b1;		// cho phép ghi ngược vào regfile
				o_bsel 			= 1'b1;		// B chọn Imm_Gen theo J type
				o_asel  		= 1'b1;		// A chọn PC hiện hành
				o_alu_op 		= 4'b0000;	// ALU thực hiện phép cộng
				o_wren 			= 1'b0;		// Cho phép đọc DMEM
				o_wb_sel 		= 2'b10;	// Write back chọn PC+4 để return
				o_br_un    		= 1'b0;
				o_slt_sl 		= 3'b000;
				o_ctrl 			= 1'b1;
			end
			
			7'b1100111: begin // I-type JALR
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b000; 	// Imm_Gen theo I Type
				o_rd_wren 		= 1'b1;		// cho phép ghi ngược vào regfile
				o_bsel 			= 1'b1;		// B chọn Imm_Gen theo I type
				o_asel 			= 1'b0;		// A chọn rs1
				o_alu_op 		= 4'b0000;	// ALU thực hiện phép cộng
				o_wren 			= 1'b0;		// Cho phép đọc DMEM
				o_wb_sel 		= 2'b10; 	// Write back chọn PC+4 để return
				o_br_un    		= 1'b0;
				o_slt_sl 		= 3'b000;
				o_ctrl 			= 1'b1;
			end
			7'b0110111: begin // U-type LUI
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b100; 	//Imm_Gen theo U type LUI
				o_rd_wren 		= 1'b1; 	//cho phép ghi vào reg file
				o_bsel 			= 1'b1;		// B chọn Imm_Gen theo U type LUI
				o_asel 			= 1'b0;		// A tùy định
				o_alu_op 		= 4'b1111;  //ALU dẫn B ra ALU_out
				o_wren 			= 1'b0; 	// Cho phép đọc DMEM
				o_wb_sel 		= 2'b01; 	// chọn write back từ ALU_out
				o_br_un   		= 1'b0;
				o_slt_sl 		= 3'b000;
			end
			7'b0010111: begin // U-type AUIPC
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b101; 	//Imm_Gen theo U type AUIPC
				o_rd_wren 		= 1'b1; 	//cho phép ghi vào reg file
				o_bsel 			= 1'b1;		// B chọn Imm_Gen theo U type LUI
				o_asel 			= 1'b1;		// A tùy lấy PC hiện hành
				o_alu_op 		= 4'b0000; 	//ALU thực hiện phép cộng
				o_wren 			= 1'b0; 	// Cho phép đọc DMEM
				o_wb_sel 		= 2'b01; 	// chọn write back từ ALU_out
				o_br_un    		= 1'b0;
				o_slt_sl 		= 3'b000;
			end
			default begin
				o_insn_vld_ctrl = 1'b0;
				o_imm_sel 		= 3'b000;
				o_rd_wren  		= 1'b0;
				o_br_un    		= 1'b0;
				o_bsel    		= 1'b0;
				o_asel    		= 1'b0;
				o_alu_op 		= 4'b0000;
				o_wren   		= 1'b0;
				o_wb_sel   		= 2'b00;
				o_slt_sl 		= 3'b000; 
			end
		endcase
	end
endmodule
`endif