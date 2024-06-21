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
/*************************************************/
/**  Registers, wires declaration  ***************/
/*************************************************/
	// CPU
    reg [ADDR_WIDTH-1:0] current_pc, next_pc;
    reg                  pc_overflow;
    
	// ALU control block
	wire                 Reg2Loc;
	wire                 z_flag;
	wire                 branch;
	wire                 MemRead;
	wire                 MemtoReg;
	wire   [5:0]         ALUOp;
	wire                 MemWrite;
	wire                 ALUsrc;
	wire                 RegWrite;
	wire                 PCWrite;
    wire                 PCWriteCond;
    wire                 IorD;
    wire                 IRWrite;
    wire                 PCSource1;
    wire                 PCSource0;
    wire                 ALUOp1;
    wire                 ALUOp0;
    wire                 ALUSrcB1;
    wire                 ALUSrcB0;
    wire                 ALUSrcA;
    wire                 RegDst;

	// Register file
	wire   [4:0] 		 rg_w_addr;
	wire   [31:0] 		 rg_w_data;
	wire   [31:0] 		 rg_r_data;
	wire                  r_type;
	wire                  i_type;

/*************************************************/
/*************    State machine  *****************/
/*************************************************/
	parameter FETCH                   = 0;
	parameter DECODE                  = 1;
	parameter MEMORY_ACCESS_COMPUTE   = 2;
	parameter MEMORY_ACCESS_READ      = 3;
	parameter WRITEBACK               = 4;
	parameter MEMORY_ACCESS_WRITE     = 5;
	parameter EXECUTION               = 6;
	parameter RTYPE_COMPLETION        = 7;
	parameter BRANCH_COMPLETION       = 8;
	parameter JUMP_COMPLETION         = 9;
	
	
	reg [3:0]  state, next_state;
	
	
	
/*************************************************/
/*************         PC       ******************/
/*************************************************/
    // COMBINATIONAL LOGIC FOR PROGRAM COUNTER
    always @ (*) begin
        if (z_flag && branch) begin 
            next_pc = i_i_inst[15:0];
        end
        else begin
            next_pc = current_pc + 4;
        end
    end

    // SEQUENTIAL LOGIC FOR PC
    always @ (posedge i_clk) begin
        if(!i_rst_n) begin
            current_pc = 0;
            next_pc = 0;
        end
        else begin
            current_pc = next_pc;
        end
    end

/*************************************************/
/*********    ALU Control Block      *************/
/*************************************************/
	assign r_type = ((i_i_inst[31:26] == `OP_ADD)
                       || (i_i_inst[31:26] == `OP_SUB)
                       || (i_i_inst[31:26] == `OP_MUL)
                       || (i_i_inst[31:26] == `OP_AND)
                       || (i_i_inst[31:26] == `OP_OR)
                       || (i_i_inst[31:26] == `OP_NOR)
                       || (i_i_inst[31:26] == `OP_SLT)
                       || (i_i_inst[31:26] == `OP_FP_ADD)
                       || (i_i_inst[31:26] == `OP_FP_SUB)
                       || (i_i_inst[31:26] == `OP_FP_MUL)
                       || (i_i_inst[31:26] == `OP_SLL)
                       || (i_i_inst[31:26] == `OP_SRL));

	assign i_type = ((i_i_inst[31:26] == `OP_ADDI)
						   || (i_i_inst[31:26] == `OP_LW)
						   || (i_i_inst[31:26] == `OP_SW)
						   || (i_i_inst[31:26] == `OP_BEQ)
						   || (i_i_inst[31:26] == `OP_BNE));
						   
    // State transition combination 
    always @ (*) begin
        case(state)
			FETCH                  : next_state = DECODE;
			DECODE                 : begin
				if ((i_i_inst[31:26] == `OP_LW) || (i_i_inst[31:26] == `OP_SW)) begin
					next_state = MEMORY_ACCESS_COMPUTE;
				end
				else if (r_type) begin
					next_state = EXECUTION;
				end
				else if ((i_i_inst[31:26] == `OP_BEQ) || (i_i_inst[31:26] == `OP_BNE)) begin
					next_state = BRANCH_COMPLETION;
				end
				else
					next_state = JUMP_COMPLETION;
			end
			MEMORY_ACCESS_COMPUTE  : begin
                if (i_i_inst[31:26] == `OP_LW)
                    next_state = MEMORY_ACCESS_READ;
                else
                    next_state = MEMORY_ACCESS_WRITE;
            end
			MEMORY_ACCESS_READ     : next_state = WRITEBACK;
			WRITEBACK              : next_state = FETCH;
			MEMORY_ACCESS_WRITE    : next_state = FETCH;
			EXECUTION              : next_state = RTYPE_COMPLETION;
			RTYPE_COMPLETION       : next_state = FETCH;
			BRANCH_COMPLETION      : next_state = FETCH;
			JUMP_COMPLETION        : next_state = FETCH;
        endcase
	end


	// Combinational circuit
	
	
	
    // SEQUENTIAL LOGIC FOR FSM
    always @ (posedge i_clk) begin
        if(!i_rst_n) begin
            state        = FETCH;
            next_state   = DECODE;
        end
        else begin
            next_state  <= state;
        end
    end
	
    assign PCWrite         = (state == FETCH) || (state == JUMP_COMPLETION);
    assign PCWriteCond     = (state == BRANCH_COMPLETION);
    assign IorD            = (state == MEMORY_ACCESS_READ) || (state == MEMORY_ACCESS_WRITE);
    assign MemRead         = (state == FETCH) || (state == MEMORY_ACCESS_READ);
    assign MemWrite        = (state == MEMORY_ACCESS_WRITE);
    assign IRWrite         = (state == FETCH);
    assign MemtoReg        = (state == WRITEBACK);
    assign PCSource1       = (state == JUMP_COMPLETION);
    assign PCSource0       = (state == BRANCH_COMPLETION);
    assign ALUOp1          = (state == EXECUTION);
    assign ALUOp0          = (state == BRANCH_COMPLETION);
    assign ALUSrcB1        = (state == DECODE) || (state == MEMORY_ACCESS_COMPUTE);
    assign ALUSrcB0        = (state == FETCH) || (state == DECODE);
    assign ALUSrcA         = (state == MEMORY_ACCESS_COMPUTE) || (state == EXECUTION) || (state == BRANCH_COMPLETION);
    assign RegWrite        = (state == WRITEBACK) || (state == RTYPE_COMPLETION);
    assign RegDst          = (state == RTYPE_COMPLETION);
    assign o_status_valid  = (state == WRITEBACK) || (state == MEMORY_ACCESS_WRITE) || (state == RTYPE_COMPLETION) 
                                                        || (state == BRANCH_COMPLETION) || (state == JUMP_COMPLETION);
/*************************************************/
/*************  Register file    *****************/
/*************************************************/
    reg_file#(
    .ADDR_WIDTH(5),
    .DATA_WIDTH(DATA_WIDTH),
    .REG_AMOUNT(32)
    ) u_reg_file (   
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .w_enable(o_d_we),
        .w_addr(rg_w_addr),
        .w_data(rg_w_data),
        .r_addr(rg_w_addr),
        .r_data(rg_r_data)
    );
endmodule