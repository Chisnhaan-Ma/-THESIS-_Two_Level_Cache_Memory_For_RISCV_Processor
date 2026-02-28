`ifndef SHIFT_LEFT_LOGICAL
`define SHIFT_LEFT_LOGICAL
module shift_left_logical (
    input  logic [31:0] data_in,   // Data
    input  logic [4:0]  shift_amt, // Số bit cần dịch
    output logic [31:0] data_out);   // Kết quả


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