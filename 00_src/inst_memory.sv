`ifndef INST_MEMORY
`define INST_MEMORY
module inst_memory (
  output logic [31:0] o_rdata,
  input  logic [31:0] i_addr
);

  logic [31:0] imem [0:2048];
  initial begin
    //$readmemh("D:/HCMUT/Year_2025_2026/252/LVTN/milestone_3_cache/00_src/isa_4b_ms3.hex", imem);
    $readmemh("D:/HCMUT/Year_2025_2026/252/LVTN/milestone_3_cache/00_src/Test_Store_Type.dump", imem);
    //D:\HCMUT\Year_2025_2026\252\LVTN\milestone_3_cache\00_src\isa_4b_ms3.hex
  end
  always @(*) begin
      o_rdata = imem[i_addr[31:2]];  
  end
endmodule
`endif

