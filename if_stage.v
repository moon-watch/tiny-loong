`include "cpu_config.h"
`include "bus_width.h"
module if_stage (
    input  wire         clk,
    input  wire         rst,
    //cacop
    input  wire         cacop_valid,
    input  wire [ 3:0]  cacop_op,
    output wire         cacop_req_ok,
    input  wire [ 7:0]  cacop_target_index,
    input  wire         cacop_target_way,
    input  wire [19:0]  cacop_target_tag,
    output wire         cacop_ok,
    //flush
    input  wire         ex_flush,
    input  wire         ertn_flush,
    input  wire [31:0]  ex_next_pc,
    input  wire [31:0]  ertn_next_pc,
    input  wire         pred_flush,
    input  wire [31:0]  br_target,
    //btb
    output wire [11:0]  btb_fetch_pc,
    output wire [ 7:0]  btb_tag_buf,
    input  wire         btb_hit,
    input  wire [ 2:0]  btb_type,
    input  wire [31:0]  btb_target,
    //ras
    output wire         is_call,
    output wire [31:0]  call_target,
    output wire         is_rtn,
    input  wire [31:0]  rtn_target,
    input  wire [ 2:0]  ras_chkpt,
    //pht
    output wire [ 7:0]  pht0_idx,
    input  wire         pht0_taken,
    //next_stage
    output wire [`IF_BUS_W - 1:0] if2id_bus,
    output wire         if_ready_go,
    input  wire         id_allowin,
    //csr
    input  wire         crmd_da,
    input  wire         crmd_pg,
    input  wire [ 1:0]  crmd_datf,
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
    input  wire         tlb_v,
    //icache
    output wire         icache_cacop_valid,
    output wire [ 3:0]  icache_cacop_op,
    input  wire         icache_cacop_req_ok,
    input  wire         icache_cacop_running,
    output wire         icache_cacop_target_way,
    input  wire         icache_cacop_ok,
    output wire         icache_mem_cancel,
    output wire         icache_valid,
    input  wire         icache_addr_ok,
    output wire         icache_mat,
    output wire [ 7:0]  icache_index,
    output wire [ 7:0]  icache_index_buf,
    output wire [19:0]  icache_tag,
    output wire [ 3:0]  icache_offset_buf,
    input  wire         icache_data_ok,
    input  wire [31:0]  icache_rdata
);
//declaration
    //fsm
    localparam  expired     = 3'b001;
    localparam  fresh       = 3'b010;
    localparam  hold        = 3'b100;
    reg  [ 2:0] if_state;
    wire        is_expired  = if_state[0];
    wire        is_fresh    = if_state[1];
    wire        is_hold     = if_state[2];
    wire [31:0] pc;
    wire [31:0] inst;
    reg  [31:0] pc_reg;
    reg  [31:0] inst_reg;
    reg         stall_flag;
    wire        stall_now;
    wire        new_entry;
    wire        fetch_valid;
    wire        any_excp;
    wire        mem_cancel;
    //addr trans
    wire        dmw0_hit;
    wire        dmw1_hit;
    wire        dmw_hit;
    wire        direct_access;
    wire [32:0] physical_addr;
    //excp
    wire        if_adef;
    wire        if_tlbr;
    wire        if_pif;
    wire        if_ppi;
    wire        if_any_ex;
    wire [ 3:0] if_ex_bus;
    //pred
    wire        btb_new_enty;
    wire        br_type, jump_type, call_type;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [15:0] ofst_16;
    wire [ 5:0] opcode;
    wire        inst_bl, inst_jirl;
    wire [31:0] pc_seqnxt;
    wire [31:0] pred_target;
    wire [31:0] fetch_pc;
    reg         recovery_mode;
//if2id_bus
    assign  if2id_bus = {
        ras_chkpt,
        inst,
        pc,
        if_ex_bus,
        if_any_ex
    };
//addr_trans
    assign {tlb_vppn, tlb_va_bit12} = pc_reg[31:12];
    assign tlb_asid         = asid_asid;
    assign dmw0_hit         = (pc_reg[31:29] == dmw0_vseg) && ((crmd_plv == 2'd3 && dmw0_plv3 == 1'b1) || (crmd_plv == 2'd0 && dmw0_plv0 == 1'b1));
    assign dmw1_hit         = (pc_reg[31:29] == dmw1_vseg) && ((crmd_plv == 2'd3 && dmw1_plv3 == 1'b1) || (crmd_plv == 2'd0 && dmw1_plv0 == 1'b1));
    assign dmw_hit          = dmw0_hit || dmw1_hit;
    assign direct_access    = crmd_da == 1'b1 && crmd_pg == 1'b0;
    assign physical_addr    = direct_access ? {crmd_datf[0], pc_reg}                                                        //direct map
                            :  dmw_hit ? {(dmw0_hit ? {dmw0_mat[0], dmw0_pseg} : {dmw1_mat[0], dmw1_pseg}), pc_reg[28:0]}   //dmw
                            : {tlb_mat[0], tlb_ppn[19:9], (tlb_ps == 6'd21 ? pc_reg[20:12] : tlb_ppn[8:0]), pc_reg[11:0]};  //tlb
//excp
    assign if_adef      = pc_reg[0] | pc_reg[1];
    assign if_tlbr      = ~direct_access && ~dmw_hit && ~tlb_found;
    assign if_pif       = ~direct_access && ~dmw_hit &&  tlb_found && ~tlb_v;
    assign if_ppi       = ~direct_access && ~dmw_hit &&  tlb_found &&  tlb_v && (crmd_plv == 2'd3 && tlb_plv == 2'd0);
    assign if_any_ex    = if_tlbr || if_pif || if_ppi || if_adef;
    assign if_ex_bus    = {if_adef, if_tlbr, if_pif, if_ppi};
//pred
    assign btb_new_enty = ((is_fresh && icache_data_ok) || (is_hold && icache_addr_ok)) && id_allowin;
    assign btb_fetch_pc = btb_new_enty ? fetch_pc[13:2] : pc_reg[13:2];
    assign btb_tag_buf  = pc_reg[15:8];
    assign {br_type, jump_type, call_type} = btb_type;
    assign pc_seqnxt    = pc_reg + 32'd4;
    assign rd           = inst[4:0];
    assign rj           = inst[9:5];
    assign ofst_16      = inst[25:10];
    assign opcode       = inst[31:26];
    assign inst_bl      = opcode == 6'b010101;
    assign inst_jirl    = opcode == 6'b010011;
    assign is_call      = btb_new_enty && (inst_bl || (inst_jirl && (rd == 5'd1) && (ofst_16 == 16'b0)));
    assign call_target  = pc_seqnxt;
    assign is_rtn       = btb_new_enty && inst_jirl && (rd == 5'd0) && (rj == 5'd1) && (ofst_16 == 16'b0);
    assign pred_target  = (btb_hit && (jump_type || call_type || (br_type && pht0_taken))) ? btb_target : pc_seqnxt;
    assign fetch_pc     = recovery_mode ? pc_reg : (is_rtn ? rtn_target : pred_target);
    assign pht0_idx     = pc_reg[9:2];
//icache
    assign icache_cacop_valid = cacop_valid;
    assign icache_cacop_op    = cacop_op;
    assign cacop_req_ok       = icache_cacop_req_ok;
    assign icache_cacop_target_way = cacop_target_way;
    assign cacop_ok           = icache_cacop_ok;
    assign icache_mem_cancel  = mem_cancel;
    assign icache_valid       = fetch_valid;
    assign icache_mat         = physical_addr[32];
    assign icache_index       = cacop_valid ? cacop_target_index : fetch_pc[11:4];
    assign icache_index_buf   = physical_addr[11:4];
    assign icache_tag         = icache_cacop_running ? cacop_target_tag : physical_addr[31:12];
    assign icache_offset_buf  = physical_addr[3:0];
//fsm
    assign any_excp     = if_any_ex;
    assign stall_now    = any_excp; //if doesn't need stall, can be removed, to do :(
    assign fetch_valid  = (is_expired && ~stall_flag) || ((is_fresh || is_hold) && id_allowin);
    assign mem_cancel   = is_fresh && (any_excp || cacop_valid);
    assign new_entry    = fetch_valid && icache_addr_ok && ~mem_cancel;
    assign inst         = is_hold ? inst_reg : icache_rdata;
    assign pc           = pc_reg;
    assign if_ready_go  = (is_fresh && (icache_data_ok || any_excp)) || is_hold;
    always @(posedge clk) begin
        if (rst || ex_flush || pred_flush)
            recovery_mode <= 1'b1;
        else if (new_entry)
            recovery_mode <= 1'b0;

        if (rst || ex_flush || pred_flush)
            stall_flag <= 1'b0;
        else if (is_fresh && stall_now)
            stall_flag <= 1'b1;

        if (rst)
            pc_reg <= `RESET_PC;
        else if (ex_flush)
            pc_reg <= ertn_flush ? ertn_next_pc : ex_next_pc;
        else if (pred_flush)
            pc_reg <= br_target;
        else if (new_entry)
            pc_reg <= fetch_pc;

        if (is_fresh && if_ready_go && ~id_allowin)
            inst_reg <= icache_rdata;

        if (rst || ex_flush || pred_flush) begin
            if_state <= expired;
        end else begin
            case (if_state)
                expired:
                    if (new_entry)
                        if_state <= fresh;
                fresh:
                    if (stall_now)
                        if_state    <= id_allowin ? expired : hold;
                    else if (if_ready_go) begin
                        if (id_allowin) begin
                            if (~new_entry)
                                if_state <= expired;
                        end else
                            if_state <= hold;
                    end
                hold:
                    if (id_allowin)
                        if_state <= stall_flag ? expired : (new_entry ? fresh : expired);
            endcase
        end
    end
endmodule
