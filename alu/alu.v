module alu(
  input  wire        clk,
  input  wire        rst,
  //To exe_stage
  input  wire        ex_flush,
  input  wire        multi_circle,
  input  wire        new_entry,
  input  wire [18:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result,
  output wire [31:0] quick_sum,
  output wire        neq,
  output wire        lt,
  output wire        ltu,
  output wire        res_ready
);
wire op_add     = alu_op[0];  //add operation
wire op_sub     = alu_op[1];  //sub operation
wire op_slt     = alu_op[2];  //signed compared and set less than
wire op_sltu    = alu_op[3];  //unsigned compared and set less than
wire op_sll     = alu_op[4];  //logic left shift
wire op_srl     = alu_op[5];  //logic right shift
wire op_sra     = alu_op[6];  //arithmetic right shift
wire op_bypass  = alu_op[7];  //bypass the value to the next stage
wire op_and     = alu_op[8];  //bitwise and
wire op_nor     = alu_op[9];  //bitwise nor
wire op_or      = alu_op[10]; //bitwise or
wire op_xor     = alu_op[11]; //bitwise xor
wire op_mul     = alu_op[12];
wire op_mulh    = alu_op[13];
wire op_mulhu   = alu_op[14];
wire op_div     = alu_op[15];
wire op_divu    = alu_op[16];
wire op_mod     = alu_op[17];
wire op_modu    = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [31:0] bypass_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] prodl_result; //Product low
wire [31:0] prodh_result; //Product high
wire [31:0] quot_result;  //Quotient
wire [31:0] remdr_result; //Remainder

// 32-bit adder
wire [31:0] adder_src1 = alu_src1;
wire [31:0] adder_src2 = alu_src2;
wire [31:0] adder_result;
wire add_or_sub = op_sub | op_slt | op_sltu | op_div;

adder u_adder(
  .src1       (adder_src1),
  .src2       (adder_src2),
  .add_or_sub (add_or_sub),
  .lt         (lt),
  .ltu        (ltu),
  .result     (adder_result)
);
// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = lt;

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ltu;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign bypass_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

//Multiplier
wire [32:0] mul_a = op_mulh ? {alu_src1[31], alu_src1} : {1'b0, alu_src1};
wire [32:0] mul_b = op_mulh ? {alu_src2[31], alu_src2} : {1'b0, alu_src2};
wire [65:0] mul_p;
assign prodl_result = mul_p[31:0];
assign prodh_result = mul_p[63:32];

//Divider
wire div_start = op_div | op_divu | op_mod | op_modu;
wire div_sig = op_div | op_mod;
wire div_ready;
//Output interface
assign neq = |xor_result;
assign quick_sum = adder_result;
assign res_ready = multi_circle ? div_ready : 1'b1;
// final result mux
assign alu_result = ({32{op_add|op_sub    }} & add_sub_result)
                  | ({32{op_slt           }} & slt_result)
                  | ({32{op_sltu          }} & sltu_result)
                  | ({32{op_and           }} & and_result)
                  | ({32{op_nor           }} & nor_result)
                  | ({32{op_or            }} & or_result)
                  | ({32{op_xor           }} & xor_result)
                  | ({32{op_bypass        }} & bypass_result)
                  | ({32{op_sll           }} & sll_result)
                  | ({32{op_srl|op_sra    }} & sr_result)
                  | ({32{op_mul           }} & prodl_result)
                  | ({32{op_mulh|op_mulhu }} & prodh_result)
                  | ({32{op_div|op_divu   }} & quot_result)
                  | ({32{op_mod|op_modu   }} & remdr_result);

multiplier u_multiplier (
  .a  (mul_a),  // input [32:0]
  .b  (mul_b),  // input [32:0]
  .clk(clk),    // input
  .rst(rst),  // input
  .ce (1'b1),   // input
  .p  (mul_p)   // output [65:0]
);

divider u_divider(
    .clk          (clk),
    .rst          (rst),
    .ex_flush     (ex_flush),
    .start        (div_start),
    .new_entry    (new_entry),
    .dividend     (alu_src1),
    .divisor      (alu_src2),
    .u_sig        (div_sig),
    .quotient     (quot_result),
    .remainder    (remdr_result),
    .result_ready (div_ready)
);
endmodule
