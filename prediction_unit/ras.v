module ras (
    input   wire        clk,
    input   wire        rst,
    input   wire        is_call,
    input   wire [31:0] call_target,
    input   wire        is_rtn,
    output  wire [31:0] rtn_target,
    output  wire [ 2:0] ras_chkpt,
    input   wire        ras_rollbk,
    input   wire [ 2:0] rllbk_ckpt
);
    reg [ 2:0] ras_ptr;
    reg [31:0] ras[7:0];
    wire [2:0] ras_prev_ptr;
    wire [2:0] ras_nxt_ptr;
    assign ras_prev_ptr = ras_ptr - 3'b1;
    assign ras_nxt_ptr  = ras_ptr + 3'b1;
    assign rtn_target   = ras[ras_prev_ptr];
    assign ras_chkpt    = ras_ptr;
    integer i;
    always @(posedge clk) begin
        if (rst)
            ras_ptr <= 3'b0;
        else if (ras_rollbk)
            ras_ptr <= rllbk_ckpt;
        else if (is_call)
            ras_ptr <= ras_nxt_ptr;
        else if (is_rtn)
            ras_ptr <= ras_prev_ptr;

        if (rst)
            for (i = 0; i < 8; i = i + 1)
                ras[i] <= 32'b0;
        else if (is_call)
            ras[ras_ptr] <= call_target;
    end
endmodule
