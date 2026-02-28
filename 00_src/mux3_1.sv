`ifndef MUX_3_1
`define MUX_3_1
module mux_3_1 (
  input logic [31:0] data_0_i,
  input logic [31:0] data_1_i,
  input logic [31:0] data_2_i,
  input logic [1:0] sel_i,
  output logic [31:0] data_out_o		
  );
  
  always_comb begin
    case (sel_i)
      2'b00 : data_out_o = data_0_i;
      2'b01 : data_out_o = data_1_i;
      2'b10 : data_out_o = data_2_i;
      default : data_out_o = 32'b0;		
    endcase
  end
endmodule
`endif