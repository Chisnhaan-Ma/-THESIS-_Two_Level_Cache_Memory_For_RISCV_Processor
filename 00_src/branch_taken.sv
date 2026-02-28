module branch_taken (
	input logic i_br_less_mem,
	input logic i_br_equal_mem,
	input logic [31:0] i_inst_mem,
	output logic o_pc_sel,
	output logic flush);
	
    localparam BEQ = 3'b000;
    localparam BNE = 3'b001;
    localparam BLT = 3'b100;
    localparam BGE = 3'b101;
    localparam BLTU = 3'b110;
    localparam BGEU = 3'b111;
	always_comb begin
        if (i_inst_mem[6:0] == 7'b1100011) begin : B_TYPE
            case (i_inst_mem[14:12])
                BEQ:   o_pc_sel = i_br_equal_mem;    //BEQ
				BNE:   o_pc_sel = ~i_br_equal_mem;	 //BNE
				BLT:   o_pc_sel = i_br_less_mem;	 //BLT
				BGE:   o_pc_sel = ~i_br_less_mem;    //BGE
				BLTU:   o_pc_sel = i_br_less_mem;	 //BLTU
				BGEU:   o_pc_sel = ~i_br_less_mem;	 //BGEU
                default: o_pc_sel= 1'b0;
                
            endcase
        end
        // JAL & JALR
        else if(i_inst_mem[6:0] == 7'b1101111) o_pc_sel = 1;
        else if(i_inst_mem[6:0] == 7'b1100111) o_pc_sel = 1;
        else o_pc_sel = 0;
    end
	assign flush = o_pc_sel;
endmodule