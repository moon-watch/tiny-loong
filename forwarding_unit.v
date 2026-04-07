module forwarding_unit (
    input   wire        clk,
    input   wire        rst,
    input   wire        ex_flush,
    input   wire [ 4:0] query1,
    input   wire [ 4:0] query2,
    output  wire        blocked1,
    output  wire        blocked2,
    output  wire        ready1,
    output  wire        ready2,
    output  wire [31:0] result1,
    output  wire [31:0] result2,
    input   wire        new_rd,
    input   wire [ 4:0] rd,
    input   wire [ 2:0] rd_src,
    output  wire [ 2:0] ptr_out,
    input   wire        exe_ready,
    input   wire [ 2:0] exe_ptr,
    input   wire [31:0] exe_res,
    input   wire        mem_ready,
    input   wire [ 2:0] mem_ptr,
    input   wire [31:0] mem_res,
    input   wire        wb_ready,
    input   wire [ 2:0] wb_ptr,
    input   wire [31:0] wb_res,
    input   wire        gr_wr_en,
    input   wire [ 4:0] wb_index
);
    reg [ 2:0] ptr;
    reg [ 2:0] ptr_reg[31:0];
    reg [ 2:0] src_reg[31:0];
    reg [31:0] valid;
    assign ptr_out      = ptr;
    assign blocked1     = valid[query1];
    assign blocked2     = valid[query2];
    assign ready1 = ((ptr_reg[query1] == exe_ptr) & exe_ready)
                  | ((ptr_reg[query1] == mem_ptr) & mem_ready)
                  | ((ptr_reg[query1] == wb_ptr ) & wb_ready );
    assign ready2 = ((ptr_reg[query2] == exe_ptr) & exe_ready)
                  | ((ptr_reg[query2] == mem_ptr) & mem_ready)
                  | ((ptr_reg[query2] == wb_ptr ) & wb_ready );
    assign result1 = ({32{src_reg[query1][0]}} & exe_res)
                   | ({32{src_reg[query1][1]}} & mem_res)
                   | ({32{src_reg[query1][2]}} & wb_res );
    assign result2 = ({32{src_reg[query2][0]}} & exe_res)
                   | ({32{src_reg[query2][1]}} & mem_res)
                   | ({32{src_reg[query2][2]}} & wb_res );
    always @(posedge clk) begin
        if (rst) begin
            ptr <= 3'b100;
            valid <= 32'b0;
        end else begin
            if (ex_flush)
                valid <= 32'b0;
            else begin
                if (gr_wr_en && ((wb_index == rd) ? ~new_rd : 1'b1)
                    && (ptr_reg[wb_index] == wb_ptr))   //Sucks :(
                    valid[wb_index] <= 1'b0;
                if (new_rd && rd != 5'b0)
                    valid[rd] <= 1'b1;
            end

            if (new_rd) begin
                ptr <= {ptr[0], ptr[2:1]};
                ptr_reg[rd] <= ptr; //maybe a hold time violation
                src_reg[rd] <= rd_src;
            end
        end
    end
endmodule
