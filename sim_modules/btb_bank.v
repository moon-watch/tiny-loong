module btb_bank #(
    parameter INDEX_WIDTH = 6,
    parameter DATA_WIDTH = 44
) (
    input  wire [DATA_WIDTH - 1:0]  wr_data,
    input  wire [INDEX_WIDTH - 1:0]  addr,
    input  wire         wr_en,
    input  wire         clk,
    input  wire         rst,
    output wire [DATA_WIDTH - 1:0]  rd_data
);
    reg  [DATA_WIDTH - 1:0] data_bank [2 ** INDEX_WIDTH - 1:0];
    reg  [DATA_WIDTH - 1:0] data_phase;
    assign      rd_data = data_phase;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            data_phase <= {DATA_WIDTH{1'b0}};
            for (i = 0; i < (2 ** INDEX_WIDTH); i = i + 1)
                data_bank[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            data_phase <= data_bank[addr];
            if (wr_en)
                data_bank[addr] <= wr_data;
        end
    end
endmodule