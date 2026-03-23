module dcache_block (
    input  wire        clk,
    input  wire        rst,
    input  wire        mem_cancel,
    input  wire        mat,
    input  wire        cacop_valid,
    output wire        cacop_req_ok,
    input  wire [3:0]  cacop_op,
    output wire        cacop_ok,
    input  wire        cacop_target_way,
    input  wire [19:0] tag,
    input  wire [ 7:0] index,
    input  wire [ 7:0] index_buf,
    input  wire [ 3:0] offset_buf,
    input  wire        op,
    input  wire        op_buf,
    input  wire        valid,
    output wire        addr_ok,
    output wire        data_ok,
    input  wire [31:0] wdata,
    input  wire [ 3:0] wstrb,
    output wire [31:0] rdata,
    output wire [31:0] axi_awaddr,
    output wire        axi_awvalid,
    input  wire        axi_awready,
    output wire [ 2:0] axi_awsize,
    output wire [ 7:0] axi_awlen,
    output wire [ 1:0] axi_awburst,
    output wire [31:0] axi_wdata,
    output wire        axi_wvalid,
    input  wire        axi_wready,
    output wire [ 3:0] axi_wstrb,
    output wire        axi_wlast,
    input  wire        axi_bvalid,
    output wire        axi_bready,
    input  wire [ 1:0] axi_bresp,
    output wire [31:0] axi_araddr,
    output wire        axi_arvalid,
    input  wire        axi_arready,
    output wire [ 2:0] axi_arsize,
    output wire [ 7:0] axi_arlen,
    output wire [ 1:0] axi_arburst,
    input  wire [31:0] axi_rdata,
    input  wire        axi_rvalid,
    output wire        axi_rready,
    input  wire        axi_rlast,
    input  wire [ 1:0] axi_rresp
);
//declaration
    //fsm
    localparam  IDLE     = 6'b000001;
    localparam  WRLOOKUP = 6'b000010;
    localparam  HITWR    = 6'b000100;
    localparam  RDLOOKUP = 6'b001000;
    localparam  REFILL   = 6'b010000;
    localparam  SUCOK    = 6'b100000;
    reg  [ 5:0] cache_state;
    wire        is_idle     = cache_state[0];
    wire        is_wrlookup = cache_state[1];
    wire        is_hitwr    = cache_state[2];
    wire        is_rdlookup = cache_state[3];
    wire        is_refill   = cache_state[4];
    wire        is_sucok    = cache_state[5];
    localparam  RFIDLE   = 1'b0;
    localparam  RF       = 1'b1;
    reg         rf_state;
    reg         rf_req_reg;
    reg  [ 3:0] rf_cnt_reg;
    localparam  WBIDLE   = 2'b00;
    localparam  WB       = 2'b01;
    localparam  RECEVB   = 2'b11;
    reg  [ 1:0] wb_state;
    reg         wb_req_reg;
    reg  [ 3:0] wb_cnt_reg;
    //axi
    reg         axi_awvalid_reg;
    reg         axi_arvalid_reg;
    reg         axi_wvalid_reg;
    reg         axi_wlast_reg;
    reg         axi_rready_reg;
    wire [19:0] wb_tag;
    wire [ 1:0] ofst_32;
    //ram
    reg [255:0] d_value [1:0];
    reg [255:0] v_value [1:0];
    reg  [19:0] tag_buf;
    reg  [35:0] write_buf;
    wire [31:0] wdata_buf;
    wire [ 3:0] wstrb_buf;
    reg         cacop_w_en;
    wire [19:0] tag_wdata;
    wire [ 7:0] tag_index;
    wire [ 1:0] tag_wr_en;
    wire [19:0] tag_rdata [1:0];
    wire        way0_hit;
    wire        way1_hit;
    wire        hit;
    wire        hit_way;
    wire [31:0] cache_wdata;
    wire [ 7:0] cache_index;
    reg  [ 3:0] cache_wr_en_reg [1:0];
    wire [ 3:0] cache_wr_en [1:0];
    wire [ 3:0] cache_wstrb;
    wire [31:0] way0_rd_data [3:0];
    wire [31:0] way1_rd_data [3:0];
    reg [127:0] wb_buf;
    //lfsr
    reg   [7:0] lfsr;
    reg         target_way_reg;
    wire        target_way;
    //cpu_interface
    reg         cacop_accepted;
    reg         cacop_op1;
    reg         cacop_ok_reg;
//cpu_interface
    assign addr_ok = (is_hitwr & hit & op) | (is_rdlookup & hit & ~mem_cancel) | ((is_idle | is_sucok) & ~cacop_accepted);
    assign data_ok = (is_hitwr & hit) | (is_rdlookup & hit) | is_sucok;
    assign rdata   = mat ? (hit_way ? way1_rd_data[offset_buf[3:2]] : way0_rd_data[offset_buf[3:2]])
                         : wb_buf[31:0];
    assign cacop_ok     = cacop_ok_reg;
    assign cacop_req_ok = is_idle & ~cacop_accepted;
//axi
    assign axi_awvalid  = axi_awvalid_reg;
    assign wb_tag       = cacop_accepted ? tag_rdata[target_way_reg] : mat ? tag_buf : tag;
    assign ofst_32      = (cacop_accepted | mat) ? 2'b00 : offset_buf[3:2];
    assign axi_awaddr   = {wb_tag, index_buf, ofst_32, 2'b00};
    assign axi_awsize   = 3'd2;
    assign axi_awlen    = (mat | cacop_accepted) ? 8'd3 : 8'd0;
    assign axi_awburst  = 2'b01;
    assign axi_arvalid  = axi_arvalid_reg;
    assign axi_araddr   = mat ? {tag, index_buf, 4'b0000}
                              : {tag, index_buf, offset_buf[3:2], 2'b0};
    assign axi_arsize   = 3'd2;
    assign axi_arlen    = mat ? 8'd3 : 8'd0;
    assign axi_arburst  = 2'b01;
    assign axi_wvalid   = axi_wvalid_reg;
    assign axi_wdata    = (mat | cacop_accepted) ? ({32{wb_cnt_reg[0]}} & wb_buf[ 31:0 ]) |
                                                   ({32{wb_cnt_reg[1]}} & wb_buf[ 63:32]) |
                                                   ({32{wb_cnt_reg[2]}} & wb_buf[ 95:64]) |
                                                   ({32{wb_cnt_reg[3]}} & wb_buf[127:96]) : wdata_buf;
    assign axi_wstrb    = (mat | cacop_accepted) ? 4'hF : wstrb_buf;
    assign axi_wlast    = axi_wlast_reg;
    assign axi_bready   = 1'b1;
    assign axi_rready   = axi_rready_reg;
//ram
    assign wdata_buf    = write_buf[35:4];
    assign wstrb_buf    = write_buf[ 3:0];
    //tag
    assign tag_wdata    = cacop_accepted ? 20'b0 : tag;
    assign tag_index    = (is_refill | is_wrlookup | cacop_accepted) ? index_buf : index;
    assign tag_wr_en[0] = ((is_refill & axi_rlast & axi_rvalid & mat) | cacop_w_en) & (~target_way_reg);
    assign tag_wr_en[1] = ((is_refill & axi_rlast & axi_rvalid & mat) | cacop_w_en) &   target_way_reg ;
    assign way0_hit     = (tag_rdata[0] == tag) && v_value[0][index_buf];
    assign way1_hit     = (tag_rdata[1] == tag) && v_value[1][index_buf];
    assign hit          = (way0_hit | way1_hit) & (mat | cacop_accepted);
    assign hit_way      = way1_hit;
    //data_bank
    assign cache_wdata      = is_refill ? axi_rdata : wdata_buf;
    assign cache_index      = (is_idle | is_sucok | is_rdlookup) ? index : index_buf;
    assign cache_wr_en[0]   = (is_refill & ~target_way_reg & mat) ? (rf_cnt_reg & {4{axi_rvalid}})
                                                                      : cache_wr_en_reg[0];
    assign cache_wr_en[1]   = (is_refill &  target_way_reg & mat) ? (rf_cnt_reg & {4{axi_rvalid}})
                                                                      : cache_wr_en_reg[1];
    assign cache_wstrb      = is_refill ? 4'hf : wstrb_buf;
//lfsr
    assign target_way = lfsr[3];
//fsm
    always @(posedge clk) begin
        if (rst) begin
            cache_state         <= IDLE;
            rf_state            <= RFIDLE;
            wb_state            <= WBIDLE;
            axi_awvalid_reg     <= 1'b0;
            axi_arvalid_reg     <= 1'b0;
            axi_wvalid_reg      <= 1'b0;
            axi_wlast_reg       <= 1'b0;
            axi_rready_reg      <= 1'b0;
            d_value[0]          <= 256'b0;
            d_value[1]          <= 256'b0;
            cache_wr_en_reg[0]  <= 4'b0;
            cache_wr_en_reg[1]  <= 4'b0;
            lfsr                <= 8'h80;
            rf_req_reg          <= 1'b0;
            wb_req_reg          <= 1'b0;
            cacop_w_en          <= 1'b0;
            cacop_accepted      <= 1'b0;
            cacop_op1           <= 1'b0;
            cacop_ok_reg        <= 1'b0;
        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};
            case (cache_state)
                IDLE: begin
                    if (cacop_w_en)
                        cacop_w_en <= 1'b0;
                    if (cacop_ok_reg) begin
                        cacop_ok_reg <= 1'b0;
                        cacop_accepted <= 1'b0;
                    end
                    if (!cacop_accepted)
                        if (cacop_valid) begin
                            cacop_accepted <= 1'b1;
                            if (cacop_op[0] | cacop_op[3]) begin
                                target_way_reg <= cacop_target_way;
                                v_value[cacop_target_way][index] <= 1'b0;
                                cacop_w_en <= 1'b1;
                                cacop_ok_reg <= 1'b1;
                            end
                            if (cacop_op[1]) begin
                                target_way_reg <= cacop_target_way;
                                v_value[cacop_target_way][index] <= 1'b0;
                                if (d_value[cacop_target_way][index]) begin
                                    cacop_op1 <= 1'b1;
                                    wb_req_reg <= 1'b1;
                                    axi_awvalid_reg <= 1'b1;
                                end else
                                    cacop_ok_reg <= 1'b1;
                            end
                            if (cacop_op[2])
                                cache_state <= RDLOOKUP;
                        end else if (valid) begin
                            if (op) begin
                                write_buf   <= {wdata, wstrb};
                                cache_state <= WRLOOKUP;
                            end else
                                cache_state <= RDLOOKUP;
                        end
                end
                WRLOOKUP: 
                    if (mem_cancel)
                        cache_state <= IDLE;
                    else begin
                        if (hit) begin
                            cache_state <= HITWR;
                            cache_wr_en_reg[hit_way][offset_buf[3:2]] <= 1'b1;
                        end else begin
                            target_way_reg <= target_way;
                            cache_state <= REFILL;
                            if (mat) begin
                                rf_req_reg <= 1'b1;
                                axi_arvalid_reg <= 1'b1;
                                v_value[target_way][index_buf] <= 1'b1;
                            end
                            if ((d_value[target_way][index_buf]
                                & v_value[target_way][index_buf]) | ~mat) begin
                                wb_buf <= target_way ? {way1_rd_data[3], way1_rd_data[2],
                                                        way1_rd_data[1], way1_rd_data[0]} 
                                                     : {way0_rd_data[3], way0_rd_data[2],
                                                        way0_rd_data[1], way0_rd_data[0]};
                                tag_buf <= tag_rdata[target_way];
                                axi_awvalid_reg <= 1'b1;
                                wb_req_reg <= 1'b1;
                            end
                        end
                    end
                HITWR:
                    if (hit) begin
                        d_value        [hit_way][index_buf]       <= 1'b1;
                        cache_wr_en_reg[hit_way][offset_buf[3:2]] <= 1'b0;
                        if (valid) begin
                            if (op) begin
                                write_buf   <= {wdata, wstrb};
                                cache_state <= WRLOOKUP;
                            end else
                                cache_state <= IDLE;
                        end else
                            cache_state <= IDLE;
                    end else
                        cache_state <= cache_state;
                RDLOOKUP: begin
                    target_way_reg <= cacop_accepted ? hit_way : target_way;
                    if (mem_cancel)
                        cache_state <= IDLE;
                    else
                        if (hit) begin
                            if (cacop_accepted) begin
                                cache_state <= IDLE;
                                v_value[hit_way][index_buf] <= 1'b0;
                                if (d_value[hit_way][index_buf]) begin
                                    wb_buf <= hit_way ? {way1_rd_data[3], way1_rd_data[2],
                                                         way1_rd_data[1], way1_rd_data[0]} 
                                                      : {way0_rd_data[3], way0_rd_data[2],
                                                         way0_rd_data[1], way0_rd_data[0]};
                                    wb_req_reg <= 1'b1;
                                    axi_awvalid_reg <= 1'b1;
                                end else
                                    cacop_ok_reg <= 1'b1;
                            end else if (valid) begin
                                if (op) begin
                                    write_buf   <= {wdata, wstrb};
                                    cache_state <= WRLOOKUP;
                                end
                            end else
                                cache_state <= IDLE;
                        end else begin
                            if (cacop_accepted) begin
                                cache_state <= IDLE;
                                cacop_ok_reg <= 1'b1;
                            end else begin
                                cache_state     <= REFILL;
                                rf_req_reg      <= 1'b1;
                                axi_arvalid_reg <= 1'b1;
                                if (mat) begin
                                    v_value[target_way][index_buf] <= 1'b1;
                                    d_value[target_way][index_buf] <= 1'b0;
                                end
                                if (v_value[target_way][index_buf]
                                    & d_value[target_way][index_buf] & mat) begin
                                        wb_buf <= target_way ? {way1_rd_data[3], way1_rd_data[2],
                                                                way1_rd_data[1], way1_rd_data[0]} 
                                                             : {way0_rd_data[3], way0_rd_data[2],
                                                                way0_rd_data[1], way0_rd_data[0]};
                                        tag_buf <= tag_rdata[target_way];
                                        wb_req_reg      <= 1'b1;
                                        axi_awvalid_reg <= 1'b1;
                                end
                            end
                        end
                end
                REFILL: 
                    if (~(wb_req_reg | rf_req_reg))
                        if (mat)
                            if (op_buf)
                                cache_state <= WRLOOKUP;
                            else
                                cache_state <= RDLOOKUP;
                        else
                            cache_state <= SUCOK;
                SUCOK: 
                    if (cacop_valid)
                        cache_state <= IDLE;
                    else if (valid)
                        if (op) begin
                            write_buf   <= {wdata, wstrb};
                            cache_state <= WRLOOKUP;
                        end else
                            cache_state <= RDLOOKUP;
                    else
                        cache_state <= IDLE;
            endcase
            case (rf_state)
                RFIDLE:
                    if (rf_req_reg & axi_arready) begin
                        axi_arvalid_reg <= 1'b0;
                        axi_rready_reg  <= 1'b1;
                        rf_state        <= RF;
                        rf_cnt_reg      <= 4'b0001;
                    end
                RF:
                    if (axi_rvalid) begin
                        rf_cnt_reg <= rf_cnt_reg << 1;
                        if (!mat)
                            wb_buf[31:0] <= axi_rdata;
                        if (axi_rresp != 2'b00) begin
                            rf_state        <= RFIDLE;
                            axi_arvalid_reg <= 1'b1;
                            axi_rready_reg  <= 1'b0;    
                        end else if (axi_rlast) begin
                            rf_state        <= RFIDLE;
                            rf_req_reg      <= 1'b0;
                            axi_rready_reg  <= 1'b0;
                        end
                    end
            endcase
            case (wb_state)
                WBIDLE:
                    if (wb_req_reg & axi_awready) begin
                        wb_state        <= WB;
                        axi_awvalid_reg <= 1'b0;
                        axi_wvalid_reg  <= 1'b1;
                        wb_cnt_reg      <= 4'b0001;
                        if (~(mat | cacop_accepted))
                            axi_wlast_reg <= 1'b1;
                        if (cacop_op1) begin
                            cacop_op1 <= 1'b0;
                            wb_buf <= target_way_reg ? {way1_rd_data[3], way1_rd_data[2],
                                                        way1_rd_data[1], way1_rd_data[0]} 
                                                     : {way0_rd_data[3], way0_rd_data[2],
                                                        way0_rd_data[1], way0_rd_data[0]};
                        end
                    end
                WB:
                    if (axi_wready) begin
                        if (mat | cacop_accepted) begin
                            wb_cnt_reg      <= wb_cnt_reg << 1;
                            axi_wlast_reg   <= wb_cnt_reg[2] ? 1'b1 : 1'b0;
                            if (wb_cnt_reg[3]) begin
                                wb_state        <= RECEVB;
                                axi_wvalid_reg  <= 1'b0;
                            end
                        end else begin
                            wb_state       <= RECEVB;
                            axi_wlast_reg  <= 1'b0;
                            axi_wvalid_reg <= 1'b0;
                        end
                    end
                RECEVB:
                    if (axi_bvalid) begin
                        wb_state <= WBIDLE;
                        if (axi_bresp != 2'b00)
                            axi_awvalid_reg <= 1'b1;
                        else begin
                            wb_req_reg      <= 1'b0;
                            if (cacop_accepted)
                                cacop_ok_reg <= 1'b1;
                        end
                    end
            endcase
        end
    end
    
    tag_ram way0_tag_ram (
        .wr_data(tag_wdata   ),    // input  [19:0]
        .addr   (tag_index   ),    // input  [7:0]
        .wr_en  (tag_wr_en[0]),    // input
        .clk    (clk         ),    // input
        .rst    (rst         ),    // input
        .rd_data(tag_rdata[0])     // output [19:0]
    );
    tag_ram way1_tag_ram (
        .wr_data(tag_wdata   ),    // input  [19:0]
        .addr   (tag_index   ),    // input  [7:0]
        .wr_en  (tag_wr_en[1]),    // input
        .clk    (clk         ),    // input
        .rst    (rst         ),    // input
        .rd_data(tag_rdata[1])     // output [19:0]
    );

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : DATA_BANKS
            data_bank_ram way0_data_bank_ram (
                .wr_data    (cache_wdata      ),    // input [31:0]
                .addr       (cache_index      ),    // input [7:0]
                .wr_en      (cache_wr_en[0][i]),    // input
                .wr_byte_en (cache_wstrb      ),    // input [3:0]
                .clk        (clk              ),    // input
                .rst        (rst              ),    // input
                .rd_data    (way0_rd_data[i]  )     // output [31:0]
            );
            data_bank_ram way1_data_bank_ram (
                .wr_data    (cache_wdata      ),    // input [31:0]
                .addr       (cache_index      ),    // input [7:0]
                .wr_en      (cache_wr_en[1][i]),    // input
                .wr_byte_en (cache_wstrb      ),    // input [3:0]
                .clk        (clk              ),    // input
                .rst        (rst              ),    // input
                .rd_data    (way1_rd_data[i]  )     // output [31:0]
            );
        end
    endgenerate

endmodule