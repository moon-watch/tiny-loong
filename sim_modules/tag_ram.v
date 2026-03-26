module tag_ram(
    input  wire [19:0]  wr_data,    // input [19:0]
    input  wire [ 7:0]  addr,       // input [7:0]
    input  wire         wr_en,      // input
    input  wire         clk,        // input
    input  wire         rst,        // input
    output wire [19:0]  rd_data     // output [19:0]
);
    reg  [19:0] data_bank [255:0];
    reg  [19:0] data_phase;
    assign      rd_data = data_phase;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            data_phase <= 'b0;
            for (i = 0; i < 256; i = i + 1)
                data_bank[i] <= 20'b0;
        end else begin
            data_phase <= data_bank[addr];
            if (wr_en)
                data_bank[addr] <= wr_data;
        end
    end
endmodule
