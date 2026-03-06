// Auto-generated synthesis bundle from 00_src .sv files
// Generated: 2026-03-06 10:09:51


// ===== BEGIN FILE: add_sub_32_bit.sv =====
`ifndef ADD_SUB_32_BIT
`define ADD_SUB_32_BIT
module add_sub_32_bit (
    input  logic [31:0] A, B,   // Input A, B
    input  logic Sel,           // 0 = ADD, 1 = SUB
    output logic [31:0] Result, // Káº¿t quáº£ phÃ©p cá»™ng 
    output logic Cout);         // Carry-out

    logic [31:0] B_mod;         
    logic Cin;                  // Carry-in
    logic [31:0] carry;         // Carry signals
    assign B_mod = (Sel) ? ~B : B;  // BÃ¹ 2 cá»§a B

    full_adder FA0(
	 A[0],
	 B_mod[0],
	 Sel,
	 Result[0],
	 carry[0]);

    // Generate 31 more full adders
    genvar i;
    generate
        for (i = 1; i < 32; i = i + 1) begin :adder_32
            full_adder FA (A[i], B_mod[i], carry[i-1], Result[i], carry[i]);
        end
    endgenerate

    assign Cout = carry[31];

endmodule
`endif
// ===== END FILE: add_sub_32_bit.sv =====


// ===== BEGIN FILE: alu.sv =====

`ifndef ALU
`define ALU


module alu(
	//  input
	input  logic  [31:0]  i_operand_a,
	input  logic  [31:0]  i_operand_b,
    input  logic   [3:0]  i_alu_op,
	//  output
	output  logic  [31:0]  o_alu_data
);
    logic [31:0] add_sub_out, sll_out, srl_out, sra_out;
    logic [31:0] slt_out, sltu_out;

    // Instance cÃ¡c module cáº§n dÃ¹ng
	 // ADD, SUB
    add_sub_32_bit add_sub_alu( 
	 .A(i_operand_a),
	 .B(i_operand_b),
	 .Sel(i_alu_op[3]),
	 .Result(add_sub_out)); 
	 
	 // SLL
    shift_left_logical sll_alu(
	 .data_in(i_operand_a),
	 .shift_amt(i_operand_b[4:0]),
	 .data_out(sll_out)); // SLL

	 // SRL
    shift_right_logical srl_alu(
	 .data_in(i_operand_a), 
	 .shift_amt(i_operand_b[4:0]),
	 .data_out(srl_out)); 
	 
	 // SRA
    shift_right_arithmetic sra_alu(
	 .data_in(i_operand_a), 
	 .shift_amt(i_operand_b[4:0]),
	 .data_out(sra_out)); 
	 
	 // SLT
    slt_sltu slt_alu(
	 .A(i_operand_a), 
	 .B(i_operand_b), 
	 .Sel(1'b0),
	 .Result(slt_out));  
	 
	 // SLT
    slt_sltu sltu_alu(
	 .A(i_operand_a),
	 .B(i_operand_b), 
	 .Sel(1'b1), 
	 .Result(sltu_out));  

    always_comb begin
        case (i_alu_op)
            4'b0000: o_alu_data = add_sub_out;  			  // ADD
            4'b1000: o_alu_data = add_sub_out;  			  // SUB
            4'b0001: o_alu_data = sll_out;      			  // SLL
            4'b0010: o_alu_data = slt_out;  				  // SLT (1 bit)
            4'b0011: o_alu_data = sltu_out;                   // SLTU (1 bit)
            4'b0100: o_alu_data = i_operand_a ^ i_operand_b;  // XOR
            4'b0101: o_alu_data = srl_out;                    // SRL
            4'b1101: o_alu_data = sra_out;                    // SRA
            4'b0110: o_alu_data = i_operand_a | i_operand_b;  // OR
            4'b0111: o_alu_data = i_operand_a & i_operand_b;  // AND
			4'b1111: o_alu_data = i_operand_b; 				  //Cho lá»‡nh LUI
            default: o_alu_data = 32'bz;  
        endcase
    end
endmodule
`endif
// ===== END FILE: alu.sv =====


// ===== BEGIN FILE: branch_taken.sv =====
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
// ===== END FILE: branch_taken.sv =====


// ===== BEGIN FILE: brc.sv =====
`ifndef BRC
`define BRC
module  brc (
	//  input
	input  logic  [31:0]  i_rs1_data,
	input  logic  [31:0]  i_rs2_data,
	input  logic          i_br_un,
	//  output
	output  logic  o_br_less,
	output  logic  o_br_equal
);
    logic [31:0] Diff;  // Káº¿t quáº£ phÃ©p trá»« rs1 - rs2
    logic Cout;         // Carry-out tá»« add_sub_32_bit

    add_sub_32_bit subtractor (
        .A          (i_rs1_data),
        .B          (i_rs2_data),
        .Sel        (1'b1),   // SUB
        .Result     (Diff),
        .Cout       (Cout)
    );

    // o_br_equal
    always @(*) begin
        if (Diff == 32'b0)
            o_br_equal = 1'b1;
        else
            o_br_equal = 1'b0;
    end

    // o_br_less
    always @(*) begin
        if (i_br_un)  // Unsigned
            o_br_less = ~Cout;
        else       // Signed
            o_br_less = Diff[31];
    end

endmodule
`endif 
// ===== END FILE: brc.sv =====


// ===== BEGIN FILE: cache.sv =====
module cache (
    input  logic         i_clk,
    input  logic         i_reset,

    input  logic         i_mem_access,   // = 1 if load/store, 0 = no access
    input  logic         i_wr_en,        // 1 = write, 0 = read
    input  logic  [3:0]  i_byte_mask,     // byte enable for write
    input  logic [31:0]  i_addr,
    input  logic [31:0]  i_wdata,
    output logic [31:0]  o_rdata,
    output logic         o_hit_debug,
    output logic         o_miss_debug,
    output logic         o_stall,        // stall CPU
    output logic         o_cache_done,   

    // ============================
    // SRAM INTERFACE
    // ============================
    output logic         o_sram_enb,
    output logic [31:0]  o_sram_addr,
    output logic         o_sram_wr_en,
    output logic [31:0]  o_sram_wdata,
    input  logic [31:0]  i_sram_rdata,
    input  logic         i_sram_ready
);
    localparam int NUM_SET = 4;
    localparam int NUM_WAY = 16;  

    localparam SW = 3'b010;
    localparam SB = 3'b000;
    localparam SH = 3'b001;
    localparam LW = 3'b101;
    localparam LB = 3'b011;
    localparam LH = 3'b100;
    localparam LBU = 3'b110;
    localparam LHU = 3'b111;
    // ---------------------------
    // TAG + INDEX
    // ---------------------------
    logic [31:0] req_addr_reg;
    logic [31:0] req_wdata_reg;
    logic        req_wr_en_reg;
    logic [3:0]  req_byte_mask_reg;

    logic [1:0] index;
    assign index = req_addr_reg[3:2];

    logic [27:0] tag;
    assign tag  = req_addr_reg[31:4];

    // ---------------------------
    // CACHE STORAGE
    // ---------------------------
    logic valid   [NUM_SET][NUM_WAY];
    logic dirty   [NUM_SET][NUM_WAY];
    logic [27:0] tag_array [NUM_SET][NUM_WAY];
    logic [31:0] data_array[NUM_SET][NUM_WAY];
    logic [$clog2(NUM_WAY)-1:0] fifo_ptr[NUM_SET];

    logic dirty_debug;
    logic stall;

    function automatic logic [31:0] write_with_mask(
        input logic [31:0] old_data,
        input logic [31:0] new_data,
        input logic [3:0]  byte_mask
    );
        begin
            case (byte_mask)
                4'b0001: write_with_mask = {old_data[31:8],  new_data[7:0]};
                4'b0010: write_with_mask = {old_data[31:16], new_data[15:8],  old_data[7:0]};
                4'b0100: write_with_mask = {old_data[31:24], new_data[23:16], old_data[15:0]};
                4'b1000: write_with_mask = {new_data[31:24], old_data[23:0]};
                4'b0011: write_with_mask = {old_data[31:16], new_data[15:0]};
                4'b1100: write_with_mask = {new_data[31:16], old_data[15:0]};
                4'b1111: write_with_mask = new_data;
                default: write_with_mask = old_data;
            endcase
        end
    endfunction
    // HIT CHECK (ONLY WHEN i_mem_access=1)
    // ---------------------------
    logic [NUM_WAY-1:0] way_hit;

    always_comb begin
        for (int w=0; w<NUM_WAY; w++)
            way_hit[w] = valid[index][w] && (tag_array[index][w] == tag);
    end

    logic hit;
    assign hit = |way_hit;
    logic [$clog2(NUM_WAY)-1:0] hit_way;
    always_comb begin
        hit_way = '0;
        for (int w=0; w<NUM_WAY; w++)
            if (way_hit[w]) hit_way = w;
    end

    // -----------------------------------
    // MISS INFO LATCH REGISTERS
    // -----------------------------------
    logic [31:0]  miss_addr_reg;
    logic [31:0]  miss_wdata_reg;
    logic         miss_wr_en_reg;
    logic [$clog2(NUM_WAY)-1:0] victim_way_reg;
    logic [1:0]   miss_index_reg;
    logic [27:0]  miss_tag_reg;
    logic [31:0]  victim_addr_reg;  // Address of victim line for writeback
    logic         victim_dirty_reg;  // Latch victim's dirty bit at CHECK_CACHE time
    logic         need_writeback_reg; // Latch writeback decision at CHECK_CACHE time
    logic [1:0]   hit_index_reg;
    logic [$clog2(NUM_WAY)-1:0] hit_way_reg;
    logic         output_from_hit_reg;

    // Select victim way using FIFO pointer
    logic [$clog2(NUM_WAY)-1:0] victim_way;
    assign victim_way = fifo_ptr[index];

    // Check if victim way is dirty
    logic victim_is_dirty;
    assign victim_is_dirty = dirty[index][victim_way];

    // -----------------------------------
    // FSM
    // -----------------------------------
    typedef enum logic [3:0] {
        IDLE          = 4'b0000,
        CHECK_CACHE   = 4'b0001,
        WRITEBACK_L2  = 4'b0010,
        L2_READ       = 4'b0011,
        UPDATE_CACHE  = 4'b0101,
        OUTPUT_DATA   = 4'b0110
    } state_t;

    state_t current_state, next_state;

    //assign hit = (current_state == CHECK_CACHE) && (|way_hit);
    assign o_hit_debug = hit && (current_state == CHECK_CACHE);
    assign o_miss_debug = (!hit) && (current_state == CHECK_CACHE);
    assign o_stall = stall;//|~(current_state == IDLE);
    always_comb begin
        case(current_state)
            IDLE: begin
                if (!i_mem_access)
                    next_state = IDLE;
                else
                    next_state = CHECK_CACHE;
            end
            CHECK_CACHE: begin
                if (hit) begin
                    //$display("CACHE HIT ADDR: %h, TIME = %d", i_addr, $time);
                    next_state = OUTPUT_DATA;  // Hit response goes through OUTPUT_DATA
                    //$display("HIT ADDR = %h", req_addr_reg);
                    /*
                    if (i_mem_access == 1'b1)
                        next_state = CHECK_CACHE;      // Hit response goes through OUTPUT_DATA
                    else
                        next_state = IDLE;
                    */
                end
                else begin
                    // Miss detected: check if victim is dirty
                    // CRITICAL: victim_way points to the FIFO victim for this set
                    // Check CURRENT victim_way's dirty bit at THIS cycle
                    if (dirty[index][victim_way]) begin
                        next_state = WRITEBACK_L2;  // Writeback dirty victim to L2 first
                        //$display("MISS DIRTY");
                    end
                    else begin
                        next_state = L2_READ;       // Always read allocate from L2 on miss
                        //$display("READ MISS CLEAN");
                    end
                    //$display("MISS ADDR = %h", miss_addr_reg);
                end
            end
            WRITEBACK_L2: begin
                // Writing dirty victim to L2
                // Use LATCHED victim_dirty_reg (captured at CHECK_CACHE time)
                if(i_sram_ready) begin
                    // After writeback, request line from L2
                    next_state = L2_READ;
                end else
                    next_state = WRITEBACK_L2;  // Wait for L2 ready
            end
            L2_READ: begin
                // Reading missed line from L2
                if(i_sram_ready)
                    next_state = UPDATE_CACHE;
                else
                    next_state = L2_READ;
            end
            UPDATE_CACHE: begin
                next_state = OUTPUT_DATA;
            end
            OUTPUT_DATA: begin
                //if (i_mem_access == 1'b0)
                    next_state = IDLE;
                //else
                //    next_state = CHECK_CACHE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // -----------------------------------
    // SEQUENTIAL: FSM STATE + CACHE UPDATE + MISS LATCH
    // -----------------------------------
    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            current_state <= IDLE;
            req_addr_reg <= 32'b0;
            req_wdata_reg <= 32'b0;
            req_wr_en_reg <= 1'b0;
            req_byte_mask_reg <= 4'b0;
            miss_addr_reg  <= 32'b0;
            miss_wdata_reg <= 32'b0;
            miss_wr_en_reg <= 1'b0;
            victim_way_reg <= {$clog2(NUM_WAY){1'b0}};
            miss_index_reg <= 2'b0;
            miss_tag_reg   <= 28'b0;
            victim_addr_reg<= 32'b0;
            victim_dirty_reg <= 1'b0;
            need_writeback_reg <= 1'b0;
            hit_index_reg <= 2'b0;
            hit_way_reg <= {$clog2(NUM_WAY){1'b0}};
            output_from_hit_reg <= 1'b0;
            
            // Reset cache storage
            for (int s=0; s<NUM_SET; s++) begin
                fifo_ptr[s] <= '0;
                for (int w=0; w<NUM_WAY; w++) begin
                    valid[s][w] <= 1'b0;
                    dirty[s][w] <= 1'b0;
                    dirty_debug <= 0;
                    tag_array[s][w] <= 28'b0;
                    data_array[s][w] <= 32'b0;
                end
            end
        end 
        else begin
            current_state <= next_state;

            if (current_state == IDLE && i_mem_access) begin
                req_addr_reg <= i_addr;
                req_wdata_reg <= i_wdata;
                req_wr_en_reg <= i_wr_en;
                req_byte_mask_reg <= i_byte_mask;
            end

            if (current_state == CHECK_CACHE && hit) begin
                hit_index_reg <= index;
                hit_way_reg <= hit_way;
                output_from_hit_reg <= 1'b1;
            end

            // ===================================================
            // LATCH MISS INFO: when CHECK_CACHE detects miss
            // ===================================================
            if (current_state == CHECK_CACHE && !hit) begin
                
                miss_addr_reg  <= req_addr_reg;
                miss_wdata_reg <= req_wdata_reg;
                miss_wr_en_reg <= req_wr_en_reg;  
                victim_way_reg <= victim_way;
                miss_index_reg <= index;
                miss_tag_reg   <= tag;
                
                victim_dirty_reg <= dirty[index][victim_way];  // Latch victim's dirty bit NOW
                need_writeback_reg <= dirty[index][victim_way];  // Latch writeback decision NOW
                //victim address: victim_tag || index
                victim_addr_reg <= {tag_array[index][victim_way], index};
                output_from_hit_reg <= 1'b0;
            end

            // ===================================================
            // UPDATE CACHE: Sync cache with SRAM
            // ===================================================
            if (current_state == UPDATE_CACHE) begin
                // Update victim cache line with SRAM data
                tag_array[miss_index_reg][victim_way_reg]  <= miss_tag_reg;
                valid[miss_index_reg][victim_way_reg]      <= 1'b1;

                // Set dirty based on operation type
                if (miss_wr_en_reg) begin
                    // STORE operation: overwrite with write data and mark dirty
                    data_array[miss_index_reg][victim_way_reg] <= write_with_mask(i_sram_rdata, miss_wdata_reg, req_byte_mask_reg);
                    dirty[miss_index_reg][victim_way_reg]      <= 1'b1;
                    dirty_debug <= 1;
                end else begin
                    // LOAD operation: data from SRAM, mark clean
                    data_array[miss_index_reg][victim_way_reg] <= i_sram_rdata;
                    dirty[miss_index_reg][victim_way_reg]      <= 1'b0;
                    dirty_debug <= 0;
                end

                // Increment FIFO pointer for next victim selection
                fifo_ptr[miss_index_reg] <= fifo_ptr[miss_index_reg] + 1;
            end

            // ===================================================
            // WRITE HIT: Update cache on write hits
            // ===================================================
            if (current_state == CHECK_CACHE && hit && req_wr_en_reg) begin
                // Write hit: update data and mark dirty
                dirty[index][hit_way]      <= 1'b1;
                dirty_debug <= 1;
                data_array[index][hit_way] <= write_with_mask(data_array[index][hit_way], req_wdata_reg, req_byte_mask_reg);
            end
        end
    end

    // -----------------------------------
    // FSM OUTPUT (COMBINATIONAL)
    // -----------------------------------
    always_comb begin
        case(current_state)
            IDLE: begin
                // Idle: no activity
                stall = 1'b0;
            end

            CHECK_CACHE: begin
                stall        = 1'b1;
                o_sram_enb   = 1'b0; // No SRAM access in CHECK_CACHE
                o_sram_addr  = 32'b0;
                o_sram_wr_en = 1'b0;
                o_sram_wdata = 32'b0;
                o_cache_done = 1'b0;
                //o_rdata      = 32'b0; // Default read data
            end

            WRITEBACK_L2: begin
                // Write dirty victim back to L2
                stall      = 1'b1;
                o_sram_enb   = 1'b1;
                o_sram_addr  = victim_addr_reg;  // Victim's original address
                o_sram_wr_en = 1'b1;             // Write mode
                o_sram_wdata = data_array[miss_index_reg][victim_way_reg];  // Victim data
                //$display("WRITEBACK ADDR: %h, DATA: %h, TIME = %d", victim_addr_reg, data_array[miss_index_reg][victim_way_reg], $time);
            end

            L2_READ: begin
                // LOAD missed line from L2
                stall      = 1'b1;
                o_sram_enb   = 1'b1;
                o_sram_addr  = miss_addr_reg;
                o_sram_wr_en = 1'b0;  // Read mode
                o_sram_wdata = 32'b0;
                //$display("RAM READ ADDR: %h, TIME = %d", miss_addr_reg, $time);
            end

            UPDATE_CACHE: begin
                // Update cache from SRAM: stall for 1 cycle
                stall = 1'b1;
                o_sram_enb   = 1'b0; // No SRAM access here
                o_sram_addr  = miss_addr_reg;
                o_sram_wr_en = 1'b0;  
                o_sram_wdata = 32'b0;
                //$display("UPDATE CACHE FROM SRAM ADDR: %h, DATA: %h, TIME = %d", miss_addr_reg, i_sram_rdata, $time);
            end

            OUTPUT_DATA: begin
                // Data ready: return to IDLE next cycle
                stall = 1'b1;
                o_sram_enb   = 1'b0; // No SRAM access here
                o_sram_addr  = miss_addr_reg;
                o_sram_wr_en = 1'b0;  
                o_sram_wdata = 32'b0;
                o_cache_done = 1'b1;
                // Return data based on path reaching OUTPUT_DATA
                if (output_from_hit_reg)
                    o_rdata = data_array[hit_index_reg][hit_way_reg];
                else
                    o_rdata = data_array[miss_index_reg][victim_way_reg];
            end

            default: begin
                stall = 1'b0;
                o_sram_enb   = 1'b0;
                o_sram_addr  = 32'b0;
                o_sram_wr_en = 1'b0;
                o_sram_wdata = 32'b0;
                o_rdata      = 32'b0;
                o_cache_done = 1'b0;
            end
        endcase
        
    end

endmodule
// ===== END FILE: cache.sv =====


// ===== BEGIN FILE: cache_l2.sv =====
module cache_l2 (
    input  logic         i_clk,
    input  logic         i_reset,

    input  logic         i_req_valid,
    input  logic         i_req_wr_en,
    input  logic  [3:0]  i_req_byte_mask,
    input  logic [31:0]  i_req_addr,
    input  logic [31:0]  i_req_wdata,

    output logic [31:0]  o_resp_rdata,
    output logic         o_resp_valid,
    output logic         o_stall,
    output logic         o_hit_debug,
    output logic         o_miss_debug,

    output logic         o_sram_enb,
    output logic [31:0]  o_sram_addr,
    output logic         o_sram_wr_en,
    output logic [31:0]  o_sram_wdata,
    input  logic [31:0]  i_sram_rdata,
    input  logic         i_sram_ready
);
    localparam int NUM_SET = 16;
    localparam int NUM_WAY = 8;

    logic valid   [NUM_SET][NUM_WAY];
    logic dirty   [NUM_SET][NUM_WAY];
    logic [25:0] tag_array [NUM_SET][NUM_WAY];
    logic [31:0] data_array[NUM_SET][NUM_WAY];
    logic [$clog2(NUM_WAY)-1:0] fifo_ptr[NUM_SET];

    logic [31:0] req_addr_reg;
    logic [31:0] req_wdata_reg;
    logic [3:0]  req_byte_mask_reg;
    logic        req_wr_en_reg;

    logic [3:0]  req_index;
    logic [25:0] req_tag;

    logic [NUM_WAY-1:0] way_hit;
    logic hit;
    logic [$clog2(NUM_WAY)-1:0] hit_way;
    logic [$clog2(NUM_WAY)-1:0] victim_way;

    logic [31:0] victim_addr_reg;
    logic [31:0] refill_data_reg;
    logic        hit_on_req;

    typedef enum logic [2:0] {
        S_IDLE      = 3'b000,
        S_LOOKUP    = 3'b001,
        S_WRITEBACK = 3'b010,
        S_ALLOCATE  = 3'b011,
        S_REFILL    = 3'b100,
        S_RESP      = 3'b101
    } state_t;

    state_t state, next_state;

    function automatic logic [31:0] write_with_mask(
        input logic [31:0] old_data,
        input logic [31:0] new_data,
        input logic [3:0]  byte_mask
    );
        begin
            case (byte_mask)
                4'b0001: write_with_mask = {old_data[31:8], new_data[7:0]};
                4'b0010: write_with_mask = {old_data[31:16], new_data[15:8], old_data[7:0]};
                4'b0100: write_with_mask = {old_data[31:24], new_data[23:16], old_data[15:0]};
                4'b1000: write_with_mask = {new_data[31:24], old_data[23:0]};
                4'b0011: write_with_mask = {old_data[31:16], new_data[15:0]};
                4'b1100: write_with_mask = {new_data[31:16], old_data[15:0]};
                4'b1111: write_with_mask = new_data;
                default: write_with_mask = old_data;
            endcase
        end
    endfunction

    assign req_index  = req_addr_reg[5:2];
    assign req_tag    = req_addr_reg[31:6];
    assign victim_way = fifo_ptr[req_index];

    always_comb begin
        for (int w = 0; w < NUM_WAY; w++)
            way_hit[w] = valid[req_index][w] && (tag_array[req_index][w] == req_tag);
    end

    assign hit = |way_hit;

    always_comb begin
        hit_way = '0;
        for (int w = 0; w < NUM_WAY; w++)
            if (way_hit[w]) hit_way = w;
    end

    assign o_hit_debug  = (state == S_LOOKUP) && hit;
    assign o_miss_debug = (state == S_LOOKUP) && !hit;

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (i_req_valid)
                    next_state = S_LOOKUP;
            end

            S_LOOKUP: begin
                if (hit)
                    next_state = S_RESP;
                else if (dirty[req_index][victim_way])
                    next_state = S_WRITEBACK;
                else
                    next_state = S_ALLOCATE;
            end

            S_WRITEBACK: begin
                if (i_sram_ready)
                    next_state = S_ALLOCATE;
            end

            S_ALLOCATE: begin
                if (i_sram_ready)
                    next_state = S_REFILL;
            end

            S_REFILL: begin
                next_state = S_RESP;
            end

            S_RESP: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            state <= S_IDLE;
            req_addr_reg <= 32'b0;
            req_wdata_reg <= 32'b0;
            req_byte_mask_reg <= 4'b0;
            req_wr_en_reg <= 1'b0;
            victim_addr_reg <= 32'b0;
            refill_data_reg <= 32'b0;
            hit_on_req <= 1'b0;

            for (int s = 0; s < NUM_SET; s++) begin
                fifo_ptr[s] <= '0;
                for (int w = 0; w < NUM_WAY; w++) begin
                    valid[s][w] <= 1'b0;
                    dirty[s][w] <= 1'b0;
                    tag_array[s][w] <= 26'b0;
                    data_array[s][w] <= 32'b0;
                end
            end
        end else begin
            state <= next_state;

            if (state == S_IDLE && i_req_valid) begin
                req_addr_reg <= i_req_addr;
                req_wdata_reg <= i_req_wdata;
                req_byte_mask_reg <= i_req_byte_mask;
                req_wr_en_reg <= i_req_wr_en;
            end

            if (state == S_LOOKUP) begin
                hit_on_req <= hit;
                victim_addr_reg <= {tag_array[req_index][victim_way], req_index, 2'b00};

                if (hit && req_wr_en_reg) begin
                    data_array[req_index][hit_way] <= write_with_mask(data_array[req_index][hit_way], req_wdata_reg, req_byte_mask_reg);
                    dirty[req_index][hit_way] <= 1'b1;
                end
            end

            if (state == S_ALLOCATE && i_sram_ready) begin
                refill_data_reg <= i_sram_rdata;
            end

            if (state == S_REFILL) begin
                tag_array[req_index][victim_way] <= req_tag;
                valid[req_index][victim_way] <= 1'b1;
                fifo_ptr[req_index] <= fifo_ptr[req_index] + 1'b1;

                if (req_wr_en_reg) begin
                    data_array[req_index][victim_way] <= write_with_mask(refill_data_reg, req_wdata_reg, req_byte_mask_reg);
                    dirty[req_index][victim_way] <= 1'b1;
                end else begin
                    data_array[req_index][victim_way] <= refill_data_reg;
                    dirty[req_index][victim_way] <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        o_stall = 1'b1;
        o_resp_valid = 1'b0;
        o_resp_rdata = 32'b0;

        o_sram_enb = 1'b0;
        o_sram_addr = 32'b0;
        o_sram_wr_en = 1'b0;
        o_sram_wdata = 32'b0;

        case (state)
            S_IDLE: begin
                o_stall = 1'b0;
            end

            S_WRITEBACK: begin
                o_sram_enb = 1'b1;
                o_sram_addr = victim_addr_reg;
                o_sram_wr_en = 1'b1;
                o_sram_wdata = data_array[req_index][victim_way];
            end

            S_ALLOCATE: begin
                o_sram_enb = 1'b1;
                o_sram_addr = req_addr_reg;
                o_sram_wr_en = 1'b0;
            end

            S_RESP: begin
                o_stall = 1'b0;
                o_resp_valid = 1'b1;
                if (!req_wr_en_reg) begin
                    if (hit_on_req)
                        o_resp_rdata = data_array[req_index][hit_way];
                    else
                        o_resp_rdata = data_array[req_index][victim_way];
                end
            end

            default: begin
            end
        endcase
    end

endmodule
// ===== END FILE: cache_l2.sv =====


// ===== BEGIN FILE: control_unit_new.sv =====
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
    	// GiÃ¡ trá»‹ máº·c Ä‘á»‹nh
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
				o_rd_wren  		= 1'b1;		// cho phÃ©p ghi reg file
				o_wb_sel   		= 2'b1; 	// chá»n write back tá»« ngÃµ ra ALU
				o_asel    		= 1'b0; 	// chá»n A tá»« rs1
				o_bsel    		= 1'b0; 	// chá»n B tá»« rs2s
				o_imm_sel 	 	= 3'b000;	// Imm_Gen theo I type
				o_br_un    		= 1'b0;
				o_wren   		= 1'b0;
				o_slt_sl 		= 3'b0;
				case(funct3)
					3'b000: o_alu_op = (i_inst[30]) ? 4'b1000 : 4'b0000; // SUB náº¿u i_inst[30] = 1, ADD náº¿u i_inst[30] = 0
					3'b001: o_alu_op = 4'b0001; // SLL
					3'b010: o_alu_op = 4'b0010; // SLT
					3'b011: o_alu_op = 4'b0011; // SLTU
					3'b100: o_alu_op = 4'b0100; // XOR
					3'b101: o_alu_op = (i_inst[30]) ? 4'b1101 : 4'b0101; // SRA náº¿u i_inst[30] = 1, SRL náº¿u i_inst[30] = 0
					3'b110: o_alu_op = 4'b0110; // OR
					3'b111: o_alu_op = 4'b0111; // AND
					default: begin
						o_insn_vld_ctrl =  1'b0;
						o_alu_op = 4'b0000; // Máº·c Ä‘á»‹nh lÃ  ADD
					end
				endcase
			end
			

			7'b0010011: begin  // I-type
				o_slt_sl 		= 3'b000; 
				o_insn_vld_ctrl = 1'b1; 
				o_rd_wren  		= 1'b1;//cho phÃ©p ghi reg file
				o_wb_sel   		= 2'b1;// chá»n write back tá»« ngÃµ ra ALU
				o_asel    		= 1'b0;// chá»n A tá»« rs1
				o_bsel    		= 1'b1;//chá»n B tá»« rs2
				o_imm_sel 		= 3'b000;// Imm_Gen theo I type
				o_wren   		= 1'b0;	// Cho phÃ©p Ä‘á»c Ä‘á»c DMEM
				o_br_un    		= 1'b0;
				case(funct3)
					3'b000: o_alu_op = 4'b0000; // ADDI
					3'b001: o_alu_op = 4'b0001; // SLLI
					3'b010: o_alu_op = 4'b0010; // SLTI
					3'b011: o_alu_op = 4'b0011; // SLTUI
					3'b100: o_alu_op = 4'b0100; // XORI
					3'b101: o_alu_op = (i_inst[30]) ? 4'b1101 : 4'b0101; // SRAI náº¿u i_inst[30] = 1, SRLI náº¿u i_inst[30] = 0
					3'b110: o_alu_op = 4'b0110; // ORI
					3'b111: o_alu_op = 4'b0111; // ANDI
					default: begin
						o_insn_vld_ctrl =  1'b0;
						o_alu_op = 4'b0000; // Máº·c Ä‘á»‹nh lÃ  ADD
					end
				endcase																							
			end
				
			7'b0000011: begin  // Load
				o_insn_vld_ctrl = 1'b1; 
				o_rd_wren  		= 1'b1; 	// Cho phÃ©p ghi láº¡i vÃ o regfile
				o_wb_sel   		= 2'b0; 	// Láº¥y dá»¯ liá»‡u tá»« DMEM
				o_asel    		= 1'b0; 	// Chá»n Rs1 + Imm_Gen
				o_bsel    		= 1'b1; 	// Chá»n Imm_Gen
				o_imm_sel 		= 3'b000;	// Imm_Gen theo I type
				o_alu_op 		= 4'b0000;	// Thá»±c hiá»‡n phÃ©p cá»™ng
				o_wren   		= 1'b0;		// Cho phÃ©p Ä‘á»c Ä‘á»c DMEM
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
				o_rd_wren 		= 1'b0; 	//khÃ´ng cho ghi láº¡i vÃ o reg file
				o_asel 			= 1'b0; 	//chá»n A lÃ  rs1 
				o_bsel 			= 1'b1; 	//chá»n B lÃ  Imm_Gen theo S type
				o_wren 			= 1'b1; 	//cho phÃ©p Ä‘á»c vÃ  ghi DMEM
				o_alu_op 		= 4'b0000;	// Thá»±c hiá»‡n phÃ©p cá»™ng
				o_wb_sel 		= 2'b11; 	//write back lÃ  tÃ¹y Ä‘á»‹nh vÃ¬ khÃ´ng ghi ngÆ°á»£c láº¡i vÃ o regfile
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
				o_rd_wren 		= 1'b0;		// KhÃ´ng ghi láº¡i vÃ o reg file
				o_asel 			= 1'b1;		// A chá»n PC hiá»‡n hÃ nh
				o_bsel 			= 1'b1;		// B chá»n imm_Gen theo B type
				o_alu_op 		= 4'b0000;	// ALU thá»±c hiá»‡n phÃ©p cá»™ng
				o_wren 			= 1'b0;		// Cho phÃ©p Ä‘á»c DMEM
				o_wb_sel 		= 2'b11; 	// write back lÃ  tÃ¹y Ä‘á»‹nh vÃ¬ khÃ´ng ghi ngÆ°á»£c láº¡i vÃ o regfile
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
				o_rd_wren 		= 1'b1;		// cho phÃ©p ghi ngÆ°á»£c vÃ o regfile
				o_bsel 			= 1'b1;		// B chá»n Imm_Gen theo J type
				o_asel  		= 1'b1;		// A chá»n PC hiá»‡n hÃ nh
				o_alu_op 		= 4'b0000;	// ALU thá»±c hiá»‡n phÃ©p cá»™ng
				o_wren 			= 1'b0;		// Cho phÃ©p Ä‘á»c DMEM
				o_wb_sel 		= 2'b10;	// Write back chá»n PC+4 Ä‘á»ƒ return
				o_br_un    		= 1'b0;
				o_slt_sl 		= 3'b000;
				o_ctrl 			= 1'b1;
			end
			
			7'b1100111: begin // I-type JALR
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b000; 	// Imm_Gen theo I Type
				o_rd_wren 		= 1'b1;		// cho phÃ©p ghi ngÆ°á»£c vÃ o regfile
				o_bsel 			= 1'b1;		// B chá»n Imm_Gen theo I type
				o_asel 			= 1'b0;		// A chá»n rs1
				o_alu_op 		= 4'b0000;	// ALU thá»±c hiá»‡n phÃ©p cá»™ng
				o_wren 			= 1'b0;		// Cho phÃ©p Ä‘á»c DMEM
				o_wb_sel 		= 2'b10; 	// Write back chá»n PC+4 Ä‘á»ƒ return
				o_br_un    		= 1'b0;
				o_slt_sl 		= 3'b000;
				o_ctrl 			= 1'b1;
			end
			7'b0110111: begin // U-type LUI
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b100; 	//Imm_Gen theo U type LUI
				o_rd_wren 		= 1'b1; 	//cho phÃ©p ghi vÃ o reg file
				o_bsel 			= 1'b1;		// B chá»n Imm_Gen theo U type LUI
				o_asel 			= 1'b0;		// A tÃ¹y Ä‘á»‹nh
				o_alu_op 		= 4'b1111;  //ALU dáº«n B ra ALU_out
				o_wren 			= 1'b0; 	// Cho phÃ©p Ä‘á»c DMEM
				o_wb_sel 		= 2'b01; 	// chá»n write back tá»« ALU_out
				o_br_un   		= 1'b0;
				o_slt_sl 		= 3'b000;
			end
			7'b0010111: begin // U-type AUIPC
				o_insn_vld_ctrl = 1'b1; 
				o_imm_sel 		= 3'b101; 	//Imm_Gen theo U type AUIPC
				o_rd_wren 		= 1'b1; 	//cho phÃ©p ghi vÃ o reg file
				o_bsel 			= 1'b1;		// B chá»n Imm_Gen theo U type LUI
				o_asel 			= 1'b1;		// A tÃ¹y láº¥y PC hiá»‡n hÃ nh
				o_alu_op 		= 4'b0000; 	//ALU thá»±c hiá»‡n phÃ©p cá»™ng
				o_wren 			= 1'b0; 	// Cho phÃ©p Ä‘á»c DMEM
				o_wb_sel 		= 2'b01; 	// chá»n write back tá»« ALU_out
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
// ===== END FILE: control_unit_new.sv =====


// ===== BEGIN FILE: data_transfer.sv =====
`ifndef DATA_TRANSFER
`define DATA_TRANSFER

module data_transfer(
    input  logic [31:0] i_ld_data,
    input  logic [2:0]  i_load_type,
    input  logic [1:0]  i_byte_offset,
    output logic [31:0] o_ld_result
);
    localparam LB  = 3'b011;
    localparam LH  = 3'b100;
    localparam LW  = 3'b101;
    localparam LBU = 3'b110;
    localparam LHU = 3'b111;

    logic [7:0]  selected_byte;
    logic [15:0] selected_half;

    always_comb begin
        case (i_byte_offset)
            2'b00: selected_byte = i_ld_data[7:0];
            2'b01: selected_byte = i_ld_data[15:8];
            2'b10: selected_byte = i_ld_data[23:16];
            default: selected_byte = i_ld_data[31:24];
        endcase
    end

    always_comb begin
        if (i_byte_offset[1] == 1'b0)
            selected_half = i_ld_data[15:0];
        else
            selected_half = i_ld_data[31:16];
    end

    always_comb begin
        case (i_load_type)
            LB:  o_ld_result = {{24{selected_byte[7]}}, selected_byte};
            LH:  o_ld_result = {{16{selected_half[15]}}, selected_half};
            LW:  o_ld_result = i_ld_data;
            LBU: o_ld_result = {24'b0, selected_byte};
            LHU: o_ld_result = {16'b0, selected_half};
            default: o_ld_result = i_ld_data;
        endcase
    end
endmodule

`endif
// ===== END FILE: data_transfer.sv =====


// ===== BEGIN FILE: decode_cycle.sv =====
`ifndef DECODE_CYCLE
`define DECODE_CYCLE
module decode_cycle(
    input logic         i_decode_clk,
    input logic         i_decode_reset,

    // Input tá»« Fetch
    input logic [31:0]  i_decode_pc,
    input logic [31:0]  i_decode_inst,

    // Input tá»« Writeback
    input logic [31:0]  i_decode_rd_data,
    input logic [4:0]   i_decode_rd_addr,
    input logic         i_decode_rd_wren,
	
	// i_decode_flush
    input logic         i_decode_flush,
    input logic         i_decode_stall,
    input logic         i_decode_stall_cache,
    input logic         i_decode_insn_vld,

    //Input alu data for forwarding
    input logic  [31:0] i_decode_alu_data_execute,

    // Output tá»›i Ex giÃ¡ trá»‹ PC vÃ  inst
    output logic [31:0] o_decode_inst_ex,
    output logic [31:0] o_decode_pc_ex,


    // Output to Execute EX_control
    output logic        o_decode_asel_ex,
    output logic        o_decode_bsel_ex,
    output logic [31:0] o_decode_rs1_data_ex,
    output logic [31:0] o_decode_rs2_data_ex,
    output logic [31:0] o_decode_imm_out_ex,
    output logic [3:0]  o_decode_alu_op_ex,
    output logic        o_decode_br_un_ex,

    // Output to Execute MEM control
    output logic        o_decode_lsu_wren_ex,
    output logic [2:0]  o_decode_slt_sl_ex,

    // Output to Execute Writeback control
    output logic [1:0]  o_decode_wb_sel_ex,
    output logic        o_decode_rd_wren_ex,

    // Output instruction valid
    output logic        o_insn_vld_ctrl,
	 
	// Output Ä‘á»ƒ fix load hazard
	output logic [4:0]  o_decode_rs1_addr_hazard,
	output logic [4:0]  o_decode_rs2_addr_hazard,

    output logic o_decode_ctrl
);
    // Signal Imm_Gen
    logic [31:0]        imm_out, imm_out_reg;
    logic [2:0]         imm_sel;

    // Signal Regfile
    logic [31:0]        data_1, data_2;
    logic [31:0]        data_1_reg, data_2_reg;

    //Signal Control Unit
    logic [3:0] alu_op, alu_op_reg;
    logic       br_un,  br_un_reg; 
    logic       wren,   wren_reg;
    logic [2:0] slt_sl, slt_sl_reg;
    logic [1:0] wb_sel, wb_sel_reg;
    logic       rd_wren,rd_wren_reg;
    logic       asel,   asel_reg;
    logic       bsel,   bsel_reg;

    logic       insn_vld_ctrl, insn_vld_ctrl_reg;

    logic [31:0] pc_reg, inst_reg;
    logic ctrl_reg, ctrl;

    //For decode forwarding
    logic [4:0] rd_addr_execute;
    logic [4:0] rs1_addr_decode;
    logic [4:0] rs2_addr_decode;
    logic sel_forward_decode;

    assign rd_addr_execute = o_decode_inst_ex[11:7];
    assign rs1_addr_decode = i_decode_inst[19:15];
    assign rs2_addr_decode = i_decode_inst[24:20];

    regfile regfile_at_decode (
        .i_clk      (i_decode_clk),
        .i_reset    (i_decode_reset),
        .i_rs1_addr (rs1_addr_decode),
        .i_rs2_addr (rs2_addr_decode),
        .i_rd_addr  (i_decode_rd_addr),
        .i_rd_data  (i_decode_rd_data),
        .i_rd_wren  (i_decode_rd_wren),
        .o_rs1_data (data_1),
        .o_rs2_data (data_2)
    );
/*
Control unit cá»§a pipeline khÃ¡c vá»›i cá»§a single cycle, dá»± Ä‘oÃ¡n luÃ´n nháº£y
 -> bá» cÃ¡c tÃ­n hiá»‡u liÃªn quan Ä‘áº¿n nháº£y */
    control_unit_new control_unit_at_decode (
        .i_inst         (i_decode_inst),
        .o_imm_sel      (imm_sel),
        .o_rd_wren      (rd_wren),
        .o_br_un        (br_un),
        .o_bsel         (bsel),
        .o_asel         (asel),
        .o_alu_op       (alu_op),
        .o_wren         (wren),
        .o_slt_sl       (slt_sl),
        .o_wb_sel       (wb_sel),
        .o_ctrl         (ctrl)
    );

    imm_gen imm_gen_at_decode (
        .i_inst         (i_decode_inst),
        .i_imm_sel      (imm_sel),
        .o_imm_out      (imm_out)
    );

    always_ff @(posedge i_decode_clk ) begin
        if (i_decode_reset) begin
            imm_out_reg   <= 32'b0;
            data_1_reg    <= 32'b0;
            data_2_reg    <= 32'b0;
            pc_reg        <= 32'b0;
            inst_reg      <= 32'h00000013; // NOP
            alu_op_reg    <= 4'b0;
            br_un_reg     <= 1'b0;
            wren_reg      <= 1'b0;
            slt_sl_reg    <= 3'b0;
            wb_sel_reg    <= 2'b0;
            rd_wren_reg   <= 1'b0;
            asel_reg      <= 1'b0;
            bsel_reg      <= 1'b0;
            insn_vld_ctrl_reg <= 1'b0;
            ctrl_reg <= 0;
        end 
		else if (i_decode_stall) begin
            // Khi i_decode_stall: Giá»¯ láº¡i toÃ n bá»™ dá»¯ liá»‡u cÅ©, nhÆ°ng chÃ¨n NOP
            inst_reg      <= 32'h00000013; // chá»‰ thay Ä‘á»•i instruction
            insn_vld_ctrl_reg <= 1'b0;
        end 
        else if (i_decode_stall_cache) begin
            // Khi i_stall: Giá»¯ láº¡i toÃ n bá»™ dá»¯ liá»‡u cÅ©, nhÆ°ng chÃ¨n NOP
            //inst_reg     <= inst_reg;  // NOP khi i_stall
            //insn_vld_reg <= 1'b0;
        end
		  else if (i_decode_flush) begin
			imm_out_reg   <= 32'b0;
            data_1_reg    <= 32'b0;
            data_2_reg    <= 32'b0;
            pc_reg        <= i_decode_pc;
            inst_reg      <= 32'h00000013; // NOP
            alu_op_reg    <= 4'b0;
            br_un_reg     <= 1'b0;
            wren_reg      <= 1'b0;
            slt_sl_reg    <= 3'b0;
            wb_sel_reg    <= 2'b0;
            rd_wren_reg   <= 1'b0;
            asel_reg      <= 1'b0;
            insn_vld_ctrl_reg <= 1'b0;
            ctrl_reg      <= ctrl;
		  end
		  else begin
            imm_out_reg   <= imm_out;
            data_1_reg    <= data_1;
            data_2_reg    <= data_2;
            pc_reg        <= i_decode_pc;
            inst_reg      <= i_decode_inst;
            alu_op_reg    <= alu_op;
            br_un_reg     <= br_un;
            wren_reg      <= wren;
            slt_sl_reg    <= slt_sl;
            wb_sel_reg    <= wb_sel;
            rd_wren_reg   <= rd_wren;
            asel_reg      <= asel;
            bsel_reg      <= bsel;
            insn_vld_ctrl_reg <= i_decode_insn_vld; //insn_vld_ctrl;
            ctrl_reg      <= ctrl;
        end
    end

    assign o_decode_pc_ex       = (i_decode_flush) ? 32'b0: pc_reg;
    assign o_decode_rs1_data_ex = data_1_reg;
    assign o_decode_rs2_data_ex = data_2_reg;
    assign o_decode_imm_out_ex  = imm_out_reg;
    assign o_decode_inst_ex     = (i_decode_stall_cache) ? 32'h00000013 : inst_reg;
    assign o_decode_alu_op_ex   = alu_op_reg;
    assign o_decode_br_un_ex    = br_un_reg;
    assign o_decode_lsu_wren_ex = wren_reg;
    assign o_decode_slt_sl_ex   = slt_sl_reg;
    assign o_decode_wb_sel_ex   = wb_sel_reg;
    assign o_decode_rd_wren_ex  = rd_wren_reg;
    assign o_decode_asel_ex     = asel_reg;
    assign o_decode_bsel_ex     = bsel_reg;
	assign o_insn_vld_ctrl      = insn_vld_ctrl_reg;
	// fix load hazard
	assign o_decode_rs1_addr_hazard = i_decode_inst[19:15];
	assign o_decode_rs2_addr_hazard = i_decode_inst[24:20];
    assign o_decode_ctrl = ctrl_reg;
endmodule
`endif
// ===== END FILE: decode_cycle.sv =====


// ===== BEGIN FILE: execute_cycle.sv =====
//chÆ°a add insn valid///////
module execute_cycle(
    input logic         i_execute_clk,
    input logic         i_execute_reset,

    // Input tá»« Decode PC, inst giá»¯ nguyÃªn
    input logic [31:0]  i_execute_pc, 
    input logic [31:0]  i_execute_inst,
    input logic         i_execute_insn_vld,
    input logic         i_execute_ctrl,

    // Input tá»« Decode, giá»¯ há»™ MEM control
    input logic         i_execute_lsu_wren,
    input logic [2:0]   i_execute_slt_sl,

    // Input tá»« Decode, giá»¯ há»™ Writeback control
    input logic [1:0]   i_execute_wb_sel,
    input logic         i_execute_rd_wren,

    // Input tá»« Decode Ä‘Æ°á»£c sá»­ dá»¥ng trong Execute
    input logic         i_execute_asel,
    input logic         i_execute_bsel,
    input logic [31:0]  i_execute_rs1_data,
    input logic [31:0]  i_execute_rs2_data,
    input logic [31:0]  i_execute_imm_out,
    input logic [3:0]   i_execute_alu_op,
    input logic         i_execute_br_un,

    // Input tá»« MEM cho flush
    input logic         flush,
    input logic         i_stall,
    input logic         i_execute_stall_cache,
    input logic         i_execute_cache_done,

    // Input tá»« Forwarding control
    input logic [1:0]   i_execute_fwd_operand_a,
    input logic [1:0]   i_execute_fwd_operand_b,

    // Data forwarding tá»« MEM vÃ  WriteBack
    input logic [31:0]  i_execute_fwd_alu_data,
    input logic [31:0]  i_execute_fwd_wb_data,

    // Outputs tá»›i MEM giÃ¡ trá»‹ tÃ­nh Ä‘Æ°á»£c tá»« Execute
    output logic        o_execute_br_equal_mem,
    output logic        o_execute_br_less_mem,
    output logic [31:0] o_execute_alu_data,

    // Output tá»›i MEM cÃ¡c giÃ¡ trá»‹ giá»¯ há»™
    output logic [31:0] o_execute_pc_mem,
    output logic [31:0] o_execute_rs2_data_mem,
    output logic [31:0] o_execute_inst_mem,
    output logic        o_execute_insn_vld_mem,
    output logic        o_execute_ctrl,

    // Output to Execute MEM control
    output logic        o_execute_lsu_wren_mem,
    output logic [2:0]  o_execute_slt_sl_mem,

    // Output to Execute Writeback control
    output logic [1:0]  o_execute_wb_sel_mem,
    output logic        o_execute_rd_wren_mem,

    // Output rs1 vÃ  rs2 Ä‘á»ƒ forward
    output logic [31:0] o_execute_inst_fwd,

    //Output to decode Ä‘á»ƒ forward
    output logic  [31:0] o_execute_alu_data_decode
);

    logic [31:0] alu_data;
    logic [31:0] forward_a_out;
    logic [31:0] forward_b_out;

    logic [31:0] pc_reg;
    logic [31:0] inst_reg, inst_tmp;;
    logic [31:0] rs2_data;
    logic [31:0] rs2_data_reg;
    logic [31:0] alu_data_reg;
    logic br_equal_reg, br_equal;
    logic br_less_reg, br_less;
    logic wren_reg;
    logic [2:0] slt_sl_reg;
    logic [1:0] wb_sel_reg;
    logic rd_wren_reg;
    logic [31:0] asel_out, bsel_out;
    logic [31:0]brc_operand_a_out, brc_operand_b_out;
    logic insn_vld_reg;
    logic ctrl_reg;
    assign o_execute_inst_fwd = i_execute_inst;

    mux_3_1 mux_forward_operand_a (
        .data_0_i       (i_execute_rs1_data),
        .data_1_i       (i_execute_fwd_alu_data),
        .data_2_i       (i_execute_fwd_wb_data),
        .sel_i          (i_execute_fwd_operand_a),
        .data_out_o     (forward_a_out)
    );

    mux_3_1 mux_forward_operand_b (
        .data_0_i       (i_execute_rs2_data),
        .data_1_i       (i_execute_fwd_alu_data),
        .data_2_i       (i_execute_fwd_wb_data),
        .sel_i          (i_execute_fwd_operand_b),
        .data_out_o     (forward_b_out)
    );

    mux_2_1 mux_asel (
        .data_0_i       (forward_a_out),
        .data_1_i       (i_execute_pc),
        .sel_i          (i_execute_asel),
        .data_out_o     (asel_out)
    );

    mux_2_1 mux_bsel (
        .data_0_i       (forward_b_out),
        .data_1_i       (i_execute_imm_out),
        .sel_i          (i_execute_bsel),
        .data_out_o     (bsel_out)
    );

    // Branch comparator
    brc brc_at_execute (
        .i_br_un        (i_execute_br_un),
        .i_rs1_data     (forward_a_out),
        .i_rs2_data     (forward_b_out),
        .o_br_equal     (br_equal),
        .o_br_less      (br_less)
    );

    // ALU
    alu alu_at_execute(
        .i_operand_a    (asel_out),
        .i_operand_b    (bsel_out), 
        .o_alu_data     (alu_data),
        .i_alu_op       (i_execute_alu_op)
    );

    // Pipeline registers
    always_ff @ (posedge i_execute_clk) begin
        
        if (i_execute_reset) begin
            pc_reg          <= 32'd0;
            inst_reg        <= 32'h00000013; // NOP
            rs2_data_reg    <= 32'd0;
            alu_data_reg    <= 32'd0;
            wren_reg        <= 0;
            slt_sl_reg      <= 0;
            wb_sel_reg      <= 0;
            rd_wren_reg     <= 0;
            br_equal_reg    <= 0;
            br_less_reg     <= 0;
            insn_vld_reg    <= 0;
            ctrl_reg <= 1'b0;    
        end 
        /*
        else if (i_execute_stall_cache) begin
            // Khi i_stall: Giá»¯ láº¡i toÃ n bá»™ dá»¯ liá»‡u cÅ©, nhÆ°ng chÃ¨n NOP
            inst_reg     <= inst_reg; //i_execute_inst;//inst_reg; // NOP khi i_stall
            //$display("Stall inst_reg: %h", inst_reg);
        end
        */
		else if (flush) begin
			pc_reg       <= 32'b0;//i_execute_pc; //pc_reg;
            inst_reg     <= 32'h00000013; // NOP khi i_flush
            rs2_data_reg <= 32'd0;
            alu_data_reg <= 32'd0;
            wren_reg     <= 0;
            slt_sl_reg   <= 0;
            wb_sel_reg   <= 0;
            rd_wren_reg  <= 0;
            br_equal_reg <= 0;
            br_less_reg  <= 0;
            insn_vld_reg <= 0;
            ctrl_reg <= i_execute_ctrl;    
          end	

		else if (!i_execute_stall_cache) begin
            pc_reg       <= i_execute_pc;
            inst_reg     <= i_execute_inst;
            rs2_data_reg <= forward_b_out;
            alu_data_reg <= alu_data;
            wren_reg     <= i_execute_lsu_wren;
            slt_sl_reg   <= i_execute_slt_sl;
            wb_sel_reg   <= i_execute_wb_sel;
            rd_wren_reg  <= i_execute_rd_wren;
            br_equal_reg <= br_equal;
            br_less_reg  <= br_less;
            insn_vld_reg <= i_execute_insn_vld;
            ctrl_reg     <= i_execute_ctrl;
        end
        else;
    end

    assign o_execute_alu_data       = alu_data_reg;
    assign o_execute_pc_mem         = /*i_execute_stall_cache ? 32'h00000013 :*/ pc_reg;
    assign o_execute_rs2_data_mem   = /*i_execute_stall_cache ? 32'h00000013 :*/ rs2_data_reg;
    assign o_execute_inst_mem       = i_execute_stall_cache ? 32'h00000013 : inst_reg;
    assign o_execute_lsu_wren_mem   = /*i_execute_stall_cache ? 1'b0 :*/ wren_reg;
    assign o_execute_slt_sl_mem     = /*i_execute_stall_cache ? 1'b0 :*/ slt_sl_reg;
    assign o_execute_wb_sel_mem     = /*i_execute_stall_cache ? 1'b0 :*/ wb_sel_reg;
    assign o_execute_rd_wren_mem    = /*i_execute_stall_cache ? 1'b0 :*/ rd_wren_reg;
    assign o_execute_br_equal_mem   = /*i_execute_stall_cache ? 1'b0 :*/ br_equal_reg;
    assign o_execute_br_less_mem    = /*i_execute_stall_cache ? 1'b0 :*/ br_less_reg;  
    assign o_execute_insn_vld_mem   = /*i_execute_stall_cache ? 1'b0 :*/ insn_vld_reg;
    assign o_execute_alu_data_decode= /*i_execute_stall_cache ? 32'h00000013 :*/ alu_data;
    assign o_execute_ctrl           = /*i_execute_stall_cache ? 1'b0 :*/ ctrl_reg;
endmodule
// ===== END FILE: execute_cycle.sv =====


// ===== BEGIN FILE: fetch_cycle.sv =====
`ifndef FETCH_CYCLE
`define FETCH_CYCLE


module fetch_cycle (
    input logic         i_fetch_clk,
    input logic         i_fetch_reset,

    // i_fetch_pc_sel chá»n nháº£y tá»« control unit
    input logic         i_fetch_pc_sel,                      
    input logic [31:0]  i_fetch_alu_data,  // Ä‘á»‹a chá»‰ nháº£y tá»« Execute
	
	 // i_stall, i_flush
	input logic         i_stall,
    input logic         i_fetch_stall_cache,
	input logic         i_flush,
	 
    // Output to Decode
    output logic [31:0] o_fetch_pc_id,
    output logic [31:0] o_fetch_inst_id,
    output logic        o_fetch_insn_vld_id
);
    logic [31:0] reg_pc_in, reg_pc_out, reg_pc_add4_out, pc_reg;
    logic [31:0] inst, inst_reg;
    logic insn_vld_reg, insn_vld;
    logic pc_enable;
    assign pc_enable = ~i_stall & ~i_fetch_stall_cache;
    // pc
    pc pc_at_fetch (
        .i_clk          (i_fetch_clk),
        .i_reset        (i_fetch_reset),
        .i_pc_enable    (pc_enable), // ThÃªm enable Ä‘á»ƒ dá»«ng pc khi i_stall
        .i_pc_data_in   (reg_pc_in),
        .o_pc_data_out  (reg_pc_out)
    );


    // TÃ­nh pc + 4
    add_sub_32_bit pc_add4_at_fetch (
        .A              (reg_pc_out),
        .B              (32'd4),
        .Sel            (1'b0),
        .Result         (reg_pc_add4_out)
    );

    // Chá»n Ä‘á»‹a chá»‰ tiáº¿p theo: nháº£y hoáº·c +4
    mux_2_1 pc_taken_at_fetch (
        .data_0_i   (reg_pc_add4_out),
        .data_1_i   (i_fetch_alu_data),
        .sel_i      (i_fetch_pc_sel),
        .data_out_o (reg_pc_in)
    );

    inst_memory inst_memory_at_fetch (
        .i_addr     (reg_pc_out),
        .o_rdata    (inst)
    );
    // Pipeline register IF/ID
    always_ff @(posedge i_fetch_clk /*or posedge i_fetch_reset*/) begin
        if (i_fetch_reset) begin
            inst_reg     <= 32'b0;
            pc_reg       <= 32'b0;
            insn_vld_reg <= 0;
        end 
        else begin

            if (i_flush) begin
                inst_reg     <= 32'h00000013; // NOP khi i_flush
                pc_reg       <= 32'b0;
                insn_vld_reg <= 0;
            end 
            else begin
                inst_reg     <= inst;
                insn_vld_reg <= 1'b1;
            end

            if (~i_stall & ~i_fetch_stall_cache) begin
                pc_reg <= reg_pc_out; // Chá»‰ cáº­p nháº­t pc náº¿u khÃ´ng i_stall
                
            end
            else inst_reg <= inst_reg;
        end
    end

    assign o_fetch_inst_id      = i_flush ? 1'b0 : inst_reg;
    assign o_fetch_pc_id        = pc_reg;
    assign o_fetch_insn_vld_id  = insn_vld_reg;
endmodule
`endif
// ===== END FILE: fetch_cycle.sv =====


// ===== BEGIN FILE: forward_unit.sv =====
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
    // TÃ¡ch rs1 vÃ  rs2 tá»« instruction 
    assign rs1_addr_execute = i_fwd_inst_execute[19:15];
    assign rs2_addr_execute = i_fwd_inst_execute[24:20];
    assign opcode_fwd       = i_fwd_inst_execute[6:0];

    always @ (*) begin
            //---------- Forward operand a ALU -----------------------
            if ((i_fwd_rd_addr_at_mem != 5'd0) && (i_fwd_rd_addr_at_mem == rs1_addr_execute)&&(i_fwd_rd_wren_at_mem))
                o_fwd_operand_a_execute = 2'b01;  // Forward tá»« MEM
                
            else if ((i_fwd_rd_addr_at_wb != 5'd0) && (i_fwd_rd_addr_at_wb == rs1_addr_execute)&&(i_fwd_rd_wren_at_wb))
                o_fwd_operand_a_execute = 2'b10;  // Forward tá»« WB
                
            else o_fwd_operand_a_execute = 2'b00;

            //-------------Forward operand b ALU -----------------------
            if ((i_fwd_rd_addr_at_mem != 5'd0) && (i_fwd_rd_addr_at_mem == rs2_addr_execute)&&(i_fwd_rd_wren_at_mem))
                o_fwd_operand_b_execute = 2'b01;  // Forward tá»« MEM

            else if ((i_fwd_rd_addr_at_wb != 5'd0) && (i_fwd_rd_addr_at_wb == rs2_addr_execute)&&(i_fwd_rd_wren_at_wb))
                o_fwd_operand_b_execute = 2'b10;  // Forward tá»« WB

            else o_fwd_operand_b_execute = 2'b00;
    end

endmodule
// ===== END FILE: forward_unit.sv =====


// ===== BEGIN FILE: full_adder.sv =====
`ifndef FULL_ADDER
`define FULL_ADDER
module full_adder (
    input  logic A,
	input logic B,
	input logic Cin,
    output logic Sum,
	output logic Cout);
	 
    assign Sum  = A ^ B ^ Cin;
    assign Cout = (A & B) | (Cin & (A ^ B));
endmodule
`endif
// ===== END FILE: full_adder.sv =====


// ===== BEGIN FILE: hazard_detection.sv =====
module hazard_detection(
    input  logic [31:0] i_hazard_inst_execute,
    input  logic [4:0]  i_hazard_rs1_addr_decode,
    input  logic [4:0]  i_hazard_rs2_addr_decode,
    input  logic [1:0]  i_hazard_wb_sel_execute,        // XÃ¡c Ä‘á»‹nh náº¿u lá»‡nh trÆ°á»›c lÃ  load
    input  logic        i_hazard_rd_wren_execute,       // CÃ³ ghi thanh ghi khÃ´ng
    //input  logic [31:0] i_hazard_inst_mem,
    input  logic  [31:0]      i_hazard_inst_decode,
    output logic        Stall
);
    logic [4:0] rd_addr_execute;

    // TÃ¡ch rd tá»« instruction á»Ÿ EX stage
    assign rd_addr_execute = i_hazard_inst_execute[11:7];

    always_comb begin
        // Náº¿u lá»‡nh á»Ÿ EX lÃ  load (WBSel = 2'b00) vÃ  ghi vÃ o thanh ghi (i_hazard_rd_wren_execute)
        // vÃ  rd_addr_execute khá»›p vá»›i i_hazard_rs1_addr_decode hoáº·c i_hazard_rs2_addr_decode cá»§a lá»‡nh hiá»‡n táº¡i á»Ÿ Decode
			if ((i_hazard_wb_sel_execute == 2'b00 && i_hazard_rd_wren_execute == 1'b1) && (rd_addr_execute != 5'd0) && (rd_addr_execute == i_hazard_rs1_addr_decode || rd_addr_execute == i_hazard_rs2_addr_decode)) begin
				 Stall = 1'b1;
			end
            else if (
                (i_hazard_inst_execute[6:0] == 7'b0100011)&&(i_hazard_inst_decode[6:0] == 7'b0000011) // STORE -> LOAD
                ||
                (i_hazard_inst_execute[6:0] == 7'b0100011)&&(i_hazard_inst_decode[6:0] == 7'b0100011) // STORE -> STORE
                //||
                //(i_hazard_inst_execute[6:0] == 7'b0100011) // STORE -> OTHER
            ) 
            begin
                Stall = 1'b1;
                //$display ("STALL FOR READ");
            end
			else Stall = 1'b0;
    end
endmodule
// ===== END FILE: hazard_detection.sv =====


// ===== BEGIN FILE: imm_gen.sv =====
`ifndef IMM_GEN
`define IMM_GEN
/////////Immediate generator///////////////
module imm_gen(	
	input logic [2:0] i_imm_sel, // Chá»n kiá»ƒu generate
	input logic [31:0] i_inst,	// i_instruction
	output logic [31:0] o_imm_out); // Káº¿t quáº£
	// I type = 000	7'b0010011
	// S type = 001	7'b0100011
	// B type = 010	7'b1100011
	// J type = 011	7'b1101111	JAL
	// U type = 100	7'b0110111 	LUI
	// U type = 101	7'b0010111	AUIPC
always @(*) begin
	case(i_imm_sel) 
		3'b000: begin //I typte
          o_imm_out = {{20{i_inst[31]}}, i_inst[31:20]};
		end
		3'b001: begin // S type
          o_imm_out = {{20{i_inst[31]}}, i_inst[31:25], i_inst[11:7]};
		end
		3'b010: begin //B type
          o_imm_out = {{20{i_inst[31]}}, i_inst[7],i_inst[30:25], i_inst[11:8],1'b0};
		end
		3'b011: begin // J type JAL
          o_imm_out = {{11{i_inst[31]}}, i_inst[31], i_inst[19:12], i_inst[20], i_inst[30:21], 1'b0};
		end
		3'b100: begin // U type LUI
			o_imm_out = {i_inst[31:12], 12'b0};
		end
		3'b101: begin // U type AUIPC
			o_imm_out = {i_inst[31:12], 12'b0};
		end
		default: o_imm_out = 32'bz;
	endcase
end
endmodule
`endif
// ===== END FILE: imm_gen.sv =====


// ===== BEGIN FILE: inst_memory.sv =====
`ifndef INST_MEMORY
`define INST_MEMORY
module inst_memory (
  output logic [31:0] o_rdata,
  input  logic [31:0] i_addr
);

  logic [31:0] imem [0:2048];
  initial begin
    $readmemh("D:/HCMUT/Year_2025_2026/252/LVTN/milestone_3_cache/00_src/isa_4b_ms3.hex", imem);
    //$readmemh("D:/HCMUT/Year_2025_2026/252/LVTN/milestone_3_cache/00_src/Test_Store_Type.dump", imem);
    //D:\HCMUT\Year_2025_2026\252\LVTN\milestone_3_cache\00_src\isa_4b_ms3.hex
  end
  always @(*) begin
      o_rdata = imem[i_addr[31:2]];  
  end
endmodule
`endif

// ===== END FILE: inst_memory.sv =====


// ===== BEGIN FILE: load_unit.sv =====
`ifndef LOAD_UNIT
`define LOAD_UNIT
////////Load Encoding/////
module load_unit(
    input  logic [31:0] i_load_data, // Data tá»« DMEM
    input  logic [2:0]  i_load_type,  // Chá»n kiá»ƒu load
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
// ===== END FILE: load_unit.sv =====


// ===== BEGIN FILE: lsu_new.sv =====
// Author: Nhu Bui
`ifndef LSU
`define LSU
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
  always_ff @(posedge i_clk) begin // ghi Ä‘á»“ng bá»™
    INPUT <= i_io_sw;
  end
  assign input_bf_tmp = i_reset ? 32'd0: INPUT; // Ä‘á»c báº¥t Ä‘á»“ng bá»™

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
  input logic [2:0] slt_sl, // chá»n store/load kiá»ƒu gÃ¬ (W H B HU BU)
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
  // Äá»‹nh nghÄ©a giÃ¡ trá»‹ SW, SB, SH, LW, LB, LH, LBU, LHU
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
// ===== END FILE: lsu_new.sv =====


// ===== BEGIN FILE: memory_cycle.sv =====
`ifndef MEMORY_CYCLE
`define MEMORY_CYCLE
module memory_cycle(
    input logic         i_clk,
    input logic         i_reset,

    // Inputs tá»« Execute giá»¯ há»™ inst
    input logic [31:0]  i_mem_inst,

    // Input tá»« Execute giÃ¡ trá»‹ Ä‘Æ°á»£c sá»­ dá»¥ng trong MEM
    input logic [31:0]  i_mem_pc,
    input logic [31:0]  i_mem_rs2_data,
    input logic         i_mem_br_equal,
    input logic         i_mem_br_less,
    input logic [31:0]  i_mem_alu_data,

    // input tá»« Execute MEM control
    input logic         i_mem_lsu_wren,
    input logic [2:0]   i_mem_slt_sl,

    // input tá»« Execute giá»¯ há»™ Writeback control
    input logic [1:0]   i_mem_wb_sel,
    input logic         i_mem_rd_wren,
    input logic         i_mem_insn_vld,
    input logic         i_mem_ctrl,

    // Input IO switch
    input logic [31:0]  i_io_sw,

    // Outputs tá»« Memory tá»›i Writeback
    output logic [31:0] o_mem_pc_add4_wb, 
    output logic [31:0] o_mem_alu_data_wb,
    output logic        o_mem_insn_vld_wb,
    output logic        o_mem_ctrl,
    output logic  [2:0] o_mem_slt_sl_wb,

    //output logic [31:0] mem_WB,  thay cÃ¡i nÃ y báº±ng 1 Ä‘á»‘ng IO
    output logic [31:0] o_mem_ld_data_wb , // Data thá»±c sá»± writeback
    output logic [31:0] o_mem_io_ledr_wb , 
    output logic [31:0] o_mem_io_ledg_wb ,
    output logic [6:0]  o_mem_io_hex0_wb , 
    output logic [6:0]  o_mem_io_hex1_wb , 
    output logic [6:0]  o_mem_io_hex2_wb ,   
    output logic [6:0]  o_mem_io_hex3_wb , 
    output logic [6:0]  o_mem_io_hex4_wb , 
    output logic [6:0]  o_mem_io_hex5_wb , 
    output logic [6:0]  o_mem_io_hex6_wb ,   
    output logic [6:0]  o_mem_io_hex7_wb , 
    output logic [31:0] o_mem_io_lcd_wb ,
    
    output logic [31:0] o_mem_inst_wb,
    output logic [31:0] o_mem_pc_debug,

    // Output tá»›i Writeback Control
    output logic [1:0]  o_mem_wb_sel_wb,
    output logic        o_mem_rd_wren_wb,

    // Output thÃªm rd á»Ÿ táº§ng Memory Ä‘á»ƒ forward  
    output logic [4:0]  o_mem_rd_addr_fwd,
    output logic         o_mem_stall_cache,
    output logic         o_mem_cache_done,
    // Debug: bubble up cache hit from LSU
    output logic         o_mem_cache_hit_debug,
    // Debug: bubble up cache miss from LSU
    output logic         o_mem_cache_miss_debug
);
    
    // Internal signals
    logic [31:0]    PC_add4_internal;

    // Pipeline registers
    logic [31:0]    pc_add4_reg;
    logic [31:0]    alu_data_reg;
    logic [31:0]    inst_reg;
    logic [2:0]     slt_sl_reg;
    logic [1:0]     wb_sel_reg;
    logic           rd_wren_reg;
    logic           insn_vld_reg;
    

    logic [31:0]   ld_data, ld_data_reg;
    logic [31:0]   io_ledr, io_ledr_reg;
    logic [31:0]   io_ledg, io_ledg_reg;
    logic [6:0]    io_hex0, io_hex0_reg; 
    logic [6:0]    io_hex1, io_hex1_reg;
    logic [6:0]    io_hex2, io_hex2_reg;
    logic [6:0]    io_hex3, io_hex3_reg;
    logic [6:0]    io_hex4, io_hex4_reg;
    logic [6:0]    io_hex5, io_hex5_reg;
    logic [6:0]    io_hex6, io_hex6_reg;
    logic [6:0]    io_hex7, io_hex7_reg;
    logic [31:0]   io_lcd,  io_lcd_reg;
    logic [31:0]   pc_debug_reg;
    logic          ctrl_reg;
    logic [6:0]    opcode_mem;
    logic          internal_stall;
    logic          mem_access;
    // Latch request info to hold through cache transaction
    logic          mem_req_active;
    logic [31:0]   latched_addr;
    logic          latched_wr_en;
    logic [31:0]   latched_wdata;

    assign opcode_mem = i_mem_inst[6:0];
    // RISC-V opcodes: LOAD=0000011, STORE=0100011
    assign mem_access = (opcode_mem == 7'b0000011) || (opcode_mem == 7'b0100011);
    assign o_mem_stall_cache = internal_stall;
    //assign internal_stall = (opcode_mem == 7'b0000011) 1'b1 : 1'b0;

    // PC + 4
    add_sub_32_bit PC_add4_at_memory (
        .A(i_mem_pc),
        .B(32'd4),
        .Sel(1'b0),
        .Result(PC_add4_internal)
    );

    // Select current vs latched request for LSU/cache
    logic [31:0] lsu_addr_mux;
    logic        lsu_wr_en_mux;
    logic [31:0] lsu_wdata_mux;

    assign lsu_addr_mux  = mem_req_active ? latched_addr  : i_mem_alu_data;
    assign lsu_wr_en_mux = mem_req_active ? latched_wr_en : i_mem_lsu_wren;
    assign lsu_wdata_mux = mem_req_active ? latched_wdata : i_mem_rs2_data;

    lsu_new lsu_memory(
        .i_clk          (i_clk),
        .i_reset        (i_reset),

        .i_lsu_wren     (lsu_wr_en_mux),
        .i_mem_access   (mem_access/*|(~internal_stall)*/),
        .i_lsu_addr     (i_mem_alu_data/*lsu_addr_mux */),
        .i_lsu_byte_offset (i_mem_alu_data[1:0]),
        .i_st_data      (lsu_wdata_mux),

        .slt_sl         (i_mem_slt_sl),

        .i_io_sw        (i_io_sw),

        .o_ld_data     (ld_data),
        .o_io_lcd      (io_lcd), 
        .o_io_ledg     (io_ledg), 
        .o_io_ledr     (io_ledr), 
        .o_io_hex0     (io_hex0), 
        .o_io_hex1     (io_hex1), 
        .o_io_hex2     (io_hex2), 
        .o_io_hex3     (io_hex3),
        .o_io_hex4     (io_hex4), 
        .o_io_hex5     (io_hex5), 
        .o_io_hex6     (io_hex6), 
        .o_io_hex7     (io_hex7),
        .o_cache_stall (internal_stall),
        .o_cache_done  (o_mem_cache_done),
        .o_cache_hit_debug (o_mem_cache_hit_debug),
        .o_cache_miss_debug (o_mem_cache_miss_debug)
        );

    // Latch request on mem_access and hold until cache finishes (internal_stall deasserts)
    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            mem_req_active <= 1'b0;
            latched_addr   <= 32'b0;
            latched_wr_en  <= 1'b0;
            latched_wdata  <= 32'b0;
        end else begin
            // Start new request
            if (!mem_req_active && mem_access) begin
                mem_req_active <= 1'b1;
                latched_addr   <= i_mem_alu_data;
                latched_wr_en  <= i_mem_lsu_wren;
                latched_wdata  <= i_mem_rs2_data;
            end
            // Clear when LSU/cache signals done (no stall)
            else if (mem_req_active && !internal_stall) begin
                mem_req_active <= 1'b0;
            end
        end
    end

    always_ff @(posedge i_clk /*or posedge i_reset*/) begin
        if (i_reset) begin
            pc_add4_reg <= 32'd0;
            alu_data_reg<= 32'd0;
            inst_reg    <= 32'd0;
            wb_sel_reg  <= 0;
            rd_wren_reg <= 0;
            ld_data_reg <= 32'b0;
            io_ledr_reg <= 32'b0;
            io_ledg_reg <= 32'b0;
            io_hex0_reg <= 7'b0;
            io_hex1_reg <= 7'b0;
            io_hex2_reg <= 7'b0;
            io_hex3_reg <= 7'b0;
            io_hex4_reg <= 7'b0;
            io_hex5_reg <= 7'b0;
            io_hex6_reg <= 7'b0;
            io_hex7_reg <= 7'b0;
            io_lcd_reg  <= 32'b0;
            insn_vld_reg<= 0;
            pc_debug_reg<= 0;
            ctrl_reg    <= 0;  

        end 
        
        else if (internal_stall) begin
            inst_reg    <= inst_reg;//i_mem_inst;
        end
        
        else /*if (!internal_stall)*/ begin
            pc_add4_reg     <= PC_add4_internal;
            alu_data_reg    <= i_mem_alu_data;
            inst_reg        <= i_mem_inst;
            wb_sel_reg      <= i_mem_wb_sel;
            rd_wren_reg     <= i_mem_rd_wren;
            slt_sl_reg      <= i_mem_slt_sl;
            ld_data_reg     <= ld_data;
            /*
            io_ledr_reg <= io_ledr;
            io_ledg_reg <= io_ledg;
            io_hex0_reg <= io_hex0;
            io_hex1_reg <= io_hex1;
            io_hex2_reg <= io_hex2;
            io_hex3_reg <= io_hex3;
            io_hex4_reg <= io_hex4;
            io_hex5_reg <= io_hex5;
            io_hex6_reg <= io_hex6;
            io_hex7_reg <= io_hex7;
            io_lcd_reg  <= io_lcd;
            */
            insn_vld_reg <= i_mem_insn_vld;
            pc_debug_reg <= i_mem_pc;
            ctrl_reg     <= i_mem_ctrl;
        end
    end

    assign o_mem_pc_add4_wb     = pc_add4_reg;
    assign o_mem_alu_data_wb    = alu_data_reg;
    assign o_mem_inst_wb        = inst_reg;
    assign o_mem_wb_sel_wb      = wb_sel_reg;
    assign o_mem_rd_wren_wb     = rd_wren_reg;
    assign o_mem_ld_data_wb     = ld_data;//_reg;
    assign o_mem_io_ledr_wb     = io_ledr;
    assign o_mem_io_ledg_wb     = io_ledg;
    assign o_mem_io_hex0_wb     = io_hex0; 
    assign o_mem_io_hex1_wb     = io_hex1;
    assign o_mem_io_hex2_wb     = io_hex2;   
    assign o_mem_io_hex3_wb     = io_hex3; 
    assign o_mem_io_hex4_wb     = io_hex4; 
    assign o_mem_io_hex5_wb     = io_hex5; 
    assign o_mem_io_hex6_wb     = io_hex6;   
    assign o_mem_io_hex7_wb     = io_hex7; 
    assign o_mem_io_lcd_wb      = io_lcd; 
    assign o_mem_rd_addr_fwd    = i_mem_inst[11:7]; // o_mem_rd_addr_fwd cho forward
    // Invalidate instruction to WB while stalled
    assign o_mem_insn_vld_wb    = internal_stall ? 1'b0 : insn_vld_reg;
    assign o_mem_pc_debug       = pc_debug_reg;
    assign o_mem_ctrl           = ctrl_reg;
    assign o_mem_slt_sl_wb      = slt_sl_reg;
endmodule
`endif
// ===== END FILE: memory_cycle.sv =====


// ===== BEGIN FILE: mux2_1.sv =====
`ifndef MUX_2_1
`define MUX_2_1
module mux_2_1 (
  input logic [31:0] data_1_i    ,
  input logic [31:0] data_0_i    ,
  input logic        sel_i       ,
  output logic [31:0] data_out_o		
  );
  
  always_comb begin
    case (sel_i)
      1'b0 : data_out_o = data_0_i;
      1'b1 : data_out_o = data_1_i;
      default: data_out_o = 32'b0;
    endcase
  end
endmodule 
`endif
// ===== END FILE: mux2_1.sv =====


// ===== BEGIN FILE: mux3_1.sv =====
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
// ===== END FILE: mux3_1.sv =====


// ===== BEGIN FILE: pc.sv =====
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
// ===== END FILE: pc.sv =====


// ===== BEGIN FILE: pipeline.sv =====
`ifndef PIPILINE
`define PIPELINE
module pipelined (
    input logic i_clk,
    input logic i_reset,

    // Input IO 
    input  logic [31:0] i_io_sw,

    // Output LED, HEX, LCD
    output logic [31:0] o_io_ledr, 
    output logic [31:0] o_io_ledg,
    output logic [6:0]  o_io_hex0, 
    output logic [6:0]  o_io_hex1, 
    output logic [6:0]  o_io_hex2,   
    output logic [6:0]  o_io_hex3, 
    output logic [6:0]  o_io_hex4, 
    output logic [6:0]  o_io_hex5, 
    output logic [6:0]  o_io_hex6,   
    output logic [6:0]  o_io_hex7, 
    output logic [31:0] o_io_lcd,

    // Output debug signals
    output logic        o_insn_vld,
    output logic [31:0] o_pc_debug,
    output logic        o_ctrl,
    output logic        o_mispred,
    // Debug: cache hit propagated from cache -> LSU -> MEM -> top
    output logic        o_cache_hit_debug,
    // Debug: cache miss propagated from cache -> LSU -> MEM -> top
    output logic        o_cache_miss_debug
);
logic Stall;
logic flush;
logic        o_cache_done;
//Input fetch for jump
logic           pc_sel;
logic [31:0]    o_mem_alu_data;

//Output fetch -> Input decode
logic [31:0]    pc_decode;
logic [31:0]    inst_decode;
logic           insn_vld_decode;

//Output writeback -> Input decode
logic [31:0]    rd_data_decode;
logic [4:0]     rd_addr_decode;
logic           rd_wren_decode;

//Output decode -> input execute
logic [31:0]    inst_execute;
logic [31:0]    pc_execute;
logic           asel_execute;
logic           bsel_execute;
logic [31:0]    rs1_data_execute;
logic [31:0]    rs2_data_execute;
logic [31:0]    imm_out_execute;
logic [3:0]     alu_op_execute;
logic           br_un_execute;
logic           lsu_wren_execute;
logic [2:0]     slt_sl_execute;
logic [1:0]     wb_sel_execute;
logic           rd_wren_execute;
logic           insn_vld_execute;
logic           ctrl_execute;

//Ouput execute -> input memory
logic           br_equal_mem;
logic           br_less_mem;
logic [31:0]    alu_data_mem;
logic [31:0]    pc_mem;
logic [31:0]    rs2_data_mem;
logic [31:0]    inst_mem;
logic           lsu_wren_mem;
logic [2:0]     slt_sl_mem;
logic [1:0]     wb_sel_mem;
logic           rd_wren_mem;
logic           insn_vld_mem;
logic           ctrl_mem;
           

//Outpit memory -> input Writeback
logic [31:0]    pc_add4_wb;
logic [31:0]    alu_data_wb;
logic [31:0]    inst_wb;
logic [1:0]     wb_sel_wb;
logic           rd_wren_wb;
logic [31:0]    ld_data_wb;
logic [31:0]    pc_debug_wb;
logic [2:0]     slt_sl_wb;

//Fix load hazard
logic [4:0]     rs1_addr_decode;
logic [4:0]     rs2_addr_decode;
logic [4:0]     rd_addr_mem;
logic [4:0]     rd_addr_wb;
logic [1:0]     fwd_operand_a;
logic [1:0]     fwd_operand_b;
logic [1:0]     fwd_rs2;
logic [1:0]     fwd_brc_a;
logic [1:0]     fwd_brc_b;
logic X;
logic [31:0] o_execute_alu_data_decode;
logic ctrl_wb;
logic stall_cache;
logic cache_hit_debug;
logic cache_miss_debug;
    fetch_cycle fetch_top(
        .i_fetch_clk        (i_clk),
        .i_fetch_reset      (i_reset),

        .i_fetch_pc_sel     (pc_sel),
        .i_fetch_alu_data   (alu_data_mem /*o_mem_alu_data*/),
        .i_stall            (Stall),
        .i_flush            (flush),
        .i_fetch_stall_cache (stall_cache),

        .o_fetch_inst_id    (inst_decode),
        .o_fetch_pc_id      (pc_decode),
        .o_fetch_insn_vld_id(insn_vld_decode)
    );

    decode_cycle decoce_top(
        .i_decode_clk           (i_clk),
        .i_decode_reset         (i_reset),
        
        .i_decode_inst          (inst_decode),
        .i_decode_pc            (pc_decode),

        .i_decode_rd_addr       (rd_addr_decode),
        .i_decode_rd_data       (rd_data_decode),
        .i_decode_rd_wren       (rd_wren_decode),

        .i_decode_flush         (flush),
        .i_decode_stall         (Stall),
        .i_decode_stall_cache   (stall_cache),
        .i_decode_insn_vld      (insn_vld_decode),

        .i_decode_alu_data_execute (o_execute_alu_data_decode),

        .o_decode_inst_ex       (inst_execute),
        .o_decode_pc_ex         (pc_execute),
        .o_decode_ctrl          (ctrl_execute),

        .o_decode_asel_ex       (asel_execute),
        .o_decode_bsel_ex       (bsel_execute),
        .o_decode_rs1_data_ex   (rs1_data_execute),
        .o_decode_rs2_data_ex   (rs2_data_execute),
        .o_decode_imm_out_ex    (imm_out_execute),
        .o_decode_alu_op_ex     (alu_op_execute),
        .o_decode_br_un_ex      (br_un_execute),

        .o_decode_lsu_wren_ex   (lsu_wren_execute),
        .o_decode_slt_sl_ex     (slt_sl_execute),
        .o_decode_wb_sel_ex     (wb_sel_execute),
        .o_decode_rd_wren_ex    (rd_wren_execute),
        .o_insn_vld_ctrl        (insn_vld_execute),
        .o_decode_rs1_addr_hazard(rs1_addr_decode),
        .o_decode_rs2_addr_hazard(rs2_addr_decode)
        
    );

    execute_cycle execute_top(
        .i_execute_clk           (i_clk),
        .i_execute_reset         (i_reset),

        .i_execute_pc           (pc_execute),
        .i_execute_inst         (inst_execute),
        .i_execute_ctrl         (ctrl_execute),

        .i_execute_lsu_wren     (lsu_wren_execute),
        .i_execute_slt_sl       (slt_sl_execute),
        
        .i_execute_wb_sel       (wb_sel_execute),
        .i_execute_rd_wren      (rd_wren_execute),

        .i_execute_asel         (asel_execute),
        .i_execute_bsel         (bsel_execute),
        .i_execute_rs1_data     (rs1_data_execute),
        .i_execute_rs2_data     (rs2_data_execute),
        .i_execute_imm_out      (imm_out_execute),
        .i_execute_alu_op       (alu_op_execute),
        .i_execute_br_un        (br_un_execute),    
        .i_execute_insn_vld     (insn_vld_execute),

        .flush                  (flush),
        //.i_stall                (Stall),
        .i_execute_cache_done (o_cache_done),
        .i_execute_stall_cache  (stall_cache),

        .i_execute_fwd_operand_a(fwd_operand_a),
        .i_execute_fwd_operand_b(fwd_operand_b),
        
        .i_execute_fwd_alu_data (alu_data_mem),
        .i_execute_fwd_wb_data  (rd_data_decode),

        .o_execute_br_equal_mem (br_equal_mem),
        .o_execute_br_less_mem  (br_less_mem),
        .o_execute_alu_data     (alu_data_mem),

        .o_execute_pc_mem       (pc_mem),
        .o_execute_rs2_data_mem (rs2_data_mem),
        .o_execute_inst_mem     (inst_mem),
        .o_execute_insn_vld_mem (insn_vld_mem),
        .o_execute_ctrl         (ctrl_mem),

        .o_execute_lsu_wren_mem (lsu_wren_mem),
        .o_execute_slt_sl_mem   (slt_sl_mem),
        
        .o_execute_wb_sel_mem   (wb_sel_mem),
        .o_execute_rd_wren_mem  (rd_wren_mem),

        .o_execute_inst_fwd     (),

        .o_execute_alu_data_decode (o_execute_alu_data_decode)
    );

    memory_cycle memory_top(
        .i_clk                  (i_clk),
        .i_reset                (i_reset),      

        .i_mem_inst             (inst_mem),

        .i_mem_pc               (pc_mem),
        .i_mem_rs2_data         (rs2_data_mem),
        .i_mem_br_equal         (br_equal_mem),
        .i_mem_br_less          (br_less_mem),
        .i_mem_alu_data         (alu_data_mem),

        .i_mem_lsu_wren         (lsu_wren_mem),
        .i_mem_slt_sl           (slt_sl_mem),
        .i_mem_insn_vld         (insn_vld_mem),
        .i_mem_ctrl             (ctrl_mem),

        .i_mem_wb_sel           (wb_sel_mem),
        .i_mem_rd_wren          (rd_wren_mem),

        .i_io_sw                (i_io_sw),

        .o_mem_pc_add4_wb       (pc_add4_wb),
        .o_mem_alu_data_wb      (alu_data_wb),
        .o_mem_insn_vld_wb      (insn_vld_wb),

        .o_mem_ld_data_wb       (ld_data_wb),
        .o_mem_io_ledr_wb       (o_io_ledr),
        .o_mem_io_ledg_wb       (o_io_ledg),
        .o_mem_io_hex0_wb       (o_io_hex0),
        .o_mem_io_hex1_wb       (o_io_hex1),
        .o_mem_io_hex2_wb       (o_io_hex2),
        .o_mem_io_hex3_wb       (o_io_hex3),
        .o_mem_io_hex4_wb       (o_io_hex4),
        .o_mem_io_hex5_wb       (o_io_hex5),
        .o_mem_io_hex6_wb       (o_io_hex6),
        .o_mem_io_hex7_wb       (o_io_hex7),
        .o_mem_io_lcd_wb        (o_io_lcd),

        .o_mem_inst_wb          (inst_wb),

        .o_mem_wb_sel_wb        (wb_sel_wb),
        .o_mem_rd_wren_wb       (rd_wren_wb),

        .o_mem_rd_addr_fwd      (rd_addr_mem),
        .o_mem_pc_debug         (pc_debug_wb),
        .o_mem_ctrl             (ctrl_wb),
        .o_mem_stall_cache       (stall_cache),
        .o_mem_cache_done        (o_cache_done),
        .o_mem_cache_hit_debug   (cache_hit_debug),
        .o_mem_cache_miss_debug  (cache_miss_debug),
        .o_mem_slt_sl_wb          (slt_sl_wb)
    );

    writeback_cycle writeback_top(
        .i_wb_inst          (inst_wb),

        .i_wb_pc_add4       (pc_add4_wb),
        .i_wb_alu_data      (alu_data_wb),
        
        .i_wb_ld_data       (ld_data_wb),

        .i_wb_wb_sel        (wb_sel_wb),
        .i_wb_rd_wren       (rd_wren_wb),
        .i_wb_slt_sl        (slt_sl_wb),

        .o_wb_data_wb       (rd_data_decode),
        .o_wb_rd_addr       (rd_addr_decode),
        .o_wb_rd_wren       (rd_wren_decode),

        .o_wb_rd_data_fwd   (rd_addr_wb),
        .o_wb_ctrl          (X)
    );
    //assign Stall = 0; // temporary disable hazard detection
    hazard_detection hazard_load_top(
        .i_hazard_inst_execute      (inst_execute),
        .i_hazard_rs1_addr_decode   (rs1_addr_decode),
        .i_hazard_rs2_addr_decode   (rs2_addr_decode),
        .i_hazard_wb_sel_execute    (wb_sel_execute),
        .i_hazard_rd_wren_execute   (rd_wren_execute),
        .i_hazard_inst_decode       (inst_decode),
        .Stall                      (Stall)
    );

    branch_taken branch_taken_top(
        .i_br_less_mem              (br_less_mem),
        .i_br_equal_mem             (br_equal_mem),
        .i_inst_mem                 (inst_mem),
        .o_pc_sel                   (pc_sel),
        .flush                      (flush)
    );

    forward forward_top(
        .i_fwd_inst_execute         (inst_execute),
        .i_fwd_rd_addr_at_mem       (rd_addr_mem),
        .i_fwd_rd_addr_at_wb        (rd_addr_wb),
        .i_fwd_rd_wren_at_mem       (rd_wren_mem),
        .i_fwd_rd_wren_at_wb        (rd_wren_wb),
        .o_fwd_operand_a_execute    (fwd_operand_a),
        .o_fwd_operand_b_execute    (fwd_operand_b)
  
    );

    always_ff @ (negedge i_clk) begin
        //$display(" INST_WB = %h, PC_DEBUG = %h, load_data = %h, data_writeback = %h, stall = %h",inst_wb, o_pc_debug, ld_data_wb, rd_data_decode, Stall);
       if (insn_vld_wb)
       $display("INST_WB = %h, PC_DEBUG = %h, INSN_VLD = %h, RD_WREN = %h, RD_ADDR = %h, WB_DATA = %h, time = %d", inst_wb, o_pc_debug, insn_vld_wb, rd_wren_decode,rd_addr_decode, rd_data_decode, $time);
    end
    
    always_ff @ (posedge i_clk) begin
            o_mispred  <= flush;
    end
           
    assign o_insn_vld = insn_vld_wb;
    assign o_pc_debug = (o_insn_vld) ? pc_debug_wb : 32'b0;
    assign o_ctrl = ctrl_wb;
    assign o_cache_hit_debug = cache_hit_debug;
    assign o_cache_miss_debug = cache_miss_debug;
endmodule
`endif
// ===== END FILE: pipeline.sv =====


// ===== BEGIN FILE: Pipeline_Tb.sv =====
`ifndef PIPELINE_TB
`define PIPELINE_TB
`timescale 1ps/1ps

module Pipeline_Cache_Tb ();
    logic tb_clk;
    logic tb_reset;
    logic [31:0] tb_io_sw;
    pipelined pipeline_cache_test (
        .i_clk(tb_clk),
        .i_reset(tb_reset),
        .i_io_sw(tb_io_sw)
    );
   // Clock generation
    always #5 tb_clk = ~tb_clk;
	
    initial begin
        $dumpfile("wave.vcd");      // file VCD sáº½ sinh ra
        $dumpvars(0, Pipeline_Cache_Tb); //tÃªn module testbench top-level
        tb_clk = 0;
        tb_reset = 1;    // Reset Ä‘á»ƒ PC = 0
        #7ps;
        force  tb_reset = 0; 
        force  tb_io_sw = 32'ha;
        #100000ps;
        $finish;  
    end

endmodule

`endif
// ===== END FILE: Pipeline_Tb.sv =====


// ===== BEGIN FILE: regfile.sv =====
`ifndef REGFILE
`define REGFILE
module regfile (
  input  logic        i_clk,
  input  logic        i_reset,

  input  logic [4:0]  i_rs1_addr, 
  input  logic [4:0]  i_rs2_addr,

  input  logic [4:0]  i_rd_addr,
  input  logic [31:0] i_rd_data,
  input  logic        i_rd_wren,

  output logic [31:0] o_rs1_data, 
  output logic [31:0] o_rs2_data
);

  logic [31:0] Reg [31:0];

  // --- RESET + WRITE LOGIC ---
  always_ff @(posedge i_clk) begin : RESET_and_WRITE
      if (i_reset) begin
        // Reset táº¥t cáº£ 32 thanh ghi vá» 0
        for (int i = 0; i < 32; i++) begin
          Reg[i] <= 32'h0;
        end 
      end
      else begin end
        // Chá»‰ ghi náº¿u cÃ³ enable vÃ  khÃ´ng ghi vÃ o x0 (r0)
      if (i_rd_wren && (i_rd_addr != 5'd0))begin
          Reg[i_rd_addr] <= i_rd_data;
      end
      else begin end
    end
  
    always_comb begin : READ
      if ((i_rs1_addr == 5'd0))begin
        o_rs1_data = 32'b0;
      end
      else if ((i_rs1_addr == i_rd_addr) && (i_rd_wren == 1'b1)) begin
        o_rs1_data = i_rd_data;
      end
      else begin
        o_rs1_data = Reg[i_rs1_addr];
      end

      // rs2
      if ((i_rs2_addr == 5'd0))begin
        o_rs2_data = 32'b0;
      end
      else if ((i_rs2_addr == i_rd_addr)&&(i_rd_wren == 1'b1)) begin
        o_rs2_data = i_rd_data;
      end
      else begin
        o_rs2_data = Reg[i_rs2_addr];
      end
    end
  
endmodule
`endif
// ===== END FILE: regfile.sv =====


// ===== BEGIN FILE: shift_left_logical.sv =====
`ifndef SHIFT_LEFT_LOGICAL
`define SHIFT_LEFT_LOGICAL
module shift_left_logical (
    input  logic [31:0] data_in,   // Data
    input  logic [4:0]  shift_amt, // Sá»‘ bit cáº§n dá»‹ch
    output logic [31:0] data_out);   // Káº¿t quáº£


    always_comb begin
        case (shift_amt)
            5'd0:  data_out = data_in;
            5'd1:  data_out = {data_in[30:0], 1'b0};
            5'd2:  data_out = {data_in[29:0], 2'b0};
            5'd3:  data_out = {data_in[28:0], 3'b0};
            5'd4:  data_out = {data_in[27:0], 4'b0};
            5'd5:  data_out = {data_in[26:0], 5'b0};
            5'd6:  data_out = {data_in[25:0], 6'b0};
            5'd7:  data_out = {data_in[24:0], 7'b0};
            5'd8:  data_out = {data_in[23:0], 8'b0};
            5'd9:  data_out = {data_in[22:0], 9'b0};
            5'd10: data_out = {data_in[21:0], 10'b0};
            5'd11: data_out = {data_in[20:0], 11'b0};
            5'd12: data_out = {data_in[19:0], 12'b0};
            5'd13: data_out = {data_in[18:0], 13'b0};
            5'd14: data_out = {data_in[17:0], 14'b0};
            5'd15: data_out = {data_in[16:0], 15'b0};
            5'd16: data_out = {data_in[15:0], 16'b0};
            5'd17: data_out = {data_in[14:0], 17'b0};
            5'd18: data_out = {data_in[13:0], 18'b0};
            5'd19: data_out = {data_in[12:0], 19'b0};
            5'd20: data_out = {data_in[11:0], 20'b0};
            5'd21: data_out = {data_in[10:0], 21'b0};
            5'd22: data_out = {data_in[9:0], 22'b0};
            5'd23: data_out = {data_in[8:0], 23'b0};
            5'd24: data_out = {data_in[7:0], 24'b0};
            5'd25: data_out = {data_in[6:0], 25'b0};
            5'd26: data_out = {data_in[5:0], 26'b0};
            5'd27: data_out = {data_in[4:0], 27'b0};
            5'd28: data_out = {data_in[3:0], 28'b0};
            5'd29: data_out = {data_in[2:0], 29'b0};
            5'd30: data_out = {data_in[1:0], 30'b0};
            5'd31: data_out = {data_in[0], 31'b0};
            default: data_out = 32'bz;
        endcase
    end

endmodule
`endif
// ===== END FILE: shift_left_logical.sv =====


// ===== BEGIN FILE: shift_right_arithmetic.sv =====
`ifndef SHIFT_RIGHT_ARITHMETIC
`define SHIFT_RIGHT_ARITHMETIC

module shift_right_arithmetic (
    input  logic [31:0] data_in, // Data
    input  logic [4:0] shift_amt, // Sá»‘ bit cáº§n dá»‹ch
    output logic [31:0] data_out); //Káº¿t quáº£

    always_comb begin
        case (shift_amt)
            5'd0:  data_out = data_in;
            5'd1:  data_out = {data_in[31], data_in[31:1]};
            5'd2:  data_out = {{2{data_in[31]}}, data_in[31:2]};
            5'd3:  data_out = {{3{data_in[31]}}, data_in[31:3]};
            5'd4:  data_out = {{4{data_in[31]}}, data_in[31:4]};
            5'd5:  data_out = {{5{data_in[31]}}, data_in[31:5]};
            5'd6:  data_out = {{6{data_in[31]}}, data_in[31:6]};
            5'd7:  data_out = {{7{data_in[31]}}, data_in[31:7]};
            5'd8:  data_out = {{8{data_in[31]}}, data_in[31:8]};
            5'd9:  data_out = {{9{data_in[31]}}, data_in[31:9]};
            5'd10: data_out = {{10{data_in[31]}}, data_in[31:10]};
            5'd11: data_out = {{11{data_in[31]}}, data_in[31:11]};
            5'd12: data_out = {{12{data_in[31]}}, data_in[31:12]};
            5'd13: data_out = {{13{data_in[31]}}, data_in[31:13]};
            5'd14: data_out = {{14{data_in[31]}}, data_in[31:14]};
            5'd15: data_out = {{15{data_in[31]}}, data_in[31:15]};
            5'd16: data_out = {{16{data_in[31]}}, data_in[31:16]};
            5'd17: data_out = {{17{data_in[31]}}, data_in[31:17]};
            5'd18: data_out = {{18{data_in[31]}}, data_in[31:18]};
            5'd19: data_out = {{19{data_in[31]}}, data_in[31:19]};
            5'd20: data_out = {{20{data_in[31]}}, data_in[31:20]};
            5'd21: data_out = {{21{data_in[31]}}, data_in[31:21]};
            5'd22: data_out = {{22{data_in[31]}}, data_in[31:22]};
            5'd23: data_out = {{23{data_in[31]}}, data_in[31:23]};
            5'd24: data_out = {{24{data_in[31]}}, data_in[31:24]};
            5'd25: data_out = {{25{data_in[31]}}, data_in[31:25]};
            5'd26: data_out = {{26{data_in[31]}}, data_in[31:26]};
            5'd27: data_out = {{27{data_in[31]}}, data_in[31:27]};
            5'd28: data_out = {{28{data_in[31]}}, data_in[31:28]};
            5'd29: data_out = {{29{data_in[31]}}, data_in[31:29]};
            5'd30: data_out = {{30{data_in[31]}}, data_in[31:30]};
            5'd31: data_out = {{31{data_in[31]}}, data_in[31]};
            default: data_out = 32'bz;
        endcase
    end
endmodule
	
`endif 
// ===== END FILE: shift_right_arithmetic.sv =====


// ===== BEGIN FILE: shift_right_logical.sv =====
`ifndef SHIFT_RIGHT_LOGICAL
`define SHIFT_RIGHT_LOGICAL

module shift_right_logical (
    input  logic [31:0] data_in,   // Data
    input  logic [4:0]  shift_amt, // Sá»‘ bit cáº§n dá»‹ch
    output logic [31:0] data_out);   // Káº¿t quáº£ 


    always_comb begin
        case (shift_amt)
            5'd0:  data_out = data_in;
            5'd1:  data_out = {1'b0, data_in[31:1]};
            5'd2:  data_out = {2'b0, data_in[31:2]};
            5'd3:  data_out = {3'b0, data_in[31:3]};
            5'd4:  data_out = {4'b0, data_in[31:4]};
            5'd5:  data_out = {5'b0, data_in[31:5]};
            5'd6:  data_out = {6'b0, data_in[31:6]};
            5'd7:  data_out = {7'b0, data_in[31:7]};
            5'd8:  data_out = {8'b0, data_in[31:8]};
            5'd9:  data_out = {9'b0, data_in[31:9]};
            5'd10: data_out = {10'b0, data_in[31:10]};
            5'd11: data_out = {11'b0, data_in[31:11]};
            5'd12: data_out = {12'b0, data_in[31:12]};
            5'd13: data_out = {13'b0, data_in[31:13]};
            5'd14: data_out = {14'b0, data_in[31:14]};
            5'd15: data_out = {15'b0, data_in[31:15]};
            5'd16: data_out = {16'b0, data_in[31:16]};
            5'd17: data_out = {17'b0, data_in[31:17]};
            5'd18: data_out = {18'b0, data_in[31:18]};
            5'd19: data_out = {19'b0, data_in[31:19]};
            5'd20: data_out = {20'b0, data_in[31:20]};
            5'd21: data_out = {21'b0, data_in[31:21]};
            5'd22: data_out = {22'b0, data_in[31:22]};
            5'd23: data_out = {23'b0, data_in[31:23]};
            5'd24: data_out = {24'b0, data_in[31:24]};
            5'd25: data_out = {25'b0, data_in[31:25]};
            5'd26: data_out = {26'b0, data_in[31:26]};
            5'd27: data_out = {27'b0, data_in[31:27]};
            5'd28: data_out = {28'b0, data_in[31:28]};
            5'd29: data_out = {29'b0, data_in[31:29]};
            5'd30: data_out = {30'b0, data_in[31:30]};
            5'd31: data_out = {31'b0, data_in[31]};
            default: data_out = 32'bz;
        endcase
    end

endmodule
`endif 
// ===== END FILE: shift_right_logical.sv =====


// ===== BEGIN FILE: slt_sltu.sv =====
// Author: Nhan Ma C
`ifndef SLT_SLTU
`define SLT_SLTU 
module slt_sltu (
    input  logic [31:0] A, B,  // Input A, B
    input  logic Sel,          // 0 = SLT (cÃ³ dáº¥u), 1 = SLTU (khÃ´ng dáº¥u)
    output logic [31:0] Result); // Káº¿t quáº£

    logic [31:0] diff_out;  // Káº¿t quáº£ phÃ©p trá»« A - B
    logic carry_out;        // Carry/Borrow tá»« phÃ©p trá»«

    add_sub_32_bit SUB(
        .A(A),
        .B(B), 
        .Sel(1'b1), 
        .Result(diff_out),
        .Cout(carry_out)
    );

    // So sÃ¡nh
    always_comb begin
        if (Sel == 1'b0) begin  // SLT (cÃ³ dáº¥u)
            // Náº¿u khÃ¡c dáº¥u: A<0 && B>=0 â†’ 1; B<0 && A>=0 â†’ 0
            // Náº¿u cÃ¹ng dáº¥u: dÃ¹ng bit dáº¥u cá»§a (A - B)
            if (A[31] != B[31])
                Result = {31'b0, A[31]};
            else
                Result = {31'b0, diff_out[31]};
        end 
        else begin  // SLTU (khÃ´ng dáº¥u)
            Result = {31'b0, ~carry_out}; // carry_out=1 nghÄ©a lÃ  A>=B
        end
    end

endmodule
`endif 
// ===== END FILE: slt_sltu.sv =====


// ===== BEGIN FILE: sram.sv =====
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
// ===== END FILE: sram.sv =====


// ===== BEGIN FILE: writeback_cycle.sv =====
`ifndef WRITEBACK_CYCLE
`define WRITEBACK_CYCLE


module writeback_cycle(
    //input logic         i_clk,
    //input logic         i_reset,

    //Input instruction
    input logic [31:0]  i_wb_inst,

    //Input tá»« Execute data writeback
    input logic [31:0]  i_wb_pc_add4,
    input logic [31:0]  i_wb_alu_data,
       
    input logic [31:0]  i_wb_ld_data,   
    /*Input from Execute LSU dataa
    input logic [31:0]  i_wb_ld_data,
    input logic [31:0]  i_wb_io_ledr, 
    input logic [31:0]  i_wb_io_ledg,
    input logic [6:0]   i_wb_io_hex0, 
    input logic [6:0]   i_wb_io_hex1, 
    input logic [6:0]   i_wb_io_hex2,   
    input logic [6:0]   i_wb_io_hex3, 
    input logic [6:0]   i_wb_io_hex4, 
    input logic [6:0]   i_wb_io_hex5, 
    input logic [6:0]   i_wb_io_hex6,   
    input logic [6:0]   i_wb_io_hex7, 
    input logic [31:0]  i_wb_io_lcd,
    */

    //Input control signals
    input logic [1:0]   i_wb_wb_sel,
    input logic         i_wb_rd_wren,
    input logic  [2:0]  i_wb_slt_sl,
    //Output data writeback
    output logic [31:0] o_wb_data_wb,
    output logic [4:0]  o_wb_rd_addr,
    output logic        o_wb_rd_wren,
    //Output for forwarding
    output logic [4:0]  o_wb_rd_data_fwd,

    output logic        o_wb_ctrl
);
    localparam BR =   7'b110_0011; //0x63
    localparam JALR = 7'b110_0111; //0x67
    localparam JAL =  7'b110_1111; //0x37
    logic [6:0] opcode_wb;
    logic [31:0] ld_data_transfer;

    data_transfer data_transfer_wb (
        .i_ld_data     (i_wb_ld_data),
        .i_load_type   (i_wb_slt_sl),
        .i_byte_offset (i_wb_alu_data[1:0]),
        .o_ld_result   (ld_data_transfer)
    );

    mux_3_1 mux_3_1_at_writeback (
        .data_0_i      (ld_data_transfer), 
        .data_1_i      (i_wb_alu_data), 
        .data_2_i      (i_wb_pc_add4), 
        .sel_i         (i_wb_wb_sel  ), 
        .data_out_o    (o_wb_data_wb)
    );
    assign o_wb_rd_addr = i_wb_inst[11:7];
    assign o_wb_rd_wren = i_wb_rd_wren;
    assign o_wb_rd_data_fwd = i_wb_inst[11:7];
    assign opcode_wb = i_wb_inst[6:0];
    //assign o_wb_data_wb = (i_wb_inst == 32'h00000013 ) ? data_wb: 32'b0;
    always_comb begin
        if ((opcode_wb == BR)||(opcode_wb == JAL) || (opcode_wb == JALR)) o_wb_ctrl = 1'b1;
        else o_wb_ctrl = 1'b0;
    end

endmodule
`endif
// ===== END FILE: writeback_cycle.sv =====

