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
    localparam  idle     = 6'b000001;
    localparam  wrlookup = 6'b000010;
    localparam  hitwr    = 6'b000100;
    localparam  rdlookup = 6'b001000;
    localparam  refill   = 6'b010000;
    localparam  sucok    = 6'b100000;
    reg  [ 5:0] cache_state;
    wire        is_idle     = cache_state[0];
    wire        is_wrlookup = cache_state[1];
    wire        is_hitwr    = cache_state[2];
    wire        is_rdlookup = cache_state[3];
    wire        is_refill   = cache_state[4];
    wire        is_sucok    = cache_state[5];
    localparam  rfidle      = 1'b0;
    localparam  rf          = 1'b1;
    reg         rf_state;
    wire        is_rf       = rf_state;
    reg         rf_req_reg;
    reg  [ 3:0] rf_cnt_reg;
    localparam  wbidle      = 2'b00;
    localparam  wb          = 2'b01;
    localparam  recevb      = 2'b11;
    reg  [ 1:0] wb_state;
    wire        is_recevb   = wb_state[1];
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
    reg         tag_we_reg;
    wire [19:0] tag_wdata;
    wire [ 7:0] tag_index;
    wire [ 1:0] tag_we;
    wire [19:0] tag_rdata [1:0];
    wire        way0_hit;
    wire        way1_hit;
    wire        hit;
    wire        hit_way;
    wire [31:0] cache_wdata;
    wire [ 7:0] cache_index;
    reg  [ 3:0] cache_we_reg [1:0];
    wire [ 3:0] cache_we [1:0];
    wire [ 3:0] cache_wstrb;
    wire [31:0] way0_rd_data [3:0];
    wire [31:0] way1_rd_data [3:0];
    reg  [31:0] wb_buf;
    //lfsr
    reg   [7:0] lfsr;
    reg         target_way_reg;
    wire        target_way;
    //cpu_interface
    reg         cacop_accepted;
    reg         cacop_ok_reg;
//cpu_interface
    assign addr_ok = (is_hitwr & hit & op) | (((is_rdlookup & hit & ~mem_cancel) | is_idle | is_sucok) & ~cacop_accepted);  //Sucks :(
    assign data_ok = (is_hitwr & hit) | (is_rdlookup & hit) | is_sucok;
    assign rdata   = mat ? (hit_way ? way1_rd_data[offset_buf[3:2]] : way0_rd_data[offset_buf[3:2]])
                         : wb_buf;
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
    assign axi_arvalid  = axi_arvalid_reg & ~wb_req_reg;
    assign axi_araddr   = mat ? {tag, index_buf, 4'b0000}
                              : {tag, index_buf, offset_buf[3:2], 2'b0};
    assign axi_arsize   = 3'd2;
    assign axi_arlen    = mat ? 8'd3 : 8'd0;
    assign axi_arburst  = 2'b01;
    assign axi_wvalid   = axi_wvalid_reg;
    assign axi_wdata    = (mat | cacop_accepted) ?
                            ({32{wb_cnt_reg[0]}} & (target_way_reg ? way1_rd_data[0] : way0_rd_data[0])) |
                            ({32{wb_cnt_reg[1]}} & (target_way_reg ? way1_rd_data[1] : way0_rd_data[1])) |
                            ({32{wb_cnt_reg[2]}} & (target_way_reg ? way1_rd_data[2] : way0_rd_data[2])) |
                            ({32{wb_cnt_reg[3]}} & (target_way_reg ? way1_rd_data[3] : way0_rd_data[3])) : wdata_buf;
    assign axi_wstrb    = (mat | cacop_accepted) ? 4'hf : wstrb_buf;
    assign axi_wlast    = axi_wlast_reg;
    assign axi_bready   = 1'b1;
    assign axi_rready   = axi_rready_reg;
//ram
    assign wdata_buf    = write_buf[35:4];
    assign wstrb_buf    = write_buf[ 3:0];
    //tag
    assign tag_wdata    = cacop_accepted ? 20'b0 : tag;
    assign tag_index    = (is_refill | is_wrlookup | cacop_accepted) ? index_buf : index;
    assign tag_we[0]    = tag_we_reg & ~target_way_reg;
    assign tag_we[1]    = tag_we_reg & target_way_reg;
    assign way0_hit     = (tag_rdata[0] == tag) && v_value[0][index_buf];
    assign way1_hit     = (tag_rdata[1] == tag) && v_value[1][index_buf];
    assign hit          = (way0_hit | way1_hit) & (mat | cacop_accepted);
    assign hit_way      = way1_hit;
    //data_bank
    assign cache_wdata  = {32{is_refill}} & axi_rdata
                        | {32{is_hitwr }} & wdata_buf;
    assign cache_index  = (is_hitwr | is_refill) ? index_buf : index;
    assign cache_we[0]  = ({4{is_hitwr}} & cache_we_reg[0])
                        | ({4{is_refill & ~target_way_reg & mat & axi_rvalid}} & rf_cnt_reg);
    assign cache_we[1]  = ({4{is_hitwr}} & cache_we_reg[1])
                        | ({4{is_refill &  target_way_reg & mat & axi_rvalid}} & rf_cnt_reg);
    assign cache_wstrb  = ({4{is_hitwr}} & wstrb_buf)
                        | ({4{is_refill}} & 4'hf);
//lfsr
    assign target_way = lfsr[3];
//fsm
    always @(posedge clk) begin
        if (rst) begin
            cache_state         <= idle;
            rf_state            <= rfidle;
            wb_state            <= wbidle;
            axi_awvalid_reg     <= 1'b0;
            axi_arvalid_reg     <= 1'b0;
            axi_wvalid_reg      <= 1'b0;
            axi_wlast_reg       <= 1'b0;
            axi_rready_reg      <= 1'b0;
            d_value[0]          <= 256'b0;
            d_value[1]          <= 256'b0;
            cache_we_reg[0]     <= 4'b0;
            cache_we_reg[1]     <= 4'b0;
            lfsr                <= 8'h80;
            rf_req_reg          <= 1'b0;
            wb_req_reg          <= 1'b0;
            tag_we_reg          <= 1'b0;
            cacop_accepted      <= 1'b0;
            cacop_ok_reg        <= 1'b0;
        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};
            case (cache_state)
                idle: begin
                    if (tag_we_reg)
                        tag_we_reg <= 1'b0;
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
                                tag_we_reg <= 1'b1;
                                cacop_ok_reg <= 1'b1;
                            end
                            if (cacop_op[1]) begin
                                target_way_reg <= cacop_target_way;
                                v_value[cacop_target_way][index] <= 1'b0;
                                if (d_value[cacop_target_way][index]
                                    & v_value[cacop_target_way][index]) begin
                                    cache_state <= refill;
                                    wb_req_reg <= 1'b1;
                                    axi_awvalid_reg <= 1'b1;
                                end else
                                    cacop_ok_reg <= 1'b1;
                            end
                            if (cacop_op[2])
                                cache_state <= rdlookup;
                        end else if (valid) begin
                            if (op) begin
                                write_buf   <= {wdata, wstrb};
                                cache_state <= wrlookup;
                            end else
                                cache_state <= rdlookup;
                        end
                end
                wrlookup: 
                    if (mem_cancel)
                        cache_state <= idle;
                    else begin
                        if (hit) begin
                            cache_state <= hitwr;
                            cache_we_reg[hit_way][offset_buf[3:2]] <= 1'b1;
                        end else begin
                            target_way_reg <= target_way;
                            cache_state <= refill;
                            if (mat) begin
                                tag_we_reg <= 1'b1;
                                rf_req_reg <= 1'b1;
                                axi_arvalid_reg <= 1'b1;
                                v_value[target_way][index_buf] <= 1'b1;
                            end
                            if ((d_value[target_way][index_buf]
                                & v_value[target_way][index_buf]) | ~mat) begin
                                tag_buf <= tag_rdata[target_way];
                                wb_req_reg <= 1'b1;
                                axi_awvalid_reg <= 1'b1;
                            end
                        end
                    end
                hitwr:
                    if (hit) begin
                        d_value     [hit_way][index_buf]       <= 1'b1;
                        cache_we_reg[hit_way][offset_buf[3:2]] <= 1'b0;
                        if (valid) begin
                            if (op) begin
                                write_buf   <= {wdata, wstrb};
                                cache_state <= wrlookup;
                            end else
                                cache_state <= idle;
                        end else
                            cache_state <= idle;
                    end
                rdlookup: begin
                    target_way_reg <= cacop_accepted ? hit_way : target_way;
                    if (mem_cancel)
                        cache_state <= idle;
                    else
                        if (hit) begin
                            if (cacop_accepted) begin
                                v_value[hit_way][index_buf] <= 1'b0;
                                if (d_value[hit_way][index_buf]) begin
                                    cache_state <= refill;
                                    wb_req_reg <= 1'b1;
                                    axi_awvalid_reg <= 1'b1;
                                end else begin
                                    cache_state <= idle;
                                    cacop_ok_reg <= 1'b1;
                                end
                            end else if (valid) begin
                                if (op) begin
                                    write_buf   <= {wdata, wstrb};
                                    cache_state <= wrlookup;
                                end
                            end else
                                cache_state <= idle;
                        end else begin
                            if (cacop_accepted) begin
                                cache_state <= idle;
                                cacop_ok_reg <= 1'b1;
                            end else begin
                                cache_state     <= refill;
                                rf_req_reg      <= 1'b1;
                                axi_arvalid_reg <= 1'b1;
                                if (mat) begin
                                    tag_we_reg      <= 1'b1;
                                    v_value[target_way][index_buf] <= 1'b1;
                                    d_value[target_way][index_buf] <= 1'b0;
                                end
                                if (v_value[target_way][index_buf]
                                    & d_value[target_way][index_buf] & mat) begin
                                    tag_buf <= tag_rdata[target_way];
                                    wb_req_reg      <= 1'b1;
                                    axi_awvalid_reg <= 1'b1;
                                end
                            end
                        end
                end
                refill: begin
                    case (rf_state)
                        rfidle:
                            if (rf_req_reg & ~wb_req_reg & axi_arready) begin
                                axi_arvalid_reg <= 1'b0;
                                axi_rready_reg  <= 1'b1;
                                rf_state        <= rf;
                                rf_cnt_reg      <= 4'b0001;
                            end
                        rf:
                            if (axi_rvalid) begin
                                rf_cnt_reg <= {rf_cnt_reg[2:0], rf_cnt_reg[3]};
                                if (!mat)
                                    wb_buf <= axi_rdata;
                                if (axi_rresp != 2'b00) begin
                                    rf_state        <= rfidle;
                                    axi_arvalid_reg <= 1'b1;
                                    axi_rready_reg  <= 1'b0;    
                                end else if (axi_rlast) begin
                                    rf_state        <= rfidle;
                                    rf_req_reg      <= 1'b0;
                                    axi_rready_reg  <= 1'b0;
                                end
                            end
                    endcase
                    case (wb_state)
                        wbidle:
                            if (wb_req_reg & axi_awready) begin
                                wb_state        <= wb;
                                axi_awvalid_reg <= 1'b0;
                                axi_wvalid_reg  <= 1'b1;
                                wb_cnt_reg      <= 4'b0001;
                                if (~(mat | cacop_accepted))
                                    axi_wlast_reg <= 1'b1;
                            end
                        wb:
                            if (axi_wready) begin
                                if (mat | cacop_accepted) begin
                                    wb_cnt_reg <= {wb_cnt_reg[2:0], wb_cnt_reg[3]};
                                    if (wb_cnt_reg[2])
                                        axi_wlast_reg <= 1'b1;
                                    if (wb_cnt_reg[3]) begin
                                        wb_state        <= recevb;
                                        axi_wvalid_reg  <= 1'b0;
                                        axi_wlast_reg   <= 1'b0;
                                    end
                                end else begin
                                    wb_state       <= recevb;
                                    axi_wlast_reg  <= 1'b0;
                                    axi_wvalid_reg <= 1'b0;
                                end
                            end
                        recevb:
                            if (axi_bvalid) begin
                                wb_state <= wbidle;
                                if (axi_bresp != 2'b00)
                                    axi_awvalid_reg <= 1'b1;
                                else
                                    wb_req_reg      <= 1'b0;
                            end
                    endcase
                    if (tag_we_reg)
                        tag_we_reg <= 1'b0;
                    if (~(rf_req_reg | wb_req_reg)) begin   //Sucks :(
                        if (cacop_accepted) begin
                            cacop_ok_reg <= 1'b1;
                            cache_state <= idle;
                        end else if (mat) begin
                            if (op_buf)
                                cache_state <= wrlookup;
                            else
                                cache_state <= rdlookup;
                        end else
                            cache_state <= sucok;
                    end
                end
                sucok: 
                    if (cacop_valid)
                        cache_state <= idle;
                    else if (valid) begin
                        if (op) begin
                            write_buf   <= {wdata, wstrb};
                            cache_state <= wrlookup;
                        end else
                            cache_state <= rdlookup;
                    end else
                        cache_state <= idle;
            endcase
        end
    end
    
    tag_ram way0_tag_ram (
        .wr_data(tag_wdata   ),    // input  [19:0]
        .addr   (tag_index   ),    // input  [7:0]
        .wr_en  (tag_we[0]   ),    // input
        .clk    (clk         ),    // input
        .rst    (rst         ),    // input
        .rd_data(tag_rdata[0])     // output [19:0]
    );
    tag_ram way1_tag_ram (
        .wr_data(tag_wdata   ),    // input  [19:0]
        .addr   (tag_index   ),    // input  [7:0]
        .wr_en  (tag_we[1]   ),    // input
        .clk    (clk         ),    // input
        .rst    (rst         ),    // input
        .rd_data(tag_rdata[1])     // output [19:0]
    );

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : DATA_BANKS
            data_bank_ram way0_data_bank_ram (
                .wr_data    (cache_wdata    ),    // input [31:0]
                .addr       (cache_index    ),    // input [7:0]
                .wr_en      (cache_we[0][i] ),    // input
                .wr_byte_en (cache_wstrb    ),    // input [3:0]
                .clk        (clk            ),    // input
                .rst        (rst            ),    // input
                .rd_data    (way0_rd_data[i])     // output [31:0]
            );
            data_bank_ram way1_data_bank_ram (
                .wr_data    (cache_wdata    ),    // input [31:0]
                .addr       (cache_index    ),    // input [7:0]
                .wr_en      (cache_we[1][i] ),    // input
                .wr_byte_en (cache_wstrb    ),    // input [3:0]
                .clk        (clk            ),    // input
                .rst        (rst            ),    // input
                .rd_data    (way1_rd_data[i])     // output [31:0]
            );
        end
    endgenerate

endmodule
