module tlb #(
    parameter TLBNUM = 16
) (
    input  wire                        clk,
    //if
    input  wire [                18:0] s0_vppn,
    input  wire                        s0_va_bit12,
    input  wire [                 9:0] s0_asid,
    output wire                        s0_found,
    output wire [$clog2(TLBNUM) - 1:0] s0_index,
    output wire [                19:0] s0_ppn,
    output wire [                 5:0] s0_ps,
    output wire [                 1:0] s0_plv,
    output wire [                 1:0] s0_mat,
    output wire                        s0_d,
    output wire                        s0_v,
    //mem
    input  wire [                18:0] s1_vppn,
    input  wire                        s1_va_bit12,
    input  wire [                 9:0] s1_asid,
    output wire                        s1_found,
    output wire [$clog2(TLBNUM) - 1:0] s1_index,
    output wire [                19:0] s1_ppn,
    output wire [                 5:0] s1_ps,
    output wire [                 1:0] s1_plv,
    output wire [                 1:0] s1_mat,
    output wire                        s1_d,
    output wire                        s1_v,
    //inv
    input  wire                        invtlb_valid,
    input  wire [                 4:0] invtlb_op,
    //wr
    input  wire                        we,
    input  wire [$clog2(TLBNUM) - 1:0] w_index,
    input  wire                        w_e,
    input  wire [                18:0] w_vppn,
    input  wire [                 5:0] w_ps,
    input  wire [                 9:0] w_asid,
    input  wire                        w_g,
    input  wire [                19:0] w_ppn0,
    input  wire [                 1:0] w_plv0,
    input  wire [                 1:0] w_mat0,
    input  wire                        w_d0,
    input  wire                        w_v0,
    input  wire [                19:0] w_ppn1,
    input  wire [                 1:0] w_plv1,
    input  wire [                 1:0] w_mat1,
    input  wire                        w_d1,
    input  wire                        w_v1,
    //rd
    input  wire [$clog2(TLBNUM) - 1:0] r_index,
    output wire                        r_e,
    output wire [                18:0] r_vppn,
    output wire [                 5:0] r_ps,
    output wire [                 9:0] r_asid,
    output wire                        r_g,
    output wire [                19:0] r_ppn0,
    output wire [                 1:0] r_plv0,
    output wire [                 1:0] r_mat0,
    output wire                        r_d0,
    output wire                        r_v0,
    output wire [                19:0] r_ppn1,
    output wire [                 1:0] r_plv1,
    output wire [                 1:0] r_mat1,
    output wire                        r_d1,
    output wire                        r_v1
);
//declaration
    //ram
    reg  [TLBNUM - 1:0] tlb_e;
    reg  [TLBNUM - 1:0] tlb_ps4MB;
    reg  [        18:0] tlb_vppn [TLBNUM - 1:0];
    reg  [         9:0] tlb_asid [TLBNUM - 1:0];
    reg  [TLBNUM - 1:0] tlb_g;
    reg  [        19:0] tlb_ppn0 [TLBNUM - 1:0];
    reg  [         1:0] tlb_plv0 [TLBNUM - 1:0];
    reg  [         1:0] tlb_mat0 [TLBNUM - 1:0];
    reg  [TLBNUM - 1:0] tlb_d0;
    reg  [TLBNUM - 1:0] tlb_v0;
    reg  [        19:0] tlb_ppn1 [TLBNUM - 1:0];
    reg  [         1:0] tlb_plv1 [TLBNUM - 1:0];
    reg  [         1:0] tlb_mat1 [TLBNUM - 1:0];
    reg  [TLBNUM - 1:0] tlb_d1;
    reg  [TLBNUM - 1:0] tlb_v1;
    wire [TLBNUM - 1:0] is_g_set;
    wire [TLBNUM - 1:0] is_e_set;
    //if
    wire [TLBNUM - 1:0] is_asid_match0;
    wire [TLBNUM - 1:0] is_vppn_match0;
    wire [TLBNUM - 1:0] match0;
    wire [TLBNUM - 1:0] s0_odd_even;
    //mem
    wire [TLBNUM - 1:0] is_asid_match1;
    wire [TLBNUM - 1:0] is_vppn_match1;
    wire [TLBNUM - 1:0] match1;
    wire [TLBNUM - 1:0] s1_odd_even;
//ram
    assign is_g_set = tlb_g;
    assign is_e_set = tlb_e;
//if
    assign match0       = is_vppn_match0 & (is_asid_match0 | is_g_set) & is_e_set;
    assign s0_found     = |match0;
    assign s0_odd_even  = (tlb_ps4MB & s0_vppn[8]) | (~tlb_ps4MB & s0_va_bit12);
    encoder_16_4 s0_index_gen(
        .in(match0),
        .out(s0_index));
    assign s0_ppn   = s0_odd_even ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
    assign s0_ps    = tlb_ps4MB[s0_index] ? 6'd21 : 6'd12;
    assign s0_plv   = s0_odd_even ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
    assign s0_mat   = s0_odd_even ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
    assign s0_d     = s0_odd_even ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
    assign s0_v     = s0_odd_even ? tlb_v1  [s0_index] : tlb_v0  [s0_index];
//mem
    assign match1       = is_vppn_match1 & (is_asid_match1 | is_g_set) & is_e_set;
    assign s1_found     = |match1;
    assign s1_odd_even  = (tlb_ps4MB & s1_vppn[8]) | (~tlb_ps4MB & s1_va_bit12);
    encoder_16_4 s1_index_gen(
        .in(match1),
        .out(s1_index));
    assign s1_ppn   = s1_odd_even ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
    assign s1_ps    = tlb_ps4MB[s1_index] ? 6'd21 : 6'd12;
    assign s1_plv   = s1_odd_even ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
    assign s1_mat   = s1_odd_even ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
    assign s1_d     = s1_odd_even ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
    assign s1_v     = s1_odd_even ? tlb_v1  [s1_index] : tlb_v0  [s1_index];
//match
    genvar j;
    generate
        for (j = 0; j < TLBNUM; j = j + 1) begin : COND_GEN
            assign is_asid_match0[j] = s0_asid == tlb_asid[j];
            assign is_asid_match1[j] = s1_asid == tlb_asid[j];
            assign is_vppn_match0[j] = (s0_vppn[18:9] == tlb_vppn[j][18:9])
                                    && (tlb_ps4MB[j] || s0_vppn[8:0] == tlb_vppn[j][8:0]);
            assign is_vppn_match1[j] = (s1_vppn[18:9] == tlb_vppn[j][18:9])
                                    && (tlb_ps4MB[j] || s1_vppn[8:0] == tlb_vppn[j][8:0]);
        end
    endgenerate
//inv
    always @(posedge clk) begin
        if (invtlb_valid) begin
            case (invtlb_op)
                5'h0 : tlb_e <= {TLBNUM{1'b0}};
                5'h1 : tlb_e <= {TLBNUM{1'b0}};
                5'h2 : tlb_e <= tlb_e & ~is_g_set;
                5'h3 : tlb_e <= tlb_e & is_g_set;
                5'h4 : tlb_e <= tlb_e & ~(~is_g_set & is_asid_match1);
                5'h5 : tlb_e <= tlb_e & ~(~is_g_set & is_asid_match1 & is_vppn_match1);
                5'h6 : tlb_e <= tlb_e & ~(is_vppn_match1 & (is_asid_match1 | is_g_set));
                default: tlb_e <= tlb_e;
            endcase
        end else if (we)
            tlb_e [w_index] <= w_e;
    end
//wr
    always @(posedge clk) begin
        if (we) begin
            tlb_vppn [w_index] <= w_vppn;
            tlb_ps4MB[w_index] <= w_ps == 6'd21;
            tlb_asid [w_index] <= w_asid;
            tlb_g    [w_index] <= w_g;
            tlb_ppn0 [w_index] <= w_ppn0;
            tlb_plv0 [w_index] <= w_plv0;
            tlb_mat0 [w_index] <= w_mat0;
            tlb_d0   [w_index] <= w_d0;
            tlb_v0   [w_index] <= w_v0;
            tlb_ppn1 [w_index] <= w_ppn1;
            tlb_plv1 [w_index] <= w_plv1;
            tlb_mat1 [w_index] <= w_mat1;
            tlb_d1   [w_index] <= w_d1;
            tlb_v1   [w_index] <= w_v1;
        end
    end
//rd
    assign r_e    = tlb_e    [r_index];
    assign r_vppn = tlb_vppn [r_index];
    assign r_ps   = tlb_ps4MB[r_index] ? 6'd21 : 6'd12;
    assign r_asid = tlb_asid [r_index];
    assign r_g    = tlb_g    [r_index];
    assign r_ppn0 = tlb_ppn0 [r_index];
    assign r_plv0 = tlb_plv0 [r_index];
    assign r_mat0 = tlb_mat0 [r_index];
    assign r_d0   = tlb_d0   [r_index];
    assign r_v0   = tlb_v0   [r_index];
    assign r_ppn1 = tlb_ppn1 [r_index];
    assign r_plv1 = tlb_plv1 [r_index];
    assign r_mat1 = tlb_mat1 [r_index];
    assign r_d1   = tlb_d1   [r_index];
    assign r_v1   = tlb_v1   [r_index];
endmodule
