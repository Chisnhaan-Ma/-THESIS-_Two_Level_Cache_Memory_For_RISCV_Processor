// Author: Nhu Bui
`ifndef LSU
`define LSU
`include "mux3_1.sv"
`include "cache.sv"
`include "cache_l2.sv"
`include "sram.sv"
/*------------------------------------------------------------*/

module lsu_new (
    input logic i_clk, 
    input logic i_reset, 
    input logic i_lsu_wren,
    input logic i_mem_access,
    input logic [31:0] i_lsu_addr,
    input logic [31:0] i_st_data,
    input logic [1:0]  i_lsu_byte_offset,
    output logic [31:0] o_ld_data, 
    input logic [2:0] slt_sl,
    /* case slt_st
       SW = 3'b010, SB = 3'b000, SH = 3'b001;
       LW = 3'b101, LB = 3'b011, LH = 3'b100;
       LBU = 3'b110, LHU = 3'b111;
    */
    output logic [31:0] o_io_ledr, //
    output logic [31:0] o_io_ledg,  
    output logic [6:0] o_io_hex0, 
    output logic [6:0] o_io_hex1, 
    output logic [6:0] o_io_hex2,   
    output logic [6:0] o_io_hex3,  // output buffer
    output logic [6:0] o_io_hex4, 
    output logic [6:0] o_io_hex5, 
    output logic [6:0] o_io_hex6,   
    output logic [6:0] o_io_hex7, 
    output logic [31:0] o_io_lcd, //
    
    input logic [31:0] i_io_sw, // switch -> input buffer
    output logic        o_cache_stall,
    output logic        o_cache_done,
    // Debug: bubble up cache hit
    output logic        o_cache_hit_debug,
    // Debug: bubble up cache miss
    output logic        o_cache_miss_debug
  );

  /*---------------------------------*/
  localparam SW = 3'b010, SB = 3'b000, SH = 3'b001;
  localparam LW = 3'b101, LB = 3'b011, LH = 3'b100;
  localparam LBU = 3'b110, LHU = 3'b111;

  /*---------------------------------*/

  logic [31:0] data_out_1, data_out_2, data_out_3; // IO_switchs - peripheral registers - Data (SRAM)
  logic en_datamem;
  logic en_op_buf;
  logic [31:0] ld_data_tmp;

  logic [31:0] input_bf_tmp;
  logic [31:0] output_bf_tmp;
  logic [31:0] data_mem_tmp;
  logic [2:0]  slt_sl_tmp;
  logic [31:0] ld_cache_data;
  logic [31:0] st_cache_data;
  logic [3:0]  byte_mask;
/*-------- Input buffer --------*/
  logic [31:0] INPUT;
  always_ff @(posedge i_clk) begin // ghi đồng bộ
    INPUT <= i_io_sw;
  end
  assign input_bf_tmp = i_reset ? 32'd0: INPUT; // đọc bất đồng bộ

//---------Syn Read------------
 always_ff @ (posedge i_clk) begin
    data_out_1 <= input_bf_tmp;
    data_out_2 <= output_bf_tmp;
    slt_sl_tmp <= slt_sl; 
 end

/*-------- Cache + SRAM (replaces data mem) --------*/

  logic        cache_done;
  logic        cache_hit_dbg;
  logic        cache_miss_dbg;
  logic        l1_l2_req_valid;
  logic [31:0] l1_l2_req_addr;
  logic        l1_l2_req_wr_en;
  logic [31:0] l1_l2_req_wdata;
  logic [31:0] l2_l1_resp_rdata;
  logic        l2_l1_resp_valid;

  logic        l2_sram_enb;
  logic [31:0] l2_sram_addr;
  logic        l2_sram_wr_en;
  logic [31:0] l2_sram_wdata;
  logic [31:0] sram_rdata;
  logic        sram_ready;

  // Create byte mask for cache write
  mask_create u_mask_create (
    .slt_sl      (slt_sl),
    .addr_sp     (i_lsu_addr[1:0]),
    .byte_mask   (byte_mask)
  );

  mask_load u_mask_load (
    .slt_sl        (slt_sl_tmp),
    .ld_data       (ld_cache_data),
    .addr_sp       (i_lsu_addr[1:0]),
    .data_after_load (data_out_3)
  );
  mask_store u_mask_store (
    .slt_sl        (slt_sl),
    .st_data       (i_st_data),
    .addr_sp       (i_lsu_addr[1:0]),
    .data_to_cache (st_cache_data)
  );
  // Instantiate Cache; memory access only when demux selects data memory
  cache u_cache (
    .i_clk         (i_clk),
    .i_reset       (i_reset),
    .i_mem_access  (en_datamem && i_mem_access),
    .i_wr_en       (i_lsu_wren),
    .i_addr        (i_lsu_addr),
    .i_byte_mask   (byte_mask),
    .i_wdata       (st_cache_data),
    .o_rdata       (ld_cache_data /*data_out_3*/),
    .o_hit_debug   (cache_hit_dbg),
    .o_miss_debug  (cache_miss_dbg),
    .o_stall       (o_cache_stall),
    .o_cache_done  (o_cache_done),
    // SRAM interface
    .o_sram_enb    (l1_l2_req_valid),
    .o_sram_addr   (l1_l2_req_addr),
    .o_sram_wr_en  (l1_l2_req_wr_en),
    .o_sram_wdata  (l1_l2_req_wdata),
    .i_sram_rdata  (l2_l1_resp_rdata),
    .i_sram_ready  (l2_l1_resp_valid)
  );

  // L2 cache serves L1 misses/hit-under-L2, and accesses SRAM on L2 miss
  cache_l2 u_cache_l2 (
    .i_clk          (i_clk),
    .i_reset        (i_reset),
    .i_req_valid    (l1_l2_req_valid),
    .i_req_wr_en    (l1_l2_req_wr_en),
    .i_req_byte_mask(l1_l2_req_wr_en ? 4'b1111 : 4'b0000),
    .i_req_addr     (l1_l2_req_addr),
    .i_req_wdata    (l1_l2_req_wdata),
    .o_resp_rdata   (l2_l1_resp_rdata),
    .o_resp_valid   (l2_l1_resp_valid),
    .o_stall        (),
    .o_hit_debug    (),
    .o_miss_debug   (),
    .o_sram_enb     (l2_sram_enb),
    .o_sram_addr    (l2_sram_addr),
    .o_sram_wr_en   (l2_sram_wr_en),
    .o_sram_wdata   (l2_sram_wdata),
    .i_sram_rdata   (sram_rdata),
    .i_sram_ready   (sram_ready)
  );

  // SRAM is now behind L2
  sram u_sram (
    .i_clk      (i_clk),
    .i_reset    (i_reset),
    .i_sram_enb (l2_sram_enb),
    .i_wr_en    (l2_sram_wr_en),
    .i_addr     (l2_sram_addr),
    .i_wdata    (l2_sram_wdata),
    .o_rdata    (sram_rdata),
    .o_ready    (sram_ready)
  );

/*-------- DEMUX --------*/
  demux_sel_mem demux_1 (
    .i_lsu_addr(i_lsu_addr[31:0]),
    .en_datamem(en_datamem),
    .en_op_buf(en_op_buf)  
  );

/*-------- Output buffer --------*/
  output_buffer  outputperiph (
    .slt_sl (slt_sl),
    .st_data_2_i   (i_st_data), 
    .addr_2_i      (i_lsu_addr[31:0]),
    .en_bf         (en_op_buf), 
    .st_en_2_i     (i_lsu_wren),
    .i_clk         (i_clk), 
    .i_reset       (i_reset),
    .data_out_2_o  (output_bf_tmp /*data_out_2*/), 
    .io_lcd_o      (o_io_lcd), 
    .io_ledg_o     (o_io_ledg), 
    .io_ledr_o     (o_io_ledr), 
    .io_hex0_o     (o_io_hex0), 
    .io_hex1_o     (o_io_hex1), 
    .io_hex2_o     (o_io_hex2), 
    .io_hex3_o     (o_io_hex3), 
    .io_hex4_o     (o_io_hex4), 
    .io_hex5_o     (o_io_hex5), 
    .io_hex6_o     (o_io_hex6), 
    .io_hex7_o     (o_io_hex7)
	  );

/*-------- MUX --------*/
  mux_3_1_lsu mux31  (
    .i_clk      (i_clk),
    .in_data_3_i(data_out_3), 
    .in_data_2_i(data_out_2), 
    .in_data_1_i(data_out_1), 
    .i_lsu_addr(i_lsu_addr[31:0]),
    .o_ld_data(o_ld_data)
    );	
  // Drive debug hit to top-level LSU port
  assign o_cache_hit_debug = cache_hit_dbg;
  // Drive debug miss to top-level LSU port
  assign o_cache_miss_debug = cache_miss_dbg;
endmodule

`ifndef MASK_CREATE
`define MASK_CREATE
module mask_create (
  input logic [2:0] slt_sl,
  input logic [1:0] addr_sp,
  output logic [3:0] byte_mask
);
 localparam SW = 3'b010, SB = 3'b000, SH = 3'b001;

  always_comb begin
      case (slt_sl) 
        SW: byte_mask = 4'b1111;
        SB: begin
          case(addr_sp)
            2'b00: byte_mask = 4'b0001;
            2'b01: byte_mask = 4'b0010;
            2'b10: byte_mask = 4'b0100;
            2'b11: byte_mask = 4'b1000;
            default: byte_mask = 4'b0000;
          endcase
        end
        SH: begin
          case(addr_sp[1])
            1'b0: byte_mask = 4'b0011;
            1'b1: byte_mask = 4'b1100;
            default: byte_mask = 4'b0000;
          endcase
        end
        default: byte_mask = 4'b0000;
      endcase

  end


endmodule
`endif

`ifndef MASK_STORE
`define MASK_STORE
module mask_store (
  input logic [2:0] slt_sl,
  input logic [31:0] st_data,
  input logic [1:0] addr_sp,
  output logic [31:0] data_to_cache
);

  localparam SW = 3'b010, SB = 3'b000, SH = 3'b001;

  always_comb begin
      case (slt_sl) 
        SW: data_to_cache = st_data;
        SB: begin
          case(addr_sp)
            2'b00: data_to_cache = {24'b0,st_data[7:0]};
            2'b01: data_to_cache = {16'b0,st_data[7:0],8'b0};
            2'b10: data_to_cache = {8'b0,st_data[7:0],16'b0};
            2'b11: data_to_cache = {st_data[7:0],24'b0};
            default: data_to_cache = st_data;
          endcase
        end
        SH: begin
          case(addr_sp[1])
            1'b0: data_to_cache = {16'b0,st_data[15:0]};
            1'b1: data_to_cache = {st_data[15:0],16'b0};
            default: data_to_cache = st_data;
          endcase
        end
        default: data_to_cache = st_data;
      endcase

  end


endmodule
`endif

`ifndef MASK_LOAD
`define MASK_LOAD
module mask_load (
  input logic [2:0] slt_sl,
  input logic [31:0] ld_data,
  input logic [1:0] addr_sp,
  output logic [31:0] data_after_load
);

  localparam LW = 3'b101, LB = 3'b011, LH = 3'b100;
  localparam LBU = 3'b110, LHU = 3'b111;

  always_comb begin
      /*
      case (slt_sl) 
        LW: data_after_load = ld_data;
        LB: begin
          case(addr_sp)
            2'b00: data_after_load = {{24{ld_data[7]}}, ld_data[7:0]};
            2'b01: data_after_load = {{24{ld_data[15]}}, ld_data[15:8]};
            2'b10: data_after_load = {{24{ld_data[23]}}, ld_data[23:16]};
            2'b11: data_after_load = {{24{ld_data[31]}}, ld_data[31:24]};
            default: data_after_load = ld_data;
          endcase
        end
        LH: begin
          case(addr_sp[1])
            1'b0: data_after_load = {{16{ld_data[15]}}, ld_data[15:0]};
            1'b1: data_after_load = {{16{ld_data[31]}}, ld_data[31:16]};
            default: data_after_load = ld_data;
          endcase
        end
        LBU: begin
          case(addr_sp)
            2'b00: data_after_load = {24'b0, ld_data[7:0]};
            2'b01: data_after_load = {24'b0, ld_data[15:8]};
            2'b10: data_after_load = {24'b0, ld_data[23:16]};
            2'b11: data_after_load = {24'b0, ld_data[31:24]};
            default: data_after_load = ld_data;
          endcase
        end
        LHU: begin
          case(addr_sp[1])
            1'b0: data_after_load = {16'b0, ld_data[15:0]};
            1'b1: data_after_load = {16'b0, ld_data[31:16]};
            default: data_after_load = ld_data;
          endcase
        end
        default: data_after_load = ld_data;
      endcase*/
      data_after_load = ld_data;
  end
endmodule

`endif

`ifndef DEMUX_SEL_MEM
`define DEMUX_SEL_MEM

module demux_sel_mem (
    input logic [31:0]  i_lsu_addr,
    output logic        en_datamem,
    output logic        en_op_buf  
  );
  always @(*) begin
    en_datamem  = 1'b0;
    en_op_buf   = 1'b0;
    if (i_lsu_addr[31:28]==4'b0) begin //0xxx_xxxx
      en_datamem  = 1'b1;
      en_op_buf   = 1'b0;
    end
    else if (i_lsu_addr[19:16]==4'b0) begin //1xx0_xxxx
      en_datamem  = 1'b0;
      en_op_buf   = 1'b1;
    end
    else begin //1xx1_xxxx
      en_datamem  = 1'b0;
      en_op_buf   = 1'b0;
    end
  end
endmodule
`endif

module output_buffer(
  input logic [2:0] slt_sl, // chọn store/load kiểu gì (W H B HU BU)
    /* 
       SW = 3'b010, SB = 3'b000, SH = 3'b001;
       LW = 3'b101, LB = 3'b011, LH = 3'b100;
       LBU = 3'b110, LHU = 3'b111;
    */
  input logic [31:0] st_data_2_i, // data
	input logic [31:0] addr_2_i, // address
  input logic en_bf, // en
	input logic st_en_2_i, //write enable
	input logic i_clk,
  input logic i_reset,

	output logic [31:0] data_out_2_o, // data out -> mux
	output logic [31:0] io_lcd_o,
	output logic [31:0] io_ledg_o,
	output logic [31:0] io_ledr_o,
	output logic [6:0] io_hex0_o,
	output logic [6:0] io_hex1_o,
	output logic [6:0] io_hex2_o,
	output logic [6:0] io_hex3_o,
	output logic [6:0] io_hex4_o,
	output logic [6:0] io_hex5_o,
	output logic [6:0] io_hex6_o,
	output logic [6:0] io_hex7_o
	 );

  logic [31:0] data_bs,data_tmp;
  logic [31:0] MEMBF [0:4];

  assign data_out_2_o = (i_reset == 1'b1) ? 32'h0: data_tmp;
  assign io_ledr_o =  MEMBF[0];
  assign io_ledg_o =  MEMBF[1];
  assign io_hex0_o =  MEMBF[2][6:0];  
  assign io_hex1_o =  MEMBF[2][14:8];
  assign io_hex2_o =  MEMBF[2][22:16]; 
  assign io_hex3_o =  MEMBF[2][30:24];
  assign io_hex4_o =  MEMBF[3][6:0];
  assign io_hex5_o =  MEMBF[3][14:8]; 
  assign io_hex6_o =  MEMBF[3][22:16];
  assign io_hex7_o =  MEMBF[3][30:24];    
  assign io_lcd_o  =  MEMBF[4];  

  data_trsf trsf_st (
    .slt_sl(slt_sl),
    .addr_sp(addr_2_i[1:0]),
    .wr_en(st_en_2_i),
    .data_bf(st_data_2_i),
    .data_bs(data_bs),
    .data_af(data_tmp)
  );

  always @(*) begin
    case(addr_2_i[15:12])
      4'h0: data_bs = MEMBF[0]; // LED Red
      4'h1: data_bs = MEMBF[1]; // led green
      4'h2: data_bs = MEMBF[2];// HEX 0-3
      4'h3: data_bs = MEMBF[3];// HEX 4-7
      4'h4: data_bs = MEMBF[4]; //lcd
      default data_bs = 32'h0;
    endcase
  end

  always_ff @(posedge i_clk or posedge i_reset) begin
    if (i_reset) begin
      MEMBF[0] <= '0;
      MEMBF[1] <= '0;
      MEMBF[2] <= '0;
      MEMBF[3] <= '0;
      MEMBF[4] <= '0;
    end
    else if (en_bf) begin
      if (st_en_2_i) begin
        case(addr_2_i[15:12])
          4'h0: MEMBF[0] <= data_tmp; // LED Red
          4'h1: MEMBF[1] <= data_tmp; // led green
          4'h2: MEMBF[2] <= data_tmp; // HEX 0-3
          4'h3: MEMBF[3] <= data_tmp; //HEX 4-7
          4'h4: MEMBF[4] <= data_tmp; //lcd
          default: begin
            MEMBF[0] <= MEMBF[0];
            MEMBF[1] <= MEMBF[1];
            MEMBF[2] <= MEMBF[2];
            MEMBF[3] <= MEMBF[3];
            MEMBF[4] <= MEMBF[4];
          end
        endcase
      end      
    end
  end
endmodule

module  data_trsf
  (
    input logic [2:0] slt_sl,
    input logic [1:0] addr_sp,
    input logic wr_en,
    input logic [31:0] data_bf,
    input logic [31:0] data_bs,
    output logic [31:0] data_af
  );
  // Định nghĩa giá trị SW, SB, SH, LW, LB, LH, LBU, LHU
  localparam SW = 3'b010, SB = 3'b000, SH = 3'b001;
  localparam LW = 3'b101, LB = 3'b011, LH = 3'b100;
  localparam LBU = 3'b110, LHU = 3'b111;

  logic [31:0] memb_tmp,memh_tmp;

  always @(*) begin
    case (addr_sp) 
      2'b00: begin
      memb_tmp = (data_bs & 32'h000000ff);
      memh_tmp = (data_bs & 32'h0000ffff);
      end
      2'b01: begin
      memb_tmp = (data_bs & 32'h0000ff00);
      memh_tmp = (data_bs & 32'h0000ffff);
      end
      2'b10: begin
      memb_tmp = (data_bs & 32'h00ff0000);
      memh_tmp = (data_bs & 32'hffff0000);
      end
      2'b11: begin
      memb_tmp = (data_bs & 32'hff000000);
      memh_tmp = (data_bs & 32'hffff0000);
      end
    endcase
  end

  always @(*) begin
    if(wr_en) begin
      case (slt_sl) 
        SW: data_af = data_bf;
        SB: begin
          case(addr_sp)
            2'b00: data_af = {data_bs[31:8],data_bf[7:0]};               //(data_bf & 32'h000000ff) | (data_bs & 32'hffffff00);
            2'b01: data_af = {data_bs[31:16],data_bf[7:0],data_bs[7:0]}; //((data_bf & 32'h000000ff) << 8) | (data_bs & 32'hffff00ff);
            2'b10: data_af = {data_bs[31:24],data_bf[7:0],data_bs[15:0]};//((data_bf & 32'h000000ff) << 16)| (data_bs & 32'hff00ffff);
            2'b11: data_af = {data_bf[7:0],data_bs[23:0]};               //((data_bf & 32'h000000ff) << 24)| (data_bs & 32'h00ffffff);
          endcase
        end
        SH: begin
          case (addr_sp)
            2'b00: data_af = {data_bs[31:16],data_bf[15:0]};  //(data_bf & 32'h0000ffff) | (data_bs & 32'hffff0000); 
            2'b01: data_af = {data_bs[31:16],data_bf[15:0]};  //((data_bf & 32'h0000ffff)) | (data_bs & 32'hffff0000); 
            2'b10: data_af = {data_bf[15:0], data_bs[15:0]};  //((data_bf & 32'h0000ffff) << 16) | (data_bs & 32'h0000ffff);
            2'b11: data_af = {data_bf[15:0], data_bs[15:0]};  //((data_bf & 32'h0000ffff) << 16)  | (data_bs & 32'h0000ffff); 
          endcase 
        end
        default: data_af = data_bf;
      endcase
    end
    else begin
      case (slt_sl) 
      LW: data_af = data_bs;
      LBU: begin
        case (addr_sp) 
          2'b00: data_af = memb_tmp;
          2'b01: data_af = {8'b0, memb_tmp[31:8]};  //(memb_tmp >>8);
          2'b10: data_af = {16'b0,memb_tmp[31:16]}; //(memb_tmp >>16);
          2'b11: data_af = {23'b0,memb_tmp[31:24]}; //(memb_tmp >>24);
        endcase
      end
      LHU: begin
        case(addr_sp)
          2'b00: data_af = memh_tmp;
          2'b01: data_af = memh_tmp;
          2'b10: data_af = {16'b0,memh_tmp[31:16]}; //memh_tmp >> 16;
          2'b11: data_af = {16'b0,memh_tmp[31:16]}; //memh_tmp >> 16;
        endcase
      end
      LB: begin
        case (addr_sp)
          2'b00: data_af = (memb_tmp[7])  ? {24'hffffff, memb_tmp[7:0]}   : {24'h000000, memb_tmp[7:0]};
          2'b01: data_af = (memb_tmp[15]) ? {24'hffffff, memb_tmp[15:8]}  : {24'h000000, memb_tmp[15:8]};
          2'b10: data_af = (memb_tmp[23]) ? {24'hffffff, memb_tmp[23:16]} : {24'h000000, memb_tmp[23:16]};
          2'b11: data_af = (memb_tmp[31]) ? {24'hffffff, memb_tmp[31:24]} : {24'h000000, memb_tmp[31:24]};
        endcase
        /*case(addr_sp)
          2'b00: data_af = (memb_tmp[7] == 1) ? (memb_tmp | 32'hffffff00): memb_tmp;
          2'b01: data_af = (memb_tmp[15] == 1)? ((memb_tmp >> 8) | 32'hffffff00) : (memb_tmp >>8);
          2'b10: data_af = (memb_tmp[23] == 1)? ((memb_tmp >> 16) | 32'hffffff00) : (memb_tmp >>16);
          2'b11: data_af = (memb_tmp[31] == 1)? ((memb_tmp >> 24) | 32'hffffff00) : (memb_tmp >>24);
        endcase*/
      end
      
      LH: begin
        case (addr_sp)
          2'b00: data_af = (memh_tmp[15]) ? {16'hffff, memh_tmp[15:0]}   : {16'h0000, memh_tmp[15:0]};
          2'b01: data_af = (memh_tmp[15]) ? {16'hffff, memh_tmp[15:0]}   : {16'h0000, memh_tmp[15:0]};
          2'b10: data_af = (memh_tmp[31]) ? {16'hffff, memh_tmp[31:16]}  : {16'h0000, memh_tmp[31:16]};
          2'b11: data_af = (memh_tmp[31]) ? {16'hffff, memh_tmp[31:16]}  : {16'h0000, memh_tmp[31:16]};
        endcase
        /*case(addr_sp)
          2'b00: data_af = (memh_tmp[15] == 1)? (memh_tmp | 32'hffff0000): memh_tmp;
          2'b01: data_af = (memh_tmp[15] == 1)? (memh_tmp | 32'hffff0000): memh_tmp;
          2'b10: data_af = (memh_tmp[31] == 1)? ((memh_tmp >> 16) | 32'hffff0000) : (memh_tmp >>16);
          2'b11: data_af = (memh_tmp[31] == 1)? ((memh_tmp >> 16) | 32'hffff0000) : (memh_tmp >>16);
        endcase*/
      end
      default: data_af = 32'h00000000;
      endcase
    end
  end
endmodule

module mux_3_1_lsu(
  input logic        i_clk,
  input logic [31:0] in_data_1_i,
  input logic [31:0] in_data_2_i,
  input logic [31:0] in_data_3_i,
  input logic [31:0] i_lsu_addr,
  output logic [31:0] o_ld_data
);
  logic [1:0] addr_sel ;
  logic [1:0] addr_sel_tmp;
  always_comb begin
      case (i_lsu_addr[31:16])
        16'h1001:  addr_sel  =  2'b00; // SW
        16'h1000:  addr_sel  =  2'b01; // LCD
        16'h0000:  addr_sel  =  2'b10; // RL
        default:   addr_sel = 2'b11; 
      endcase
  end

  always_ff @ (posedge i_clk) begin
    addr_sel_tmp <= addr_sel;
  end

  always_comb begin
    case(addr_sel_tmp)
      2'b00:o_ld_data = in_data_1_i; // input_bf
      2'b01:o_ld_data = in_data_2_i; // output_bf
      2'b10:o_ld_data = in_data_3_i; // mem
      default: o_ld_data = 32'd0;    
    endcase
  end
/*
  always_ff @ (posedge i_clk) begin
	o_ld_data <= load_data_tmp;
  end
  */
endmodule

/*------------------------------------------------------------*/
`endif