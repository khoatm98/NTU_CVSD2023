`define SRAM_4096
module core (                       //Don't modify interface
	input         i_clk,
	input         i_rst_n,
	input         i_op_valid,
	input  [ 3:0] i_op_mode,
    output        o_op_ready,
	input         i_in_valid,
	input  [ 7:0] i_in_data,
	output        o_in_ready,
	output        o_out_valid,
	output [13:0] o_out_data
);


parameter FETCH           = 0;
parameter DECODE          = 1;
parameter SCALE_DOWN      = 2; //0010
parameter SCALE_UP        = 3; //0011
parameter SHIFT_RIGHT     = 4; //0100
parameter SHIFT_LEFT      = 5; //0101
parameter SHIFT_UP        = 6; //0110
parameter SHIFT_DOWN      = 7; //0111  
parameter LOAD_MAP        = 8; // 1000       
parameter DISPLAY         = 9; //1001
parameter CONV_CALC       = 10;//1010
parameter MED_FILTER      = 11;//1011
parameter SOBER_NMS       = 12;//1100
parameter IDLE            = 13;//1101
 
`ifdef SRAM_256
parameter NUM_SRAM    		  = 8;
`elsif SRAM_512
parameter NUM_SRAM    		  = 4;
`elsif SRAM_4096
parameter NUM_SRAM    		  = 1;
`endif
parameter MAP_ROW    		  = 8;
parameter MAP_COL    		  = 8;
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// ---- Add your own wires and registers here if needed ---- //

reg [3:0] state, next_state;
// Flag for loading img
wire 	  load_map_done;
// Flag for display operation
reg 	  display_done;
// Flag for med filter operation
reg 	  med_filter_done;
// Flag for sobber nms operation
reg 	  sober_nms_done;
reg [5:0]  dept;

reg [12:0] cnt;
reg [3:0]  origin_index_x;
reg [3:0]  origin_index_y;
reg [3:0]  new_x;
reg [3:0]  new_y;
reg [5:0]  new_z;
reg [13:0] out_data_w, out_data_r;
reg        out_valid_w, out_valid_r;
reg 	   o_in_ready_w, o_in_ready_r;

wire [7:0] sram_data_out ;
wire       sram_wen       ;
reg        sram_wen_r, sram_wen_w      ;
wire       sram_cen       ;
reg        sram_cen_r, sram_cen_w      ;
`ifdef SRAM_256
wire  [7:0] sram_addr	 [NUM_SRAM-1:0]; 
`elsif SRAM_512
wire  [8:0] sram_addr	 [NUM_SRAM-1:0]; 
`elsif SRAM_4096
wire  [11:0] sram_addr	 ; 
reg   [11:0] sram_addr_w;
`endif

wire  [7:0] sram_data	, sram_data_w ; 
reg   [7:0] sram_data_r; 
// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
genvar SRAM_inst;
generate
	for(SRAM_inst = 0; SRAM_inst < NUM_SRAM; SRAM_inst = SRAM_inst + 1) begin:SRAM_inst_loop
		sram_4096x8 u_sram (
			.Q(sram_data_out),
			.CLK(i_clk),
			.CEN(sram_cen),
			.WEN(sram_wen),
			.A(sram_addr),
			.D(sram_data)
			);
	end
endgenerate

assign load_map_done = cnt == 2048;
assign display_done  = cnt == 4*(dept) + 1;  // one extra cycle for DECODE
assign o_op_ready = (state == FETCH) & i_rst_n;
assign o_in_ready = o_in_ready_r;
assign o_out_valid = out_valid_r;

assign o_out_data  = out_data_r;

assign sram_addr  = sram_addr_w;
assign sram_data  = sram_data_r;
assign sram_wen = sram_wen_r;
assign sram_cen = sram_cen_r;

assign sram_data_w = i_in_data;
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //
always @(posedge i_clk ) begin
	if(state[3:1] == 3'b001) begin// SCALE
		dept = state[0]? (dept == 32  ? dept: dept<<1): (dept == 8 ? dept : dept>>1); 
		
	end
	else if(state[3:2] == 2'b01) begin// SHIFT
		//right
		//left
		if(state[1]==0)
			origin_index_x = state[0] == 0 ? (origin_index_x == (MAP_COL-1) ? origin_index_x: origin_index_x + 1): (origin_index_x == 0 ? origin_index_x : origin_index_x - 1); 
		//up
		//down
		else begin
			origin_index_y = state[0] == 1 ? (origin_index_y == (MAP_ROW-1) ? origin_index_y: origin_index_y + 1): (origin_index_y == 0 ? origin_index_y : origin_index_y - 1); 
		end
			
	end
end
//FSM
always @(*) begin
	casez(state)
		FETCH      : begin
			sram_cen_w  = 1;
			o_in_ready_w = 0;
			out_valid_w = 0;
			out_valid_r = 0;
			if (i_op_valid) 
				next_state = DECODE;
			else
				next_state = FETCH;
		end
		DECODE     : begin
			cnt  = 0;
			if      (i_op_mode == 4'b0000) begin
				sram_wen_w  = 0;
				next_state = LOAD_MAP;
				sram_cen_w  = 0;
				o_in_ready_w = 1;
			end
			else if (i_op_mode == 4'b0001) 
				next_state = SHIFT_RIGHT;
			else if (i_op_mode == 4'b0010) 
				next_state = SHIFT_LEFT;
			else if (i_op_mode == 4'b0011) 
				next_state = SHIFT_UP;
			else if (i_op_mode == 4'b0100) 
				next_state = SHIFT_DOWN;
			else if (i_op_mode == 4'b0101) 
				next_state = SCALE_DOWN;
			else if (i_op_mode == 4'b0110) 
				next_state = SCALE_UP;
			else if (i_op_mode == 4'b0111) begin
				// Start reading sram 1 cycle earlier
				sram_addr_w = origin_index_x + origin_index_y*MAP_COL;
				sram_wen_w  = 1;
				sram_wen_r  = 1;
				sram_cen_w  = 0;
				sram_cen_r  = 0;
				next_state = DISPLAY;
			end
			else if (i_op_mode == 4'b1000) 
				next_state = CONV_CALC;
			else if (i_op_mode == 4'b1001) 
				next_state = MED_FILTER;
			else if (i_op_mode == 4'b1010) 
				next_state = SOBER_NMS;
			else
				next_state = IDLE;
		end
		LOAD_MAP   : begin
			if (load_map_done) begin
				next_state = FETCH;
				sram_cen_w  = 1;
				sram_cen_r  = 1;
			end
			else begin
				next_state = LOAD_MAP;
				sram_addr_w = cnt;
			end
				
		end
		
		4'b001z      : begin
			next_state = FETCH;
		end
		
		4'b01zz      : begin
			next_state = FETCH;
		end
		DISPLAY    : begin
			if (display_done) begin
				out_valid_w = 0;
				next_state = FETCH;
				sram_cen_w  = 1;
				sram_cen_r  = 1;
			end
			else begin
				out_valid_w = 1;
				next_state = DISPLAY;
				out_data_w = sram_data_out;
				new_z = cnt>>2;
				new_x = origin_index_x + ((cnt%4) %2 == 1); 
				new_y = origin_index_y + ((cnt%4)     > 1);
				sram_addr_w = new_x + new_y*MAP_COL + new_z*MAP_COL*MAP_ROW;
			end
		end
		CONV_CALC  : begin
			next_state = FETCH;
		end
		MED_FILTER : begin
			if (med_filter_done)
				next_state = FETCH;
			else
				next_state = MED_FILTER;
		end
		SOBER_NMS  : begin
			if (sober_nms_done)
				next_state = FETCH;
			else
				next_state = SOBER_NMS;
		end
		IDLE       : begin
			
		end
		default	   : next_state = IDLE;
	endcase	
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
reg[15:0] counter;
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state <= FETCH;
		dept <= 32; // default channel dept 32
		sram_cen_w  <= 1;
		sram_cen_r  <= 1;
		origin_index_x <= 0;
		origin_index_y <= 0;
		counter <=0;
	end else begin
		state <= next_state;
		if ((state == LOAD_MAP && i_in_valid)) begin
			
			cnt <= cnt + 1;
		end else if (next_state == DISPLAY)
			cnt <= cnt + 1;
		sram_data_r <= sram_data_w;
		out_data_r  <= out_data_w;
		out_valid_r <= out_valid_w;
		sram_cen_r  <= sram_cen_w;
		sram_wen_r  <= sram_wen_w;
		o_in_ready_r <= o_in_ready_w;
		counter <= out_valid_w? counter + 1: counter;
	end
end

endmodule
