`ifndef PC
`define PC
/////////Program Counter//////////////////////
module pc (
  input logic i_clk,
  input logic i_reset,
  input logic [31:0] i_pc_data_in,
  input logic i_pc_enable,
  output logic [31:0] o_pc_data_out);

  always_ff @(posedge i_clk /*or posedge i_reset*/) begin
    if (i_reset) begin
      o_pc_data_out <= 32'b0;
    end

    else if (i_pc_enable) begin
      o_pc_data_out <= i_pc_data_in;
    end

  end
endmodule
`endif