module core #( // DO NOT MODIFY!!!
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (   
    input                    i_clk,
    input                    i_rst_n,
    output  [ADDR_WIDTH-1:0] o_i_addr,
    input   [INST_WIDTH-1:0] i_i_inst,
    output                   o_d_we,
    output  [ADDR_WIDTH-1:0] o_d_addr,
    output  [DATA_WIDTH-1:0] o_d_wdata,
    input   [DATA_WIDTH-1:0] i_d_rdata,
    output  [           1:0] o_status,
    output                   o_status_valid
);
    // Registers, wires declaration
    reg [ADDR_WIDTH-1:0] current_pc, next_pc;
    reg                  pc_overflow;
    logic                z_flag;
    
    
    
    
    // COMBINATIONAL LOGIC FOR PROGRAM COUNTER
    always @ (*) begin
        if ((z_flag && (i_i_inst[31:26] == `OP_BEQ)) || ((!z_flag && (i_i_inst[31:26] == `OP_BNE)))) begin 
            next_pc = i_i_inst[15:0];
        end
        else begin
            next_pc = current_pc + 4;
        end
    end

    // SEQUENTIAL LOGIC FOR PC
    always @ () begin
        if(!i_rst_n) begin
            current_pc = 0;
            next_pc = 0;
        end
        else begin
            current_pc = next_pc;
        end
    end



    reg_file#(
    .ADDR_WIDTH(5),
    .DATA_WIDTH(DATA_WIDTH),
    .REG_AMOUNT(32)
    ) u_reg_file (   
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .w_enable(o_d_we),
        .w_addr(o_d_addr),
        .w_data(o_d_wdata),
        .r_addr(o_d_addr),
        .r_data(o_d_rdata)
    );
endmodule