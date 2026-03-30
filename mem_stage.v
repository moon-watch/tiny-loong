`include "bus_width.h"
module mem_stage (
    input  wire         clk,
    input  wire         rst,
    input  wire         ex_flush,
    input  wire         idle_flush,
    //csr
    input  wire         llbit,
    input  wire         crmd_da,
    input  wire         crmd_pg,
    input  wire [ 1:0]  crmd_datm,
    input  wire [ 1:0]  crmd_plv,
    input  wire [ 9:0]  asid_asid,
    input  wire         dmw0_plv0,
    input  wire         dmw0_plv3,
    input  wire [ 1:0]  dmw0_mat,
    input  wire [ 2:0]  dmw0_pseg,
    input  wire [ 2:0]  dmw0_vseg,
    input  wire         dmw1_plv0,
    input  wire         dmw1_plv3,
    input  wire [ 1:0]  dmw1_mat,
    input  wire [ 2:0]  dmw1_pseg,
    input  wire [ 2:0]  dmw1_vseg,
    //tlb
    output wire [18:0]  tlb_vppn,
    output wire         tlb_va_bit12,
    output wire [ 9:0]  tlb_asid,
    input  wire         tlb_found,
    input  wire [19:0]  tlb_ppn,
    input  wire [ 5:0]  tlb_ps,
    input  wire [ 1:0]  tlb_plv,
    input  wire [ 1:0]  tlb_mat,
    input  wire         tlb_d,
    input  wire         tlb_v,
    //prev_stage
    output wire         allow_mem,  //block mem_req when there is an ongoing icache_cacop, sucks :(
    output wire         allow_icacop,   //block icacop when there is an ongoing mem/dcacop, sucks :(
    output wire         allow_dcacop,   //block dcacop when there is an ongoing icacop, sucks :(
    output wire         mem_any_excp,
    output wire         ll_running,
    input  wire [`EXE_BUS_W - 1:0] exe2mem_bus,
    input  wire         exe_ready_go,
    output wire         mem_allowin,
    //next_stage
    input  wire         ll_finished,
    input  wire         wb_need_tlb,
    input  wire [18:0]  wb_tlb_vppn,
    input  wire [ 9:0]  wb_tlb_asid,
    output wire [`MEM_BUS_W - 1:0] mem2wb_bus,
    output wire         mem_ready_go,
    input  wire         wb_allowin,
    //cache
    input  wire         dcache_cacop_ok,
    output wire         dcache_mem_cancel,
    output wire         dcache_mat,
    output wire         dcache_op_buf,
    output wire [ 7:0]  dcache_index_buf,
    output wire [19:0]  dcache_tag,
    output wire [ 3:0]  dcache_offset_buf,
    input  wire         dcache_data_ok,
    input  wire [31:0]  dcache_rdata,
    output wire [19:0]  icache_cacop_target_tag,
    input  wire         icache_cacop_ok,
    //forward
    output wire         forwrd_we,
    output wire [ 2:0]  forwrd_ptr,
    output wire [31:0]  forwrd_res
);
//declaration
    //fsm
    localparam  expired  = 2'b01;
    localparam  fresh    = 2'b10;
    reg  [ 1:0] mem_state;
    wire        is_expired = mem_state[0];
    wire        is_fresh   = mem_state[1];
    reg         recovery_mode;
    wire        cacop_ok;
    reg  [31:0] ll_target_reg;
    reg         ll_running_reg;
    wire        preld_valid;
    wire        sc_valid;
    wire        mem_invalid;
    wire        mem_cancel;
    wire [15:0] ld_hlfwd_res;
    wire [ 7:0] ld_byte_res;
    wire [31:0] ld_res;
    wire [31:0] mem_result;
    wire        any_excp;
    wire        stall_now;
    reg         stall_flag;
    wire        new_entry;
    //exe2mem_bus
    reg [`EXE_BUS_W - 1:0] exe2mem_bus_reg;
    wire [31:0] pc_reg;
    wire [31:0] exe_result_reg;
    wire        forwrd_on_mem_reg;
    wire        forwrd_on_wb_reg;
    wire [ 2:0] forwrd_ptr_reg;
    wire [31:0] rj_value_reg;
    wire [31:0] rd_value_reg;
    wire [ 4:0] rd_addr_reg;
    wire        mem_ld_reg;
    wire        mem_st_reg;
    wire        mem_isll_reg;
    wire        mem_issc_reg;
    wire        mem_ispreld_reg;
    wire        mem_usign_reg;
    wire [ 3:0] mem_mask_reg;
    wire [ 2:0] mem_len_reg;
    wire        mem_has_req_reg;
    wire        mem_res_ld_reg;
    wire        cacop_valid_reg;
    wire        cacop_target_reg;
    wire        cacop_op2_reg;
    wire [ 4:0] tlb_inst_reg;
    wire        id_isidle_reg;
    wire        id_isertn_reg;
    wire        id_flush_reg;
    wire        gr_we_reg;
    wire [ 4:0] wb_src_reg;
    wire        csr_we_reg;
    wire        csr_nomask_reg;
    wire        if_any_ex_reg;
    wire        id_any_ex_reg;
    wire [ 9:0] exe_ex_bus_reg;
    //addr_trans
    wire        direct_access;
    wire        dmw0_hit;
    wire        dmw1_hit;
    wire        dmw_hit;
    wire [32:0] physical_addr;
    //excp
    wire        pil_inst, pis_inst, pme_inst, ppi_inst, ale_inst, tlbr_inst;
    wire        mem_pil, mem_pis, mem_pme, mem_ppi, mem_ale, mem_tlbr;
    wire [15:0] mem_ex_bus;
    //mem2wb_bus
    wire [31:0] pc;
    wire        forwrd_on_wb;
    wire [31:0] rj_value;
    wire [31:0] rd_value;
    wire [ 4:0] rd_addr;
    wire        mem_isll;
    wire [ 4:0] tlb_inst;
    wire        id_isidle;
    wire        id_isertn;
    wire        id_flush;
    wire        gr_we;
    wire [ 4:0] wb_src;
    wire        csr_we;
    wire        csr_nomask;
    wire        if_any_ex;
    wire        id_any_ex;
//exe2mem_bus
    assign {
        pc_reg,
        exe_result_reg,
        forwrd_on_mem_reg,
        forwrd_on_wb_reg,
        forwrd_ptr_reg,
        rj_value_reg,
        rd_value_reg,
        rd_addr_reg,
        mem_ld_reg,
        mem_st_reg,
        mem_isll_reg,
        mem_issc_reg,
        mem_ispreld_reg,
        mem_usign_reg,
        mem_mask_reg,
        mem_len_reg,
        mem_has_req_reg,
        mem_res_ld_reg,
        cacop_valid_reg,
        cacop_target_reg,
        cacop_op2_reg,
        tlb_inst_reg,
        id_isidle_reg,
        id_isertn_reg,
        id_flush_reg,
        gr_we_reg,
        wb_src_reg,
        csr_we_reg,
        csr_nomask_reg,
        if_any_ex_reg,
        id_any_ex_reg,
        exe_ex_bus_reg
    } = exe2mem_bus_reg;
//forward
    assign forwrd_we  = forwrd_on_mem_reg && is_fresh && mem_has_req_reg
                        && ((mem_issc_reg && ~sc_valid) || dcache_data_ok); //Sucks :(
    assign forwrd_ptr = forwrd_ptr_reg;
    assign forwrd_res = mem_result;
//tlb
    assign tlb_vppn     = wb_need_tlb ? wb_tlb_vppn : exe_result_reg[31:13];
    assign tlb_va_bit12 = exe_result_reg[12];
    assign tlb_asid     = wb_need_tlb ? wb_tlb_asid : asid_asid;
//addr_trans
    assign direct_access    = crmd_da == 1'b1 && crmd_pg == 1'b0;
    assign dmw0_hit         = (exe_result_reg[31:29] == dmw0_vseg) && ((crmd_plv == 2'd3 && dmw0_plv3 == 1'b1) || (crmd_plv == 2'd0 && dmw0_plv0 == 1'b1));
    assign dmw1_hit         = (exe_result_reg[31:29] == dmw1_vseg) && ((crmd_plv == 2'd3 && dmw1_plv3 == 1'b1) || (crmd_plv == 2'd0 && dmw1_plv0 == 1'b1));
    assign dmw_hit          = dmw0_hit || dmw1_hit;
    assign physical_addr    = direct_access ? {crmd_datm[0], exe_result_reg}                                                                //direct map
                            : dmw_hit ? {(dmw0_hit ? {dmw0_mat[0], dmw0_pseg} : {dmw1_mat[0], dmw1_pseg}), exe_result_reg[28:0]}            //dmw
                            : {tlb_mat[0], tlb_ppn[19:9], (tlb_ps == 6'd21 ? exe_result_reg[20:12] : tlb_ppn[8:0]), exe_result_reg[11:0]};  //tlb
//cache
    assign dcache_mat               = physical_addr[32];
    assign dcache_tag               = wb_need_tlb ? 20'b0 : physical_addr[31:12];
    assign dcache_index_buf         = exe_result_reg[11:4];
    assign dcache_offset_buf        = exe_result_reg[3:0];
    assign dcache_op_buf            = mem_st_reg;
    assign dcache_mem_cancel        = mem_cancel;
    assign icache_cacop_target_tag  = physical_addr[31:12];
    assign cacop_ok                 = icache_cacop_ok | dcache_cacop_ok;
//excp
    assign pil_inst     = mem_ld_reg | mem_isll_reg | cacop_op2_reg;
    assign pis_inst     = mem_st_reg | mem_issc_reg;
    assign pme_inst     = mem_st_reg | mem_issc_reg;
    assign ppi_inst     = mem_ld_reg | mem_isll_reg | mem_st_reg | mem_issc_reg | cacop_op2_reg;
    assign ale_inst     = mem_ld_reg | mem_isll_reg | mem_st_reg | mem_issc_reg;
    assign tlbr_inst    = mem_ld_reg | mem_isll_reg | mem_st_reg | mem_issc_reg | cacop_op2_reg;
    assign mem_pil      = pil_inst & ~direct_access & ~dmw_hit & tlb_found & ~tlb_v;
    assign mem_pis      = pis_inst & ~direct_access & ~dmw_hit & tlb_found & ~tlb_v;
    assign mem_pme      = pme_inst & ~direct_access & ~dmw_hit & tlb_found &  tlb_v
                        & ((crmd_plv == 2'd3 && tlb_plv == 2'd3) || crmd_plv == 2'd0) & ~tlb_d;
    assign mem_ppi      = ppi_inst & ~direct_access & ~dmw_hit
                        & tlb_found & tlb_v & (crmd_plv == 2'd3 && tlb_plv == 2'd0);
    assign mem_ale      = ale_inst & ((mem_len_reg[1] & exe_result_reg[0])
                                    | (mem_len_reg[2] & (exe_result_reg[0] | exe_result_reg[1])));
    assign mem_tlbr     = tlbr_inst & ~direct_access & ~dmw_hit & ~tlb_found;
    assign mem_any_ex   = mem_pil | mem_pis | mem_pme | mem_ppi | mem_ale | mem_tlbr;
    assign mem_any_excp = ~recovery_mode && mem_any_ex;
    assign mem_ex_bus   = {exe_ex_bus_reg, mem_pil, mem_pis, mem_pme, mem_ppi, mem_ale, mem_tlbr};
//mem2wb_bus
    assign pc           = pc_reg;
    assign forwrd_on_wb = forwrd_on_wb_reg;
    assign rj_value     = rj_value_reg;
    assign rd_value     = mem_any_ex ? exe_result_reg : rd_value_reg; //vaddr
    assign rd_addr      = rd_addr_reg;
    assign mem_isll     = mem_isll_reg;
    assign tlb_inst     = tlb_inst_reg;
    assign id_isidle    = id_isidle_reg;
    assign id_isertn    = id_isertn_reg;
    assign id_flush     = id_flush_reg;
    assign gr_we        = gr_we_reg;
    assign wb_src       = wb_src_reg;
    assign csr_we       = csr_we_reg;
    assign csr_nomask   = csr_nomask_reg;
    assign if_any_ex    = if_any_ex_reg;
    assign id_any_ex    = id_any_ex_reg;
    assign mem2wb_bus = {
        pc,
        forwrd_on_wb,
        forwrd_ptr,
        rj_value,
        rd_value,
        rd_addr,
        mem_isll,
        tlb_inst,
        id_isidle,
        id_isertn,
        id_flush,
        gr_we,
        wb_src,
        csr_we,
        csr_nomask,
        mem_result,
        if_any_ex,
        id_any_ex,
        any_excp,
        mem_ex_bus
    };
//fsm
    assign ll_running   = ll_running_reg || (mem_isll_reg && is_fresh);
    assign preld_valid  = direct_access ? crmd_datm[0] : (dmw_hit ? (dmw0_hit ? dmw0_mat[0] : dmw1_mat[0])
                        : (tlb_found & tlb_v & ((crmd_plv == 2'd3 && tlb_plv == 2'd3) || crmd_plv == 2'd0) & tlb_mat[0]));
    assign sc_valid     = (physical_addr[31:0] == ll_target_reg) & llbit;
    assign mem_invalid  = (mem_ispreld_reg & ~preld_valid) | (mem_issc_reg & ~sc_valid);
    assign mem_cancel   = (mem_has_req_reg | cacop_op2_reg) & (mem_any_ex | mem_invalid);
    assign ld_hlfwd_res = ({16{mem_mask_reg[2]}} & dcache_rdata[31:16])    //migrate to dcache?
                        | ({16{mem_mask_reg[0]}} & dcache_rdata[15:0 ]);
    assign ld_byte_res  = ({ 8{mem_mask_reg[0]}} & dcache_rdata[ 7:0 ])
                        | ({ 8{mem_mask_reg[1]}} & dcache_rdata[15:8 ])
                        | ({ 8{mem_mask_reg[2]}} & dcache_rdata[23:16])
                        | ({ 8{mem_mask_reg[3]}} & dcache_rdata[31:24]);
    assign ld_res       = ({32{mem_len_reg[2]}} & dcache_rdata)
                        | ({32{mem_len_reg[1]}} & {{16{mem_usign_reg ? 1'b0 : ld_hlfwd_res[15]}}, ld_hlfwd_res[15:0]})
                        | ({32{mem_len_reg[0]}} & {{24{mem_usign_reg ? 1'b0 : ld_byte_res [ 7]}}, ld_byte_res [ 7:0]});
    assign mem_result   = ({32{mem_res_ld_reg}} & ld_res)
                        | ({32{mem_issc_reg  }} & {31'b0, sc_valid})
                        | ({32{~(mem_res_ld_reg | mem_issc_reg)}} & exe_result_reg);
    assign any_excp    = if_any_ex_reg | id_any_ex_reg | mem_any_ex;
    assign stall_now   = any_excp | id_flush_reg | id_isidle_reg;
    assign allow_mem   = (is_fresh & cacop_valid_reg & cacop_target_reg) ? icache_cacop_ok : 1'b1;   //Sucks :(
    assign allow_icacop = (is_fresh & (mem_has_req_reg | cacop_valid_reg)) ?
                            (mem_invalid | dcache_data_ok | cacop_ok) : 1'b1;   //Sucks :( maybe can just use mem_ready_go
    assign allow_dcacop = (is_fresh & cacop_valid_reg & cacop_target_reg) ? icache_cacop_ok : 1'b1; //Sucks :(
    assign mem_allowin  = (is_expired & ~stall_flag) | (mem_ready_go & ~stall_now & wb_allowin);
    assign mem_ready_go = is_fresh & (any_excp                                                  //excp
                                        | (mem_has_req_reg & (mem_invalid | dcache_data_ok))    //mem
                                        | (cacop_valid_reg & cacop_ok)                          //cacop
                                        | (~(mem_has_req_reg | cacop_valid_reg)));              //others
    assign new_entry    = mem_allowin & exe_ready_go;
    always @(posedge clk) begin
        if (rst || ex_flush)
            recovery_mode <= 1'b1;
        else if (new_entry)
            recovery_mode <= 1'b0;

        if (rst || ex_flush || idle_flush)
            stall_flag <= 1'b0;
        else if (is_fresh && stall_now)
            stall_flag <= 1'b1;

        if (rst || ex_flush || ll_finished)
            ll_running_reg <= 1'b0;
        else if (mem_ready_go && wb_allowin && mem_isll_reg)
            ll_running_reg <= 1'b1;

        if (mem_ready_go && wb_allowin && mem_isll_reg)
            ll_target_reg <= physical_addr[31:0];

        if (new_entry)
            exe2mem_bus_reg <= exe2mem_bus;

        if (rst || ex_flush)
            mem_state       <= expired;
        else begin
            case (mem_state)
                expired:
                    if (new_entry)
                        mem_state <= fresh;
                fresh:
                    if (stall_now)
                        mem_state <= expired;
                    else if (mem_ready_go) begin
                        if (~new_entry)
                            mem_state <= expired;
                    end
            endcase
        end
    end
endmodule
