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
