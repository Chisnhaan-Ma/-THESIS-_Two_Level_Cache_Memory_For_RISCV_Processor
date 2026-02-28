`ifndef LOAD_UNIT
`define LOAD_UNIT
////////Load Encoding/////
module load_unit(
    input  logic [31:0] i_load_data, // Data từ DMEM
    input  logic [2:0]  i_load_type,  // Chọn kiểu load
    output logic [31:0] o_load_result); 
	 
    always @(*) begin
        case (i_load_type)
            3'b000: o_load_result = {{24{i_load_data[7]}}, i_load_data[7:0]};  // LB
            3'b001: o_load_result = {{16{i_load_data[15]}}, i_load_data[15:0]}; // LH
            3'b010: o_load_result = i_load_data;  // LW 
            3'b100: o_load_result = {24'b0, i_load_data[7:0]};  // LBU 
            3'b101: o_load_result = {16'b0, i_load_data[15:0]}; // LHU 
            default: o_load_result = 32'b0000;  
        endcase
    end

endmodule
`endif