module ras (    //Known risk: return before call may let program jump to 0x00000000 or other illegal address
    input   wire        clk,
    input   wire        rst,
    input   wire        is_call,
    input   wire [31:0] call_target,    //Actual return address
    input   wire        is_rtn,
    output  wire [31:0] rtn_target,
    output  wire [ 2:0] ras_chkpt,      //Speculatively updated
    input   wire        ras_rollbk,
    input   wire [ 2:0] rllbk_ckpt
);
    reg [ 2:0] ras_ptr;
    reg [31:0] ras[7:0];
    wire [2:0] ras_prev_ptr = ras_ptr - 3'b1;
    wire [2:0] ras_nxt_ptr = ras_ptr + 3'b1;
    assign rtn_target = ras[ras_prev_ptr];
    assign ras_chkpt = ras_ptr;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            ras_ptr <= 3'b0;
            for (i = 0; i < 8; i = i + 1)
                ras[i] <= 32'b0;
        end else begin
            if (ras_rollbk)
                ras_ptr <= rllbk_ckpt;
            else if (is_call) begin
                ras_ptr <= ras_nxt_ptr;
                ras[ras_ptr] <= call_target;
            end else if (is_rtn)
                ras_ptr <= ras_prev_ptr;
        end
    end
endmodule