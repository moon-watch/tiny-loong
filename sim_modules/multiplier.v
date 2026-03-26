module multiplier (
    input  wire [32:0] a,
    input  wire [32:0] b,
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    output wire [65:0] p
);
    assign p = a * b;
endmodule
