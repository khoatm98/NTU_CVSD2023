module reg_file #(
    parameter ADDR_WIDTH   = 5,
    parameter DATA_WIDTH   = 32,
    parameter REG_AMOUNT   = 32
) (   
    input                     i_clk,
    input                     i_rst_n,
    input                     w_enable, //w_enable high means can write
    input  [  ADDR_WIDTH-1:0] w_addr,
    input  [  DATA_WIDTH-1:0] w_data,
    input  [  ADDR_WIDTH-1:0] r_addr,
    output [  DATA_WIDTH-1:0] r_data
);

reg  [DATA_WIDTH-1:0] data_store[0:REG_AMOUNT-1];

wire [DATA_WIDTH-1:0] r_data_w;
reg  [DATA_WIDTH-1:0] r_data_r;


assign r_data =  data_store[r_addr];
integer i;
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        for(i=0; i<REG_AMOUNT; i=i+1)
            data_store[reg_var] <= {DATA_WIDTH{1'b0}};
    end
    else begin
        if(w_enable) begin
            data_store[w_addr] <= w_data;
        end
    end
end
endmodule