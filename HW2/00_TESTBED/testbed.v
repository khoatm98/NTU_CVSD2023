`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   120000
`define PAT_NUM     1024
`define RST_DELAY   2
`ifdef p0
    `define Inst   "../00_TESTBED/PATTERN/p0/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p0/data.dat"
    `define Status "../00_TESTBED/PATTERN/p0/status.dat"
`endif
`ifdef p1
    `define Inst   "../00_TESTBED/PATTERN/p1/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p1/data.dat"
    `define Status "../00_TESTBED/PATTERN/p1/status.dat"
`endif
`ifdef p2
    `define Inst   "../00_TESTBED/PATTERN/p2/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p2/data.dat"
    `define Status "../00_TESTBED/PATTERN/p2/status.dat"
`endif
`ifdef p3
    `define Inst   "../00_TESTBED/PATTERN/p3/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p3/data.dat"
    `define Status "../00_TESTBED/PATTERN/p3/status.dat"
`endif
`ifdef p4
    `define Inst   "../00_TESTBED/PATTERN/p4/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p4/data.dat"
    `define Status "../00_TESTBED/PATTERN/p4/status.dat"
`endif
`ifdef p5
    `define Inst   "../00_TESTBED/PATTERN/p5/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p5/data.dat"
    `define Status "../00_TESTBED/PATTERN/p5/status.dat"
`endif
`ifdef p6
    `define Inst   "../00_TESTBED/PATTERN/p6/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p6/data.dat"
    `define Status "../00_TESTBED/PATTERN/p6/status.dat"
`endif
`ifdef p7
    `define Inst   "../00_TESTBED/PATTERN/p7/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p7/data.dat"
    `define Status "../00_TESTBED/PATTERN/p7/status.dat"
`endif
`ifdef p8
    `define Inst   "../00_TESTBED/PATTERN/p8/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p8/data.dat"
    `define Status "../00_TESTBED/PATTERN/p8/status.dat"
`endif
`ifdef p9
    `define Inst   "../00_TESTBED/PATTERN/p9/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p9/data.dat"
    `define Status "../00_TESTBED/PATTERN/p9/status.dat"
`endif
`ifdef p10
    `define Inst   "../00_TESTBED/PATTERN/p10/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p10/data.dat"
    `define Status "../00_TESTBED/PATTERN/p10/status.dat"
`endif
`ifdef p11
    `define Inst   "../00_TESTBED/PATTERN/p11/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p11/data.dat"
    `define Status "../00_TESTBED/PATTERN/p11/status.dat"
`endif
`ifdef p12
    `define Inst   "../00_TESTBED/PATTERN/p12/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p12/data.dat"
    `define Status "../00_TESTBED/PATTERN/p12/status.dat"
`endif
`ifdef p13
    `define Inst   "../00_TESTBED/PATTERN/p13/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p13/data.dat"
    `define Status "../00_TESTBED/PATTERN/p13/status.dat"
`endif
`ifdef p14
    `define Inst   "../00_TESTBED/PATTERN/p14/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p14/data.dat"
    `define Status "../00_TESTBED/PATTERN/p14/status.dat"
`endif
`ifdef p15
    `define Inst   "../00_TESTBED/PATTERN/p15/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p15/data.dat"
    `define Status "../00_TESTBED/PATTERN/p15/status.dat"
`endif
`ifdef p16
    `define Inst   "../00_TESTBED/PATTERN/p16/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p16/data.dat"
    `define Status "../00_TESTBED/PATTERN/p16/status.dat"
`endif
`ifdef p17
    `define Inst   "../00_TESTBED/PATTERN/p17/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p17/data.dat"
    `define Status "../00_TESTBED/PATTERN/p17/status.dat"
`endif
`ifdef p18
    `define Inst   "../00_TESTBED/PATTERN/p18/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p18/data.dat"
    `define Status "../00_TESTBED/PATTERN/p18/status.dat"
`endif
`ifdef p19
    `define Inst   "../00_TESTBED/PATTERN/p19/inst.dat"
    `define Data   "../00_TESTBED/PATTERN/p19/data.dat"
    `define Status "../00_TESTBED/PATTERN/p19/status.dat"
`endif
`ifdef h10
    `define STR "H10"
    `define Inst "../00_TESTBED/PATTERN/h10/inst.dat"
    `define Status "../00_TESTBED/PATTERN/h10/status.dat"
    `define Data "../00_TESTBED/PATTERN/h10/data.dat"
`endif

module testbed;

	reg clk, rst_n;
	wire [ 31 : 0 ] imem_addr;
	wire [ 31 : 0 ] imem_inst;
	wire            dmem_wen;
	wire [ 31 : 0 ] dmem_addr;
	wire [ 31 : 0 ] dmem_wdata;
	wire [ 31 : 0 ] dmem_rdata;
	wire [  1 : 0 ] mips_status;
	wire            mips_status_valid;
	reg 			jump;
    reg [31:0]        golden_data [0:`PAT_NUM-1];
    reg [1:0]         golden_status [0:`PAT_NUM-1];
	reg [1:0]         output_status [0:`PAT_NUM-1];
	integer i, j, error_data, error_status;
	integer                  over;
	// Import test data 
	initial begin
        $readmemb (`Inst, u_inst_mem.mem_r);
        $readmemb (`Data, golden_data);
		$readmemb (`Status, golden_status);
    end
	
	core u_core (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.o_i_addr(imem_addr),
		.i_i_inst(imem_inst),
		.o_d_we(dmem_wen),
		.o_d_addr(dmem_addr),
		.o_d_wdata(dmem_wdata),
		.i_d_rdata(dmem_rdata),
		.o_status(mips_status),
		.o_status_valid(mips_status_valid)
	);

	inst_mem  u_inst_mem (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.i_addr(imem_addr),
		.o_inst(imem_inst)
	);

	data_mem  u_data_mem (
		.i_clk(clk),
		.i_rst_n(rst_n),
		.i_we(dmem_wen),
		.i_addr(dmem_addr),
		.i_wdata(dmem_wdata),
		.o_rdata(dmem_rdata)
	);

	// Clock initialization
    initial clk = 0;
    always #(`CYCLE/2.0) clk = ~clk; 
	
	initial begin
		//$fsdbDumpfile("core.fsdb");
		//$fsdbDumpvars(0, testbed, "+mda");
		$dumpfile("core.vcd");
		$dumpvars; 
	end
	
	initial begin
        i        = 0;
        rst_n  = 1;
		error_data = 0;
		error_status = 0;
		jump = 0;
        reset;
		over     = 0;
        while ( i < `PAT_NUM && !jump ) begin
			@(negedge clk)
			if (mips_status_valid) begin
				output_status[i] = mips_status;
				if (mips_status == 2'd2 || mips_status == 2'd3) begin
					jump = 1;
				end
				i = i + 1;
			end
		end
		// test status
		for (j = 0; j < i; j = j + 1) begin
			if (golden_status[j] !== output_status[j]) begin
				error_status = error_status + 1;
				$display(
					"[Error!] Status[%d]: Golden = %b, Yours = %b",
					j, golden_status[j], output_status[j]
				);
			end
			//else
				//$display("Correct Status[%d]: Golden = %b, Yours = %b", j, golden_status[j], output_status[j]);
		end

		// test data
		for (j = 0; j < i; j = j + 1 ) begin
			if(golden_data[j] !== u_data_mem.mem_r[j]) begin
				error_data = error_data + 1;
				$display(
					"[Error!] Data[%d]: Golden = %b, Yours = %b",
					j, golden_data[j], u_data_mem.mem_r[j]
				);
			end
		end
		if (j < `PAT_NUM && !jump)  over = 0;
        else               over = 1;
    end
	initial begin
        wait(over);
		if(error_data === 0 && error_status === 0) begin
            $display("----------------------------------------------");
            $display("-                 ALL PASS!                  -");
            $display("----------------------------------------------");
        end else begin
            $display("----------------------------------------------");
            $display("  Wrong! Total error: %d", error_data+error_status);
			$display("  Data error: %d, Status error: %d", error_data,error_status);
            $display("----------------------------------------------");
        end
        # (2 * `CYCLE);
        $finish;
    end    
	initial begin
        # (`MAX_CYCLE * `CYCLE);
        $display("----------------------------------------------");
        $display("Latency of your design is over 100000 cycles!!");
        $display("----------------------------------------------");
        $finish;
    end

	task reset; begin
        # ( 0.25 * `CYCLE);
        rst_n = 0;    
        # ((`RST_DELAY) * `CYCLE);
        rst_n = 1;    
    end endtask


endmodule



