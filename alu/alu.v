module alu(
    input   wire        clk,
    input   wire        rst,
    input   wire        ex_flush,
    input   wire        multi_circle,
    input   wire        new_entry,
    input   wire [18:0] alu_op,
    input   wire [31:0] alu_src1,
    input   wire [31:0] alu_src2,
    output  wire [31:0] alu_result,
    output  wire [31:0] quick_sum,
    output  wire        neq,
    output  wire        lt,
    output  wire        ltu,
    output  wire        res_ready
);
//declaration
    //op_bus
    wire        op_add;
    wire        op_sub;
    wire        op_slt;
    wire        op_sltu;
    wire        op_sll;
    wire        op_srl;
    wire        op_sra;
    wire        op_bypass;
    wire        op_and;
    wire        op_nor;
    wire        op_or;
    wire        op_xor;
    wire        op_mul;
    wire        op_mulh;
    wire        op_mulhu;
    wire        op_div;
    wire        op_divu;
    wire        op_mod;
    wire        op_modu;
    //adder
    wire [31:0] adder_src1;
    wire [31:0] adder_src2;
    wire [31:0] adder_result;
    wire        add_or_sub;
    //mul
    wire [32:0] mul_a;
    wire [32:0] mul_b;
    wire [65:0] mul_p;
    //div
    wire        div_start;
    wire        div_sig;
    wire        div_ready;
    //result
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
    wire [31:0] prodl_result;
    wire [31:0] prodh_result;
    wire [31:0] quot_result;
    wire [31:0] remdr_result;
//op_bus
    assign  op_add      = alu_op[0];
    assign  op_sub      = alu_op[1];
    assign  op_slt      = alu_op[2];
    assign  op_sltu     = alu_op[3];
    assign  op_sll      = alu_op[4];
    assign  op_srl      = alu_op[5];
    assign  op_sra      = alu_op[6];
    assign  op_bypass   = alu_op[7];
    assign  op_and      = alu_op[8];
    assign  op_nor      = alu_op[9];
    assign  op_or       = alu_op[10];
    assign  op_xor      = alu_op[11];
    assign  op_mul      = alu_op[12];
    assign  op_mulh     = alu_op[13];
    assign  op_mulhu    = alu_op[14];
    assign  op_div      = alu_op[15];
    assign  op_divu     = alu_op[16];
    assign  op_mod      = alu_op[17];
    assign  op_modu     = alu_op[18];
//adder
    assign  adder_src1 = alu_src1;
    assign  adder_src2 = alu_src2;
    assign  add_or_sub = op_sub | op_slt | op_sltu | op_div;
    adder u_adder(
        .src1       (adder_src1     ),
        .src2       (adder_src2     ),
        .add_or_sub (add_or_sub     ),
        .lt         (lt             ),
        .ltu        (ltu            ),
        .result     (adder_result   )
    );
    assign add_sub_result = adder_result;
//slt
    assign  slt_result[31:1] = 31'b0;
    assign  slt_result[0]    = lt;
//sltu
    assign  sltu_result[31:1] = 31'b0;
    assign  sltu_result[0]    = ltu;
//bit_op
    assign  and_result = alu_src1 & alu_src2;
    assign  or_result  = alu_src1 | alu_src2;
    assign  nor_result = ~or_result;
    assign  xor_result = alu_src1 ^ alu_src2;
    assign  bypass_result = alu_src2;
//sll
    assign  sll_result = alu_src1 << alu_src2[4:0];
//srl/sra
    assign  sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0];
    assign  sr_result   = sr64_result[31:0];
//mul
    assign  mul_a = op_mulh ? {alu_src1[31], alu_src1} : {1'b0, alu_src1};
    assign  mul_b = op_mulh ? {alu_src2[31], alu_src2} : {1'b0, alu_src2};
    multiplier u_multiplier (
        .a  (mul_a  ),  // input [32:0]
        .b  (mul_b  ),  // input [32:0]
        .clk(clk    ),  // input
        .rst(rst    ),  // input
        .ce (1'b1   ),  // input
        .p  (mul_p  )   // output [65:0]
    );
    assign  prodl_result = mul_p[31:0];
    assign  prodh_result = mul_p[63:32];
//Divider
    assign  div_start   = op_div | op_divu | op_mod | op_modu;
    assign  div_sig     = op_div | op_mod;
    divider u_divider(
        .clk          (clk          ),
        .rst          (rst          ),
        .ex_flush     (ex_flush     ),
        .start        (div_start    ),
        .new_entry    (new_entry    ),
        .dividend     (alu_src1     ),
        .divisor      (alu_src2     ),
        .u_sig        (div_sig      ),
        .quotient     (quot_result  ),
        .remainder    (remdr_result ),
        .result_ready (div_ready    )
    );
//result
    assign  neq         = |xor_result;
    assign  quick_sum   = adder_result;
    assign  res_ready   = multi_circle ? div_ready : 1'b1;
    assign  alu_result  = ({32{op_add|op_sub    }} & add_sub_result)
                        | ({32{op_slt           }} & slt_result    )
                        | ({32{op_sltu          }} & sltu_result   )
                        | ({32{op_and           }} & and_result    )
                        | ({32{op_nor           }} & nor_result    )
                        | ({32{op_or            }} & or_result     )
                        | ({32{op_xor           }} & xor_result    )
                        | ({32{op_bypass        }} & bypass_result )
                        | ({32{op_sll           }} & sll_result    )
                        | ({32{op_srl|op_sra    }} & sr_result     )
                        | ({32{op_mul           }} & prodl_result  )
                        | ({32{op_mulh|op_mulhu }} & prodh_result  )
                        | ({32{op_div|op_divu   }} & quot_result   )
                        | ({32{op_mod|op_modu   }} & remdr_result  );
endmodule
