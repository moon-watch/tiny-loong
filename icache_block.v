module icache_block (
    input  wire        clk,
    input  wire        rst,

    input  wire        mem_cancel,
    input  wire        mat,
    input  wire        cacop_valid,
    output wire        cacop_req_ok,
    input  wire [3:0]  cacop_op,
    output wire        cacop_ok,
    input  wire        cacop_target_way,
    output wire        cacop_running,
    input  wire [19:0] tag,
    input  wire [ 7:0] index,
    input  wire [ 7:0] index_buf_,
    input  wire [ 3:0] offset_buf,
    input  wire        valid,
    output wire        addr_ok,
    output wire        data_ok,
    output wire [31:0] rdata,

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
//FSM
    localparam IDLE     = 4'b0001;
    localparam RDLOOKUP = 4'b0010;
    localparam REFILL   = 4'b0100;
    localparam SUCOK    = 4'b1000;    //Strongly-ordered UnCached operation OK
    reg [5:0]   cache_state;
    wire        is_idle     = cache_state[0];
    wire        is_rdlookup = cache_state[1];
    wire        is_refill   = cache_state[2];
    wire        is_sucok    = cache_state[3];
    localparam RFIDLE   = 1'b0;
    localparam RF       = 1'b1;
    reg         rf_state;
    reg         after_rf;
    reg         mat_buf;
    reg [ 7:0]  index_buf;  //ex_flush will change external index, which will let refill data be stored incorrectly
    reg [19:0]  tag_buf;    //The same as above, maybe can be muxed with wb_buf, to do :(
//Ports
    assign addr_ok = (is_rdlookup & hit) | ((is_idle | is_sucok) & ~(cacop_valid | cacop_accepted));
    assign data_ok = (is_rdlookup & hit) | is_sucok;
    assign rdata   = mat ? (hit_way ? way1_rd_data[offset_buf[3:2]] : way0_rd_data[offset_buf[3:2]])
                         : wb_buf;
    reg    axi_arvalid_reg;
    reg    axi_rready_reg;
    assign axi_arvalid  = axi_arvalid_reg;
    assign axi_araddr   = mat_buf ? {tag_buf, index_buf, 4'b0000}
                                  : {tag_buf, index_buf, offset_buf[3:2], 2'b0};
    assign axi_arsize   = 3'd2;
    assign axi_arlen    = mat_buf ? 8'd3 : 8'd0;
    assign axi_arburst  = 2'b01;
    assign axi_rready   = axi_rready_reg;
//RAM
    reg [255:0] v_value [1:0];
    //tagv ram
    reg         cacop_w_en;
    wire [19:0] tag_wdata      = cacop_accepted ? 20'b0 : tag_buf;
    wire [ 7:0] tag_index      = (is_refill | cacop_accepted) ? index_buf : index;
    wire [ 1:0] tag_wr_en;
    assign      tag_wr_en[0]   = ((is_refill & axi_rlast & axi_rvalid & mat_buf) | cacop_w_en) & (~target_way_reg);
    assign      tag_wr_en[1]   = ((is_refill & axi_rlast & axi_rvalid & mat_buf) | cacop_w_en) &   target_way_reg ;
    wire [19:0] tag_rdata [1:0];
    wire        way0_hit        = (tag_rdata[0] == (after_rf ? tag_buf : tag)) && v_value[0][index_buf];
    wire        way1_hit        = (tag_rdata[1] == (after_rf ? tag_buf : tag)) && v_value[1][index_buf];
    wire        hit             = (way0_hit | way1_hit) & (mat | cacop_accepted);
    wire        hit_way         = way1_hit;
    //cache block ram
    wire [31:0] cache_wdata     = axi_rdata;
    wire [ 7:0] cache_index     = (is_idle | is_sucok | is_rdlookup) ? index : index_buf;
    wire [ 3:0] cache_wr_en     [1:0];
    assign cache_wr_en[0]       = (is_refill & ~target_way_reg & mat_buf) ? (rf_cnt_reg & {4{axi_rvalid}})
                                                                      : 4'b0;
    assign cache_wr_en[1]       = (is_refill &  target_way_reg & mat_buf) ? (rf_cnt_reg & {4{axi_rvalid}})
                                                                      : 4'b0;
    wire [31:0] way0_rd_data [3:0];
    wire [31:0] way1_rd_data [3:0];
    reg  [31:0] wb_buf; //Used for read data buffer when mat is Strongly-ordered UnCached
//LFSR
    reg   [7:0] lfsr;   //Pseudo-random number generator
    reg         target_way_reg;
    wire        target_way = lfsr[3];

    reg         rf_req_reg;
    reg   [3:0] rf_cnt_reg;
//CACOP
    reg    cacop_accepted;  //A CACOP req has been accepted
    reg    cacop_ok_reg;
    assign cacop_ok = cacop_ok_reg;
    assign cacop_req_ok = is_idle & ~cacop_accepted;
    assign cacop_running = cacop_accepted;

    always @(posedge clk) begin
        if (rst) begin
            cache_state         <= IDLE;
            rf_state            <= RFIDLE;
            after_rf            <= 1'b0;
            axi_arvalid_reg     <= 1'b0;
            // v_value[0]          <= 256'b0;
            // v_value[1]          <= 256'b0;
            lfsr                <= 8'h80;
            rf_req_reg          <= 1'b0;
            cacop_accepted      <= 1'b0;
            cacop_w_en          <= 1'b0;
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
                    if (!cacop_accepted)        //Receive CACOP request
                        if (cacop_valid) begin  //Attention!!! privileged CACOP can't be canceled
                            cacop_accepted <= 1'b1;
                            index_buf <= index;
                            if (cacop_op[0] | cacop_op[3]) begin
                                target_way_reg <= cacop_target_way;
                                v_value[cacop_target_way][index] <= 1'b0;
                                cacop_w_en <= 1'b1;
                                cacop_ok_reg <= 1'b1;
                            end
                            if (cacop_op[1]) begin
                                v_value[cacop_target_way][index] <= 1'b0;
                                cacop_ok_reg <= 1'b1;
                            end
                            if (cacop_op[2])
                                cache_state <= RDLOOKUP;
                        end else if (valid) begin
                            index_buf <= index;
                            cache_state <= RDLOOKUP;
                        end
                end
                RDLOOKUP: begin
                    after_rf <= 1'b0;
                    target_way_reg <= cacop_accepted ? hit_way : target_way;
                    if (mem_cancel)
                        cache_state <= IDLE;
                    else
                        if (hit) begin
                            if (cacop_accepted) begin
                                cache_state <= IDLE;
                                v_value[hit_way][index_buf] <= 1'b0;
                                cacop_ok_reg <= 1'b1;
                            end else if (valid)
                                index_buf <= index;
                            else
                                cache_state <= IDLE;
                        end else begin
                            if (cacop_accepted) begin
                                cache_state <= IDLE;    //CACOP cache miss, do nothing
                                cacop_ok_reg <= 1'b1;
                            end else begin
                                cache_state     <= REFILL;
                                mat_buf         <= mat;
                                index_buf       <= index_buf_;
                                tag_buf         <= tag;
                                rf_req_reg      <= 1'b1;
                                axi_arvalid_reg <= 1'b1;
                                if (mat)
                                    v_value[target_way][index_buf] <= 1'b1;
                            end
                        end
                end
                REFILL: 
                    if (~rf_req_reg)     //Refill finished
                        if (mat_buf) begin
                            after_rf    <= 1'b1;
                            cache_state <= RDLOOKUP;
                        end else
                            cache_state <= SUCOK;
                SUCOK: 
                    if (cacop_valid)
                        cache_state <= IDLE;
                    else if (valid)
                        cache_state <= RDLOOKUP;
                    else
                        cache_state <= IDLE;
            endcase
            case (rf_state) //Read and fill
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
                        if (!mat_buf)
                            wb_buf <= axi_rdata;
                        if (axi_rresp != 2'b00) begin   //Some error occurred, restart RF process
                            rf_state        <= RFIDLE;
                            axi_arvalid_reg <= 1'b1;    //Maybe not a standard timing sequence :(
                            axi_rready_reg  <= 1'b0;    
                        end else if (axi_rlast) begin
                            rf_state        <= RFIDLE;
                            rf_req_reg      <= 1'b0;
                            axi_rready_reg  <= 1'b0;
                        end
                    end
            endcase
        end
    end
    
    tag_ram way0_tag_ram (
        .wr_data(tag_wdata   ),    // input [19:0]
        .addr   (tag_index   ),    // input [7:0]
        .wr_en  (tag_wr_en[0]),    // input
        .clk    (clk         ),    // input
        .rst    (rst         ),    // input
        .rd_data(tag_rdata[0])     // output [19:0]
    );
    tag_ram way1_tag_ram (
        .wr_data(tag_wdata   ),    // input [19:0]
        .addr   (tag_index   ),    // input [7:0]
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
                .wr_byte_en (4'b1111          ),    // input [3:0]
                .clk        (clk              ),    // input
                .rst        (rst              ),    // input
                .rd_data    (way0_rd_data[i]  )     // output [31:0]
            );
            data_bank_ram way1_data_bank_ram (
                .wr_data    (cache_wdata      ),    // input [31:0]
                .addr       (cache_index      ),    // input [7:0]
                .wr_en      (cache_wr_en[1][i]),    // input
                .wr_byte_en (4'b1111          ),    // input [3:0]
                .clk        (clk              ),    // input
                .rst        (rst              ),    // input
                .rd_data    (way1_rd_data[i]  )     // output [31:0]
            );
        end
    endgenerate

endmodule