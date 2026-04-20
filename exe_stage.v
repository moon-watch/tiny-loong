`include "bus_width.h"
module exe_stage (
    input  wire         clk,
    input  wire         rst,
    input  wire         ex_flush,
    output wire         pred_flush,
    output wire [31:0]  br_target,
    //btb
    output wire [11:0]  btb_wr_pc,
    output wire         btb_we,
    output wire [43:0]  btb_wdata,
    //ras
    output wire         ras_rollbk,
    output wire [ 2:0]  rllbk_ckpt,
    //pht
    output wire [ 7:0]  pht1_idx,
    output wire         pht1_we,
    output wire         pht1_taken,
    //prev_stage
    input  wire         id_is_fresh,
    input  wire [`ID_BUS_W - 1:0] id2exe_bus,
    input  wire         id_ready_go,
    output wire         exe_allowin,
    //next_stage
    input  wire         allow_mem,
    input  wire         allow_icacop,
    input  wire         allow_dcacop,
    input  wire         mem_any_ex,
    input  wire         ll_running,
    output wire [`EXE_BUS_W - 1:0] exe2mem_bus,
    output wire         exe_ready_go,
    input  wire         mem_allowin,
    //tlb
    input  wire [ 9:0]  asid_asid,
    output wire [18:0]  tlb_vppn,
    output wire         tlb_va_bit12,
    output wire [ 9:0]  tlb_asid,
    //icache
    output wire         icache_cacop_valid,
    output wire [ 3:0]  icache_cacop_op,
    input  wire         icache_cacop_req_ok,
    output wire [ 7:0]  icache_cacop_tagt_idx,
    output wire         icache_cacop_tagt_way,
    //dcache
    output wire         dcache_cacop_valid,
    output wire [3:0]   dcache_cacop_op,
    input  wire         dcache_cacop_req_ok,
    output wire         dcache_cacop_tagt_way,
    output wire         dcache_valid,
    input  wire         dcache_addr_ok,
    output wire         dcache_op,
    output wire [ 7:0]  dcache_index,
    output wire [31:0]  dcache_wdata,
    output wire [ 3:0]  dcache_wstrb,
    //forward
    output wire         forwrd_we,
    output wire [ 2:0]  forwrd_ptr,
    output wire [31:0]  forwrd_res
);
//declaration
    //fsm
    localparam  expired  = 3'b001;
    localparam  fresh    = 3'b010;
    localparam  hold     = 3'b100;
    reg  [ 2:0] exe_state;
    wire        is_expired  = exe_state[0];
    wire        is_fresh    = exe_state[1];
    wire        is_hold     = exe_state[2];
    reg         recovery_mode;
    wire        any_excp;
    wire        stall_now;
    reg         stall_flag;
    wire        new_entry;
    //id2exe_bus
    reg  [`ID_BUS_W - 1:0] id2exe_bus_reg;
    wire [ 2:0] ras_chkpt_reg;
    wire [31:0] pc_reg;
    wire        forwrd_on_exe_reg;
    wire        forwrd_on_mem_reg;
    wire        forwrd_on_wb_reg;
    wire [ 2:0] forwrd_ptr_reg;
    wire        src1_pc_reg;
    wire [31:0] alu_src1_reg;
    wire [31:0] alu_src2_reg;
    wire [31:0] rd_value_reg;
    wire [ 4:0] rd_addr_reg;
    wire [18:0] alu_op_reg;
    wire        multi_circle_reg;
    wire        id_isidle_reg;
    wire        mem_ld_reg;
    wire        mem_st_reg;
    wire        mem_isll_reg;
    wire        mem_issc_reg;
    wire        mem_ispreld_reg;
    wire [ 2:0] mem_len_reg;
    wire        mem_usign_reg;
    wire        cacop_valid_reg;
    wire        cacop_target_reg;
    wire [ 3:0] cacop_op_reg;
    wire        br_inst_reg;
    wire        br_src1_pc_reg;
    wire [ 4:0] tlb_inst_reg;
    wire        gr_we_reg;
    wire [ 4:0] wb_src_reg;
    wire        csr_we_reg;
    wire        csr_nomask_reg;
    wire        id_isertn_reg;
    wire        id_flush_reg;
    wire [ 9:0] id_ex_bus_reg;
    wire        id_any_ex_reg;
    wire        if_any_ex_reg;
    //jump
    wire        br_type, jump_type, call_type, ret_type;
    wire        always_br, br_opst, br_eq, br_lt, br_ge;
    wire        br_equ, br_neq, br_lth, br_ltu, br_geq, br_geu;
    wire        br_cond_ok;
    wire        br_taken;
    wire [31:0] br_res;
    wire [31:0] pc_seqnxt;
    wire [ 7:0] btb_wtag;
    wire [31:0] btb_target;
    wire [ 2:0] btb_type;
    //cache
    wire        mem_valid;
    wire [ 3:0] byte_mask;
    wire [ 3:0] hlfwd_mask;
    //exe2mem_bus
    wire [31:0] pc;
    wire [31:0] exe_result;
    wire        forwrd_on_mem;
    wire        forwrd_on_wb;
    wire [31:0] rj_value;
    wire [31:0] rd_value;
    wire [ 4:0] rd_addr;
    wire        mem_ld;
    wire        mem_st;
    wire        mem_isll;
    wire        mem_issc;
    wire        mem_ispreld;
    wire        mem_usign;
    wire [ 3:0] mem_mask;
    wire [ 2:0] mem_len;
    wire        mem_has_req;
    wire        mem_res_ld;
    wire        cacop_valid;
    wire        cacop_target;
    wire        cacop_op2;
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
    wire [ 9:0] exe_ex_bus;
    //alu
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] alu_result;
    wire [31:0] quick_sum;
    wire        neq, lt, ltu;
    wire        alu_res_ready;
//id2exe_bus
    assign {
        ras_chkpt_reg,
        pc_reg,
        forwrd_on_exe_reg,
        forwrd_on_mem_reg,
        forwrd_on_wb_reg,
        forwrd_ptr_reg,
        src1_pc_reg,
        alu_src1_reg,
        alu_src2_reg,
        rd_value_reg,
        rd_addr_reg,
        alu_op_reg,
        multi_circle_reg,
        id_isidle_reg,
        mem_ld_reg,
        mem_st_reg,
        mem_isll_reg,
        mem_issc_reg,
        mem_ispreld_reg,
        mem_len_reg,
        mem_usign_reg,
        cacop_valid_reg,
        cacop_target_reg,
        cacop_op_reg,
        br_inst_reg,
        br_src1_pc_reg,
        tlb_inst_reg,
        gr_we_reg,
        wb_src_reg,
        csr_we_reg,
        csr_nomask_reg,
        id_isertn_reg,
        id_flush_reg,
        id_ex_bus_reg,
        id_any_ex_reg,
        if_any_ex_reg
    } = id2exe_bus_reg;
//forward
    assign forwrd_we  = forwrd_on_exe_reg && (is_hold || (is_fresh && alu_res_ready));
    assign forwrd_ptr = forwrd_ptr_reg;
    assign forwrd_res = alu_result;
//jump
    assign {br_type, jump_type, call_type, ret_type} = cacop_op_reg;
    assign {always_br, br_opst, br_ge, br_lt, br_eq} = tlb_inst_reg;
    assign br_equ       = br_eq && ~br_opst;
    assign br_lth       = br_lt && ~br_opst;
    assign br_geq       = br_ge && ~br_opst;
    assign br_neq       = br_eq &&  br_opst;
    assign br_ltu       = br_lt &&  br_opst;
    assign br_geu       = br_ge &&  br_opst;
    assign br_cond_ok   = always_br || (br_equ && ~neq) || (br_neq &&  neq)
                                    || (br_lth &&  lt ) || (br_ltu &&  ltu)
                                    || (br_geq && ~lt ) || (br_geu && ~ltu);
    assign br_taken     = br_inst_reg && br_cond_ok;
    assign br_res       = (br_src1_pc_reg ? pc_reg : alu_src1_reg) + rd_value_reg;
    assign pc_seqnxt    = pc_reg + 32'd4;
    assign br_target    = br_cond_ok ? br_res : pc_seqnxt;
    assign pred_flush   = id_is_fresh && ~recovery_mode && ((br_taken ? br_res : pc_seqnxt) != id2exe_bus[`ID_BUS_PC]);
    assign btb_wr_pc    = pc_reg[13:2];
    assign btb_we       = br_taken && pred_flush && ~ret_type;
    assign btb_wtag     = pc_reg[15:8];
    assign btb_target   = br_res;
    assign btb_type     = cacop_op_reg[3:1];    //not record ret_type
    assign btb_wdata    = {btb_wtag, btb_target, btb_type, 1'b1};
    assign pht1_idx     = pc_reg[9:2];
    assign pht1_we      = id_is_fresh && ~recovery_mode && br_inst_reg && br_type;
    assign pht1_taken   = br_taken;
    assign ras_rollbk   = pred_flush || ex_flush;
    assign rllbk_ckpt   = ex_flush ? ras_chkpt_reg
                                : (({3{call_type}} & (ras_chkpt_reg + 3'b1))
                                 | ({3{ret_type }} & (ras_chkpt_reg - 3'b1))
                                 | ({3{~(call_type | ret_type)}} & ras_chkpt_reg));
//tlb
    assign tlb_vppn     = quick_sum[31:13];
    assign tlb_va_bit12 = quick_sum[12];
    assign tlb_asid     = asid_asid;
//cache
    assign icache_cacop_valid    = is_fresh && cacop_valid_reg && ~any_excp && cacop_target_reg && allow_icacop;
    assign icache_cacop_op       = cacop_op_reg;
    assign icache_cacop_tagt_idx = quick_sum[11:4];
    assign icache_cacop_tagt_way = quick_sum[0];
    assign dcache_cacop_valid    = is_fresh && cacop_valid_reg && ~any_excp && ~cacop_target_reg && allow_dcacop;
    assign dcache_cacop_op       = cacop_op_reg;
    assign dcache_cacop_tagt_way = quick_sum[0];
    assign dcache_index          = quick_sum[11:4];
    assign dcache_op             = mem_st_reg;  //1: store, 0: load
    assign mem_valid             = ((mem_isll_reg | mem_issc_reg) & ~ll_running)
                                 | mem_ld_reg | mem_st_reg | mem_ispreld_reg;
    assign dcache_valid          = is_fresh & allow_mem & mem_valid & ~any_excp;
    assign dcache_wdata          = ({32{mem_len_reg[0] &  byte_mask[0]}} & {24'b0, rd_value_reg[7:0]})    //migrate to dcache?
                                 | ({32{mem_len_reg[0] &  byte_mask[1]}} & {16'b0, rd_value_reg[7:0], 8'b0})
                                 | ({32{mem_len_reg[0] &  byte_mask[2]}} & {8'b0, rd_value_reg[7:0], 16'b0})
                                 | ({32{mem_len_reg[0] &  byte_mask[3]}} & {rd_value_reg[7:0], 24'b0})
                                 | ({32{mem_len_reg[1] & ~quick_sum[1]}} & {16'b0, rd_value_reg[15:0]})
                                 | ({32{mem_len_reg[1] &  quick_sum[1]}} & {rd_value_reg[15:0], 16'b0})
                                 | ({32{mem_len_reg[2]                }} &  rd_value_reg);
    assign dcache_wstrb          = ({4{mem_len_reg[0]}} & byte_mask )
                                 | ({4{mem_len_reg[1]}} & hlfwd_mask)
                                 | ({4{mem_len_reg[2]}} & 4'hf      );
    decoder_2_4 byte_mask_gen(.in(quick_sum[1:0]), .out(byte_mask));
    assign hlfwd_mask = quick_sum[1] ? 4'b1100 : 4'b0011;
//exe2mem_bus
    assign pc              = pc_reg;
    assign exe_result      = alu_result;
    assign forwrd_on_mem   = forwrd_on_mem_reg;
    assign forwrd_on_wb    = forwrd_on_wb_reg;
    assign rj_value        = alu_src1_reg;
    assign rd_value        = rd_value_reg;
    assign rd_addr         = rd_addr_reg;
    assign mem_ld          = mem_ld_reg;
    assign mem_st          = mem_st_reg;
    assign mem_isll        = mem_isll_reg;
    assign mem_issc        = mem_issc_reg;
    assign mem_ispreld     = mem_ispreld_reg;
    assign mem_usign       = mem_usign_reg;
    assign mem_mask        = byte_mask;
    assign mem_len         = mem_len_reg;
    assign mem_has_req     = mem_ld_reg | mem_st_reg | mem_isll_reg | mem_issc_reg | mem_ispreld_reg;
    assign mem_res_ld      = mem_ld_reg | mem_isll_reg;
    assign cacop_valid     = cacop_valid_reg;
    assign cacop_target    = cacop_target_reg;
    assign cacop_op2       = cacop_valid_reg & cacop_op_reg[2];
    assign tlb_inst        = br_inst_reg ? 5'b0 : tlb_inst_reg;    //unmux
    assign id_isidle       = id_isidle_reg;
    assign id_isertn       = id_isertn_reg;
    assign id_flush        = id_flush_reg;
    assign gr_we           = gr_we_reg;
    assign wb_src          = wb_src_reg;
    assign csr_we          = csr_we_reg;
    assign csr_nomask      = csr_nomask_reg;
    assign if_any_ex       = if_any_ex_reg;
    assign id_any_ex       = id_any_ex_reg;
    assign exe_ex_bus      = id_ex_bus_reg;
    assign exe2mem_bus = {
        pc,
        exe_result,
        forwrd_on_mem,
        forwrd_on_wb,
        forwrd_ptr,
        rj_value,
        rd_value,
        rd_addr,
        mem_ld,
        mem_st,
        mem_isll,
        mem_issc,
        mem_ispreld,
        mem_usign,
        mem_mask,
        mem_len,
        mem_has_req,
        mem_res_ld,
        cacop_valid,
        cacop_target,
        cacop_op2,
        tlb_inst,
        id_isidle,
        id_isertn,
        id_flush,
        gr_we,
        wb_src,
        csr_we,
        csr_nomask,
        if_any_ex,
        id_any_ex,
        exe_ex_bus
    };
//fsm
    assign any_excp     = if_any_ex_reg | id_any_ex_reg | mem_any_ex;
    assign stall_now    = any_excp | id_flush_reg | id_isidle_reg;
    assign exe_ready_go = is_hold | (is_fresh & (any_excp                                 //excp
                                    | (icache_cacop_valid & icache_cacop_req_ok)//cacop, sucks :(
                                    | (dcache_cacop_valid & dcache_cacop_req_ok)
                                    | (mem_has_req & dcache_valid & dcache_addr_ok)       //mem, sucks :(
                                    | (~(cacop_valid_reg | mem_has_req) & alu_res_ready))); //others, optimize generation of this condition, to do :(
    assign exe_allowin  = ((is_expired & ~stall_flag) | (exe_ready_go & mem_allowin)) & ~pred_flush;
    assign new_entry    = id_ready_go & exe_allowin;
    always @(posedge clk) begin
        if (rst || ex_flush || pred_flush)
            recovery_mode <= 1'b1;
        else if (new_entry)
            recovery_mode <= 1'b0;

        if (rst || ex_flush)
            stall_flag <= 1'b0;
        else if (is_fresh && stall_now)
            stall_flag <= 1'b1;

        if (new_entry)
            id2exe_bus_reg <= id2exe_bus;

        if (rst || ex_flush)
            exe_state               <= expired;
        else begin
            case (exe_state)
                expired: 
                    if (new_entry)
                        exe_state <= fresh;
                fresh:
                    if (stall_now)
                        exe_state  <= mem_allowin ? expired : hold;
                    else if (exe_ready_go) begin
                        if (mem_allowin) begin
                            if (~new_entry)
                                exe_state <= expired;
                        end else
                            exe_state <= hold;
                    end
                hold: 
                    if (mem_allowin)
                        exe_state <= stall_flag ? expired : (new_entry ? fresh : expired);
            endcase
        end
    end
//alu
    assign alu_src1 = src1_pc_reg ? pc_reg : alu_src1_reg;
    assign alu_src2 = alu_src2_reg;
    alu u_alu(
        .clk            (clk                ),
        .rst            (rst                ),
        .ex_flush       (ex_flush           ),
        .multi_circle   (multi_circle_reg   ),
        .new_entry      (new_entry          ),
        .alu_op         (alu_op_reg         ),
        .alu_src1       (alu_src1           ),
        .alu_src2       (alu_src2           ),
        .alu_result     (alu_result         ),
        .quick_sum      (quick_sum          ),
        .neq            (neq                ),
        .lt             (lt                 ),
        .ltu            (ltu                ),
        .res_ready      (alu_res_ready      )
    );
endmodule
