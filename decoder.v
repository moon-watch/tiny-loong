module decoder_6_64 (
    input wire [5:0] in,
    output wire [63:0] out
);
    assign out = 64'b1 << in;
endmodule

module decoder_5_32 (
    input wire [4:0] in,
    output wire [31:0] out
);
    assign out = 32'b1 << in;
endmodule

module decoder_4_16 (
    input wire [3:0] in,
    output wire [15:0] out
);
    assign out = 16'b1 << in;
endmodule

module decoder_2_4 (
    input wire [1:0] in,
    output wire [3:0] out
);
    assign out = 4'b1 << in;
endmodule
