`include "csr.h"
module csr #(
    parameter COREID = 9'h0
) (
    input   wire        clk,
    input   wire        rst,
    input   wire        csr_we,
    input   wire [13:0] csr_num,
    input   wire [31:0] csr_wmask,
    input   wire [31:0] csr_wvalue,
    output  wire [31:0] csr_rvalue,
    output  wire [ 3:0] rand_index, //TLBFILL random index
//Common used csr out port
    output  wire [31:0] crmd_r,
    output  wire [31:0] asid_r,
    output  wire [31:0] dmw0_r,
    output  wire [31:0] dmw1_r,
    output  wire [31:0] euen_r,
    output  wire [31:0] tid_r,
    output  wire [63:0] timer64_r,
    output  wire [31:0] tlbrentry_r,
    output  wire [31:0] eentry_r,
    output  wire [31:0] era_r,
//llbit
    input   wire        llbit_we,
    output  wire        llbit_r,
    input   wire        llbit_w,
//CSR rw port for TLB instructions
    input   wire        tlb_csr_we,
    input   wire [31:0] tlbidx_w,
    input   wire [31:0] tlbehi_w,
    input   wire [31:0] tlbelo0_w,
    input   wire [31:0] tlbelo1_w,
    input   wire [31:0] asid_w,
    output  wire [31:0] tlbidx_r,
    output  wire [31:0] tlbehi_r,
    output  wire [31:0] tlbelo0_r,
    output  wire [31:0] tlbelo1_r,
    output  wire [31:0] estate_r,
//Exceptions
    input   wire        wb_ex,       //Exception from write back stage
    input   wire        ertn_flush,  //ERTN(exception return) instruction needs to flush the pipeline
    input   wire [7:0]  hw_int_in,   //8 external hardware interrupt
    output  wire        has_int,
    input   wire        ipi_int_in,  //Inter-processor interrupt
    input   wire [5:0]  wb_ecode,    //Exception code
    input   wire [8:0]  wb_esubcode, //Exception subcode
    input   wire [31:0] wb_pc,       //The pc of the exception instruction
    input   wire [31:0] wb_vaddr     //The virtual address that raises the exception
);
//Regs
    reg [ 1:0] csr_crmd_plv;
    reg        csr_crmd_ie;
    reg        csr_crmd_da;
    reg        csr_crmd_pg;
    reg [ 1:0] csr_crmd_datf;
    reg [ 1:0] csr_crmd_datm;
    reg [ 1:0] csr_prmd_pplv;
    reg        csr_prmd_pie;
    reg        csr_euen_fpe;
    reg [12:0] csr_ecfg_lie;
    reg [12:0] csr_estat_is;
    reg [ 5:0] csr_estat_ecode;
    reg [ 8:0] csr_estat_esubcode;
    reg [31:0] csr_era_pc;
    reg [31:0] csr_badv_vaddr;
    reg [25:0] csr_eentry_va;
    reg [31:0] csr_save0_data;
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    reg        llbit;
    reg        csr_llbctl_klo;
    reg [ 3:0] csr_tlbidx_index;
    reg [ 5:0] csr_tlbidx_ps;
    reg        csr_tlbidx_ne;
    reg [18:0] csr_tlbehi_vppn;
    reg        csr_tlbelo0_v;
    reg        csr_tlbelo0_d;
    reg [ 1:0] csr_tlbelo0_plv;
    reg [ 1:0] csr_tlbelo0_mat;
    reg        csr_tlbelo0_g;
    reg [19:0] csr_tlbelo0_ppn;
    reg        csr_tlbelo1_v;
    reg        csr_tlbelo1_d;
    reg [ 1:0] csr_tlbelo1_plv;
    reg [ 1:0] csr_tlbelo1_mat;
    reg        csr_tlbelo1_g;
    reg [19:0] csr_tlbelo1_ppn;
    reg [ 9:0] csr_asid_asid;
    reg [19:0] csr_pgdl_base;
    reg [19:0] csr_pgdh_base;
    reg [25:0] csr_tlbrentry_pa;
    reg        csr_dmw0_plv0;
    reg        csr_dmw0_plv3;
    reg [ 1:0] csr_dmw0_mat;
    reg [ 2:0] csr_dmw0_pseg;
    reg [ 2:0] csr_dmw0_vseg;
    reg        csr_dmw1_plv0;
    reg        csr_dmw1_plv3;
    reg [ 1:0] csr_dmw1_mat;
    reg [ 2:0] csr_dmw1_pseg;
    reg [ 2:0] csr_dmw1_vseg;
    reg [63:0] timer64;
    reg [31:0] csr_tid_tid;
    reg        csr_tcfg_en;
    reg        csr_tcfg_periodic;
    reg [29:0] csr_tcfg_initval;
    reg [31:0] timer_cnt;
//CRMD
    always @(posedge clk) begin
        if (rst) begin
            csr_crmd_plv  <= 2'b00;
            csr_crmd_ie   <= 1'b0;
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
            csr_crmd_datf <= 2'b00;
            csr_crmd_datm <= 2'b00;
        end else if (wb_ex) begin
            csr_crmd_plv <= 2'b00;
            csr_crmd_ie  <= 1'b0;
            csr_crmd_da <= (wb_ecode == 6'h3f) ? 1'b1 : csr_crmd_da;
            csr_crmd_pg <= (wb_ecode == 6'h3f) ? 1'b0 : csr_crmd_pg;
        end else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
            csr_crmd_da <= (csr_estat_ecode == 6'h3f) ? 1'b0 : csr_crmd_da;
            csr_crmd_pg <= (csr_estat_ecode == 6'h3f) ? 1'b1 : csr_crmd_pg;
        end else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_plv  <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                          | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
            csr_crmd_ie   <= csr_wmask[`CSR_CRMD_IE ] & csr_wvalue[`CSR_CRMD_IE ]
                          | ~csr_wmask[`CSR_CRMD_IE ] & csr_crmd_ie;
            csr_crmd_da   <= csr_wmask[`CSR_CRMD_DA ] & csr_wvalue[`CSR_CRMD_DA ]
                          | ~csr_wmask[`CSR_CRMD_DA ] & csr_crmd_da;
            csr_crmd_pg   <= csr_wmask[`CSR_CRMD_PG ] & csr_wvalue[`CSR_CRMD_PG ]
                          | ~csr_wmask[`CSR_CRMD_PG ] & csr_crmd_pg;
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF ] & csr_wvalue[`CSR_CRMD_DATF ]
                          | ~csr_wmask[`CSR_CRMD_DATF ] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM ] & csr_wvalue[`CSR_CRMD_DATM ]
                          | ~csr_wmask[`CSR_CRMD_DATM ] & csr_crmd_datm;
        end
    end
    wire [31:0] csr_crmd = {23'b0
                          , csr_crmd_datm
                          , csr_crmd_datf
                          , csr_crmd_pg
                          , csr_crmd_da
                          , csr_crmd_ie
                          , csr_crmd_plv};
//PRMD
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end else if (csr_we && csr_num == `CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                          | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE ] & csr_wvalue[`CSR_PRMD_PIE ]
                          | ~csr_wmask[`CSR_PRMD_PIE ] & csr_prmd_pie;
        end
    end
    wire [31:0] csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};
//EUEN
    always @(posedge clk) begin
        if (rst)
            csr_euen_fpe <= 1'b0;
        else if (csr_we & csr_num == `CSR_EUEN)
            csr_euen_fpe <= csr_wmask[`CSR_EUEN_FPE] & csr_wvalue[`CSR_EUEN_FPE]
                         | ~csr_wmask[`CSR_EUEN_FPE] & csr_euen_fpe;
    end
    wire [31:0] csr_euen = {31'b0, csr_euen_fpe};
//ECFG
    always @(posedge clk) begin
        if (rst)
            csr_ecfg_lie <= 13'h0;
        else if (csr_we && csr_num == `CSR_ECFG)    //13'h1bff: csr_ecfg_lie[10] is reserved, always zero
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                         | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end
    wire [31:0] csr_ecfg = {19'b0, csr_ecfg_lie[12:11], 1'b0, csr_ecfg_lie[9:0]};
    wire [12:0] csr_ecfg_lie_r = csr_ecfg[12:0];
//ESTAT
    //IS
    assign has_int = (|(csr_estat_is & csr_ecfg_lie_r)) & csr_crmd_ie;
    always @(posedge clk) begin
        if (rst)
            csr_estat_is[1:0] <= 2'b00;
        else if (csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                              | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];

        csr_estat_is[9:2] <= hw_int_in;

        csr_estat_is[10]  <= 1'b0;
        if (timer_cnt == 32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_num == `CSR_TICLR && 
                 csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
            csr_estat_is[11] <= 1'b0;

        csr_estat_is[12] <= ipi_int_in;
    end
    //Ecode Esubcode
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode     <= wb_ecode;
            csr_estat_esubcode  <= wb_esubcode;
        end
    end
    wire [31:0] csr_estat = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
//ERA
    //PC
    always @(posedge clk) begin
        if (wb_ex)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num == `CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                       | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
    end
    wire [31:0] csr_era = csr_era_pc;
//BADV
    //Vaddr
    wire wb_ex_addr_err = wb_ecode == `ECODE_TLBR
                       || wb_ecode == `ECODE_ADE
                       || wb_ecode == `ECODE_ALE
                       || wb_ecode == `ECODE_PIL
                       || wb_ecode == `ECODE_PIS
                       || wb_ecode == `ECODE_PIF
                       || wb_ecode == `ECODE_PME
                       || wb_ecode == `ECODE_PPI;
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode == `ECODE_ADE &&
                               wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
        else if (csr_we && csr_num == `CSR_BADV)
            csr_badv_vaddr <= csr_wmask[`CSR_BADV_VADDR] & csr_wvalue[`CSR_BADV_VADDR]
                           | ~csr_wmask[`CSR_BADV_VADDR] & csr_badv_vaddr;
    end
    wire [31:0] csr_badv = csr_badv_vaddr;
//EENTRY
    //VA
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                          | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end
    wire [31:0] csr_eentry = {csr_eentry_va, 6'b0};
//CPUID
    wire [31:0] csr_cpuid = {23'd0, COREID};
//SAVE0~3
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && csr_num == `CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && csr_num == `CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && csr_num == `CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end
    wire [31:0] csr_save0 = csr_save0_data;
    wire [31:0] csr_save1 = csr_save1_data;
    wire [31:0] csr_save2 = csr_save2_data;
    wire [31:0] csr_save3 = csr_save3_data;
//LLBCTL
    always @(posedge clk) begin
        if (rst)
            csr_llbctl_klo <= 1'b0;
        else if (ertn_flush)
            csr_llbctl_klo <= 1'b0;
        else if (csr_we && csr_num == `CSR_LLBCTL)
            csr_llbctl_klo <= csr_wmask[`CSR_LLBCTL_KLO] & csr_wvalue[`CSR_LLBCTL_KLO]
                           | ~csr_wmask[`CSR_LLBCTL_KLO] & csr_llbctl_klo;

        if (ertn_flush && (csr_llbctl_klo != 1'b1))
            llbit <= 1'b0;
        else if (csr_we && csr_num == `CSR_LLBCTL &&
                    csr_wmask[`CSR_LLBCTL_WCLLB] && csr_wvalue[`CSR_LLBCTL_WCLLB])
            llbit <= 1'b0;
        else if (llbit_we)
            llbit <= llbit_w;
    end
    wire [31:0] csr_llbctl = {29'b0, csr_llbctl_klo, 1'b0, llbit};
//TLBIDX
    always @(posedge clk) begin
        if (csr_we & csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]
                             | ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
            csr_tlbidx_ps    <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                             | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
            csr_tlbidx_ne    <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                             | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        end else if (tlb_csr_we) begin
            csr_tlbidx_index <= tlbidx_w[`CSR_TLBIDX_INDEX];
            csr_tlbidx_ps    <= tlbidx_w[`CSR_TLBIDX_PS];
            csr_tlbidx_ne    <= tlbidx_w[`CSR_TLBIDX_NE];
        end
    end
    assign csr_tlbidx = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
//TLBEHI
    wire wb_ex_pg_err = wb_ecode == `ECODE_TLBR
                     || wb_ecode == `ECODE_PIL
                     || wb_ecode == `ECODE_PIS
                     || wb_ecode == `ECODE_PIF
                     || wb_ecode == `ECODE_PME
                     || wb_ecode == `ECODE_PPI;
    always @(posedge clk) begin
        if (wb_ex & wb_ex_pg_err)
            csr_tlbehi_vppn <= wb_vaddr[31:13];
        else if (tlb_csr_we)
            csr_tlbehi_vppn <= tlbehi_w[`CSR_TLBEHI_VPPN];
        else if (csr_we && csr_num == `CSR_TLBEHI)
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                            | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
    end
    wire [31:0] csr_tlbehi = {csr_tlbehi_vppn, 13'b0};
//TLBELO0
    always @(posedge clk) begin
        if (tlb_csr_we) begin
            csr_tlbelo0_v   <= tlbelo0_w[`CSR_TLBELO_V];
            csr_tlbelo0_d   <= tlbelo0_w[`CSR_TLBELO_D];
            csr_tlbelo0_plv <= tlbelo0_w[`CSR_TLBELO_PLV];
            csr_tlbelo0_mat <= tlbelo0_w[`CSR_TLBELO_MAT];
            csr_tlbelo0_g   <= tlbelo0_w[`CSR_TLBELO_G];
            csr_tlbelo0_ppn <= tlbelo0_w[`CSR_TLBELO_PPN];
        end else if (csr_we && csr_num == `CSR_TLBELO0) begin
            csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                            | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo0_v;
            csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                            | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo0_d;
            csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                            | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
            csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                            | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
            csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                            | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo0_g;
            csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                            | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        end
    end
    wire [31:0] csr_tlbelo0 = {3'b0, csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat
                             , csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
//TLBELO1
    always @(posedge clk) begin
        if (tlb_csr_we) begin
            csr_tlbelo1_v   <= tlbelo1_w[`CSR_TLBELO_V];
            csr_tlbelo1_d   <= tlbelo1_w[`CSR_TLBELO_D];
            csr_tlbelo1_plv <= tlbelo1_w[`CSR_TLBELO_PLV];
            csr_tlbelo1_mat <= tlbelo1_w[`CSR_TLBELO_MAT];
            csr_tlbelo1_g   <= tlbelo1_w[`CSR_TLBELO_G];
            csr_tlbelo1_ppn <= tlbelo1_w[`CSR_TLBELO_PPN];
        end else if (csr_we && csr_num == `CSR_TLBELO1) begin
            csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                            | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo1_v;
            csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                            | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo1_d;
            csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                            | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
            csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                            | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
            csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                            | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo1_g;
            csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                            | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        end
    end
    wire [31:0] csr_tlbelo1 = {3'b0, csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat
                             , csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
//ASID
    always @(posedge clk) begin
        if (tlb_csr_we)
            csr_asid_asid <= asid_w[`CSR_ASID_ASID];
        else if (csr_we && csr_num == `CSR_ASID)
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                          | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
    end
    wire [31:0] csr_asid = {8'b0, 8'd10, 6'b0, csr_asid_asid};
//PGDL
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_PGDL)
            csr_pgdl_base <= csr_wmask[`CSR_PGD_BASE] & csr_wvalue[`CSR_PGD_BASE]
                          | ~csr_wmask[`CSR_PGD_BASE] & csr_pgdl_base;
    end
    wire [31:0] csr_pgdl = {csr_pgdl_base, 12'b0};
//PGDH
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_PGDH)
            csr_pgdh_base <= csr_wmask[`CSR_PGD_BASE] & csr_wvalue[`CSR_PGD_BASE]
                          | ~csr_wmask[`CSR_PGD_BASE] & csr_pgdh_base;
    end
    wire [31:0] csr_pgdh = {csr_pgdh_base, 12'b0};
//PGD
    wire [31:0] csr_pgd = {(csr_badv[31] ? csr_pgdh_base : csr_pgdl_base), 12'b0};
//TLBRENTRY
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_TLBRENTRY)
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                             | ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
    end
    wire [31:0] csr_tlbrentry = {csr_tlbrentry_pa, 6'b0};
//DMW0~1
    always @(posedge clk) begin
        if (rst) begin
            csr_dmw0_plv0 <= 1'b0;
            csr_dmw0_plv3 <= 1'b0;
        end else if (csr_we && csr_num == `CSR_DMW0) begin
            csr_dmw0_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                          | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0;
            csr_dmw0_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                          | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3;
            csr_dmw0_mat  <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                          | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw0_mat;
            csr_dmw0_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                          | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
            csr_dmw0_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                          | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;
        end
    end
    wire [31:0] csr_dmw0 = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat,
                            csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
//DMW1
    always @(posedge clk) begin
        if (rst) begin
            csr_dmw1_plv0 <= 1'b0;
            csr_dmw1_plv3 <= 1'b0;
        end else if (csr_we && csr_num == `CSR_DMW1) begin
            csr_dmw1_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                          | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0;
            csr_dmw1_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                          | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3;
            csr_dmw1_mat  <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                          | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw1_mat;
            csr_dmw1_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                          | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
            csr_dmw1_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                          | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;
        end
    end
    wire [31:0] csr_dmw1 = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat,
                            csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
//Timer
    //Timer64
    always @(posedge clk) begin
        if (rst)
            timer64 <= 64'b0;
        else
            timer64 <= timer64 + 1'b1;
    end
    //TID
    always @(posedge clk) begin
        if (rst)
            csr_tid_tid <= {23'b0, COREID};
        else if (csr_we && csr_num == `CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end
    wire [31:0] csr_tid = csr_tid_tid;
    //TCFG
    always @(posedge clk) begin
        if (rst)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num == `CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;

        if (csr_we && csr_num == `CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC] & csr_wvalue[`CSR_TCFG_PERIODIC]
                              | ~csr_wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITVAL ] & csr_wvalue[`CSR_TCFG_INITVAL ]
                              | ~csr_wmask[`CSR_TCFG_INITVAL ] & csr_tcfg_initval;
        end
    end
    wire [31:0] csr_tcfg = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    //TVAL and timer implementation
    wire [31:0] tcfg_next_value =  csr_wmask & csr_wvalue
                                | ~csr_wmask & csr_tcfg;
    always @(posedge clk) begin
        if (rst)
            timer_cnt <= 32'hffffffff;  //Restart counter when tcfg is configured & en == 1
        else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b00};
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
            if (timer_cnt == 32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b00};
            else
                timer_cnt <= timer_cnt - 1'b1;
        end
    end
    wire [31:0] csr_tval        =  timer_cnt;
    //TICLR
    wire [31:0] csr_ticlr = 32'b0;

    assign csr_rvalue = ({32{csr_num == `CSR_CRMD     }} & csr_crmd     )|
                        ({32{csr_num == `CSR_PRMD     }} & csr_prmd     )|
                        ({32{csr_num == `CSR_EUEN     }} & csr_euen     )|
                        ({32{csr_num == `CSR_ECFG     }} & csr_ecfg     )|
                        ({32{csr_num == `CSR_ESTAT    }} & csr_estat    )|
                        ({32{csr_num == `CSR_ERA      }} & csr_era      )|
                        ({32{csr_num == `CSR_BADV     }} & csr_badv     )|
                        ({32{csr_num == `CSR_EENTRY   }} & csr_eentry   )|
                        ({32{csr_num == `CSR_CPUID    }} & csr_cpuid    )|
                        ({32{csr_num == `CSR_SAVE0    }} & csr_save0    )|
                        ({32{csr_num == `CSR_SAVE1    }} & csr_save1    )|
                        ({32{csr_num == `CSR_SAVE2    }} & csr_save2    )|
                        ({32{csr_num == `CSR_SAVE3    }} & csr_save3    )|
                        ({32{csr_num == `CSR_LLBCTL   }} & csr_llbctl   )|
                        ({32{csr_num == `CSR_TLBIDX   }} & csr_tlbidx   )|
                        ({32{csr_num == `CSR_TLBEHI   }} & csr_tlbehi   )|
                        ({32{csr_num == `CSR_TLBELO0  }} & csr_tlbelo0  )|
                        ({32{csr_num == `CSR_TLBELO1  }} & csr_tlbelo1  )|
                        ({32{csr_num == `CSR_ASID     }} & csr_asid     )|
                        ({32{csr_num == `CSR_PGDL     }} & csr_pgdl     )|
                        ({32{csr_num == `CSR_PGDH     }} & csr_pgdh     )|
                        ({32{csr_num == `CSR_PGD      }} & csr_pgd      )|
                        ({32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry)|
                        ({32{csr_num == `CSR_DMW0     }} & csr_dmw0     )|
                        ({32{csr_num == `CSR_DMW1     }} & csr_dmw1     )|
                        ({32{csr_num == `CSR_TID      }} & csr_tid      )|
                        ({32{csr_num == `CSR_TCFG     }} & csr_tcfg     )|
                        ({32{csr_num == `CSR_TVAL     }} & csr_tval     )|
                        ({32{csr_num == `CSR_TICLR    }} & csr_ticlr    );
    assign crmd_r       = csr_crmd;
    assign asid_r       = csr_asid;
    assign dmw0_r       = csr_dmw0;
    assign dmw1_r       = csr_dmw1;
    assign euen_r       = csr_euen;
    assign tid_r        = csr_tid;
    assign timer64_r    = timer64;
    assign llbit_r      = llbit;
    assign tlbidx_r     = csr_tlbidx;
    assign tlbehi_r     = csr_tlbehi;
    assign tlbelo0_r    = csr_tlbelo0;
    assign tlbelo1_r    = csr_tlbelo1;
    assign tlbrentry_r  = csr_tlbrentry;
    assign eentry_r     = csr_eentry;
    assign era_r        = csr_era;
    assign estate_r     = csr_estat;
    assign rand_index   = timer64[3:0];
endmodule