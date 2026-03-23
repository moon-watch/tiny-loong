//Pattern History Table
module pht (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] pht0_idx,
    output wire       pht0_taken,
    input  wire [7:0] pht1_idx,
    input  wire       pht1_we,
    input  wire       pht1_taken
);
    reg [ 1:0] sat_cnt[255:0];
    reg [31:0] bias_bit;
    // assign pht0_taken = (sat_cnt[pht0_idx] == 2'b11) || ((sat_cnt[pht0_idx] == 2'b10) && bias_bit[pht0_idx[7:3]]);
    assign pht0_taken = sat_cnt[pht0_idx][1];
    reg [ 1:0] cnt_next;
    always @(*) begin
        case ({pht1_taken, sat_cnt[pht1_idx]})
            3'b1_11: cnt_next = 2'b11;
            3'b1_10: cnt_next = 2'b11;
            3'b1_01: cnt_next = 2'b10;
            3'b1_00: cnt_next = 2'b01;
            3'b0_11: cnt_next = 2'b10;
            3'b0_10: cnt_next = 2'b01;
            3'b0_01: cnt_next = 2'b00;
            3'b0_00: cnt_next = 2'b00;
        endcase
    end
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 256; i = i + 1)
                sat_cnt[i] <= 2'b10;
            bias_bit <= 32'h0;
        end else begin
            if (pht1_we) begin
                sat_cnt[pht1_idx] <= cnt_next;
                if (sat_cnt[pht1_idx] == 2'b10 || sat_cnt[pht1_idx] == 2'b01)
                    bias_bit[pht1_idx[7:3]] <= pht1_taken;
            end
        end
    end
endmodule