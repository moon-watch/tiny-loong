module divider (
    input  wire         clk,
    input  wire         rst,
    input  wire         ex_flush,
    input  wire         start,
    input  wire         new_entry,
    input  wire [31:0]  dividend,
    input  wire [31:0]  divisor,
    input  wire         u_sig,  //0 for unsigned, 1 for signed
    output wire [31:0]  quotient,
    output wire [31:0]  remainder,
    output wire         result_ready
);
localparam  IDLE    = 2'b00;
localparam  DETECT  = 2'b01;
localparam  PROCESS = 2'b10;
reg         init_flag;  //A stupid design :(
reg  [1:0]  div_state;
wire        is_detect    = div_state[0];
reg         quotient_sig;   //Whether quotient is positive or negtive, 0 for positive, 1 for negtive
reg         remainder_sig;  //Whether remainder is positive or negtive, 0 for positive, 1 for negtive
reg  [31:0] last_dividend;
reg  [31:0] last_divisor;
wire        repeated     = (last_dividend == dividend) & (last_divisor == divisor) & init_flag;
wire        repeated_ready = is_detect & repeated & start;
reg  [63:0] dividend_reg;
reg  [32:0] divisor_reg;
reg  [31:0] quotient_reg;
reg         result_ready_reg;
assign      quotient     = quotient_sig ? (~quotient_reg + 1'b1) : quotient_reg;
assign      remainder    = remainder_sig ? (~dividend_reg[63:32] + 1'b1) : dividend_reg[63:32];
assign      result_ready = result_ready_reg | repeated_ready;
reg  [4:0]  step_cnt;
wire [32:0] sub_result;
wire        cout;
assign      {cout, sub_result} = dividend_reg[63:31] + ~divisor_reg + 1'b1;
always @(posedge clk) begin
    if (rst || ex_flush) begin
        init_flag <= 1'b0;
        div_state <= IDLE;
        quotient_reg <= 32'b0;
        result_ready_reg <= 1'b0;
    end else begin
        case (div_state)
            IDLE: begin
                if (new_entry) begin
                    div_state <= DETECT;
                    result_ready_reg <= 1'b0;
                end
            end
            DETECT: begin
                if (start) begin
                    last_dividend <= dividend;
                    last_divisor  <= divisor;
                    if (!repeated) begin  //No need to repeat while received a div-mod pair
                        div_state <= PROCESS;
                        step_cnt  <= 5'd31;
                        if (u_sig) begin    //signed
                            dividend_reg  <= {32'b0, (dividend[31] ? (~dividend + 1'b1) : dividend)};
                            divisor_reg   <= {1'b0, (divisor[31] ? (~divisor + 1'b1) : divisor)};
                            quotient_sig  <= dividend[31] ^ divisor[31];
                            remainder_sig <= dividend[31];
                        end else begin      //unsigned
                            dividend_reg  <= {32'b0, dividend};
                            divisor_reg   <= {1'b0, divisor};
                            quotient_sig  <= 1'b0;
                            remainder_sig <= 1'b0;
                        end
                    end
                end
            end
            PROCESS: begin
                step_cnt <= step_cnt - 1;
                if (step_cnt == 5'b0) begin
                    div_state <= IDLE;
                    result_ready_reg <= 1'b1;
                    init_flag <= init_flag ? init_flag : 1'b1;
                end
                if (cout) begin //dividend is less than divisor
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