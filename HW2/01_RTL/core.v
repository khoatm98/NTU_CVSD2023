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
    reg signed [ADDR_WIDTH-1:0] current_pc, next_pc;
    reg                  pc_overflow, addr_ovf, overflow_true;
    reg [ADDR_WIDTH-1:0] count;
	// ALU control block
	wire                 Reg2Loc;
	wire   [4:0] 		 WriteReg;
	wire   [4:0] 		 RegA;
	wire   [4:0] 		 RegB;
	wire   [31:0]  		 WriteData;
	wire signed  [31:0]  		 ReadA;
	wire signed  [31:0]  		 ReadB;
	wire   [31:0]  		 ALUout;
	wire   	     		 ALUcond;
	wire   [5:0]  		 ALUopcode;
	wire 				 MemToReg;
	wire 				 ALUovf;
	wire   [31:0]	ALUinputA;
	wire   [31:0]	ALUinputB;
	wire 			ALUen;
	// Register file
	wire   [4:0] 		 rg_w_addr;
	wire   [31:0] 		 rg_w_data;
	wire   [4:0] 		 rg_r_addrA;
	wire   [4:0] 		 rg_r_addrB;
	wire   [31:0] 		 rg_r_dataA;
	wire   [31:0] 		 rg_r_dataB;
	reg                  r_type;
	reg                  i_type;
	
	wire 				w_enable;
	wire[5:0] opcode;
/*************************************************/
/*************    State machine  *****************/
/*************************************************/
	parameter IDLE                    = 0;
	parameter FETCH                   = 1;
	parameter DECODE            	  = 2;
	parameter EXECUTION   		      = 3;
	parameter MEMORY_ACCESS        	  = 4;
	parameter WRITEBACK               = 5;
	parameter PC_GENERATION           = 6;
	parameter END     			      = 7;
	
	parameter R_TYPE_SUCCESS                   = 0;
	parameter I_TYPE_SUCCESS                  = 1;
	parameter MIPS_OVERFLOW   = 2;
	parameter MIPS_END      = 3;
	
	reg [3:0]  state, next_state;
	reg [1:0]  next_status, next_status_valid;
	reg PCsrc;
	wire [31:0] ALUPCRes; // ALU output for PC
	
/*************************************************/
/*************         PC       ******************/
/*************************************************/
    // COMBINATIONAL LOGIC FOR PROGRAM COUNTER
    always @ (posedge i_clk) begin
		//next_pc = PCsrc? ALUPCRes : current_pc + 4;
		if(next_state == FETCH) begin
			if (ALUcond) 
				next_pc = ALUPCRes;
			else
				next_pc = current_pc + 4;
			if (next_pc >= 4096 || next_pc < 0 ) begin
				pc_overflow = 1;
			end
		end
    end

    // SEQUENTIAL LOGIC FOR PC
    always @ (posedge i_clk) begin
        if(!i_rst_n) begin
            current_pc = 0;
            next_pc = 0;
        end
        else begin
            current_pc = pc_overflow? current_pc : next_pc;
        end
    end
	assign o_i_addr = current_pc;
	
/*************************************************/
/*********    ALU Control Block      *************/
/*************************************************/
	always @ (*) begin
	//$display("opcode %d, pc %d", i_i_inst[31:26], current_pc);
		r_type = ((i_i_inst[31:26] == `OP_ADD)
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
		i_type = ((i_i_inst[31:26] == `OP_ADDI)
							   || (i_i_inst[31:26] == `OP_LW)
							   || (i_i_inst[31:26] == `OP_SW)
							   || (i_i_inst[31:26] == `OP_BEQ)
							   || (i_i_inst[31:26] == `OP_BNE));
    end
						   
    // FSM
    always @ (*) begin
        case(state)
			IDLE 				   : next_state = (r_type||i_type)? FETCH: IDLE;
			FETCH                  : next_state = DECODE;
			DECODE                 : begin
				if (r_type || i_type) begin
					next_state = EXECUTION;
					next_status = i_type? I_TYPE_SUCCESS: R_TYPE_SUCCESS;
				end else begin
					next_state = IDLE;
					next_status = `MIPS_END;
				end
			end
			
			EXECUTION              : begin
				if ((i_i_inst[31:26] == `OP_BEQ)  || (i_i_inst[31:26] == `OP_BNE)) begin
					next_state = ALUovf ? END: PC_GENERATION;
					//next_pc = PCsrc? current_pc + 4 : current_pc + 4;
				end if (r_type || (i_i_inst[31:26] == `OP_ADDI)) begin
					next_state = ALUovf ? END: WRITEBACK;
					//next_pc = PCsrc? current_pc + 4 : current_pc + 4;
				end
				else
					next_state = MEMORY_ACCESS;
			end
			PC_GENERATION: begin
				PCsrc = ALUcond;
				next_state = FETCH;
			end
			MEMORY_ACCESS          : begin
				if ((i_i_inst[31:26] == `OP_LW)) begin
					next_state = WRITEBACK;
				end else begin
					next_state =   FETCH;
					//next_pc = PCsrc? current_pc + 4 : current_pc + 4;
				end
			end 
			WRITEBACK              : begin
				next_state = FETCH;
				//next_pc = PCsrc? current_pc + 4 : current_pc + 4;
			end
			END              : begin
				next_state = END;
				//next_pc = PCsrc? current_pc + 4 : current_pc + 4;
			end
			default				   : next_state = IDLE;
        endcase
	end


	// Combinational circuit
	
	always @(*) begin
		if (ALUovf || pc_overflow || addr_ovf) begin
			overflow_true = 1;
		end else begin
			overflow_true = 0;
		end
	end
	
    // SEQUENTIAL LOGIC FOR FSM
    always @ (posedge i_clk) begin

		//$display("valid %b " , state);
        if(!i_rst_n) begin
            state        = FETCH;
            next_state   = DECODE;
			count = 0;
			pc_overflow = 0;
        end
        else begin
            state  <=  overflow_true ? END : next_state;
			next_status_valid <= (next_state==FETCH) || (next_state==IDLE) || (next_state==END) || overflow_true;
			count = (next_state==FETCH) || (next_state==IDLE) ? count + 1 : count;
        end
    end


	alu alu1(
        .i_clk          (i_clk      ),
        .i_rst_n        (i_rst_n    ),
        .i_data_a       (ALUinputA   ),
        .i_data_b       (ALUinputB),
		.alu_en         (ALUen),
        .i_inst         (i_i_inst[31:26] ),
        .o_data         (ALUout     ),
		.o_cond			(ALUcond),
		.ovf			(ALUovf)
    );
	
	assign ALUPCRes = current_pc + (i_i_inst[15:0] << 0);
	assign o_status = next_status_valid? (overflow_true ? `MIPS_OVERFLOW : next_status) : 0;
	assign o_status_valid = next_status_valid;
	assign Reg2Loc = i_type;
	assign RegA    = i_i_inst[25:21];
	assign RegB    = (r_type || (i_i_inst[31:26] == `OP_BEQ)  || (i_i_inst[31:26] == `OP_BNE) || (i_i_inst[31:26] == `OP_SW)) ? i_i_inst[20:16] : i_i_inst[15:11];
	assign w_enable = state == WRITEBACK;
	assign ALUen = state == EXECUTION;
	
	
	assign ALUinputA = ReadA;
	assign ALUinputB = (r_type || (i_i_inst[31:26] == `OP_BEQ)  || (i_i_inst[31:26] == `OP_BNE)) ? ReadB : {{16{i_i_inst[15]}},i_i_inst[15:0]};
	
	assign MemToReg  = state == WRITEBACK? ((r_type || (i_i_inst[31:26] == `OP_ADDI)) ? 0: 1) : 0;
	assign WriteData = MemToReg? i_d_rdata : ALUout;
	assign WriteReg  = r_type ? i_i_inst[15:11] : i_i_inst[20:16];
	assign rg_w_addr = r_type ? i_i_inst[15:11] : i_i_inst[20:16];
	assign rg_w_data = MemToReg? i_d_rdata : ALUout;
	assign o_d_addr  = ALUout;
	assign o_d_wdata = ReadB;
	
	assign o_d_we = (state == MEMORY_ACCESS) &  (i_i_inst[31:26] == `OP_SW);
	assign opcode = i_i_inst[31:26];
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
        .w_enable(w_enable),
        .w_addr(rg_w_addr),
        .w_data(rg_w_data),
        .r_addrA(RegA),
        .r_dataA(ReadA),
		.r_addrB(RegB),
        .r_dataB(ReadB)
    );
endmodule