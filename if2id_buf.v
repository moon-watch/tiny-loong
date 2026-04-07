module if2id_buf (
    input  wire clk,
    input  wire rst,
    input  wire ex_flush,
    input  wire ertn_flush,
    input  wire pred_flush,
    input  wire if_ready_go,
    output wire id_buf_allowin,
    input  wire [`IF_BUS_W - 1:0] if2id_buf_bus,
    output wire if_buf_ready_go,
    input  wire id_allowin,
    output wire [`IF_BUS_W - 1:0] if2id_bus
);
    reg  [ 1:0] slot_valid;
    reg  [`IF_BUS_W - 1:0] slot[1:0];
    reg         wr_ptr;
    reg         rd_ptr;
    assign if2id_bus        = slot[rd_ptr];
    assign id_buf_allowin   = slot_valid[wr_ptr] == 1'b0;
    assign if_buf_ready_go  = slot_valid[rd_ptr] == 1'b1;
    integer i;
    always @(posedge clk) begin
        if (rst || ex_flush || ertn_flush || pred_flush) begin
            slot_valid <= 2'b00;
            wr_ptr <= 1'b0;
            rd_ptr <= 1'b0;
        end else begin
            if (if_ready_go && id_buf_allowin)
                slot_valid[wr_ptr] <= 1'b1;
            if (if_buf_ready_go && id_allowin)
                slot_valid[rd_ptr] <= 1'b0;
            if (if_ready_go && id_buf_allowin) begin
                slot[wr_ptr] <= if2id_buf_bus;
                wr_ptr <= ~wr_ptr;
            end
            if (if_buf_ready_go && id_allowin)
                rd_ptr <= ~rd_ptr;
        end
    end
endmodule