`ifndef SRAM_SIMPLE
`define SRAM_SIMPLE

// Simple synchronous SRAM to use with the cache testbench
// - 32-bit data, word addressed by i_addr[31:2]
// - o_ready follows i_sram_enb with 1-cycle latency
// - write occurs on rising edge when i_sram_enb && i_wr_en
// - read is combinational from memory[i_addr[31:2]]

module sram (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic        i_sram_enb,
    input  logic        i_wr_en,
    input  logic [31:0] i_addr,
    input  logic [31:0] i_wdata,
    output logic [31:0] o_rdata,
    output logic        o_ready
);
    // number of words (index = i_addr[31:2])
    localparam int DEPTH = 16384; // supports addresses up to word index ~2047

    logic [31:0] mem [0:DEPTH-1];
    initial begin
        //$readmemh("D:/HCMUT/Year_2025_2026/251/Conmputer_Organization/milestone_3/00_src/Test_Inst_Pl.dump",mem);
    end
    logic ready_reg;

    // synchronous write + ready
    always_ff @(posedge i_clk /*or posedge i_reset*/) begin
        if (i_reset) begin
            ready_reg <= 1'b0;
            // initialize memory to 0
            for (int i = 0; i < DEPTH; i++) 
                mem[i] <= 32'h0000_0000;
        end else begin
            // ready follows enable (1-cycle latency)
            ready_reg <= i_sram_enb;

            // write when enabled and write enable asserted
            if (i_sram_enb && i_wr_en) begin
                if (i_addr[31:2] < DEPTH)
                    mem[i_addr[31:2]] <= i_wdata;
            end
        end
    end

    // combinational read

    assign o_rdata = i_reset ? 32'b0000_0000: mem[i_addr[31:2]];
    assign o_ready = ready_reg;


endmodule
`endif
