module btb (
    input  wire         clk,
    input  wire         rst,
    input  wire [11:0]  btb_fetch_pc,         //pc[13:2] 12bits
    input  wire [11:0]  btb_wr_pc,
    input  wire [ 7:0]  btb_tag_buf,    //1 cycle after btb_pc
    input  wire         btb_we,
    input  wire [43:0]  btb_wdata,
    output wire         btb_hit,
    output wire [31:0]  btb_target,
    output wire [ 2:0]  btb_type
);
    reg         rr_reg; //Round robin, determine which bank to write
    wire [11:0] btb_pc = btb_we ? btb_wr_pc : btb_fetch_pc;
    wire [ 5:0] bank0_index = btb_pc[5:0];
    wire [ 5:0] bank1_index = btb_pc[5:0] ^ btb_pc[11:6];
    wire        bank0_we = btb_we & ~rr_reg;
    wire        bank1_we = btb_we & rr_reg;
    wire [43:0] bank0_rdata, bank1_rdata;
    wire [31:0] bank0_target, bank1_target;
    wire [ 7:0] bank0_tag, bank1_tag;
    wire [ 2:0] bank0_type, bank1_type;
    wire        bank0_valid, bank1_valid;
    assign {bank0_tag, bank0_target, bank0_type, bank0_valid} = bank0_rdata;
    assign {bank1_tag, bank1_target, bank1_type, bank1_valid} = bank1_rdata;
    wire bank0_hit = {bank0_tag, bank0_valid} == {btb_tag_buf, 1'b1};
    wire bank1_hit = {bank1_tag, bank1_valid} == {btb_tag_buf, 1'b1};
    assign btb_hit = bank0_hit | bank1_hit;
    assign btb_target = bank0_hit ? bank0_target : bank1_target;
    assign btb_type   = bank0_hit ? bank0_type : bank1_type;

    always @(posedge clk)
        if (rst)
            rr_reg <= 1'b0;
        else if (btb_we)
            rr_reg <= ~rr_reg;

    btb_bank btb_bank0 (
        .wr_data    (btb_wdata      ),    // input [43:0]
        .addr       (bank0_index    ),    // input [5:0]
        .wr_en      (bank0_we       ),    // input
        .clk        (clk            ),    // input
        .rst        (rst            ),    // input
        .rd_data    (bank0_rdata    )     // output [43:0]
    );
    btb_bank btb_bank1 (
        .wr_data    (btb_wdata      ),    // input [43:0]
        .addr       (bank1_index    ),    // input [5:0]
        .wr_en      (bank1_we       ),    // input
        .clk        (clk            ),    // input
        .rst        (rst            ),    // input
        .rd_data    (bank1_rdata    )     // output [43:0]
    );
endmodule