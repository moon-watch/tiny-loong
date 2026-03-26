module axi_mux (
    input  wire         clk,
    input  wire         rst,
//To cache
    input  wire [31:0]  icache_axi_araddr,
    input  wire         icache_axi_arvalid,
    output wire         icache_axi_arready,
    input  wire [ 2:0]  icache_axi_arsize,
    input  wire [ 7:0]  icache_axi_arlen,
    input  wire [ 1:0]  icache_axi_arburst,
    output wire [31:0]  icache_axi_rdata,
    output wire         icache_axi_rvalid,
    input  wire         icache_axi_rready,
    output wire         icache_axi_rlast,
    output wire [ 1:0]  icache_axi_rresp,
    input  wire [31:0]  dcache_axi_awaddr,
    input  wire         dcache_axi_awvalid,
    output wire         dcache_axi_awready,
    input  wire [ 2:0]  dcache_axi_awsize,
    input  wire [ 7:0]  dcache_axi_awlen,
    input  wire [ 1:0]  dcache_axi_awburst,
    input  wire [31:0]  dcache_axi_wdata,
    input  wire         dcache_axi_wvalid,
    output wire         dcache_axi_wready,
    input  wire [ 3:0]  dcache_axi_wstrb,
    input  wire         dcache_axi_wlast,
    output wire         dcache_axi_bvalid,
    input  wire         dcache_axi_bready,
    output wire [ 1:0]  dcache_axi_bresp,
    input  wire [31:0]  dcache_axi_araddr,
    input  wire         dcache_axi_arvalid,
    output wire         dcache_axi_arready,
    input  wire [ 2:0]  dcache_axi_arsize,
    input  wire [ 7:0]  dcache_axi_arlen,
    input  wire [ 1:0]  dcache_axi_arburst,
    output wire [31:0]  dcache_axi_rdata,
    output wire         dcache_axi_rvalid,
    input  wire         dcache_axi_rready,
    output wire         dcache_axi_rlast,
    output wire [ 1:0]  dcache_axi_rresp,
//To axi
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
    //read back
    input  wire [ 3:0]  rid,
    input  wire [31:0]  rdata,
    input  wire [ 1:0]  rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,
    //write request
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
    //write data
    output wire [ 3:0]  wid,
    output wire [31:0]  wdata,
    output wire [ 3:0]  wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,
    //write back
    input  wire [ 3:0]  bid,
    input  wire [ 1:0]  bresp,
    input  wire         bvalid,
    output wire         bready
);
    localparam IDLE = 2'b00;
    localparam D_RD = 2'b01;
    localparam I_RD = 2'b10;
    reg [1:0] rd_state;
    reg [7:0] rd_cnt;
    wire is_idle = rd_state == 2'b00;
    wire d_rd = rd_state[0];
    wire i_rd = rd_state[1];
    //Read channel
    assign arid     = 'b0;
    assign araddr   = dcache_axi_arvalid ? dcache_axi_araddr : icache_axi_araddr;
    assign arlen    = dcache_axi_arvalid ? dcache_axi_arlen : icache_axi_arlen;
    assign arsize   = dcache_axi_arvalid ? dcache_axi_arsize : icache_axi_arsize;
    assign arburst  = dcache_axi_arvalid ? dcache_axi_arburst : icache_axi_arburst;
    assign arlock   = 'b0;
    assign arcache  = 'b0;
    assign arprot   = 'b0;
    assign arvalid  = is_idle & (dcache_axi_arvalid | icache_axi_arvalid);
    assign dcache_axi_arready = is_idle & arready;
    assign icache_axi_arready = is_idle & arready & ~dcache_axi_arvalid;    //Sucks :(
    assign dcache_axi_rdata = {32{d_rd}} & rdata;
    assign icache_axi_rdata = {32{i_rd}} & rdata;
    assign dcache_axi_rresp = {2{d_rd}} & rresp;
    assign icache_axi_rresp = {2{i_rd}} & rresp;
    assign dcache_axi_rlast = d_rd & rlast;
    assign icache_axi_rlast = i_rd & rlast;
    assign dcache_axi_rvalid = d_rd & rvalid;
    assign icache_axi_rvalid = i_rd & rvalid;
    assign rready   = (d_rd & dcache_axi_rready)
                    | (i_rd & icache_axi_rready);
    assign awid     = 'b0;
    assign awaddr   = dcache_axi_awaddr;
    assign awlen    = dcache_axi_awlen;
    assign awsize   = dcache_axi_awsize;
    assign awburst  = dcache_axi_awburst;
    assign awlock   = 'b0;
    assign awcache  = 'b0;
    assign awprot   = 'b0;
    assign awvalid  = dcache_axi_awvalid;
    assign dcache_axi_awready = awready;
    assign wid      = 'b0;
    assign wdata    = dcache_axi_wdata;
    assign wstrb    = dcache_axi_wstrb;
    assign wlast    = dcache_axi_wlast;
    assign wvalid   = dcache_axi_wvalid;
    assign dcache_axi_wready = wready;
    assign dcache_axi_bresp = bresp;
    assign dcache_axi_bvalid = bvalid;
    assign bready = dcache_axi_bready;
    
    always @(posedge clk) begin
        if (rst)
            rd_state <= IDLE;
        else 
            case (rd_state)
                IDLE: 
                    if (arready)
                        if (dcache_axi_arvalid) begin
                            rd_state <= D_RD;
                            rd_cnt   <= dcache_axi_arlen;
                        end else if (icache_axi_arvalid) begin
                            rd_state <= I_RD;
                            rd_cnt   <= icache_axi_arlen;
                        end
                D_RD: 
                    if (rvalid & rready)
                        if (rd_cnt == 8'd0)
                            rd_state <= IDLE;
                        else
                            rd_cnt <= rd_cnt - 8'b1;
                I_RD: 
                    if (rvalid & rready)
                        if (rd_cnt == 8'd0)
                            rd_state <= IDLE;
                        else
                            rd_cnt <= rd_cnt - 8'b1;
            endcase
    end
endmodule
