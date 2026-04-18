module regfile (
    input  wire         clk,
    input  wire         rst,
    input  wire [4:0]   rd_addr1,
    input  wire [4:0]   rd_addr2,
    output wire [31:0]  rd_data1,
    output wire [31:0]  rd_data2,
    input  wire         wr_en,
    input  wire [4:0]   wr_addr,
    input  wire [31:0]  wr_data
);
    reg [31:0] reg_file [31:0];

    assign rd_data1 = (rd_addr1 == 5'b0) ? 32'b0 : reg_file[rd_addr1];
    assign rd_data2 = (rd_addr2 == 5'b0) ? 32'b0 : reg_file[rd_addr2];

    always @(posedge clk) begin
        if (wr_en && (wr_addr != 5'b0)) begin
            reg_file[wr_addr] <= wr_data;
        end
    end
endmodule