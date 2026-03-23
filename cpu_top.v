`include "csr.h"
`include "bus_width.h"
module cpu_top (
    input  wire         clk,
    input  wire         rst,
    input  wire [ 7:0]  hw_int_in,
    output wire [ 3:0]  arid,
    output wire [31:0]  araddr,
    output wire [ 7:0]  arlen,
    output wire [ 2:0]  arsize,
    output wire [ 1:0]  arburst,
    output wire [ 1:0]  arlock,
    output wire [ 3:0]  arcache,
    output wire [ 2:0]  arprot,
    output wire         arvalid,
    input  wire         arready,
    input  wire [ 3:0]  rid,
    input  wire [31:0]  rdata,
    input  wire [ 1:0]  rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,
    output wire [ 3:0]  awid,
    output wire [31:0]  awaddr,
    output wire [ 7:0]  awlen,
    output wire [ 2:0]  awsize,
    output wire [ 1:0]  awburst,
    output wire [ 1:0]  awlock,
    output wire [ 3:0]  awcache,
    output wire [ 2:0]  awprot,
    output wire         awvalid,
    input  wire         awready,
    output wire [ 3:0]  wid,
    output wire [31:0]  wdata,
    output wire [ 3:0]  wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,
    input  wire [ 3:0]  bid,
    input  wire [ 1:0]  bresp,
    input  wire         bvalid,
    output wire         bready,
//debug
    output wire         debug_gr_we,
    output wire [ 4:0]  debug_gr_waddr,
    output wire [31:0]  debug_gr_wdata,
    output wire [31:0]  debug_pc
);
//Wire daclaretion
    //axi_mux
    wire [31:0]  icache_axi_araddr;
    wire         icache_axi_arvalid;
    wire         icache_axi_arready;
    wire [ 2:0]  icache_axi_arsize;
    wire [ 7:0]  icache_axi_arlen;
    wire [ 1:0]  icache_axi_arburst;
    wire [31:0]  icache_axi_rdata;
    wire         icache_axi_rvalid;
    wire         icache_axi_rready;
    wire         icache_axi_rlast;
    wire [ 1:0]  icache_axi_rresp;
    wire [31:0]  dcache_axi_awaddr;
    wire         dcache_axi_awvalid;
    wire         dcache_axi_awready;
    wire [ 2:0]  dcache_axi_awsize;
    wire [ 7:0]  dcache_axi_awlen;
    wire [ 1:0]  dcache_axi_awburst;
    wire [31:0]  dcache_axi_wdata;
    wire         dcache_axi_wvalid;
    wire         dcache_axi_wready;
    wire [ 3:0]  dcache_axi_wstrb;
    wire         dcache_axi_wlast;
    wire         dcache_axi_bvalid;
    wire         dcache_axi_bready;
    wire [ 1:0]  dcache_axi_bresp;
    wire [31:0]  dcache_axi_araddr;
    wire         dcache_axi_arvalid;
    wire         dcache_axi_arready;
    wire [ 2:0]  dcache_axi_arsize;
    wire [ 7:0]  dcache_axi_arlen;
    wire [ 1:0]  dcache_axi_arburst;
    wire [31:0]  dcache_axi_rdata;
    wire         dcache_axi_rvalid;
    wire         dcache_axi_rready;
    wire         dcache_axi_rlast;
    wire [ 1:0]  dcache_axi_rresp;
    //regfile
    wire [31:0] rd_data1;
    wire [31:0] rd_data2;
    //TLB
    wire        tlb_s0_found;
    wire [ 3:0] tlb_s0_index;
    wire [19:0] tlb_s0_ppn;
    wire [ 5:0] tlb_s0_ps;
    wire [ 1:0] tlb_s0_plv;
    wire [ 1:0] tlb_s0_mat;
    wire        tlb_s0_d;
    wire        tlb_s0_v;
    wire        tlb_s1_found;
    wire [ 3:0] tlb_s1_index;
    wire [19:0] tlb_s1_ppn;
    wire [ 5:0] tlb_s1_ps;
    wire [ 1:0] tlb_s1_plv;
    wire [ 1:0] tlb_s1_mat;
    wire        tlb_s1_d;
    wire        tlb_s1_v;
    wire        tlb_r_e;
    wire [18:0] tlb_r_vppn;
    wire [ 5:0] tlb_r_ps;
    wire [ 9:0] tlb_r_asid;
    wire        tlb_r_g;
    wire [19:0] tlb_r_ppn0;
    wire [ 1:0] tlb_r_plv0;
    wire [ 1:0] tlb_r_mat0;
    wire        tlb_r_d0;
    wire        tlb_r_v0;
    wire [19:0] tlb_r_ppn1;
    wire [ 1:0] tlb_r_plv1;
    wire [ 1:0] tlb_r_mat1;
    wire        tlb_r_d1;
    wire        tlb_r_v1;
    //icache
    wire        icache_cacop_req_ok;
    wire        icache_cacop_ok;
    wire        icache_cacop_running;
    wire        icache_addr_ok;
    wire        icache_data_ok;
    wire [31:0] icache_rdata;
    //btb
    wire [11:0]  btb_fetch_pc;
    wire [11:0]  btb_wr_pc;
    wire [ 7:0]  btb_tag_buf;
    wire         btb_we;
    wire [43:0]  btb_wdata;
    wire         btb_hit;
    wire [31:0]  btb_target;
    wire [ 2:0]  btb_type;
    //ras
    wire [31:0] rtn_target;
    wire [ 2:0] ras_chkpt;
    //bhr
    wire         bhr_rllbk;
    wire [ 7:0]  bhr_rlbk_ckpt;
    wire [ 7:0]  bhr_chkpt;
    //pht
    wire [7:0] pht0_idx;
    wire       pht0_taken;
    wire [7:0] pht1_idx;
    wire       pht1_we;
    wire       pht1_taken;
    //if_stage
    wire         if2exe_cacop_req_ok;
    wire         if2mem_cacop_ok;
    wire         is_call;
    wire [31:0]  call_target;
    wire         is_rtn;
    wire [`if_bus_w - 1:0] if2id_bus;
    wire         if_ready_go;
    wire [18:0]  tlb_s0_vppn;
    wire         tlb_s0_va_bit12;
    wire [ 9:0]  tlb_s0_asid;
    wire         icache_mem_cancel;
    wire         icache_mat;
    wire         icache_cacop_valid;
    wire [3:0]   icache_cacop_op;
    wire         icache_cacop_target_way;
    wire [19:0]  icache_tag;
    wire [7:0]   icache_index;
    wire [ 7:0]  icache_index_buf;
    wire [3:0]   icache_offset_buf;
    wire         icache_valid;
    //forwarding_unit
    wire [2:0]  current_ptr;
    wire        blocked1;
    wire        forwrd_ready1;
    wire [31:0] forwrd_res1;
    wire        blocked2;
    wire        forwrd_ready2;
    wire [31:0] forwrd_res2;
    //id_stage
    wire         id_allowin;
    wire [4:0]   rj_addr;
    wire [4:0]   rk_rd_addr;
    wire [`id_bus_w - 1:0] id2exe_bus;
    wire         id_ready_go;
    wire         id_is_fresh;
    wire         dest_wr_en;
    wire [4:0]   forwrd_idx;
    wire [2:0]   forwrd_src;
    wire [4:0]   rj_query;
    wire [4:0]   rk_rd_query;
    //dcache
    wire        dcache_cacop_req_ok;
    wire        dcache_cacop_ok;
    wire        dcache_addr_ok;
    wire        dcache_data_ok;
    wire [31:0] dcache_rdata;
    //exe_stage
    wire         ras_rollbk;
    wire [ 2:0]  rllbk_ckpt;
    wire         exe_allowin;
    wire [31:0]  br_target;
    wire         pred_flush;
    wire [`exe_bus_w - 1:0] exe2mem_bus;
    wire         exe_ready_go;
    wire         exe2if_cacop_valid;
    wire [3:0]   exe2if_cacop_op;
    wire [7:0]   exe2if_cacop_tagt_index;
    wire         exe2if_cacop_tagt_way;
    wire         dcache_cacop_valid;
    wire [3:0]   dcache_cacop_op;
    wire         dcache_cacop_tagt_way;
    wire [7:0]   dcache_index;
    wire         dcache_op;
    wire         dcache_valid;
    wire [31:0]  dcache_wdata;
    wire [3:0]   dcache_wstrb;
    wire         res_we1;
    wire [2:0]   res_ptr1;
    wire [31:0]  result1;
    //mem_stage
    wire [18:0]  tlb_s1_vppn;
    wire         tlb_s1_va_bit12;
    wire [9:0]   tlb_s1_asid;
    wire         mem_allowin;
    wire         mem_ready_go;
    wire         mem_any_ex;
    wire         ll_running;
    wire [`mem_bus_w - 1:0] mem2wb_bus;
    wire         dcache_mat;
    wire [19:0]  dcache_tag;
    wire [ 7:0]  dcache_index_buf;
    wire [ 3:0]  dcache_offset_buf;
    wire         dcache_op_buf;
    wire         dcache_mem_cancel;
    wire [19:0]  mem2if_cacop_tagt_tag;
    // wire [ 7:0]  mem2if_cacop_tagt_index_buf;
    wire         res_we2;
    wire [2:0]   res_ptr2;
    wire [31:0]  result2;
    //wb_stage
    wire         ex_flush;
    wire         idle_flush;
    wire [31:0]  ex_next_pc;
    wire         wb_allowin;
    wire         gr_wr_en;
    wire [ 4:0]  gr_wr_addr;
    wire [31:0]  gr_wr_data;
    wire         wb_need_tlb;
    wire [18:0]  wb_tlb_vppn;
    wire [ 9:0]  wb_tlb_asid;
    wire         ll_finished;
    wire [ 3:0]  tlb_r_index;
    wire         tlb_we;
    wire [ 3:0]  tlb_w_index;
    wire         tlb_w_e;
    wire [18:0]  tlb_w_vppn;
    wire [ 5:0]  tlb_w_ps;
    wire [ 9:0]  tlb_w_asid;
    wire         tlb_w_g;
    wire [19:0]  tlb_w_ppn0;
    wire [ 1:0]  tlb_w_plv0;
    wire [ 1:0]  tlb_w_mat0;
    wire         tlb_w_d0;
    wire         tlb_w_v0;
    wire [19:0]  tlb_w_ppn1;
    wire [ 1:0]  tlb_w_plv1;
    wire [ 1:0]  tlb_w_mat1;
    wire         tlb_w_d1;
    wire         tlb_w_v1;
    wire         tlb_invtlb_valid;
    wire [ 4:0]  tlb_invtlb_op;
    wire         csr_we;
    wire [13:0]  csr_num;
    wire [31:0]  csr_wmask;
    wire [31:0]  csr_wvalue;
    wire         llbit_we;
    wire         llbit_w;
    wire         tlb_csr_we;
    wire [31:0]  tlbidx_w;
    wire [31:0]  tlbehi_w;
    wire [31:0]  tlbelo0_w;
    wire [31:0]  tlbelo1_w;
    wire [31:0]  asid_w;
    wire         wb_ex;
    wire         ertn_flush;
    wire [ 5:0]  wb_ecode;
    wire [ 8:0]  wb_esubcode;
    wire [31:0]  wb_pc;
    wire [31:0]  wb_vaddr;
    wire         res_we3;
    wire [ 2:0]  res_ptr3;
    wire [31:0]  result3;
    //csr
    wire [31:0] csr_rvalue;
    wire [ 3:0] rand_index;
    wire [31:0] crmd_r;
    wire [31:0] asid_r;
    wire [31:0] dmw0_r;
    wire [31:0] dmw1_r;
    wire [31:0] euen_r;
    wire [31:0] tid_r;
    wire [63:0] timer64_r;
    wire [31:0] tlbrentry_r;
    wire [31:0] eentry_r;
    wire [31:0] era_r;
    wire        llbit_r;
    wire [31:0] tlbidx_r;
    wire [31:0] tlbehi_r;
    wire [31:0] tlbelo0_r;
    wire [31:0] tlbelo1_r;
    wire [31:0] estate_r;
    wire        has_int;
    wire        ipi_int_in  = 1'b0;      //*inter-processor interrupts
//axi_mux
    axi_mux u_axi_mux(
        .clk                  (clk                   ),
        .rst                  (rst                   ),
        .icache_axi_araddr    (icache_axi_araddr     ),
        .icache_axi_arvalid   (icache_axi_arvalid    ),
        .icache_axi_arready   (icache_axi_arready    ),
        .icache_axi_arsize    (icache_axi_arsize     ),
        .icache_axi_arlen     (icache_axi_arlen      ),
        .icache_axi_arburst   (icache_axi_arburst    ),
        .icache_axi_rdata     (icache_axi_rdata      ),
        .icache_axi_rvalid    (icache_axi_rvalid     ),
        .icache_axi_rready    (icache_axi_rready     ),
        .icache_axi_rlast     (icache_axi_rlast      ),
        .icache_axi_rresp     (icache_axi_rresp      ),
        .dcache_axi_awaddr    (dcache_axi_awaddr     ),
        .dcache_axi_awvalid   (dcache_axi_awvalid    ),
        .dcache_axi_awready   (dcache_axi_awready    ),
        .dcache_axi_awsize    (dcache_axi_awsize     ),
        .dcache_axi_awlen     (dcache_axi_awlen      ),
        .dcache_axi_awburst   (dcache_axi_awburst    ),
        .dcache_axi_wdata     (dcache_axi_wdata      ),
        .dcache_axi_wvalid    (dcache_axi_wvalid     ),
        .dcache_axi_wready    (dcache_axi_wready     ),
        .dcache_axi_wstrb     (dcache_axi_wstrb      ),
        .dcache_axi_wlast     (dcache_axi_wlast      ),
        .dcache_axi_bvalid    (dcache_axi_bvalid     ),
        .dcache_axi_bready    (dcache_axi_bready     ),
        .dcache_axi_bresp     (dcache_axi_bresp      ),
        .dcache_axi_araddr    (dcache_axi_araddr     ),
        .dcache_axi_arvalid   (dcache_axi_arvalid    ),
        .dcache_axi_arready   (dcache_axi_arready    ),
        .dcache_axi_arsize    (dcache_axi_arsize     ),
        .dcache_axi_arlen     (dcache_axi_arlen      ),
        .dcache_axi_arburst   (dcache_axi_arburst    ),
        .dcache_axi_rdata     (dcache_axi_rdata      ),
        .dcache_axi_rvalid    (dcache_axi_rvalid     ),
        .dcache_axi_rready    (dcache_axi_rready     ),
        .dcache_axi_rlast     (dcache_axi_rlast      ),
        .dcache_axi_rresp     (dcache_axi_rresp      ),
        .arid                 (arid                  ),
        .araddr               (araddr                ),
        .arlen                (arlen                 ),
        .arsize               (arsize                ),
        .arburst              (arburst               ),
        .arlock               (arlock                ),
        .arcache              (arcache               ),
        .arprot               (arprot                ),
        .arvalid              (arvalid               ),
        .arready              (arready               ),
        .rid                  (rid                   ),
        .rdata                (rdata                 ),
        .rresp                (rresp                 ),
        .rlast                (rlast                 ),
        .rvalid               (rvalid                ),
        .rready               (rready                ),
        .awid                 (awid                  ),
        .awaddr               (awaddr                ),
        .awlen                (awlen                 ),
        .awsize               (awsize                ),
        .awburst              (awburst               ),
        .awlock               (awlock                ),
        .awcache              (awcache               ),
        .awprot               (awprot                ),
        .awvalid              (awvalid               ),
        .awready              (awready               ),
        .wid                  (wid                   ),
        .wdata                (wdata                 ),
        .wstrb                (wstrb                 ),
        .wlast                (wlast                 ),
        .wvalid               (wvalid                ),
        .wready               (wready                ),
        .bid                  (bid                   ),
        .bresp                (bresp                 ),
        .bvalid               (bvalid                ),
        .bready               (bready                )
    );
//regfile :)
    regfile u_regfile(
        .clk      (clk       ),
        .rst      (rst       ),
        .rd_addr1 (rj_addr   ),
        .rd_addr2 (rk_rd_addr),
        .rd_data1 (rd_data1  ),
        .rd_data2 (rd_data2  ),
        .wr_en    (gr_wr_en  ),
        .wr_addr  (gr_wr_addr),
        .wr_data  (gr_wr_data)
    );
//TLB :)
    tlb u_tlb (
        .clk            (clk             ),
        .s0_vppn        (tlb_s0_vppn     ),
        .s0_va_bit12    (tlb_s0_va_bit12 ),
        .s0_asid        (tlb_s0_asid     ),
        .s0_found       (tlb_s0_found    ),
        .s0_index       (tlb_s0_index    ),
        .s0_ppn         (tlb_s0_ppn      ),
        .s0_ps          (tlb_s0_ps       ),
        .s0_plv         (tlb_s0_plv      ),
        .s0_mat         (tlb_s0_mat      ),
        .s0_d           (tlb_s0_d        ),
        .s0_v           (tlb_s0_v        ),
        .s1_vppn        (tlb_s1_vppn     ),
        .s1_va_bit12    (tlb_s1_va_bit12 ),
        .s1_asid        (tlb_s1_asid     ),
        .s1_found       (tlb_s1_found    ),
        .s1_index       (tlb_s1_index    ),
        .s1_ppn         (tlb_s1_ppn      ),
        .s1_ps          (tlb_s1_ps       ),
        .s1_plv         (tlb_s1_plv      ),
        .s1_mat         (tlb_s1_mat      ),
        .s1_d           (tlb_s1_d        ),
        .s1_v           (tlb_s1_v        ),
        .invtlb_valid   (tlb_invtlb_valid),
        .invtlb_op      (tlb_invtlb_op   ),
        .we             (tlb_we          ),
        .w_index        (tlb_w_index     ),
        .w_e            (tlb_w_e         ),
        .w_vppn         (tlb_w_vppn      ),
        .w_ps           (tlb_w_ps        ),
        .w_asid         (tlb_w_asid      ),
        .w_g            (tlb_w_g         ),
        .w_ppn0         (tlb_w_ppn0      ),
        .w_plv0         (tlb_w_plv0      ),
        .w_mat0         (tlb_w_mat0      ),
        .w_d0           (tlb_w_d0        ),
        .w_v0           (tlb_w_v0        ),
        .w_ppn1         (tlb_w_ppn1      ),
        .w_plv1         (tlb_w_plv1      ),
        .w_mat1         (tlb_w_mat1      ),
        .w_d1           (tlb_w_d1        ),
        .w_v1           (tlb_w_v1        ),
        .r_index        (tlb_r_index     ),
        .r_e            (tlb_r_e         ),
        .r_vppn         (tlb_r_vppn      ),
        .r_ps           (tlb_r_ps        ),
        .r_asid         (tlb_r_asid      ),
        .r_g            (tlb_r_g         ),
        .r_ppn0         (tlb_r_ppn0      ),
        .r_plv0         (tlb_r_plv0      ),
        .r_mat0         (tlb_r_mat0      ),
        .r_d0           (tlb_r_d0        ),
        .r_v0           (tlb_r_v0        ),
        .r_ppn1         (tlb_r_ppn1      ),
        .r_plv1         (tlb_r_plv1      ),
        .r_mat1         (tlb_r_mat1      ),
        .r_d1           (tlb_r_d1        ),
        .r_v1           (tlb_r_v1        )
    );
//icache :)
    icache_block u_icache_block(
        .clk              (clk                    ),
        .rst              (rst                    ),
        .mem_cancel       (icache_mem_cancel      ),
        .mat              (icache_mat             ),
        .cacop_valid      (icache_cacop_valid     ),
        .cacop_req_ok     (icache_cacop_req_ok    ),
        .cacop_op         (icache_cacop_op        ),
        .cacop_ok         (icache_cacop_ok        ),
        .cacop_target_way (icache_cacop_target_way),
        .cacop_running    (icache_cacop_running   ),
        .tag              (icache_tag             ),
        .index            (icache_index           ),
        .index_buf_       (icache_index_buf       ),
        .offset_buf       (icache_offset_buf      ),
        .valid            (icache_valid           ),
        .addr_ok          (icache_addr_ok         ),
        .data_ok          (icache_data_ok         ),
        .rdata            (icache_rdata           ),
        .axi_araddr       (icache_axi_araddr      ),
        .axi_arvalid      (icache_axi_arvalid     ),
        .axi_arready      (icache_axi_arready     ),
        .axi_arsize       (icache_axi_arsize      ),
        .axi_arlen        (icache_axi_arlen       ),
        .axi_arburst      (icache_axi_arburst     ),
        .axi_rdata        (icache_axi_rdata       ),
        .axi_rvalid       (icache_axi_rvalid      ),
        .axi_rready       (icache_axi_rready      ),
        .axi_rlast        (icache_axi_rlast       ),
        .axi_rresp        (icache_axi_rresp       )
    );
//btb
    btb u_btb(
        .clk            (clk            ),
        .rst            (rst            ),
        .btb_fetch_pc   (btb_fetch_pc   ),
        .btb_wr_pc      (btb_wr_pc      ),
        .btb_tag_buf    (btb_tag_buf    ),
        .btb_we         (btb_we         ),
        .btb_wdata      (btb_wdata      ),
        .btb_hit        (btb_hit        ),
        .btb_target     (btb_target     ),
        .btb_type       (btb_type       )
    );
//ras
    ras u_ras(
        .clk            (clk            ),
        .rst            (rst            ),
        .is_call        (is_call        ),
        .call_target    (call_target    ),
        .is_rtn         (is_rtn         ),
        .rtn_target     (rtn_target     ),
        .ras_chkpt      (ras_chkpt      ),
        .ras_rollbk     (ras_rollbk     ),
        .rllbk_ckpt     (rllbk_ckpt     )
    );
//pht
    pht u_pht(
        .clk         (clk            ),
        .rst         (rst            ),
        .pht0_idx    (pht0_idx       ),
        .pht0_taken  (pht0_taken     ),
        .pht1_idx    (pht1_idx       ),
        .pht1_we     (pht1_we        ),
        .pht1_taken  (pht1_taken     )
    );
//if_stage :)
    if_stage u_if_stage(
        .clk                     (clk                      ),
        .rst                     (rst                      ),
        .cacop_valid             (exe2if_cacop_valid       ),
        .cacop_op                (exe2if_cacop_op          ),
        .cacop_req_ok            (if2exe_cacop_req_ok      ),
        .cacop_ok                (if2mem_cacop_ok          ),
        .cacop_target_tag        (mem2if_cacop_tagt_tag    ),
        .cacop_target_index      (exe2if_cacop_tagt_index  ),
        .cacop_target_way        (exe2if_cacop_tagt_way    ),
        .ex_next_pc              (ex_next_pc               ),
        .ertn_next_pc            (era_r                    ),
        .br_target               (br_target                ),
        .ex_flush                (ex_flush                 ),
        .ertn_flush              (ertn_flush               ),
        .pred_flush              (pred_flush               ),
        .btb_fetch_pc            (btb_fetch_pc             ),
        .btb_tag_buf             (btb_tag_buf              ),
        .btb_hit                 (btb_hit                  ),
        .btb_target              (btb_target               ),
        .btb_type                (btb_type                 ),
        .is_call                 (is_call                  ),
        .call_target             (call_target              ),
        .is_rtn                  (is_rtn                   ),
        .rtn_target              (rtn_target               ),
        .ras_chkpt               (ras_chkpt                ),
        .pht0_idx                (pht0_idx                 ),
        .pht0_taken              (pht0_taken               ),
        .if2id_bus               (if2id_bus                ),
        .if_ready_go             (if_ready_go              ),
        .id_allowin              (id_allowin               ),
        .crmd_da                 (crmd_r[`CSR_CRMD_DA   ]  ),
        .crmd_pg                 (crmd_r[`CSR_CRMD_PG   ]  ),
        .crmd_datf               (crmd_r[`CSR_CRMD_DATF ]  ),
        .crmd_plv                (crmd_r[`CSR_CRMD_PLV  ]  ),
        .asid_asid               (asid_r[`CSR_ASID_ASID ]  ),
        .dmw0_plv0               (dmw0_r[`CSR_DMW_PLV0  ]  ),
        .dmw0_plv3               (dmw0_r[`CSR_DMW_PLV3  ]  ),
        .dmw0_mat                (dmw0_r[`CSR_DMW_MAT   ]  ),
        .dmw0_pseg               (dmw0_r[`CSR_DMW_PSEG  ]  ),
        .dmw0_vseg               (dmw0_r[`CSR_DMW_VSEG  ]  ),
        .dmw1_plv0               (dmw1_r[`CSR_DMW_PLV0  ]  ),
        .dmw1_plv3               (dmw1_r[`CSR_DMW_PLV3  ]  ),
        .dmw1_mat                (dmw1_r[`CSR_DMW_MAT   ]  ),
        .dmw1_pseg               (dmw1_r[`CSR_DMW_PSEG  ]  ),
        .dmw1_vseg               (dmw1_r[`CSR_DMW_VSEG  ]  ),
        .tlb_vppn                (tlb_s0_vppn              ),
        .tlb_va_bit12            (tlb_s0_va_bit12          ),
        .tlb_asid                (tlb_s0_asid              ),
        .tlb_found               (tlb_s0_found             ),
        .tlb_ppn                 (tlb_s0_ppn               ),
        .tlb_ps                  (tlb_s0_ps                ),
        .tlb_plv                 (tlb_s0_plv               ),
        .tlb_mat                 (tlb_s0_mat               ),
        .tlb_v                   (tlb_s0_v                 ),
        .icache_mem_cancel       (icache_mem_cancel        ),
        .icache_mat              (icache_mat               ),
        .icache_cacop_valid      (icache_cacop_valid       ),
        .icache_cacop_req_ok     (icache_cacop_req_ok      ),
        .icache_cacop_op         (icache_cacop_op          ),
        .icache_cacop_ok         (icache_cacop_ok          ),
        .icache_cacop_target_way (icache_cacop_target_way  ),
        .icache_cacop_running    (icache_cacop_running     ),
        .icache_tag              (icache_tag               ),
        .icache_index            (icache_index             ),
        .icache_index_buf        (icache_index_buf         ),
        .icache_offset_buf       (icache_offset_buf        ),
        .icache_valid            (icache_valid             ),
        .icache_addr_ok          (icache_addr_ok           ),
        .icache_data_ok          (icache_data_ok           ),
        .icache_rdata            (icache_rdata             )
    );
    forwarding_unit u_forwarding_unit(
        .clk        (clk            ),
        .rst        (rst            ),
        .ex_flush   (ex_flush       ),
        .query1     (rj_query       ),
        .query2     (rk_rd_query    ),
        .blocked1   (blocked1       ),
        .blocked2   (blocked2       ),
        .ready1     (forwrd_ready1  ),
        .ready2     (forwrd_ready2  ),
        .result1    (forwrd_res1    ),
        .result2    (forwrd_res2    ),
        .new_rd     (dest_wr_en     ),
        .rd         (forwrd_idx     ),
        .rd_src     (forwrd_src     ),
        .ptr_out    (current_ptr    ),
        .exe_ready  (res_we1        ),
        .exe_ptr    (res_ptr1       ),
        .exe_res    (result1        ),
        .mem_ready  (res_we2        ),
        .mem_ptr    (res_ptr2       ),
        .mem_res    (result2        ),
        .wb_ready   (res_we3        ),
        .wb_ptr     (res_ptr3       ),
        .wb_res     (result3        ),
        .gr_wr_en   (gr_wr_en       ),
        .wb_index   (gr_wr_addr     )
    );
//id_stage :)
    id_stage u_id_stage(
        .clk                    (clk                   ),
        .rst                    (rst                   ),
        .ex_flush               (ex_flush              ),
        .if2id_bus              (if2id_bus             ),
        .if_ready_go            (if_ready_go           ),
        .id_allowin             (id_allowin            ),
        .has_int                (has_int               ),
        .euen_fpe               (euen_r[`CSR_EUEN_FPE] ),
        .crmd_plv               (crmd_r[`CSR_CRMD_PLV] ),
        .rj_addr                (rj_addr               ),
        .rk_rd_addr             (rk_rd_addr            ),
        .rj_data                (rd_data1              ),
        .rk_rd_data             (rd_data2              ),
        .id2exe_bus             (id2exe_bus            ),
        .id_ready_go            (id_ready_go           ),
        .exe_allowin            (exe_allowin           ),
        .id_is_fresh            (id_is_fresh           ),
        .pred_flush             (pred_flush            ),
        .forwrd_we              (dest_wr_en            ),
        .forwrd_idx             (forwrd_idx            ),
        .forwrd_src             (forwrd_src            ),
        .forwrd_ptr             (current_ptr           ),
        .rj_query               (rj_query              ),
        .rk_rd_query            (rk_rd_query           ),
        .rj_blocked             (blocked1              ),
        .rk_rd_blocked          (blocked2              ),
        .forwrd_rj_rdy    (forwrd_ready1         ),
        .forwrd_rk_rd_rdy (forwrd_ready2         ),
        .forwrd_rj          (forwrd_res1           ),
        .forwrd_rk_rd       (forwrd_res2           )
    );
//dcache :)
    dcache_block u_dcache_block(
        .clk              (clk                    ),
        .rst              (rst                    ),
        .mem_cancel       (dcache_mem_cancel      ),
        .mat              (dcache_mat             ),
        .cacop_valid      (dcache_cacop_valid     ),
        .cacop_req_ok     (dcache_cacop_req_ok    ),
        .cacop_op         (dcache_cacop_op        ),
        .cacop_ok         (dcache_cacop_ok        ),
        .cacop_target_way (dcache_cacop_tagt_way  ),
        .tag              (dcache_tag             ),
        .index            (dcache_index           ),
        .index_buf        (dcache_index_buf       ),
        .offset_buf       (dcache_offset_buf      ),
        .op               (dcache_op              ),
        .op_buf           (dcache_op_buf          ),
        .valid            (dcache_valid           ),
        .addr_ok          (dcache_addr_ok         ),
        .data_ok          (dcache_data_ok         ),
        .wdata            (dcache_wdata           ),
        .wstrb            (dcache_wstrb           ),
        .rdata            (dcache_rdata           ),
        .axi_awaddr       (dcache_axi_awaddr      ),
        .axi_awvalid      (dcache_axi_awvalid     ),
        .axi_awready      (dcache_axi_awready     ),
        .axi_awsize       (dcache_axi_awsize      ),
        .axi_awlen        (dcache_axi_awlen       ),
        .axi_awburst      (dcache_axi_awburst     ),
        .axi_wdata        (dcache_axi_wdata       ),
        .axi_wvalid       (dcache_axi_wvalid      ),
        .axi_wready       (dcache_axi_wready      ),
        .axi_wstrb        (dcache_axi_wstrb       ),
        .axi_wlast        (dcache_axi_wlast       ),
        .axi_bvalid       (dcache_axi_bvalid      ),
        .axi_bready       (dcache_axi_bready      ),
        .axi_bresp        (dcache_axi_bresp       ),
        .axi_araddr       (dcache_axi_araddr      ),
        .axi_arvalid      (dcache_axi_arvalid     ),
        .axi_arready      (dcache_axi_arready     ),
        .axi_arsize       (dcache_axi_arsize      ),
        .axi_arlen        (dcache_axi_arlen       ),
        .axi_arburst      (dcache_axi_arburst     ),
        .axi_rdata        (dcache_axi_rdata       ),
        .axi_rvalid       (dcache_axi_rvalid      ),
        .axi_rready       (dcache_axi_rready      ),
        .axi_rlast        (dcache_axi_rlast       ),
        .axi_rresp        (dcache_axi_rresp       )
    );
//exe_stage :)
    exe_stage u_exe_stage(
        .clk                     (clk                    ),
        .rst                     (rst                    ),
        .ex_flush                (ex_flush               ),
        .btb_wr_pc               (btb_wr_pc              ),
        .btb_we                  (btb_we                 ),
        .btb_wdata               (btb_wdata              ),
        .ras_rollbk              (ras_rollbk             ),
        .rllbk_ckpt              (rllbk_ckpt             ),
        .pht1_idx                (pht1_idx               ),
        .pht1_we                 (pht1_we                ),
        .pht1_taken              (pht1_taken             ),
        .id2exe_bus              (id2exe_bus             ),
        .id_ready_go             (id_ready_go            ),
        .exe_allowin             (exe_allowin            ),
        .br_target               (br_target              ),
        .id_is_fresh             (id_is_fresh            ),
        .pred_flush              (pred_flush             ),
        .exe2mem_bus             (exe2mem_bus            ),
        .exe_ready_go            (exe_ready_go           ),
        .mem_allowin             (mem_allowin            ),
        .mem_any_ex              (mem_any_ex             ),
        .ll_running              (ll_running             ),
        .icache_cacop_valid      (exe2if_cacop_valid     ),
        .icache_cacop_op         (exe2if_cacop_op        ),
        .icache_cacop_req_ok     (if2exe_cacop_req_ok    ),
        .icache_cacop_tagt_idx   (exe2if_cacop_tagt_index),
        .icache_cacop_tagt_way   (exe2if_cacop_tagt_way  ),
        .dcache_cacop_valid      (dcache_cacop_valid     ),
        .dcache_cacop_op         (dcache_cacop_op        ),
        .dcache_cacop_req_ok     (dcache_cacop_req_ok    ),
        .dcache_cacop_tagt_way   (dcache_cacop_tagt_way  ),
        .dcache_index            (dcache_index           ),
        .dcache_op               (dcache_op              ),
        .dcache_valid            (dcache_valid           ),
        .dcache_addr_ok          (dcache_addr_ok         ),
        .dcache_wdata            (dcache_wdata           ),
        .dcache_wstrb            (dcache_wstrb           ),
        .forwrd_we               (res_we1                ),
        .forwrd_ptr              (res_ptr1               ),
        .forwrd_res              (result1                )
    );
//mem_stage :)
    mem_stage u_mem_stage(
        .clk           (clk           ),
        .rst           (rst           ),
        .ex_flush      (ex_flush      ),
        .idle_flush    (idle_flush             ),
        .llbit         (llbit_r                ),
        .crmd_da       (crmd_r[`CSR_CRMD_DA   ]),
        .crmd_pg       (crmd_r[`CSR_CRMD_PG   ]),
        .crmd_datm     (crmd_r[`CSR_CRMD_DATM ]),
        .crmd_plv      (crmd_r[`CSR_CRMD_PLV  ]),
        .asid_asid     (asid_r[`CSR_ASID_ASID ]),
        .dmw0_plv0     (dmw0_r[`CSR_DMW_PLV0  ]),
        .dmw0_plv3     (dmw0_r[`CSR_DMW_PLV3  ]),
        .dmw0_mat      (dmw0_r[`CSR_DMW_MAT   ]),
        .dmw0_pseg     (dmw0_r[`CSR_DMW_PSEG  ]),
        .dmw0_vseg     (dmw0_r[`CSR_DMW_VSEG  ]),
        .dmw1_plv0     (dmw1_r[`CSR_DMW_PLV0  ]),
        .dmw1_plv3     (dmw1_r[`CSR_DMW_PLV3  ]),
        .dmw1_mat      (dmw1_r[`CSR_DMW_MAT   ]),
        .dmw1_pseg     (dmw1_r[`CSR_DMW_PSEG  ]),
        .dmw1_vseg     (dmw1_r[`CSR_DMW_VSEG  ]),
        .tlb_vppn      (tlb_s1_vppn            ),
        .tlb_va_bit12  (tlb_s1_va_bit12        ),
        .tlb_asid      (tlb_s1_asid            ),
        .tlb_found     (tlb_s1_found           ),
        .tlb_ppn       (tlb_s1_ppn             ),
        .tlb_ps        (tlb_s1_ps              ),
        .tlb_plv       (tlb_s1_plv             ),
        .tlb_mat       (tlb_s1_mat             ),
        .tlb_d         (tlb_s1_d               ),
        .tlb_v         (tlb_s1_v               ),
        .exe2mem_bus   (exe2mem_bus   ),
        .exe_ready_go  (exe_ready_go  ),
        .mem_allowin   (mem_allowin   ),
        .mem_any_ex    (mem_any_ex    ),
        .ll_running    (ll_running    ),
        .wb_need_tlb   (wb_need_tlb   ),
        .wb_tlb_vppn   (wb_tlb_vppn   ),
        .wb_tlb_asid   (wb_tlb_asid   ),
        .ll_finished   (ll_finished   ),
        .mem_ready_go  (mem_ready_go  ),
        .wb_allowin    (wb_allowin    ),
        .mem2wb_bus    (mem2wb_bus    ),
        .dcache_mat            (dcache_mat             ),
        .dcache_tag            (dcache_tag             ),
        .dcache_index_buf      (dcache_index_buf           ),
        .dcache_offset_buf     (dcache_offset_buf          ),
        .dcache_op_buf         (dcache_op_buf              ),
        .dcache_mem_cancel     (dcache_mem_cancel),
        .dcache_data_ok(dcache_data_ok),
        .dcache_rdata  (dcache_rdata  ),
        .dcache_cacop_ok(dcache_cacop_ok),
        .icache_cacop_ok(if2mem_cacop_ok),
        .icache_cacop_target_tag (mem2if_cacop_tagt_tag),
        .forwrd_we     (res_we2       ),
        .forwrd_ptr    (res_ptr2      ),
        .forwrd_res    (result2       )
    );
//wb_stage :)
    wb_stage u_wb_stage(
        .clk             (clk             ),
        .rst             (rst             ),
        .ex_flush        (ex_flush        ),
        .idle_flush      (idle_flush      ),
        .ex_next_pc      (ex_next_pc      ),
        .mem2wb_bus      (mem2wb_bus      ),
        .mem_ready_go    (mem_ready_go    ),
        .wb_allowin      (wb_allowin      ),
        .gr_wr_en        (gr_wr_en        ),
        .gr_wr_addr      (gr_wr_addr      ),
        .gr_wr_data      (gr_wr_data      ),
        .wb_need_tlb     (wb_need_tlb     ),
        .wb_tlb_vppn     (wb_tlb_vppn     ),
        .wb_tlb_asid     (wb_tlb_asid     ),
        .ll_finished     (ll_finished     ),
        .tlb_found       (tlb_s1_found    ),
        .tlb_index       (tlb_s1_index    ),
        .tlb_r_index     (tlb_r_index     ),
        .tlb_r_e         (tlb_r_e         ),
        .tlb_r_vppn      (tlb_r_vppn      ),
        .tlb_r_ps        (tlb_r_ps        ),
        .tlb_r_asid      (tlb_r_asid      ),
        .tlb_r_g         (tlb_r_g         ),
        .tlb_r_ppn0      (tlb_r_ppn0      ),
        .tlb_r_plv0      (tlb_r_plv0      ),
        .tlb_r_mat0      (tlb_r_mat0      ),
        .tlb_r_d0        (tlb_r_d0        ),
        .tlb_r_v0        (tlb_r_v0        ),
        .tlb_r_ppn1      (tlb_r_ppn1      ),
        .tlb_r_plv1      (tlb_r_plv1      ),
        .tlb_r_mat1      (tlb_r_mat1      ),
        .tlb_r_d1        (tlb_r_d1        ),
        .tlb_r_v1        (tlb_r_v1        ),
        .tlb_we          (tlb_we          ),
        .tlb_w_index     (tlb_w_index     ),
        .tlb_w_e         (tlb_w_e         ),
        .tlb_w_vppn      (tlb_w_vppn      ),
        .tlb_w_ps        (tlb_w_ps        ),
        .tlb_w_asid      (tlb_w_asid      ),
        .tlb_w_g         (tlb_w_g         ),
        .tlb_w_ppn0      (tlb_w_ppn0      ),
        .tlb_w_plv0      (tlb_w_plv0      ),
        .tlb_w_mat0      (tlb_w_mat0      ),
        .tlb_w_d0        (tlb_w_d0        ),
        .tlb_w_v0        (tlb_w_v0        ),
        .tlb_w_ppn1      (tlb_w_ppn1      ),
        .tlb_w_plv1      (tlb_w_plv1      ),
        .tlb_w_mat1      (tlb_w_mat1      ),
        .tlb_w_d1        (tlb_w_d1        ),
        .tlb_w_v1        (tlb_w_v1        ),
        .invtlb_valid    (tlb_invtlb_valid),
        .invtlb_op       (tlb_invtlb_op   ),
        .has_int         (has_int         ),
        .csr_we          (csr_we          ),
        .csr_num         (csr_num         ),
        .csr_wmask       (csr_wmask       ),
        .csr_wvalue      (csr_wvalue      ),
        .csr_rvalue      (csr_rvalue      ),
        .rand_index      (rand_index      ),
        .asid_r          (asid_r          ),
        .tid_r           (tid_r           ),
        .timer64_r       (timer64_r       ),
        .llbit_we        (llbit_we        ),
        .llbit_w         (llbit_w         ),
        .tlb_csr_we      (tlb_csr_we      ),
        .tlbidx_w        (tlbidx_w        ),
        .tlbehi_w        (tlbehi_w        ),
        .tlbelo0_w       (tlbelo0_w       ),
        .tlbelo1_w       (tlbelo1_w       ),
        .asid_w          (asid_w          ),
        .tlbidx_r        (tlbidx_r        ),
        .tlbehi_r        (tlbehi_r        ),
        .tlbelo0_r       (tlbelo0_r       ),
        .tlbelo1_r       (tlbelo1_r       ),
        .tlbrentry_r     (tlbrentry_r     ),
        .eentry_r        (eentry_r        ),
        .estate_r        (estate_r        ),
        .wb_ex           (wb_ex           ),
        .ertn_flush      (ertn_flush      ),
        .wb_ecode        (wb_ecode        ),
        .wb_esubcode     (wb_esubcode     ),
        .wb_pc           (wb_pc           ),
        .wb_vaddr        (wb_vaddr        ),
        .forwrd_we       (res_we3         ),
        .forwrd_ptr      (res_ptr3        ),
        .forwrd_res      (result3         )
    );
//csr :)
    csr u_csr(
        .clk         (clk        ),
        .rst         (rst        ),
        .csr_we      (csr_we     ),
        .csr_num     (csr_num    ),
        .csr_wmask   (csr_wmask  ),
        .csr_wvalue  (csr_wvalue ),
        .csr_rvalue  (csr_rvalue ),
        .rand_index  (rand_index ),
        .crmd_r      (crmd_r     ),
        .asid_r      (asid_r     ),
        .dmw0_r      (dmw0_r     ),
        .dmw1_r      (dmw1_r     ),
        .euen_r      (euen_r     ),
        .tid_r       (tid_r      ),
        .timer64_r   (timer64_r  ),
        .tlbrentry_r (tlbrentry_r),
        .eentry_r    (eentry_r   ),
        .era_r       (era_r      ),
        .llbit_we    (llbit_we   ),
        .llbit_r     (llbit_r    ),
        .llbit_w     (llbit_w    ),
        .tlb_csr_we  (tlb_csr_we ),
        .tlbidx_w    (tlbidx_w   ),
        .tlbehi_w    (tlbehi_w   ),
        .tlbelo0_w   (tlbelo0_w  ),
        .tlbelo1_w   (tlbelo1_w  ),
        .asid_w      (asid_w     ),
        .tlbidx_r    (tlbidx_r   ),
        .tlbehi_r    (tlbehi_r   ),
        .tlbelo0_r   (tlbelo0_r  ),
        .tlbelo1_r   (tlbelo1_r  ),
        .estate_r    (estate_r   ),
        .wb_ex       (wb_ex      ),
        .ertn_flush  (ertn_flush ),
        .hw_int_in   (hw_int_in  ),
        .has_int     (has_int    ),
        .ipi_int_in  (ipi_int_in ),
        .wb_ecode    (wb_ecode   ),
        .wb_esubcode (wb_esubcode),
        .wb_pc       (wb_pc      ),
        .wb_vaddr    (wb_vaddr   )
    );
//end
endmodule