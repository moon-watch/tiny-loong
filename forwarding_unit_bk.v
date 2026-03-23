module forwarding_unit (    //Sucks :(
    input   wire        clk,
    input   wire        rst,
    //Flush
    input   wire        ex_flush,
    //Emit channel
    input   wire        dest_wr_en,
    input   wire [4:0]  dest_index,
    output  wire [2:0]  current_ptr,    //To exe_stage
    //Query channel
    input   wire [4:0]  query_index1,   //r0 not allowed!
    output  wire        blocked1,
    output  wire        forwrd_ready1,
    output  wire [31:0] forwrd_res1,
    input   wire [4:0]  query_index2,   //r0 not allowed!
    output  wire        blocked2,
    output  wire        forwrd_ready2,
    output  wire [31:0] forwrd_res2,
    //Result write channel
    input   wire        res_we1,    //Exe forwarding
    input   wire [2:0]  res_ptr1,
    input   wire [31:0] result1,
    input   wire        res_we2,    //Mem forwarding
    input   wire [2:0]  res_ptr2,
    input   wire [31:0] result2,
    input   wire        res_we3,    //Wb forwarding(CSR read instructions)
    input   wire [2:0]  res_ptr3,
    input   wire [31:0] result3
);
    reg [ 4:0] rf_index [2:0];
    reg [ 2:0] res_valid;
    reg [31:0] result   [2:0];
    reg [ 2:0] ptr;
    wire [2:0]        res_we       = {res_we3, res_we2, res_we1};
    wire [(3*3-1):0]  res_ptr      = {res_ptr3, res_ptr2, res_ptr1};
    wire [(3*32-1):0] res          = {result3, result2, result1};
    wire [2:0] find_ord [2:0];  //Find the nearest matching entry in this order
    assign     find_ord[0] = {ptr[1], ptr[0], ptr[2]};  //First match
    assign     find_ord[1] = {ptr[0], ptr[2], ptr[1]};  //Second match
    assign     find_ord[2] = {ptr[2], ptr[1], ptr[0]};  //Third match
    wire [2:0] found_ord1;
    wire [2:0] found_ord2;
    wire [2:0] query_match1;
    wire [2:0] query_match2;
    wire       query_found1 = |query_match1;
    wire       query_found2 = |query_match2;
    genvar j;
    generate
        for (j = 0; j < 3; j = j + 1) begin
            assign query_match1[j] = rf_index[j] == query_index1;
            assign query_match2[j] = rf_index[j] == query_index2;
            assign found_ord1[j] = |(find_ord[j] & query_match1);
            assign found_ord2[j] = |(find_ord[j] & query_match2);
        end
    endgenerate
    wire [2:0] target_ord1 = found_ord1[0] ? find_ord[0] : (found_ord1[1] ? find_ord[1] : find_ord[2]);
    wire [2:0] target_ord2 = found_ord2[0] ? find_ord[0] : (found_ord2[1] ? find_ord[1] : find_ord[2]);
    assign forwrd_res1 = ({32{target_ord1[0]}} & result[0])
                       | ({32{target_ord1[1]}} & result[1])
                       | ({32{target_ord1[2]}} & result[2]);
    assign forwrd_res2 = ({32{target_ord2[0]}} & result[0])
                       | ({32{target_ord2[1]}} & result[1])
                       | ({32{target_ord2[2]}} & result[2]);
    assign current_ptr = ptr;
    assign blocked1 = (query_index1 == 5'b0) ? 1'b0 : query_found1;
    assign forwrd_ready1 = |(target_ord1 & res_valid);
    assign blocked2 = (query_index2 == 5'b0) ? 1'b0 : query_found2;
    assign forwrd_ready2 = |(target_ord2 & res_valid);
    wire [ 2:0] query_we, wb_we;
    assign query_we = {3{dest_wr_en}} & ptr;
    genvar m;
    generate
    for (m = 0; m < 3; m = m + 1) begin
        assign wb_we[m] = (res_we1 & res_ptr1[m]) | (res_we2 & res_ptr2[m]) | (res_we3 & res_ptr3[m]);
    end
    endgenerate

    integer i, k;
    always @(posedge clk) begin
        if (rst) begin
            ptr       <= 3'b100;
            res_valid <= 3'b0;
            for (i = 0; i < 3; i = i + 1)
                rf_index[i] <= 5'b0;
        end else begin
            if (ex_flush)
                for (i = 0; i < 3; i = i + 1)
                    rf_index[i] <= 5'b0;
            else if (dest_wr_en) begin
                ptr <= {ptr[0], ptr[2:1]};  //Right shift
                for (i = 0; i < 3; i = i + 1)
                    if(ptr[i])
                        rf_index[i] <= dest_index;
            end
            for (k = 0; k < 3; k = k + 1)   //Which channel
                if (res_we[k])
                    for (i = 0; i < 3; i = i + 1)   //Which pointer
                        if (res_ptr[(k*3+i)+:1])
                            result[i] <= res[k*32+:32];
            for (i = 0; i < 3; i = i + 1) begin
                if (query_we[i])
                    res_valid[i] <= 1'b0;
                else if (wb_we[i])
                    res_valid[i] <= 1'b1;
            end
        end
    end
endmodule