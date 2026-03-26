module divider (
    input   wire        clk,
    input   wire        rst,
    input   wire        ex_flush,
    input   wire        start,
    input   wire        new_entry,
    input   wire [31:0] dividend,
    input   wire [31:0] divisor,
    input   wire        u_sig,
    output  wire [31:0] quotient,
    output  wire [31:0] remainder,
    output  wire        result_ready
);
//declaration
    localparam  idle    = 2'b00;
    localparam  detect  = 2'b01;
    localparam  proc    = 2'b10;
    reg  [1:0]  div_state;
    wire        is_detect = div_state[0];
    reg         init_flag;
    reg         quotient_sig;
    reg         remainder_sig;
    reg  [31:0] last_dividend;
    reg  [31:0] last_divisor;
    wire        repeated;
    wire        repeated_ready;
    reg  [63:0] dividend_reg;
    reg  [32:0] divisor_reg;
    reg  [31:0] quotient_reg;
    reg         result_ready_reg;
    reg  [4:0]  step_cnt;
    wire [32:0] sub_result;
    wire        cout;
//div
    assign  repeated        = (last_dividend == dividend) && (last_divisor == divisor) && init_flag;
    assign  repeated_ready  = is_detect & repeated & start;
    assign  quotient        = quotient_sig ? (~quotient_reg + 1'b1) : quotient_reg;
    assign  remainder       = remainder_sig ? (~dividend_reg[63:32] + 1'b1) : dividend_reg[63:32];
    assign  result_ready    = result_ready_reg | repeated_ready;
    assign  {cout, sub_result} = dividend_reg[63:31] + ~divisor_reg + 1'b1;     //to do widthexpand :(
    always @(posedge clk) begin
        if (rst || ex_flush) begin
            init_flag           <= 1'b0;
            div_state           <= idle;
            quotient_reg        <= 32'b0;
            result_ready_reg    <= 1'b0;
        end else begin
            case (div_state)
                idle:
                    if (new_entry) begin
                        div_state <= detect;
                        result_ready_reg <= 1'b0;
                    end
                detect:
                    if (start) begin
                        last_dividend <= dividend;
                        last_divisor  <= divisor;
                        if (!repeated) begin
                            div_state <= proc;
                            step_cnt  <= 5'd31;
                            if (u_sig) begin
                                dividend_reg  <= {32'b0, (dividend[31] ? (~dividend + 1'b1) : dividend)};
                                divisor_reg   <= {1'b0, (divisor[31] ? (~divisor + 1'b1) : divisor)};
                                quotient_sig  <= dividend[31] ^ divisor[31];
                                remainder_sig <= dividend[31];
                            end else begin
                                dividend_reg  <= {32'b0, dividend};
                                divisor_reg   <= {1'b0, divisor};
                                quotient_sig  <= 1'b0;
                                remainder_sig <= 1'b0;
                            end
                        end
                    end
                proc: begin
                    step_cnt <= step_cnt - 1;
                    if (step_cnt == 5'b0) begin
                        div_state <= idle;
                        result_ready_reg <= 1'b1;
                        if (~init_flag)
                            init_flag <= 1'b1;
                    end
                    if (cout) begin
                        dividend_reg <= dividend_reg << 1;
                        quotient_reg <= quotient_reg << 1;
                    end else begin
                        dividend_reg <= {sub_result[31:0], dividend_reg[30:0], 1'b0};
                        quotient_reg <= {quotient_reg[30:0], 1'b1};
                    end
                end
            endcase
        end
    end
endmodule
