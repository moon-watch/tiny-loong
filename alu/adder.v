module adder (
    input  wire [31:0] src1,
    input  wire [31:0] src2,
    input  wire add_or_sub, //0 for add, 1 for sub
    output wire lt,
    output wire ltu,
    output wire [31:0] result
);
    wire cin = add_or_sub ? 1'b1 : 1'b0;
    wire cout;
    assign {cout, result} = {1'b0, src1} + {1'b0, (add_or_sub ? ~src2 : src2)} + cin;
    assign ltu = ~cout;
    assign lt = (src1[31] & ~src2[31])
              | ((src1[31] ~^ src2[31]) & result[31]);
endmodule