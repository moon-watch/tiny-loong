`include "bus_width.h"
module id_stage (
    input   wire        clk,
    input   wire        rst,
    input   wire        ex_flush,
    input   wire        pred_flush,
    //prev_stage
    input   wire [`IF_BUS_W - 1:0] if2id_bus,
    input   wire        if_ready_go,
    output  wire        id_allowin,
    //next_stage
    output  wire        id_is_fresh,
    output  wire [`ID_BUS_W - 1:0] id2exe_bus,
    output  wire        id_ready_go,
    input   wire        exe_allowin,
    //csr
    input   wire        has_int,
    input   wire        euen_fpe,
    input   wire [ 1:0] crmd_plv,
    //regfile
    output  wire [ 4:0] rj_addr,
    output  wire [ 4:0] rk_rd_addr,
    input   wire [31:0] rj_data,
    input   wire [31:0] rk_rd_data,
    //forward
    output  wire        forwrd_we,
    output  wire [ 4:0] forwrd_idx,
    output  wire [ 2:0] forwrd_src,
    input   wire [ 2:0] forwrd_ptr,
    output  wire [ 4:0] rj_query,
    output  wire [ 4:0] rk_rd_query,
    input   wire        rj_blocked,
    input   wire        rk_rd_blocked,
    input   wire        forwrd_rj_rdy,
    input   wire        forwrd_rk_rd_rdy,
    input   wire [31:0] forwrd_rj,
    input   wire [31:0] forwrd_rk_rd
);
//declaration
    //fsm
    localparam  expired  = 3'b001;
    localparam  fresh    = 3'b010;
    localparam  hold     = 3'b100;
    reg [2:0]   id_state;
    wire        is_expired  = id_state[0];
    wire        is_fresh    = id_state[1];
    wire        is_hold     = id_state[2];
    wire        id_flush;
    wire        any_excp;
    wire        stall_now;
    reg         stall_flag;
    wire        src_ok;
    wire        new_entry;
    //if2id_bus
    reg [`IF_BUS_W - 1:0] if2id_bus_reg;
    wire [ 2:0] ras_chkpt_reg;
    wire [31:0] inst_reg;
    wire [31:0] pc_reg;
    wire [ 3:0] if_ex_bus_reg;
    wire        if_any_ex_reg;
    //decode
    wire [15:0] offs_15_0;
    wire [ 9:0] offs_25_16;
    wire [11:0] i12;
    wire [13:0] si14;
    wire [19:0] si20;
    wire [ 4:0] ui5;
    wire [ 5:0] op_31_26;
    wire [ 1:0] op_25_24;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] op_14_10;
    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;
    wire [31:0] op_14_10_d;
    wire [ 4:0] rj, rk, rd;
    wire        rj_eq_0, rj_eq_1, rd_eq_0, rd_eq_1;
    wire        inst_add_w;
    wire        inst_addi_w;
    wire        inst_sub_w;
    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_div_w;
    wire        inst_mod_w;
    wire        inst_div_wu;
    wire        inst_mod_wu;
    wire        inst_lu12i_w;
    wire        inst_pcaddu12i;
    wire        inst_and;
    wire        inst_nor;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_blt;
    wire        inst_bge;
    wire        inst_bltu;
    wire        inst_bgeu;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_jirl;
    wire        inst_ld_b;
    wire        inst_ld_h;
    wire        inst_ld_w;
    wire        inst_ld_bu;
    wire        inst_ld_hu;
    wire        inst_preld;
    wire        inst_ll_w;
    wire        inst_rdcntvl_w;
    wire        inst_rdcntvh_w;
    wire        inst_rdcntid;
    wire        inst_st_b;
    wire        inst_st_h;
    wire        inst_st_w;
    wire        inst_sc_w;
    wire        inst_dbar;
    wire        inst_ibar;
    wire        inst_syscall;
    wire        inst_break;
    wire        inst_cacop;
    wire        inst_csrrd;
    wire        inst_csrwr;
    wire        inst_csrxchg;
    wire        inst_tlbsrch;
    wire        inst_tlbrd;
    wire        inst_tlbwr;
    wire        inst_tlbfill;
    wire        inst_invtlb;
    wire        inst_ertn;
    wire        inst_idle;
    wire        multi_circle;
    //forward & src
    wire        forwrd_on_exe, forwrd_on_mem, forwrd_on_wb;
    wire        gr_no_we, gr_we;
    wire [ 4:0] rd_addr;
    wire        need_rj, need_rd, need_rk_rd;
    wire [31:0] final_rj;
    wire [31:0] final_rk_rd;
    //wb_info
    wire [ 4:0] wb_src;
    wire [ 4:0] tlb_op;
    wire        csr_we;
    wire        csr_nomask;
    //mem_info
    wire [ 4:0] cacop_code;
    wire        cacop_target;
    wire        cacop_valid;
    wire [ 3:0] cacop_opcode;
    wire [ 4:0] preld_hint;
    wire        mem_ld, mem_st, mem_ispreld, mem_isll, mem_issc;
    wire        mem_usign;
    wire [ 2:0] mem_len;
    //exe_info
    wire        alu_op_add;
    wire        alu_op_sub;
    wire        alu_op_slt;
    wire        alu_op_sltu;
    wire        alu_op_sll;
    wire        alu_op_srl;
    wire        alu_op_sra;
    wire        alu_op_bypass;
    wire        alu_op_and;
    wire        alu_op_nor;
    wire        alu_op_or;
    wire        alu_op_xor;
    wire        alu_op_mul;
    wire        alu_op_mulh;
    wire        alu_op_mulhu;
    wire        alu_op_div;
    wire        alu_op_divu;
    wire        alu_op_mod;
    wire        alu_op_modu;
    wire [18:0] alu_op_bus;
    wire        src1_rj;
    wire        src1_pc;
    wire        src2_rk_rd;
    wire        src2_4;
    wire        src2_si20;
    wire        src2_si12;
    wire        src2_si14;
    wire        src2_ui12;
    wire        src2_ui5;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    //jump
    wire        always_br;
    wire        br_eq;
    wire        br_lt;
    wire        br_ge;
    wire        br_opst;
    wire [ 4:0] br_cond;
    wire        br_inst;
    wire        br_type;
    wire        call_type;
    wire        ret_type;
    wire        jump_type;
    wire [ 3:0] btb_type;
    wire        br_src1_pc;
    wire        br_src2_ofst16;
    wire        br_src2_ofst26;
    //excp
    wire        inst_exist;
    wire        is_fp_inst;
    wire        is_priv_inst;
    wire        ex_int;
    wire        ex_sys;
    wire        ex_break;
    wire        ex_ine;
    wire        ex_ipe;
    wire        ex_fpd;
    wire        id_any_ex;
    wire [ 9:0] id_ex_bus;
    //id2exe_bus
    wire [ 2:0] ras_chkpt;
    wire [31:0] pc;
    wire [31:0] rd_value;
    wire        id_isidle;
    wire [ 3:0] cacop_op;
    wire        id_isertn;
    wire        if_any_ex;
//if2id_bus
    assign {
        ras_chkpt_reg,
        inst_reg,
        pc_reg,
        if_ex_bus_reg,
        if_any_ex_reg
    } = if2id_bus_reg;
//decode
    assign offs_15_0    = inst_reg [25:10];
    assign offs_25_16   = inst_reg [ 9:0 ];
    assign i12          = inst_reg [21:10];
    assign si14         = inst_reg [23:10];
    assign si20         = inst_reg [24:5 ];
    assign ui5          = inst_reg [14:10];
    assign op_31_26     = inst_reg [31:26];
    assign op_25_24     = inst_reg [25:24];
    assign op_25_22     = inst_reg [25:22];
    assign op_21_20     = inst_reg [21:20];
    assign op_19_15     = inst_reg [19:15];
    assign op_14_10     = inst_reg [14:10];
    assign rj           = inst_reg [ 9:5 ];
    assign rk           = inst_reg [14:10];
    assign rd           = inst_reg [ 4:0 ];
    decoder_6_64    u_dec_31_26(.in(op_31_26), .out(op_31_26_d));
    decoder_4_16    u_dec_25_22(.in(op_25_22), .out(op_25_22_d));
    decoder_2_4     u_dec_21_20(.in(op_21_20), .out(op_21_20_d));
    decoder_5_32    u_dec_19_15(.in(op_19_15), .out(op_19_15_d));
    decoder_5_32    u_dec_14_10(.in(op_14_10), .out(op_14_10_d));
    assign rj_eq_0      = rj == 5'b0;
    assign rj_eq_1      = rj == 5'b1;
    assign rd_eq_0      = rd == 5'b0;
    assign rd_eq_1      = rd == 5'b1;
    //calcu
    assign inst_add_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[0];
    assign inst_addi_w    = op_31_26_d[0] & op_25_22_d[10];
    assign inst_sub_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[2];
    assign inst_mul_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[24];
    assign inst_mulh_w    = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[25];
    assign inst_mulh_wu   = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[26];
    assign inst_div_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[2] & op_19_15_d[0];
    assign inst_mod_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[2] & op_19_15_d[1];
    assign inst_div_wu    = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[2] & op_19_15_d[2];
    assign inst_mod_wu    = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[2] & op_19_15_d[3];
    assign inst_lu12i_w   = op_31_26_d[5] & ~inst_reg[25];
    assign inst_pcaddu12i = op_31_26_d[7] & ~inst_reg[25];
    //bit
    assign inst_and       = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[9];
    assign inst_nor       = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[8];
    assign inst_or        = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[10];
    assign inst_xor       = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[11];
    assign inst_andi      = op_31_26_d[0] & op_25_22_d[13];
    assign inst_ori       = op_31_26_d[0] & op_25_22_d[14];
    assign inst_xori      = op_31_26_d[0] & op_25_22_d[15];
    //shift
    assign inst_sll_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[14];
    assign inst_srl_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[15];
    assign inst_sra_w     = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[16];
    assign inst_slli_w    = op_31_26_d[0] & op_25_22_d[1] & op_21_20_d[0] & op_19_15_d[1];
    assign inst_srli_w    = op_31_26_d[0] & op_25_22_d[1] & op_21_20_d[0] & op_19_15_d[9];
    assign inst_srai_w    = op_31_26_d[0] & op_25_22_d[1] & op_21_20_d[0] & op_19_15_d[17];
    //compare
    assign inst_slt       = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[4];
    assign inst_sltu      = op_31_26_d[0] & op_25_22_d[0] & op_21_20_d[1] & op_19_15_d[5];
    assign inst_slti      = op_31_26_d[0] & op_25_22_d[8];
    assign inst_sltui     = op_31_26_d[0] & op_25_22_d[9];
    //jump
    assign inst_beq       = op_31_26_d[22];
    assign inst_bne       = op_31_26_d[23];
    assign inst_blt       = op_31_26_d[24];
    assign inst_bge       = op_31_26_d[25];
    assign inst_bltu      = op_31_26_d[26];
    assign inst_bgeu      = op_31_26_d[27];
    assign inst_b         = op_31_26_d[20];
    assign inst_bl        = op_31_26_d[21];
    assign inst_jirl      = op_31_26_d[19];
    //ld
    assign inst_ld_b      = op_31_26_d[10] & op_25_22_d[0];
    assign inst_ld_h      = op_31_26_d[10] & op_25_22_d[1];
    assign inst_ld_w      = op_31_26_d[10] & op_25_22_d[2];
    assign inst_ld_bu     = op_31_26_d[10] & op_25_22_d[8];
    assign inst_ld_hu     = op_31_26_d[10] & op_25_22_d[9];
    assign inst_preld     = op_31_26_d[10] & op_25_22_d[11];
    assign inst_ll_w      = op_31_26_d[8]  & (op_25_24 == 2'b00);
    assign inst_rdcntvl_w = op_31_26_d[0]  & op_25_22_d[0] & op_21_20_d[0] & op_19_15_d[0] & op_14_10_d[24] & rj_eq_0;
    assign inst_rdcntvh_w = op_31_26_d[0]  & op_25_22_d[0] & op_21_20_d[0] & op_19_15_d[0] & op_14_10_d[25] & rj_eq_0;
    assign inst_rdcntid   = op_31_26_d[0]  & op_25_22_d[0] & op_21_20_d[0] & op_19_15_d[0] & op_14_10_d[24] & rd_eq_0;
    //st
    assign inst_st_b      = op_31_26_d[10] & op_25_22_d[4];
    assign inst_st_h      = op_31_26_d[10] & op_25_22_d[5];
    assign inst_st_w      = op_31_26_d[10] & op_25_22_d[6];
    assign inst_sc_w      = op_31_26_d[8]  & (op_25_24 == 2'b01);
    //misc
    assign inst_dbar      = op_31_26_d[14] & op_25_22_d[1] & op_21_20_d[3] & op_19_15_d[4];
    assign inst_ibar      = op_31_26_d[14] & op_25_22_d[1] & op_21_20_d[3] & op_19_15_d[5];
    assign inst_syscall   = op_31_26_d[0]  & op_25_22_d[0] & op_21_20_d[2] & op_19_15_d[22];
    assign inst_break     = op_31_26_d[0]  & op_25_22_d[0] & op_21_20_d[2] & op_19_15_d[20];
    //privileged
    assign inst_cacop     = op_31_26_d[1]  & op_25_22_d[8];
    assign inst_csrrd     = op_31_26_d[1]  & (op_25_24 == 2'b00) & rj_eq_0;
    assign inst_csrwr     = op_31_26_d[1]  & (op_25_24 == 2'b00) & rj_eq_1;
    assign inst_csrxchg   = op_31_26_d[1]  & (op_25_24 == 2'b00) & ~(rj_eq_0 | rj_eq_1);
    assign inst_tlbsrch   = op_31_26_d[1]  & op_25_22_d[9] & op_21_20_d[0] & op_19_15_d[16] & op_14_10_d[10] & rj_eq_0 & rd_eq_0;
    assign inst_tlbrd     = op_31_26_d[1]  & op_25_22_d[9] & op_21_20_d[0] & op_19_15_d[16] & op_14_10_d[11] & rj_eq_0 & rd_eq_0;
    assign inst_tlbwr     = op_31_26_d[1]  & op_25_22_d[9] & op_21_20_d[0] & op_19_15_d[16] & op_14_10_d[12] & rj_eq_0 & rd_eq_0;
    assign inst_tlbfill   = op_31_26_d[1]  & op_25_22_d[9] & op_21_20_d[0] & op_19_15_d[16] & op_14_10_d[13] & rj_eq_0 & rd_eq_0;
    assign inst_invtlb    = op_31_26_d[1]  & op_25_22_d[9] & op_21_20_d[0] & op_19_15_d[19];
    assign inst_ertn      = op_31_26_d[1]  & op_25_22_d[9] & op_21_20_d[0] & op_19_15_d[16] & op_14_10_d[14] & rj_eq_0 & rd_eq_0;
    assign inst_idle      = op_31_26_d[1]  & op_25_22_d[9] & op_21_20_d[0] & op_19_15_d[17];
    assign multi_circle = inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;
//forward & src
    assign forwrd_on_exe    = inst_add_w  
                            | inst_addi_w 
                            | inst_sub_w  
                            | inst_mul_w  
                            | inst_mulh_w 
                            | inst_mulh_wu
                            | inst_div_w  
                            | inst_mod_w  
                            | inst_div_wu 
                            | inst_mod_wu 
                            | inst_and 
                            | inst_nor 
                            | inst_or  
                            | inst_xor 
                            | inst_andi
                            | inst_ori 
                            | inst_xori
                            | inst_sll_w 
                            | inst_srl_w 
                            | inst_sra_w 
                            | inst_slli_w
                            | inst_srli_w
                            | inst_srai_w
                            | inst_slt  
                            | inst_sltu 
                            | inst_slti 
                            | inst_sltui
                            | inst_bl
                            | inst_jirl
                            | inst_lu12i_w
                            | inst_pcaddu12i;
    assign forwrd_on_mem    = inst_ld_b
                            | inst_ld_h
                            | inst_ld_w
                            | inst_ld_bu
                            | inst_ld_hu
                            | inst_ll_w
                            | inst_sc_w;
    assign forwrd_on_wb     = inst_rdcntvl_w
                            | inst_rdcntvh_w
                            | inst_rdcntid
                            | inst_csrrd
                            | inst_csrwr
                            | inst_csrxchg;
    assign gr_no_we     = inst_tlbsrch
                        | inst_tlbrd
                        | inst_tlbwr
                        | inst_tlbfill
                        | inst_invtlb
                        | inst_cacop
                        | inst_break
                        | inst_syscall
                        | inst_dbar
                        | inst_ibar
                        | inst_preld
                        | inst_st_b
                        | inst_st_h
                        | inst_st_w
                        | inst_beq
                        | inst_bne
                        | inst_blt
                        | inst_bge
                        | inst_bltu
                        | inst_bgeu
                        | inst_b;
    assign gr_we        = ~gr_no_we;
    assign rj_addr      = rj;
    assign rk_rd_addr   = need_rd ? rd : rk;
    assign rd_addr      = ({5{inst_bl}} & 5'd1)
                        | ({5{inst_rdcntid}} & rj)
                        | ({5{~(inst_bl | inst_rdcntid)}} & rd);
    //record
    assign  forwrd_we   = id_ready_go && exe_allowin && gr_we;
    assign  forwrd_idx  = rd_addr;
    assign  forwrd_src  = {forwrd_on_wb, forwrd_on_mem, forwrd_on_exe};
    //src
    assign  rj_query    = rj_addr;
    assign  rk_rd_query = rk_rd_addr;
    assign  need_rj     = src1_rj;
    assign  need_rd     = inst_csrxchg
                        | inst_csrwr
                        | inst_st_b
                        | inst_st_h
                        | inst_st_w
                        | inst_beq
                        | inst_bne
                        | inst_blt
                        | inst_bge
                        | inst_bltu
                        | inst_bgeu;
    assign  need_rk_rd  = src2_rk_rd | need_rd;
    assign  final_rj    = rj_blocked    ? forwrd_rj    : rj_data;
    assign  final_rk_rd = rk_rd_blocked ? forwrd_rk_rd : rk_rd_data;
//wb_info
    assign wb_src[0]    = ~(|wb_src[4:1]);
    assign wb_src[1]    = inst_rdcntid;
    assign wb_src[2]    = inst_rdcntvl_w;
    assign wb_src[3]    = inst_rdcntvh_w;
    assign wb_src[4]    = inst_csrrd | inst_csrwr | inst_csrxchg;
    assign tlb_op       = br_inst ? br_cond : {inst_invtlb, inst_tlbfill, inst_tlbwr, inst_tlbrd, inst_tlbsrch};    //mux with br_cond
    assign csr_we       = inst_csrwr | inst_csrxchg;
    assign csr_nomask   = inst_csrwr;   //csrwr's mask is 32'bffffffff
//mem_info
    assign cacop_code   = inst_reg[4:0];
    assign cacop_target = cacop_code[2:0] == 3'd0;  //0: dcache 1: icache
    assign cacop_valid  = inst_cacop && (cacop_code[2:0] == 3'd0 || cacop_code[2:0] == 3'd1);
    decoder_2_4 cacop_op_onehot(.in(cacop_code[4:3]), .out(cacop_opcode));
    assign preld_hint   = inst_reg[4:0];
    assign mem_ld       = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu;
    assign mem_st       = inst_st_b | inst_st_h | inst_st_w;
    assign mem_ispreld  = inst_preld && (preld_hint == 5'd0 || preld_hint == 5'd8);
    assign mem_isll     = inst_ll_w;
    assign mem_issc     = inst_sc_w;
    assign mem_usign    = inst_ld_bu | inst_ld_hu;
    assign mem_len[0]   = inst_ld_b | inst_st_b | inst_ld_bu | inst_preld;
    assign mem_len[1]   = inst_ld_h | inst_st_h | inst_ld_hu;
    assign mem_len[2]   = inst_ld_w | inst_st_w | inst_ll_w | inst_sc_w;
//exe_info
    assign alu_op_add       = inst_add_w | inst_addi_w | inst_ld_b | inst_ld_h | inst_ld_w
                            | inst_st_b | inst_st_h | inst_st_w | inst_ld_bu | inst_ld_hu
                            | inst_preld | inst_ll_w | inst_sc_w | inst_cacop | inst_bl | inst_jirl | inst_pcaddu12i;
    assign alu_op_sub       = inst_sub_w;
    assign alu_op_slt       = inst_slt | inst_slti | inst_blt | inst_bge;
    assign alu_op_sltu      = inst_sltu | inst_sltui | inst_bltu | inst_bgeu;
    assign alu_op_sll       = inst_slli_w | inst_sll_w;
    assign alu_op_srl       = inst_srli_w | inst_srl_w;
    assign alu_op_sra       = inst_srai_w | inst_sra_w;
    assign alu_op_bypass    = inst_lu12i_w | inst_csrrd | inst_csrwr | inst_csrxchg | inst_invtlb;
    assign alu_op_and       = inst_and | inst_andi;
    assign alu_op_nor       = inst_nor;
    assign alu_op_or        = inst_or | inst_ori;
    assign alu_op_xor       = inst_xor | inst_xori | inst_beq | inst_bne;
    assign alu_op_mul       = inst_mul_w;
    assign alu_op_mulh      = inst_mulh_w;
    assign alu_op_mulhu     = inst_mulh_wu;
    assign alu_op_div       = inst_div_w;
    assign alu_op_divu      = inst_div_wu;
    assign alu_op_mod       = inst_mod_w;
    assign alu_op_modu      = inst_mod_wu;
    assign alu_op_bus       = { 
        alu_op_modu,
        alu_op_mod,
        alu_op_divu,
        alu_op_div,
        alu_op_mulhu,
        alu_op_mulh,
        alu_op_mul,
        alu_op_xor,
        alu_op_or,
        alu_op_nor,
        alu_op_and,
        alu_op_bypass,
        alu_op_sra,
        alu_op_srl,
        alu_op_sll,
        alu_op_sltu,
        alu_op_slt,
        alu_op_sub,
        alu_op_add
    };
    assign src1_rj      = inst_add_w
                        | inst_addi_w
                        | inst_sub_w
                        | inst_ld_b
                        | inst_ld_h
                        | inst_ld_w
                        | inst_st_b
                        | inst_st_h
                        | inst_st_w
                        | inst_ld_bu
                        | inst_ld_hu
                        | inst_preld
                        | inst_ll_w
                        | inst_sc_w
                        | inst_csrxchg
                        | inst_cacop
                        | inst_invtlb
                        | inst_slt
                        | inst_sltu
                        | inst_beq
                        | inst_bne
                        | inst_blt
                        | inst_bltu
                        | inst_bge
                        | inst_bgeu
                        | inst_jirl
                        | inst_slli_w
                        | inst_srli_w
                        | inst_srai_w
                        | inst_and
                        | inst_nor
                        | inst_or
                        | inst_xor
                        | inst_slti
                        | inst_sltui
                        | inst_andi
                        | inst_ori
                        | inst_xori
                        | inst_sll_w
                        | inst_srl_w
                        | inst_sra_w
                        | inst_mul_w
                        | inst_mulh_w
                        | inst_mulh_wu
                        | inst_div_w
                        | inst_mod_w
                        | inst_div_wu
                        | inst_mod_wu;
    assign src1_pc      = inst_bl | inst_jirl | inst_pcaddu12i;
    assign src2_rk_rd   = inst_add_w
                        | inst_sub_w
                        | inst_invtlb
                        | inst_slt
                        | inst_sltu
                        | inst_and
                        | inst_nor
                        | inst_or
                        | inst_xor
                        | inst_sll_w
                        | inst_srl_w
                        | inst_sra_w
                        | inst_beq
                        | inst_bne
                        | inst_blt
                        | inst_bltu
                        | inst_bge
                        | inst_bgeu
                        | inst_mul_w
                        | inst_mulh_w
                        | inst_mulh_wu
                        | inst_div_w
                        | inst_mod_w
                        | inst_div_wu
                        | inst_mod_wu;
    assign src2_4       = inst_bl | inst_jirl;
    assign src2_si20    = inst_lu12i_w | inst_pcaddu12i | inst_csrrd | inst_csrwr | inst_csrxchg;
    assign src2_si12    = inst_addi_w
                        | inst_ld_b
                        | inst_ld_h
                        | inst_ld_w
                        | inst_st_b
                        | inst_st_h
                        | inst_st_w
                        | inst_ld_bu
                        | inst_ld_hu
                        | inst_preld
                        | inst_cacop
                        | inst_slti
                        | inst_sltui;
    assign src2_si14    = inst_ll_w | inst_sc_w;
    assign src2_ui12    = inst_andi
                        | inst_ori
                        | inst_xori;
    assign src2_ui5     = inst_slli_w
                        | inst_srli_w
                        | inst_srai_w;
    assign alu_src1 = final_rj;
    assign alu_src2 = ({32{src2_rk_rd}} & final_rk_rd                 )
                    | ({32{src2_4    }} & 32'd4                       )
                    | ({32{src2_si20 }} & {si20, 12'b0}               )
                    | ({32{src2_si12 }} & {{20{i12 [11]}}, i12}       )
                    | ({32{src2_si14 }} & {{16{si14[13]}}, si14, 2'b0})
                    | ({32{src2_ui12 }} & {20'b0, i12}                )
                    | ({32{src2_ui5  }} & {27'b0, ui5}                );
//jump
    assign always_br        = inst_b | inst_bl | inst_jirl;
    assign br_eq            = inst_beq | inst_bne;
    assign br_lt            = inst_blt | inst_bltu;
    assign br_ge            = inst_bge | inst_bgeu;
    assign br_opst          = inst_bne | inst_bltu | inst_bgeu;    //Opposite condition
    assign br_cond          = {always_br, br_opst, br_ge, br_lt, br_eq};
    assign br_inst          = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_b | inst_bl | inst_jirl;
    assign br_type          = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    assign call_type        = inst_bl || (inst_jirl && rd_eq_1 && (offs_15_0 == 16'b0));
    assign ret_type         = inst_jirl && rd_eq_0 && rj_eq_1 && (offs_15_0 == 16'b0);
    assign jump_type        = inst_b || (inst_jirl && ~(call_type || ret_type));
    assign btb_type         = {br_type, jump_type, call_type, ret_type};
    assign br_src1_pc       = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_b | inst_bl;
    assign br_src2_ofst16   = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_jirl;
    assign br_src2_ofst26   = inst_b | inst_bl;
//excp
    assign inst_exist   = inst_add_w    
                        | inst_addi_w   
                        | inst_sub_w    
                        | inst_mul_w    
                        | inst_mulh_w   
                        | inst_mulh_wu  
                        | inst_div_w    
                        | inst_mod_w    
                        | inst_div_wu   
                        | inst_mod_wu   
                        | inst_lu12i_w  
                        | inst_pcaddu12i
                        | inst_and 
                        | inst_nor 
                        | inst_or  
                        | inst_xor 
                        | inst_andi
                        | inst_ori 
                        | inst_xori
                        | inst_sll_w 
                        | inst_srl_w 
                        | inst_sra_w 
                        | inst_slli_w
                        | inst_srli_w
                        | inst_srai_w
                        | inst_slt  
                        | inst_sltu 
                        | inst_slti 
                        | inst_sltui
                        | inst_beq 
                        | inst_bne 
                        | inst_blt 
                        | inst_bge 
                        | inst_bltu
                        | inst_bgeu
                        | inst_b   
                        | inst_bl  
                        | inst_jirl
                        | inst_ld_b     
                        | inst_ld_h     
                        | inst_ld_w     
                        | inst_ld_bu    
                        | inst_ld_hu    
                        | inst_preld    
                        | inst_rdcntvl_w
                        | inst_rdcntvh_w
                        | inst_rdcntid  
                        | inst_st_b   
                        | inst_st_h   
                        | inst_st_w   
                        | inst_ll_w   
                        | inst_sc_w   
                        | inst_dbar   
                        | inst_ibar   
                        | inst_syscall
                        | inst_break  
                        | inst_cacop  
                        | inst_csrrd  
                        | inst_csrwr  
                        | inst_csrxchg
                        | inst_tlbsrch
                        | inst_tlbrd  
                        | inst_tlbwr  
                        | inst_tlbfill
                        | (inst_invtlb & ((rd == 5'd0)
                                        | (rd == 5'd1)
                                        | (rd == 5'd2)
                                        | (rd == 5'd3)
                                        | (rd == 5'd4)
                                        | (rd == 5'd5)
                                        | (rd == 5'd6)))
                        | inst_ertn   
                        | inst_idle;
    assign is_fp_inst   = 1'b0; //fp unimplemented now
    assign is_priv_inst = inst_csrrd | inst_csrwr | inst_csrxchg | (inst_cacop & ~cacop_opcode[2])
                        | inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb | inst_ertn | inst_idle;
    assign ex_int       = has_int;
    assign ex_sys       = inst_syscall;
    assign ex_break     = inst_break;
    assign ex_ine       = ~inst_exist;
    assign ex_ipe       = is_priv_inst && (crmd_plv == 2'd3);
    assign ex_fpd       = is_fp_inst   && (euen_fpe == 1'b0);
    assign id_any_ex    = ex_int | ex_sys | ex_break | ex_ine | ex_ipe | ex_fpd;
    assign id_ex_bus    = {if_ex_bus_reg, ex_int, ex_sys, ex_break, ex_ine, ex_ipe, ex_fpd};
//id2exe_bus
    assign ras_chkpt    = ras_chkpt_reg;
    assign pc           = pc_reg;
    assign rd_value     = ({32{br_src2_ofst16}} & {{14{offs_15_0[15]}}, offs_15_0, 2'b0})
                        | ({32{br_src2_ofst26}} & {{4{offs_25_16[9]}}, offs_25_16, offs_15_0, 2'b0})
                        | ({32{~(br_src2_ofst16 | br_src2_ofst26)}} & final_rk_rd);    //mux with pc_adder's 2nd src
    assign id_isidle    = inst_idle;
    assign cacop_op     = cacop_valid ? cacop_opcode : btb_type; //mux with btb_type
    assign id_isertn    = inst_ertn;
    assign if_any_ex    = if_any_ex_reg;
    assign id2exe_bus   = {
        ras_chkpt,
        pc,
        forwrd_on_exe,
        forwrd_on_mem,
        forwrd_on_wb,
        forwrd_ptr,
        src1_pc,
        alu_src1,
        alu_src2,
        rd_value,
        rd_addr,
        alu_op_bus,
        multi_circle,
        id_isidle,
        mem_ld,
        mem_st,
        mem_isll,
        mem_issc,
        mem_ispreld,
        mem_len,
        mem_usign,
        cacop_valid,
        cacop_target,
        cacop_op,
        br_inst,
        br_src1_pc,
        tlb_op,
        gr_we,
        wb_src,
        csr_we,
        csr_nomask,
        id_isertn,
        id_flush,
        id_ex_bus,
        id_any_ex,
        if_any_ex
    };
//fsm
    assign id_is_fresh  = is_fresh;
    assign id_flush     = inst_ibar | inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb | inst_csrwr | inst_csrxchg | inst_ertn;
    assign any_excp     = if_any_ex_reg | id_any_ex;
    assign stall_now    = any_excp | id_flush;
    assign src_ok       = (need_rj    ? (rj_blocked    ? forwrd_rj_rdy    : 1'b1) : 1'b1)
                        & (need_rk_rd ? (rk_rd_blocked ? forwrd_rk_rd_rdy : 1'b1) : 1'b1);
    assign id_ready_go  = is_hold || (is_fresh && (any_excp || src_ok));
    assign id_allowin   = (is_expired && ~stall_flag) || (id_ready_go && exe_allowin);
    assign new_entry    = if_ready_go && id_allowin;
    always @(posedge clk) begin
        if (rst || ex_flush || pred_flush)
            stall_flag <= 1'b0;
        else if (is_fresh && stall_now)
            stall_flag <= 1'b1;

        if (new_entry)
            if2id_bus_reg <= if2id_bus;

        if (rst || ex_flush || pred_flush)
            id_state    <= expired;
        else begin
            case (id_state)
                expired: 
                    if (new_entry)
                        id_state <= fresh;
                fresh:
                    if (stall_now) begin    //wait for src_ok if stall for id_flush
                        id_state    <= (exe_allowin && (any_excp || src_ok)) ? expired : hold;
                    end else if (id_ready_go)
                        if (exe_allowin) begin
                            if (~new_entry)
                                id_state <= expired;
                        end else
                            id_state <= hold;
                hold: 
                    if (exe_allowin)
                        id_state <= stall_flag ? expired : (new_entry ? fresh : expired);
            endcase
        end
    end
endmodule
