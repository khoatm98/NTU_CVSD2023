`timescale 1ns/100ps
`define CYCLE       5.0     // CLK period.
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   4000
`define RST_DELAY   2

`ifdef tb0
    `define INFILE "../00_TESTBED/PATTERN/indata0.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode0.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden0.dat"
`elsif tb1
    `define INFILE "../00_TESTBED/PATTERN/indata1.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode1.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden1.dat"
`elsif tb2
    `define INFILE "../00_TESTBED/PATTERN/indata2.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode2.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden2.dat"
`elsif tb3
    `define INFILE "../00_TESTBED/PATTERN/indata3.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode3.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden3.dat"
`elsif tb4
    `define INFILE "../00_TESTBED/PATTERN/indata4.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode4.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden4.dat"

`elsif tbh
    `define INFILE "../00_TESTBED/PATTERN/indatah.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmodeh.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/goldenh.dat"
	
`endif
`define SDFFILE "core_syn.sdf"  // Modify your sdf file name


module testbed;

reg         clk, rst_n;
reg         op_valid;
reg  [ 3:0] op_mode;
reg         op_ready;
reg         in_valid;
reg [ 7:0] in_data;
wire        in_ready;
wire        out_valid;
wire [13:0] out_data;

reg  [ 7:0] indata_mem [0:2047];
reg  [ 3:0] opmode_mem [0:1023];
reg  [13:0] golden_mem [0:4095];


// ==============================================
// TODO: Declare regs and wires you need
// ==============================================


// For gate-level simulation only
`ifdef SDF
    initial $sdf_annotate(`SDFFILE, u_core);
    initial #1 $display("SDF File %s were used for this simulation.", `SDFFILE);
`endif

// Write out waveform file
initial begin
  //$fsdbDumpfile("core.fsdb");
  //$fsdbDumpvars(0, "+mda");
  $dumpfile("core.vcd");
  $dumpvars; 
end


core u_core (
	.i_clk       (clk),
	.i_rst_n     (rst_n),
	.i_op_valid  (op_valid),
	.i_op_mode   (op_mode),
    .o_op_ready  (op_ready),
	.i_in_valid  (in_valid),
	.i_in_data   (in_data),
	.o_in_ready  (in_ready),
	.o_out_valid (out_valid),
	.o_out_data  (out_data)
);

// Read in test pattern and golden pattern
initial $readmemb(`INFILE, indata_mem);
initial $readmemb(`OPFILE, opmode_mem);
initial $readmemb(`GOLDEN, golden_mem);

// Clock generation
initial clk = 1'b0;
always
begin
 forever #(`CYCLE /2) clk = ~clk;  
end
// Reset generation
initial begin
    rst_n = 1; # (               0.25 * `CYCLE);
    rst_n = 0; # ((`RST_DELAY - 0.25) * `CYCLE);
    rst_n = 1; # (         `MAX_CYCLE * `CYCLE);
    $display("Error! Runtime exceeded!");
    $finish;
end

integer error;
integer i, j, k, cycle;
initial begin
	op_valid         = 0;
	op_mode 		 = 0;
	in_valid 		 = 0;
	in_data   		 = 0;
	error = 0;
	i = 0;
	j = 0;
	k = 0;
	cycle = 0;
	while (opmode_mem[i] !== 4'dx) begin
		@(negedge clk);
		if(op_ready) begin
			op_valid = 1;
			op_mode = opmode_mem[i][3:0];
			@(negedge clk);
			op_valid = 0;
			if (op_mode == 0) begin
				j = 0;
				// Load imput feature map
                while (j < 2048) begin
					in_valid = 1;
					in_data = indata_mem[j][7:0];
                    if (in_ready) begin
                    j = j + 1;
                    end
					@(negedge clk);
                end
                in_valid = 0;
			end
			i = i + 1;
			$display("count instruction %d", i);
		end
	end
end
//
initial begin
    k = 0;
    error = 0;
	while (golden_mem[k] !== 14'dx ) begin
		@(negedge clk);
        if (out_valid==1) begin
            if (out_data !== golden_mem[k][13:0]) begin
                $display ("Test[%4d]: Error! golden=(%d), yours=(%d)", k, golden_mem[k][13:0], out_data);
                //$finish;
                error = error+1;
            end
			else
				$display ("Test[%4d]: Correct! golden=(%d), yours=(%d)", k, golden_mem[k][13:0], out_data);
            k = k + 1;
        end
		//$display ("%d ", cycle  );
		//$finish;
	end
	
	if(error == 0) begin
        $display("----------------------------------------------------");
        $display("-                    ALL PASS!                     -");
        $display("-           Latency: %0d/%0d cycle/ns           -",cycle,$time);
        $display("----------------------------------------------------");
    end else begin
        $display("----------------------------------------------");
        $display("  Wrong! Total error: %d                      ", error);
        $display("----------------------------------------------");
    end
    # ( 2 * `CYCLE);
    //$display("End of Process, total cycle = %d",cycle_count);
    $finish;
	
end
always @(negedge clk) begin
    if(!rst_n) begin
        cycle = 0;
    end
    else begin
        cycle = cycle + 1;
    end
end
// ==============================================
// TODO: Check pattern after process finish
// ==============================================


endmodule
