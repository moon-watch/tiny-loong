`include "bus_width.h"
module wb_stage (
    input  wire         clk,
    input  wire         rst,
    output wire         ex_flush,
    output wire         ertn_flush,
    output wire         idle_flush,
    output wire [31:0]  ex_next_pc,
    //prev_stage
    output wire         ll_finished,
    output wire         wb_need_tlb,
    output wire [18:0]  wb_tlb_vppn,
    output wire [ 9:0]  wb_tlb_asid,
    input  wire [`mem_bus_w - 1:0] mem2wb_bus,
    input  wire         mem_ready_go,
    output wire         wb_allowin,
    //regfile
    output wire         gr_wr_en,
    output wire [ 4:0]  gr_wr_addr,
    output wire [31:0]  gr_wr_data,
    //tlb
    input  wire         tlb_found,
    input  wire [ 3:0]  tlb_index,
    output wire [ 3:0]  tlb_r_index,
    input  wire         tlb_r_e,
    input  wire [18:0]  tlb_r_vppn,
    input  wire [ 5:0]  tlb_r_ps,
    input  wire [ 9:0]  tlb_r_asid,
    input  wire         tlb_r_g,
    input  wire [19:0]  tlb_r_ppn0,
    input  wire [ 1:0]  tlb_r_plv0,
    input  wire [ 1:0]  tlb_r_mat0,
    input  wire         tlb_r_d0,
    input  wire         tlb_r_v0,
    input  wire [19:0]  tlb_r_ppn1,
    input  wire [ 1:0]  tlb_r_plv1,
    input  wire [ 1:0]  tlb_r_mat1,
    input  wire         tlb_r_d1,
    input  wire         tlb_r_v1,
    output wire         tlb_we,
    output wire [ 3:0]  tlb_w_index,
    output wire         tlb_w_e,
    output wire [18:0]  tlb_w_vppn,
    output wire [ 5:0]  tlb_w_ps,
    output wire [ 9:0]  tlb_w_asid,
    output wire         tlb_w_g,
    output wire [19:0]  tlb_w_ppn0,
    output wire [ 1:0]  tlb_w_plv0,
    output wire [ 1:0]  tlb_w_mat0,
    output wire         tlb_w_d0,
    output wire         tlb_w_v0,
    output wire [19:0]  tlb_w_ppn1,
    output wire [ 1:0]  tlb_w_plv1,
    output wire [ 1:0]  tlb_w_mat1,
    output wire         tlb_w_d1,
    output wire         tlb_w_v1,
    output wire         invtlb_valid,
    output wire [ 4:0]  invtlb_op,
    //csr
    input  wire         has_int,
    output wire         csr_we,
    output wire [13:0]  csr_num,
    output wire [31:0]  csr_wmask,
    output wire [31:0]  csr_wvalue,
    input  wire [31:0]  csr_rvalue,
    input  wire [ 3:0]  rand_index,
    input  wire [31:0]  asid_r,
    input  wire [31:0]  tid_r,
    input  wire [63:0]  timer64_r,
    output wire         llbit_we,
    output wire         llbit_w,
    output wire         tlb_csr_we,
    output wire [31:0]  tlbidx_w,
    output wire [31:0]  tlbehi_w,
    output wire [31:0]  tlbelo0_w,
    output wire [31:0]  tlbelo1_w,
    output wire [31:0]  asid_w,
    input  wire [31:0]  tlbidx_r,
    input  wire [31:0]  tlbehi_r,
    input  wire [31:0]  tlbelo0_r,
    input  wire [31:0]  tlbelo1_r,
    input  wire [31:0]  tlbrentry_r,
    input  wire [31:0]  eentry_r,
    input  wire [31:0]  estate_r,
    output wire         wb_ex,
    output wire [ 5:0]  wb_ecode,
    output wire [ 8:0]  wb_esubcode,
    output wire [31:0]  wb_pc,
    output wire [31:0]  wb_vaddr,
    //forward
    output wire         forwrd_we,
    output wire [ 2:0]  forwrd_ptr,
    output wire [31:0]  forwrd_res
);
//declaration
    //fsm
    localparam  expired = 2'b01;
    localparam  fresh   = 2'b10;
    reg  [ 1:0] wb_state;
    wire        is_expired = wb_state[0];
    wire        is_fresh   = wb_state[1];
    reg         recovery_mode;  //to do: use is_expired instead :(
    wire        new_entry;
    //mem2wb_bus
    reg [`mem_bus_w - 1:0] mem2wb_bus_reg;
    wire [31:0] pc_reg;
    wire        forwrd_on_wb_reg;
    wire [ 2:0] forwrd_ptr_reg;
    wire [31:0] rj_value_reg;
    wire [31:0] rd_value_reg;
    wire [ 4:0] rd_addr_reg;
    wire        mem_isll_reg;
    wire [ 4:0] tlb_inst_reg;
    wire        id_isidle_reg;
    wire        id_isertn_reg;
    wire        id_flush_reg;
    wire        gr_we_reg;
    wire [ 4:0] wb_src_reg;
    wire        csr_we_reg;
    wire        csr_nomask_reg;
    wire [31:0] mem_result_reg;
    wire        if_any_ex_reg;
    wire        id_any_ex_reg;
    wire        any_excp_reg;
    wire [15:0] mem2wb_ex_bus_reg;
    //excp
    wire        if_adef, if_tlbr, if_pif, if_ppi,
                id_int, id_sys, id_break, id_ine, id_ipe, id_fpd,
                mem_pil, mem_pis, mem_pme, mem_ppi, mem_ale, mem_tlbr;
    //tlb
    wire        is_invtlb, is_tlbfill, is_tlbwr, is_tlbrd, is_tlbsrch;
    wire [ 3:0] tlbidx_idx_r;
    wire [ 5:0] tlbidx_ps_r;
    wire        tlbidx_ne_r;
    wire [18:0] tlbehi_vppn_r;
    wire        tlbelo0_v_r;
    wire        tlbelo0_d_r;
    wire [ 1:0] tlbelo0_plv_r;
    wire [ 1:0] tlbelo0_mat_r;
    wire        tlbelo0_g_r;
    wire [19:0] tlbelo0_ppn_r;
    wire        tlbelo1_v_r;
    wire        tlbelo1_d_r;
    wire [ 1:0] tlbelo1_plv_r;
    wire [ 1:0] tlbelo1_mat_r;
    wire        tlbelo1_g_r;
    wire [19:0] tlbelo1_ppn_r;
    wire [ 9:0] asid_asid_r;
    wire [ 7:0] asid_asidbits_r;
    wire [ 3:0] tlbidx_idx_w;
    wire [ 5:0] tlbidx_ps_w;
    wire        tlbidx_ne_w;
    wire [18:0] tlbehi_vppn_w;
    wire        tlbelo0_v_w;
    wire        tlbelo0_d_w;
    wire [ 1:0] tlbelo0_plv_w;
    wire [ 1:0] tlbelo0_mat_w;
    wire        tlbelo0_g_w;
    wire [19:0] tlbelo0_ppn_w;
    wire        tlbelo1_v_w;
    wire        tlbelo1_d_w;
    wire [ 1:0] tlbelo1_plv_w;
    wire [ 1:0] tlbelo1_mat_w;
    wire        tlbelo1_g_w;
    wire [19:0] tlbelo1_ppn_w;
    wire [ 9:0] asid_asid_w;
//mem2wb_bus
    assign {
        pc_reg,
        forwrd_on_wb_reg,
        forwrd_ptr_reg,
        rj_value_reg,
        rd_value_reg,
        rd_addr_reg,
        mem_isll_reg,
        tlb_inst_reg,
        id_isidle_reg,
        id_isertn_reg,
        id_flush_reg,
        gr_we_reg,
        wb_src_reg,
        csr_we_reg,
        csr_nomask_reg,
        mem_result_reg,
        if_any_ex_reg,
        id_any_ex_reg,
        any_excp_reg,
        mem2wb_ex_bus_reg
    } = mem2wb_bus_reg;
//forward
    assign forwrd_we  = forwrd_on_wb_reg & is_fresh;
    assign forwrd_ptr = forwrd_ptr_reg;
    assign forwrd_res = gr_wr_data;
//llbit
    assign ll_finished  = is_fresh & mem_isll_reg;
    assign llbit_w      = mem_isll_reg;
    assign llbit_we     = ~any_excp_reg & is_fresh & mem_isll_reg;
//excp
    assign wb_ex        = any_excp_reg & ~recovery_mode;
    assign wb_pc        = pc_reg;
    assign wb_vaddr     = rd_value_reg;
    assign ex_flush     = (any_excp_reg | id_flush_reg) & ~recovery_mode;
    assign ertn_flush   = ~any_excp_reg & id_isertn_reg & ~recovery_mode;
    assign idle_flush   = id_isidle_reg & has_int;
    assign ex_next_pc   = any_excp_reg ? ((wb_ecode == 6'h3f) ? tlbrentry_r : eentry_r)
                                       : (pc_reg + 32'd4);
    assign {if_adef, if_tlbr, if_pif, if_ppi,
            id_int, id_sys, id_break, id_ine, id_ipe, id_fpd,
            mem_pil, mem_pis, mem_pme, mem_ppi, mem_ale, mem_tlbr} = mem2wb_ex_bus_reg;
    assign wb_ecode     = id_int ? 6'h0 
                          : if_any_ex_reg ? (if_adef ? 6'h8 : (({6{if_tlbr }} & 6'h3f)
                                                             | ({6{if_pif  }} & 6'h3 )
                                                             | ({6{if_ppi  }} & 6'h7 )))
                                          : id_any_ex_reg  ? (({6{id_sys  }} & 6'hb )
                                                            | ({6{id_break}} & 6'hc )
                                                            | ({6{id_ine  }} & 6'hd )
                                                            | ({6{id_ipe  }} & 6'he )
                                                            | ({6{id_fpd  }} & 6'hf ))
                                                           : mem_ale ? 6'h9
                                                                     : (({6{mem_pil }} & 6'h1 )
                                                                      | ({6{mem_pis }} & 6'h2 )
                                                                      | ({6{mem_pme }} & 6'h4 )
                                                                      | ({6{mem_ppi }} & 6'h7 )
                                                                      | ({6{mem_tlbr}} & 6'h3f));
    assign wb_esubcode  = 9'b0;
//regfile
    assign gr_wr_en   = ~any_excp_reg & is_fresh & gr_we_reg;
    assign gr_wr_addr = rd_addr_reg;
    assign gr_wr_data = ({32{wb_src_reg[0]}} & mem_result_reg  )
                      | ({32{wb_src_reg[1]}} & tid_r           )
                      | ({32{wb_src_reg[2]}} & timer64_r[31: 0])
                      | ({32{wb_src_reg[3]}} & timer64_r[63:32])
                      | ({32{wb_src_reg[4]}} & csr_rvalue      );
//csr
    assign csr_we     = ~any_excp_reg & is_fresh & csr_we_reg;
    assign csr_num    = mem_result_reg[30:17];
    assign csr_wmask  = csr_nomask_reg ? 32'hffffffff : rj_value_reg;
    assign csr_wvalue = rd_value_reg;
//tlb   migrate to csr, to do :(
    assign {is_invtlb, is_tlbfill, is_tlbwr, is_tlbrd, is_tlbsrch} = tlb_inst_reg;
    assign tlb_csr_we   = ~any_excp_reg & is_fresh & (is_tlbsrch | is_tlbrd);
    assign tlb_r_index  = tlbidx_idx_r;
    //search_port
    assign wb_need_tlb  = (is_tlbsrch | is_invtlb) & ~recovery_mode;//@
    assign wb_tlb_vppn  = ({19{is_tlbsrch}} & tlbehi_vppn_r)
                        | ({19{is_invtlb }} & mem_result_reg[31:13]);
    assign wb_tlb_asid  = ({10{is_tlbsrch}} & asid_asid_r)
                        | ({10{is_invtlb }} & rj_value_reg[9:0]);
    //tlbsrch/tlbrd
        //tlbidx
    assign tlbidx_idx_r = tlbidx_r[3:0];
    assign tlbidx_ps_r  = tlbidx_r[29:24];
    assign tlbidx_ne_r  = tlbidx_r[31];
    assign tlbidx_idx_w = ({4{is_tlbsrch}} & (tlb_found ? tlb_index : tlbidx_idx_r))
                        | ({4{is_tlbrd  }} & tlbidx_idx_r);
    assign tlbidx_ps_w  = ({6{is_tlbsrch}} & tlbidx_ps_r)
                        | ({6{is_tlbrd  }} & (tlb_r_e ? tlb_r_ps : 6'b0));
    assign tlbidx_ne_w  = (is_tlbsrch & (tlb_found ? 1'b0 : 1'b1))
                        | (is_tlbrd & (tlb_r_e ? 1'b0 : 1'b1));
    assign tlbidx_w     = {tlbidx_ne_w, 1'b0, tlbidx_ps_w, 20'b0, tlbidx_idx_w};
        //tlbehi
    assign tlbehi_vppn_r = tlbehi_r[31:13];
    assign tlbehi_vppn_w = ({19{is_tlbsrch}} & tlbehi_vppn_r)
                         | ({19{is_tlbrd  }} & (tlb_r_e ? tlb_r_vppn : 19'b0));
    assign tlbehi_w      = {tlbehi_vppn_w, 13'b0};
        //tlbelo0
    assign tlbelo0_v_r      = tlbelo0_r[0];
    assign tlbelo0_d_r      = tlbelo0_r[1];
    assign tlbelo0_plv_r    = tlbelo0_r[3:2];
    assign tlbelo0_mat_r    = tlbelo0_r[5:4];
    assign tlbelo0_g_r      = tlbelo0_r[6];
    assign tlbelo0_ppn_r    = tlbelo0_r[27:8];
    assign tlbelo0_v_w      = (is_tlbsrch & tlbelo0_v_r)
                            | (is_tlbrd   & (tlb_r_e ? tlb_r_v0 : 1'b0));
    assign tlbelo0_d_w      = (is_tlbsrch & tlbelo0_d_r)
                            | (is_tlbrd   & (tlb_r_e ? tlb_r_d0 : 1'b0));
    assign tlbelo0_plv_w    = ({2{is_tlbsrch}} & tlbelo0_plv_r)
                            | ({2{is_tlbrd  }} & (tlb_r_e ? tlb_r_plv0 : 2'b0));
    assign tlbelo0_mat_w    = ({2{is_tlbsrch}} & tlbelo0_mat_r)
                            | ({2{is_tlbrd  }} & (tlb_r_e ? tlb_r_mat0 : 2'b0));
    assign tlbelo0_g_w      = (is_tlbsrch & tlbelo0_g_r)
                            | (is_tlbrd   & (tlb_r_e ? tlb_r_g : 1'b0));
    assign tlbelo0_ppn_w    = ({20{is_tlbsrch}} & tlbelo0_ppn_r)
                            | ({20{is_tlbrd  }} & (tlb_r_e ? tlb_r_ppn0 : 20'b0));
    assign tlbelo0_w        = {4'b0, tlbelo0_ppn_w, 1'b0, tlbelo0_g_w, tlbelo0_mat_w,
                                tlbelo0_plv_w, tlbelo0_d_w, tlbelo0_v_w};
        //tlbelo1
    assign tlbelo1_v_r      = tlbelo1_r[0];
    assign tlbelo1_d_r      = tlbelo1_r[1];
    assign tlbelo1_plv_r    = tlbelo1_r[3:2];
    assign tlbelo1_mat_r    = tlbelo1_r[5:4];
    assign tlbelo1_g_r      = tlbelo1_r[6];
    assign tlbelo1_ppn_r    = tlbelo1_r[27:8];
    assign tlbelo1_v_w      = (is_tlbsrch & tlbelo1_v_r)
                            | (is_tlbrd   & (tlb_r_e ? tlb_r_v1 : 1'b0));
    assign tlbelo1_d_w      = (is_tlbsrch & tlbelo1_d_r)
                            | (is_tlbrd   & (tlb_r_e ? tlb_r_d1 : 1'b0));
    assign tlbelo1_plv_w    = ({2{is_tlbsrch}} & tlbelo1_plv_r)
                            | ({2{is_tlbrd  }} & (tlb_r_e ? tlb_r_plv1 : 2'b0));
    assign tlbelo1_mat_w    = ({2{is_tlbsrch}} & tlbelo1_mat_r)
                            | ({2{is_tlbrd  }} & (tlb_r_e ? tlb_r_mat1 : 2'b0));
    assign tlbelo1_g_w      = (is_tlbsrch & tlbelo1_g_r)
                            | (is_tlbrd   & (tlb_r_e ? tlb_r_g : 1'b0));
    assign tlbelo1_ppn_w    = ({20{is_tlbsrch}} & tlbelo1_ppn_r)
                            | ({20{is_tlbrd  }} & (tlb_r_e ? tlb_r_ppn1 : 20'b0));
    assign tlbelo1_w        = {4'b0, tlbelo1_ppn_w, 1'b0, tlbelo1_g_w, tlbelo1_mat_w,
                                tlbelo1_plv_w, tlbelo1_d_w, tlbelo1_v_w};
        //asid
    assign asid_asid_r      = asid_r[9:0];
    assign asid_asidbits_r  = asid_r[23:16];
    assign asid_asid_w      = ({20{is_tlbsrch}} & asid_asid_r)
                            | ({20{is_tlbrd  }} & (tlb_r_e ? tlb_r_asid : 10'b0));
    assign asid_w           = {8'b0, asid_asidbits_r, 6'b0, asid_asid_w};
    //invtlb
    assign invtlb_valid = ~any_excp_reg & is_fresh & is_invtlb;
    assign invtlb_op    = rd_addr_reg;
    //tlbwr/tlbfill
    assign tlb_we       = ~any_excp_reg & is_fresh & (is_tlbwr | is_tlbfill);
    assign tlb_w_index  = ({4{is_tlbwr  }} & tlbidx_idx_r)
                        | ({4{is_tlbfill}} & rand_index);
    assign tlb_w_e      = (estate_r[21:16] == 6'h3f) ? 1'b1 : (~tlbidx_ne_r);
    assign tlb_w_vppn   = tlbehi_vppn_r;
    assign tlb_w_ps     = tlbidx_ps_r;
    assign tlb_w_asid   = asid_asid_r;
    assign tlb_w_g      = tlbelo0_g_r & tlbelo1_g_r;
    assign tlb_w_ppn0   = tlbelo0_ppn_r;
    assign tlb_w_plv0   = tlbelo0_plv_r;
    assign tlb_w_mat0   = tlbelo0_mat_r;
    assign tlb_w_d0     = tlbelo0_d_r;
    assign tlb_w_v0     = tlbelo0_v_r;
    assign tlb_w_ppn1   = tlbelo1_ppn_r;
    assign tlb_w_plv1   = tlbelo1_plv_r;
    assign tlb_w_mat1   = tlbelo1_mat_r;
    assign tlb_w_d1     = tlbelo1_d_r;
    assign tlb_w_v1     = tlbelo1_v_r;
//fsm
    assign wb_allowin = 1'b1;
    assign new_entry  = mem_ready_go;
    always @(posedge clk) begin
        if (rst || ex_flush)
            recovery_mode <= 1'b1;
        else if (new_entry)
            recovery_mode <= 1'b0;

        if (new_entry)
            mem2wb_bus_reg <= mem2wb_bus;

        if (rst || ex_flush)
            wb_state <= expired;
        else begin
            case (wb_state)
                expired: 
                    if (new_entry)
                        wb_state <= fresh;
                fresh: 
                    if (~new_entry)
                        wb_state <= expired;
            endcase
        end
    end
endmodule