module data_bank_ram(
    input  wire [ 7:0]  addr,
    input  wire [31:0]  wr_data,
    output wire [31:0]  rd_data,
    input  wire         wr_en,
    input  wire         clk,
    input  wire [ 3:0]  wr_byte_en,
    input  wire         rst
);
    reg  [31:0] data_bank [255:0];
    reg  [31:0] data_phase;
    assign      rd_data = data_phase;
    wire [31:0] wr_mask = {{8{wr_byte_en[3]}}, {8{wr_byte_en[2]}},
                           {8{wr_byte_en[1]}}, {8{wr_byte_en[0]}}};
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            data_phase <= 'b0;
            for (i = 0; i < 256; i = i + 1)
                data_bank[i] <= 32'b0;
        end else begin
            data_phase <= data_bank[addr];
            if (wr_en)
                data_bank[addr] <= (wr_mask & wr_data)
                                 | (~wr_mask & data_bank[addr]);
        end
    end
endmodule