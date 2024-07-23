`define SRAM_256
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
parameter SRAM_READ       = 13;//1101
parameter IDLE            = 14;//1110

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

reg [3:0]   state, next_state;
//reg [ 7:0]  current_op_r, current_op_w;
// Flag for loading img
wire 	   load_map_done;
// Flag for display operation
reg 	   display_done;
// Flag for med filter operation
reg 	   med_filter_done, convolution_done;
// Flag for sobber nms operation
reg 	   sober_nms_done;
reg [5:0]  depth_r, depth_w;

reg [11:0] cnt, target_sticks;
reg [3:0]  origin_index_x_r, origin_index_x_w;
reg [3:0]  origin_index_y_r, origin_index_y_w;
reg signed [3:0]  new_x;
reg signed [3:0]  new_y, new_y_delay1, new_y_delay2;
reg  [5:0]  new_z;

reg [10:0]     index_delay_r[2:0], index_delay_w, test_index_delay_r, test_index_delay_r1;
reg [13:0]    conv_sum;
reg [13:0]    conv_partial_sum[15:0];
reg [13:0]    med_filter_partial_sum[3:0][3:0];
reg [4:0] 	 counter_r, counter_w;
reg [13:0] out_data_w, out_data_r;
reg        out_valid_w, out_valid_r;
reg 	   o_in_ready_w, o_in_ready_r;
reg [16:0] out_data_w_17;

reg [2:0] out_counter_w, out_counter_r;
reg [7:0] i_r[15:0];
wire [7:0]o_med_data[3:0];
wire [13:0]o_sobel_nms[3:0];
wire         activate_median_filter, activate_sobel_nms;


// SRAM wires
reg  [2:0] sram_wen_r[NUM_SRAM-1:0], sram_cen_r[NUM_SRAM-1:0];
reg        sram_wen_w[NUM_SRAM-1:0], sram_cen_w[NUM_SRAM-1:0];
wire       sram_cen      [NUM_SRAM-1:0];
wire       sram_wen      [NUM_SRAM-1:0];
wire [7:0] sram_data_out [NUM_SRAM-1:0];
`ifdef SRAM_256
wire  [7:0] sram_addr	 		 [NUM_SRAM-1:0]; 
reg  [7:0] sram_addr_delay_r	 [NUM_SRAM-1:0][2:0], sram_addr_delay_w[NUM_SRAM-1:0]; 
`elsif SRAM_512
wire  [8:0] sram_addr	 		 [NUM_SRAM-1:0]; 
wire  [8:0] sram_addr_delay_r	 [2:0][NUM_SRAM-1:0], sram_addr_delay_w[NUM_SRAM-1:0]; 
`elsif SRAM_4096
wire   [11:0] sram_addr   [NUM_SRAM-1:0]; 
reg   [11:0] sram_addr_delay_r  [2:0], sram_addr_delay_w[NUM_SRAM-1:0]; 
`endif

wire  [7:0] sram_data[NUM_SRAM-1:0], sram_data_w[NUM_SRAM-1:0]; 
reg   [7:0] sram_data_r[NUM_SRAM-1:0];

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
genvar SRAM_inst;
generate
	for(SRAM_inst = 0; SRAM_inst < NUM_SRAM; SRAM_inst = SRAM_inst + 1) begin:SRAM_inst_loop
		sram_256x8 u_sram (
			.Q(sram_data_out[SRAM_inst]),
			.CLK(i_clk),
			.CEN(sram_cen[SRAM_inst]),
			.WEN(sram_wen[SRAM_inst]),
			.A(sram_addr[SRAM_inst]),
			.D(sram_data[SRAM_inst])
			);
		assign sram_data[SRAM_inst]  = sram_data_r[SRAM_inst];
		assign sram_data_w[SRAM_inst]       = i_in_valid? i_in_data : sram_data_w[SRAM_inst];
		assign sram_addr[SRAM_inst]  = sram_addr_delay_r[SRAM_inst][0];
		assign sram_wen[SRAM_inst] = sram_wen_r[SRAM_inst][0];
		assign sram_cen[SRAM_inst] = sram_cen_r[SRAM_inst][0];
	end
	
endgenerate

median_filter u_med_filter_inst0 (i_r[0], i_r[1], i_r[2], i_r[3], i_r[4], i_r[5], i_r[6], i_r[7], i_r[8], i_r[9], i_r[10], i_r[11], i_r[12], i_r[13], i_r[14], i_r[15],activate_median_filter, o_med_data[3:0]);


sobel_nms sobel_nms_inst0(i_r[0], i_r[1], i_r[2], i_r[3], i_r[4], i_r[5], i_r[6], i_r[7], i_r[8], i_r[9], i_r[10], i_r[11], i_r[12], i_r[13], i_r[14], i_r[15],activate_sobel_nms, o_sobel_nms[3:0]);


assign test_index_delay_r = index_delay_r[0];
assign test_index_delay_r1 = index_delay_r[2];
assign load_map_done = cnt == 2048;
assign display_done  = (cnt == 4*(depth_r) );  // one extra cycle for DECODE
assign convolution_done  = index_delay_r[2] >= 16*depth_r;
assign med_filter_done = index_delay_r[2] >= 80; // 64 + 16 ( 4 cyles for output)
assign sober_nms_done  = index_delay_r[2] >= 80;
assign o_op_ready = (state == FETCH) & i_rst_n;
assign o_in_ready = o_in_ready_r;
assign o_out_valid = out_valid_r;

assign o_out_data  = out_data_r;





// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //
always @(*) begin
	if(state[3:1] == 3'b001) begin// SCALE
		depth_w = state[0]? (depth_r == 32  ? depth_r: depth_r<<1): (depth_r == 8 ? depth_r : depth_r>>1); 
		
	end
	else if(state[3:2] == 2'b01) begin// SHIFT
		//right
		//left
		if(state[1]==0)
			origin_index_x_w = state[0] == 0 ? (origin_index_x_r == (MAP_COL-2) ? origin_index_x_r: origin_index_x_r + 1): (origin_index_x_r == 0 ? origin_index_x_r : origin_index_x_r - 1); 
		//up
		//down
		else begin
			origin_index_y_w = state[0] == 1 ? (origin_index_y_r == (MAP_ROW-2) ? origin_index_y_r: origin_index_y_r + 1): (origin_index_y_r == 0 ? origin_index_y_r : origin_index_y_r - 1); 
		end
			
	end
end

always @(*) begin
	if(state == MED_FILTER || state == SOBER_NMS) begin
		if (med_filter_done || sober_nms_done) begin
			for(integer i=0; i<NUM_SRAM; i=i+1) begin
				sram_cen_w[i]  = 1;
				sram_wen_w[i]  = 1;
			end
			index_delay_w = 0;
		end
		else begin
			if(out_counter_r > 0) begin
				out_valid_r = 1;
				out_data_r  = state == MED_FILTER  ? o_med_data[4-out_counter_r] :  o_sobel_nms[4-out_counter_r];
				out_counter_w = out_counter_r - 1;
			end
			if(out_counter_r <= 4) begin
				out_valid_r = out_counter_r != 0;
				out_valid_w = 0;
				new_z = index_delay_r[0] >= 16*depth_r? depth_r : (index_delay_r[0])/16;
				new_x = origin_index_x_r - 1; 
				new_y = origin_index_y_r + (index_delay_r[0]%16)/4 - 1;
				if (index_delay_r[0] < 16*depth_r) begin
					if(new_y%2 == 0) begin
						if(new_x >= $signed(0)) begin
							sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+4)%8] = new_y + 1 + new_z*MAP_ROW;
							sram_cen_w[new_x] = 0; 
							sram_cen_w[(new_x+4)%8] = 0; 
						end 
						if (new_x < MAP_COL - 3) begin
							sram_addr_delay_w[new_x + 3] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + 1 + new_z*MAP_ROW;
							sram_cen_w[new_x + 3] = 0; 
							sram_cen_w[(new_x+3+4)%8] = 0; 
						end
						sram_addr_delay_w[new_x + 1] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + 1 + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y + 1 + new_z*MAP_ROW;
						
						sram_cen_w[new_x + 1] = 0; 
						sram_cen_w[(new_x+1+4)%8] = 0; 
						sram_cen_w[new_x + 2] = 0; 
						sram_cen_w[(new_x+2+4)%8] = 0; 
					end
					else begin
						
						if(new_x >= $signed(0)) begin
							sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x] = $signed(new_y + 1) + new_z*MAP_ROW;
							sram_cen_w[new_x] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+4)%8] = new_y < $signed(0) ? 1 : 0; 
						end 
						if (new_x < $signed(MAP_COL - 3)) begin
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x + 3] = $signed(new_y + 1) + new_z*MAP_ROW;
							sram_cen_w[new_x + 3] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+3+4)%8] = new_y < $signed(0) ? 1 : 0; 
						end
						sram_addr_delay_w[new_x + 1] = $signed(new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = $signed(new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y  + new_z*MAP_ROW;
						
						sram_cen_w[new_x + 1] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+1+4)%8] = new_y < $signed(0) ? 1 : 0; 
						sram_cen_w[new_x + 2] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+2+4)%8] = new_y < $signed(0) ? 1 : 0; 
					end
				end
				if(index_delay_r[0]/16 <= counter_r) begin
					index_delay_w = index_delay_r[0] + 8;
				end
				
				
				if(index_delay_r[1]/16 > counter_r) begin
					counter_w = counter_r + 1;
					out_counter_w = 4;
				end
			end
		end
	end
end



always @(*) begin
	casez(state)
		FETCH      : begin
			target_sticks = 0;
		end
		DECODE     : begin
			cnt  = 0;
			out_counter_w = 0;
			if      (i_op_mode == `OP_MAP_LOADING) begin // MAP LOADING
				o_in_ready_w = 1;
				for(integer i=0; i<NUM_SRAM; i=i+1) begin
					sram_addr_delay_w[i] = 0;
				end
			end
			else if (i_op_mode == `OP_R_SHIFT       )begin //SHIFT
			end                                      
			else if (i_op_mode == `OP_L_SHIFT       )begin // SHIFT
			end                                      
			else if (i_op_mode == `OP_U_SHIFT       )begin // SHIFT
			end                                    
			else if (i_op_mode == `OP_D_SHIFT       )begin // SHIFT
			end                                    
			else if (i_op_mode == `OP_SCALE_DOWN  )begin // SCALE
			end
			else if (i_op_mode == `OP_SCALE_UP)begin // SCALE
			end
			else if (i_op_mode == `OP_DISPLAY       )begin // DISPLAY
				for(integer i=0; i<NUM_SRAM; i=i+1) begin
					sram_wen_w[i] = 1;
				end
			end
			else if (i_op_mode == `OP_CONV         ) begin // CONV
				index_delay_w = 0;
				for(integer i=0; i<16; i=i+1) begin
					conv_partial_sum[i] = 0;
				end
				for(integer i=0; i<NUM_SRAM; i=i+1) begin
					sram_wen_w[i] = 1;
					sram_cen_w[i]  = 1;
				end
			end
			else if (i_op_mode == `OP_MED_FILTER  || i_op_mode ==`OP_SOBEL_NMS  )begin // MED filter
				counter_w = 0;
				for(integer i=0; i<16; i=i+1) begin
					i_r[i] = 0;
				end
				
				for(integer i=0; i<NUM_SRAM; i=i+1) begin
					sram_cen_w[i]  = 1;
					sram_wen_w[i]  = 1;
				end
			end
			else begin
			end
		end
		LOAD_MAP   : begin
			target_sticks = 2048;
			
			for(integer i=0; i<NUM_SRAM; i=i+1) begin
				sram_cen_w[i] = 1;
			end
			if (load_map_done) begin
				o_in_ready_w = 0;
				sram_wen_w[0]  = 1;
			end
			else begin
				new_z = cnt/64;
				new_x = (cnt%64)%8;
				new_y = (cnt%64)/8;
				if(new_y%2 == 0) begin
					sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
					sram_cen_w[new_x] = 0; 
				end
				else begin
					sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
					sram_cen_w[(new_x+4)%8] = 0; 
				end
			end
				
		end
		
		4'b001z      : begin
		end
		
		4'b01zz      : begin
		end
		DISPLAY    : begin
			target_sticks = 4*depth_r;
			out_valid_w = 0;
			for(integer i=0; i<NUM_SRAM; i=i+1) begin
				sram_cen_w[i] = 1;
				if ( sram_cen_r[i][2] == 0) begin
					out_valid_w = 1;
					out_data_w = sram_data_out[i];
					//$display("%d %d", i , sram_data_out[i]);
				end else begin
					//out_data_w = out_data_r;
				end
			end
			if (display_done) begin
			end
			else begin
				new_z = cnt>>2;
				new_x = origin_index_x_r + ((cnt%4) %2 == 1); 
				new_y = origin_index_y_r + ((cnt%4)     > 1);
				if(new_y%2 == 0) begin
					sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
					sram_cen_w[new_x] = 0; 
				end
				else begin
					sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
					sram_cen_w[(new_x+4)%8] = 0; 
				end
			end
		end
		CONV_CALC  : begin
			
			if (convolution_done) begin
				if(out_counter_r<4) begin
					out_valid_w = 1;
					if (out_counter_r <=1) begin
					out_data_w_17 = ((conv_partial_sum[out_counter_r])    )    + 
									((conv_partial_sum[1+out_counter_r] ) <<1)   + 
									((conv_partial_sum[2+out_counter_r] ) )    + 
									((conv_partial_sum[4+out_counter_r] ) <<1)    + 
									((conv_partial_sum[5+out_counter_r] ) <<2)   + 
									((conv_partial_sum[6+out_counter_r] ) <<1)   + 
									((conv_partial_sum[8+out_counter_r] ) )   + 
									((conv_partial_sum[9+out_counter_r] ) <<1)  + 
									((conv_partial_sum[10+out_counter_r]) );
					end
					else begin
					out_data_w_17 = ((conv_partial_sum[2 +out_counter_r])    )    + 
									((conv_partial_sum[3 +out_counter_r] ) <<1)   + 
									((conv_partial_sum[4 +out_counter_r] ) )    + 
									((conv_partial_sum[6 +out_counter_r] ) <<1)    + 
									((conv_partial_sum[7 +out_counter_r] ) <<2)   + 
									((conv_partial_sum[8 +out_counter_r] ) <<1)   + 
									((conv_partial_sum[10 +out_counter_r] ) )   + 
									((conv_partial_sum[11 +out_counter_r] ) <<1)  + 
									((conv_partial_sum[12+out_counter_r]) );
					end
					out_data_w = (out_data_w_17 >> 4) + out_data_w_17[3];
					
					
					out_counter_w    = out_counter_r + 1;
				end else begin
					out_valid_w = 0;
					index_delay_w = 0;
				end
				
				
			end
			else begin
				new_z = index_delay_r[0] >= 16*depth_r? depth_r : (index_delay_r[0])/16;
				new_x = origin_index_x_r - 1; 
				new_y = origin_index_y_r + (index_delay_r[0]%16)/4 - 1;
				if (index_delay_r[0] < 16*depth_r) begin
					if(new_y%2 == 0) begin
						if(new_x >= $signed(0)) begin
							sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+4)%8] = new_y + 1 + new_z*MAP_ROW;
							sram_cen_w[new_x] = 0; 
							sram_cen_w[(new_x+4)%8] = 0; 
						end 
						if (new_x < MAP_COL - 3) begin
							sram_addr_delay_w[new_x + 3] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + 1 + new_z*MAP_ROW;
							sram_cen_w[new_x + 3] = 0; 
							sram_cen_w[(new_x+3+4)%8] = 0; 
						end
						sram_addr_delay_w[new_x + 1] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + 1 + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y + 1 + new_z*MAP_ROW;
						
						sram_cen_w[new_x + 1] = 0; 
						sram_cen_w[(new_x+1+4)%8] = 0; 
						sram_cen_w[new_x + 2] = 0; 
						sram_cen_w[(new_x+2+4)%8] = 0; 
					end
					else begin
						
						if(new_x >= $signed(0)) begin
							sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x] = $signed(new_y + 1) + new_z*MAP_ROW;
							sram_cen_w[new_x] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+4)%8] = new_y < $signed(0) ? 1 : 0; 
						end 
						if (new_x < $signed(MAP_COL - 3)) begin
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x + 3] = $signed(new_y + 1) + new_z*MAP_ROW;
							sram_cen_w[new_x + 3] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+3+4)%8] = new_y < $signed(0) ? 1 : 0; 
						end
						sram_addr_delay_w[new_x + 1] = $signed(new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = $signed(new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y  + new_z*MAP_ROW;
						
						sram_cen_w[new_x + 1] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+1+4)%8] = new_y < $signed(0) ? 1 : 0; 
						sram_cen_w[new_x + 2] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+2+4)%8] = new_y < $signed(0) ? 1 : 0; 
					end
				end
				else begin
					for(integer i=0; i<NUM_SRAM; i=i+1) begin
						sram_cen_w[i] = 1;
					end
				end
				index_delay_w = index_delay_r[0] + 8;
				
			end
		end
		MED_FILTER : begin
			
		end
		SOBER_NMS  : begin
			
		end
		IDLE       : begin
			
		end
		default	   : begin
			end
	endcase
end

//FSM
always @(*) begin
	casez(state)
		FETCH      : begin

			if (i_op_valid) 
				next_state = DECODE;
			else
				next_state = FETCH;
		end
		DECODE     : begin
			if      (i_op_mode == `OP_MAP_LOADING) begin
				next_state = LOAD_MAP;
			end
			else if (i_op_mode == `OP_R_SHIFT) 
				next_state = SHIFT_RIGHT;
			else if (i_op_mode == `OP_L_SHIFT) 
				next_state = SHIFT_LEFT;
			else if (i_op_mode == `OP_U_SHIFT) 
				next_state = SHIFT_UP;
			else if (i_op_mode == `OP_D_SHIFT) 
				next_state = SHIFT_DOWN;
			else if (i_op_mode == `OP_SCALE_DOWN) 
				next_state = SCALE_DOWN;
			else if (i_op_mode == `OP_SCALE_UP) 
				next_state = SCALE_UP;
			else if (i_op_mode == `OP_DISPLAY) begin
				next_state = DISPLAY;
			end
			else if (i_op_mode == `OP_CONV) begin
				next_state = CONV_CALC;
				
			end
			else if (i_op_mode == `OP_MED_FILTER) 
				next_state = MED_FILTER;
			else if (i_op_mode == `OP_SOBEL_NMS) 
				next_state = SOBER_NMS;
			else
				next_state = IDLE;
		end
		LOAD_MAP   : begin
			if (load_map_done) begin
				next_state = FETCH;
			end
			else begin
				next_state = LOAD_MAP;
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
				next_state = FETCH;
				for(integer i=0; i<NUM_SRAM; i=i+1) begin
					if (sram_cen_r[i][2] == 0)
						next_state = DISPLAY;
				end
			end
			else begin
				next_state = DISPLAY;
			end
		end
		CONV_CALC  : begin
			if (convolution_done) begin
				if (out_counter_r < 4)
					next_state = CONV_CALC;
				else
					next_state = FETCH;
			end else begin
				next_state = CONV_CALC;
			end
		end
		MED_FILTER : begin
			if (med_filter_done) begin
				next_state = FETCH;
				
			end
			else begin
				next_state = MED_FILTER;
				
			end
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
// State transition
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state <= FETCH;
		next_state <= FETCH;
	end else
		state <= next_state;
end

// Store current instruction
always @( posedge i_clk or negedge i_rst_n) begin
	for(integer i=0; i<NUM_SRAM; i=i+1) begin
		if(~i_rst_n) begin
			sram_data_r[i] <= 0;
		end else
			sram_data_r[i] <= sram_data_w[i];
	end
end

// Store current instruction
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		o_in_ready_r  <= 0;
		o_in_ready_w  <= 0;
	end else
		o_in_ready_r  <= o_in_ready_w ;
end


// Store current sram address in last 2 cycle
generate
	for(SRAM_inst = 0; SRAM_inst < NUM_SRAM; SRAM_inst = SRAM_inst + 1) begin:SRAM_loop1
		always @( posedge i_clk or negedge i_rst_n) begin
			if(~i_rst_n) begin
				sram_addr_delay_r[SRAM_inst][0] <= 0;
				sram_addr_delay_r[SRAM_inst][1] <= 0;
				sram_addr_delay_r[SRAM_inst][2] <= 0;
				sram_addr_delay_w[SRAM_inst]    <= 0;
			end
			else begin
				sram_addr_delay_r[SRAM_inst][0] <= sram_addr_delay_w[SRAM_inst];
				sram_addr_delay_r[SRAM_inst][1] <= sram_addr_delay_r[SRAM_inst][0];
				sram_addr_delay_r[SRAM_inst][2] <= sram_addr_delay_r[SRAM_inst][1];
			end
		end
	end
	
endgenerate

//assign sram_addr  = sram_addr_delay_r[0];


// Store current index in last 2 cycle
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		index_delay_r[0] <= 0;
		index_delay_r[1] <= 0;
		index_delay_r[2] <= 0;
		index_delay_w    <= 0;
	end
	else begin
		index_delay_r[0] <= index_delay_w;
		index_delay_r[1] <= index_delay_r[0];
		index_delay_r[2] <= index_delay_r[1];
	end
end

// Counter increment
always @( posedge i_clk) begin
	if(cnt < target_sticks)
		cnt <= cnt + 1;
	else
		cnt <= cnt;
end

// Output data
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		out_data_r <= 0;
	end
	else
		out_data_r <= out_data_w;
end

// Output data valid
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		out_valid_r <= 0;
	end
	else
		out_valid_r <= out_valid_w;
end

// Output counter
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		out_counter_r <= 0;
		counter_r <= 0;
	end
	else begin
		out_counter_r <= out_counter_w;
		counter_r <= counter_w;
	end
end
assign activate_median_filter = out_counter_r==4&& state==MED_FILTER;
assign activate_sobel_nms = out_counter_r==4 && state==SOBER_NMS; 


// Delay coordinate
always @( posedge i_clk) begin
	new_y_delay1 <= new_y;
	new_y_delay2 <= new_y_delay1;
end


// Store input data for median filter and sobel nms module
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		for(integer i=0; i<16; i=i+1) begin
			i_r[i] <= 0;
		end
	end else begin
	
				/* new_z = index_delay_r[0] >= 16*depth_r? depth_r : (index_delay_r[0])/16;
				new_x = origin_index_x_r - 1; 
				new_y = origin_index_y_r + (index_delay_r[0]%16)/4 - 1; */
		if(((sram_cen_r[1][1] == 0 && sram_wen_r[1][1] == 1) || (sram_cen_r[5][1] == 0 && sram_wen_r[5][1] == 1)) && ( state==MED_FILTER || state==SOBER_NMS)) begin //SRAM READ 
			if(new_y_delay2%2 == 0) begin
				if(new_x >= $signed(0)) begin
					i_r[index_delay_r[2]%16] <=  sram_data_out[new_x];
					i_r[index_delay_r[2]%16 + 4] <=  sram_data_out[(new_x+4)%8];
				end 
				if (new_x < MAP_COL - 3) begin
					i_r[index_delay_r[2]%16 + 3] <=  sram_data_out[new_x + 3];
					i_r[index_delay_r[2]%16 + 7] <=  sram_data_out[(new_x+3+4)%8];
				end
				
				i_r[index_delay_r[2]%16 + 1] <=  sram_data_out[new_x + 1];
				i_r[index_delay_r[2]%16 + 2] <=  sram_data_out[new_x + 2];
				i_r[index_delay_r[2]%16 + 5] <=  sram_data_out[(new_x+1+4)%8];
				i_r[index_delay_r[2]%16 + 6] <=  sram_data_out[(new_x+2+4)%8];
			end
			else begin
				if(new_x >= $signed(0)) begin
					i_r[index_delay_r[2]%16]     <= new_y_delay2 < $signed(0) ? i_r[index_delay_r[2]%16]  :  sram_data_out[(new_x+4)%8];
					i_r[index_delay_r[2]%16 + 4] <= new_y_delay2 >= MAP_ROW-2 ? i_r[index_delay_r[2]%16+4]  :  sram_data_out[new_x];
					//$display("%d %d %d %d",index_delay_r[2], new_x, new_y_delay2, sram_data_out[new_x]);
				end 
				if (new_x < MAP_COL - 3) begin
					i_r[index_delay_r[2]%16 + 3] <= new_y_delay2 < $signed(0) ? i_r[index_delay_r[2]%16+3]  :  sram_data_out[(new_x+3+4)%8];
					i_r[index_delay_r[2]%16 + 7] <= new_y_delay2 >= MAP_ROW-2 ? i_r[index_delay_r[2]%16+7]  :  sram_data_out[new_x + 3   ];
				end
				
				i_r[index_delay_r[2]%16 + 1] <= new_y_delay2 < $signed(0) ? i_r[index_delay_r[2]%16 + 1]  :  sram_data_out[(new_x+1+4)%8];
				i_r[index_delay_r[2]%16 + 2] <= new_y_delay2 < $signed(0) ? i_r[index_delay_r[2]%16 + 2]  :  sram_data_out[(new_x+2+4)%8];
				i_r[index_delay_r[2]%16 + 5] <= new_y_delay2 >= MAP_ROW-2 ? i_r[index_delay_r[2]%16 + 5]  :  sram_data_out[new_x + 1];
				i_r[index_delay_r[2]%16 + 6] <= new_y_delay2 >= MAP_ROW-2 ? i_r[index_delay_r[2]%16 + 6]  :  sram_data_out[new_x + 2];
			end
		end
	end
end

//assign in_valid = index_delay_r[2]%16 

// Accumlate sum for convolution
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		for(integer i=0; i<16; i=i+1) begin
			conv_partial_sum[i] <= 0;
		end
	end else begin
		
		if(((sram_cen_r[1][1] == 0 && sram_wen_r[1][1] == 1) || (sram_cen_r[5][1] == 0 && sram_wen_r[5][1] == 1)) && state == CONV_CALC) begin //SRAM READ 
			if(new_y_delay2%2 == 0) begin
				if(new_x >= $signed(0)) begin
					conv_partial_sum[index_delay_r[2]%16] <= conv_partial_sum[index_delay_r[2]%16] + sram_data_out[new_x];
					conv_partial_sum[index_delay_r[2]%16 + 4] <= conv_partial_sum[index_delay_r[2]%16 + 4] + sram_data_out[(new_x+4)%8];
				end 
				if (new_x < MAP_COL - 3) begin
					conv_partial_sum[index_delay_r[2]%16 + 3] <= conv_partial_sum[index_delay_r[2]%16 + 3] + sram_data_out[new_x + 3];
					conv_partial_sum[index_delay_r[2]%16 + 7] <= conv_partial_sum[index_delay_r[2]%16 + 7] + sram_data_out[(new_x+3+4)%8];
				end
				
				conv_partial_sum[index_delay_r[2]%16 + 1] <= conv_partial_sum[index_delay_r[2]%16 + 1] + sram_data_out[new_x + 1];
				conv_partial_sum[index_delay_r[2]%16 + 2] <= conv_partial_sum[index_delay_r[2]%16 + 2] + sram_data_out[new_x + 2];
				conv_partial_sum[index_delay_r[2]%16 + 5] <= conv_partial_sum[index_delay_r[2]%16 + 5] + sram_data_out[(new_x+1+4)%8];
				conv_partial_sum[index_delay_r[2]%16 + 6] <= conv_partial_sum[index_delay_r[2]%16 + 6] + sram_data_out[(new_x+2+4)%8];
			end
			else begin
				if(new_x >= $signed(0)) begin
					conv_partial_sum[index_delay_r[2]%16]     <= new_y_delay2 < $signed(0) ? conv_partial_sum[index_delay_r[2]%16]  : conv_partial_sum[index_delay_r[2]%16]    + sram_data_out[(new_x+4)%8];
					conv_partial_sum[index_delay_r[2]%16 + 4] <= new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum[index_delay_r[2]%16+4 ]  :conv_partial_sum[index_delay_r[2]%16 + 4] + sram_data_out[new_x];
				end 
				if (new_x < MAP_COL - 3) begin
					conv_partial_sum[index_delay_r[2]%16 + 3] <= new_y_delay2 < $signed(0) ? conv_partial_sum[index_delay_r[2]%16+3]  : conv_partial_sum[index_delay_r[2]%16 + 3] + sram_data_out[(new_x+3+4)%8];
					conv_partial_sum[index_delay_r[2]%16 + 7] <= new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum[index_delay_r[2]%16+7]  : conv_partial_sum[index_delay_r[2]%16 + 7] + sram_data_out[new_x + 3   ];
				end
				
				conv_partial_sum[index_delay_r[2]%16 + 1] <= new_y_delay2 < $signed(0) ? conv_partial_sum[index_delay_r[2]%16 + 1]  : conv_partial_sum[index_delay_r[2]%16 + 1] + sram_data_out[(new_x+1+4)%8];
				conv_partial_sum[index_delay_r[2]%16 + 2] <= new_y_delay2 < $signed(0) ? conv_partial_sum[index_delay_r[2]%16 + 2]  : conv_partial_sum[index_delay_r[2]%16 + 2] + sram_data_out[(new_x+2+4)%8];
				conv_partial_sum[index_delay_r[2]%16 + 5] <= new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum[index_delay_r[2]%16 + 5]  : conv_partial_sum[index_delay_r[2]%16 + 5] + sram_data_out[new_x + 1];
				conv_partial_sum[index_delay_r[2]%16 + 6] <= new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum[index_delay_r[2]%16 + 6]  : conv_partial_sum[index_delay_r[2]%16 + 6] + sram_data_out[new_x + 2];
			end
		end
	end
end




// Sram chip enable and write enable pins
always @( posedge i_clk or negedge i_rst_n) begin
	for(integer i=0; i<NUM_SRAM; i=i+1) begin
		if(~i_rst_n) begin
			sram_cen_r[i]  <= 3'b111;
			sram_cen_w[i]  <= 1;
			
			sram_wen_r[i]  <= 3'b000;
			sram_wen_w[i]  <= 0;
		end else begin
			sram_wen_r[i][0] <= sram_wen_w[i];
			sram_wen_r[i][1] <= sram_wen_r[i][0];
			sram_wen_r[i][2] <= sram_wen_r[i][1];
					   
			sram_cen_r[i][0] <= sram_cen_w[i];
			sram_cen_r[i][1] <= sram_cen_r[i][0];
			sram_cen_r[i][2] <= sram_cen_r[i][1];
		end
	end
end


// Origin transition
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		origin_index_x_r <= 0;
		origin_index_y_r <= 0;
		origin_index_x_w <= 0;
		origin_index_y_w <= 0;
	end else begin
		origin_index_x_r <= origin_index_x_w;
		origin_index_y_r <= origin_index_y_w;
	end
end

// Depth transition
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		depth_r <= 32;
		depth_w <= 32;
	end else begin
		depth_r <= depth_w;
	end
end
endmodule




module median_filter_submodule(
    input [7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9,
	input i_in_valid,
    output [7:0] median
);
    wire [7:0] sorted[8:0];
    reg [7:0] temp;
    integer i, j;

    // Store the input pixels in an array for easier sorting
    reg [7:0] pixels[8:0];

    always @(*) begin
		if (i_in_valid) begin
			pixels[0] = p1;
			pixels[1] = p2;
			pixels[2] = p3;
			pixels[3] = p4;
			pixels[4] = p5;
			pixels[5] = p6;
			pixels[6] = p7;
			pixels[7] = p8;
			pixels[8] = p9;
		end
        // Sort the array using bubble sort
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8 - i; j = j + 1) begin
                if (pixels[j] > pixels[j + 1]) begin
                    temp = pixels[j];
                    pixels[j] = pixels[j + 1];
                    pixels[j + 1] = temp;
                end
            end
        end
    end

    assign median = pixels[4];  // The median is the 5th element after sorting (index 4)

endmodule

module median_filter(
	input signed[7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16,
	input i_in_valid,
	output [7:0] median [3:0]
);
	wire [7:0] sub_median[3:0];
	
	median_filter_submodule u_submodule_inst0 (p11, p10, p9 , p7 , p6 , p5 , p3, p2, p1, i_in_valid,    sub_median[0]);
	median_filter_submodule u_submodule_inst1 (p12, p11, p10, p8 , p7 , p6 , p4, p3, p2, i_in_valid,    sub_median[1]);
	median_filter_submodule u_submodule_inst2 (p15, p14, p13, p11, p10, p9 , p7, p6, p5, i_in_valid,    sub_median[2]);
	median_filter_submodule u_submodule_inst3 (p16, p15, p14, p12, p11, p10, p8, p7, p6, i_in_valid,    sub_median[3]);
	
	assign median[3] = sub_median[3];
	assign median[2] = sub_median[2];
	assign median[1] = sub_median[1];
	assign median[0] = sub_median[0];
endmodule


module sobel_nms(
    input signed[7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16,
	input i_in_valid,
    output [13:0] sobel_nms[3:0]
);
	localparam angle0   = 0;
	localparam angle45  = 1;
	localparam angle90  = 2;
	localparam angle135 = 3;
	
    wire [7:0] sorted[8:0];
    reg  [13:0] G[3:0],Gnms[3:0] ;
	reg signed [20:0]  tan[3:0];
	reg signed [20:0]  Gx[3:0], Gy[3:0], Gx_abs[3:0], Gy_abs[3:0];
	reg [1:0] angle[3:0];
    integer i, j;
	wire [1:0] a0, a1, a2, a3;
	wire [13:0] g0, g1, g2, g3;
	wire signed [20:0] gx1, gy1;
	assign a0 = angle[0];
	assign a1 = angle[1];
	assign a2 = angle[2];
	assign a3 = angle[3];
	
	assign g0 = G[0];
	assign g1 = G[1];
	assign g2 = G[2];
	assign g3 = G[3];
	
	assign gx1= Gx[2];
	assign gy1= Gy[2];
    // Store the input pixels in an array for easier sorting
    reg [7:0] pixels[15:0];

    always @(*) begin
		if (i_in_valid) begin
			pixels[0] = p1;
			pixels[1] = p2;
			pixels[2] = p3;
			pixels[3] = p4;
			pixels[4] = p5;
			pixels[5] = p6;
			pixels[6] = p7;
			pixels[7] = p8;
			pixels[8] = p9;
			pixels[9] = p10;
			pixels[10] = p11;
			pixels[11] = p12;
			pixels[12] = p13;
			pixels[13] = p14;
			pixels[14] = p15;
			pixels[15] = p16;
		end
        // Sort the array using bubble sort
        for (i = 0; i < 4; i = i + 1) begin
			if (i < 2) begin
				Gx[i] = pixels[i]* $signed(-21'd1) + pixels[i+4]* $signed(-21'd2) + pixels[i+8]* $signed(-21'd1) + pixels[i+2]* $signed(21'd1) + pixels[i+6]* $signed(21'd2) + pixels[i+10]* $signed(21'd1);
				Gy[i] = pixels[i]* $signed(-21'd1) + pixels[i+1]* $signed(-21'd2) + pixels[i+2]* $signed(-21'd1) + pixels[i+8]* $signed(21'd1) + pixels[i+9]* $signed(21'd2) + pixels[i+10]* $signed(21'd1);
			end
			else begin 
				Gx[i] = pixels[i+2]* $signed(-21'd1) + pixels[i+6]* $signed(-21'd2) + pixels[i+10]* $signed(-21'd1) + pixels[i+4]* $signed(21'd1) + pixels[i+8]* $signed(21'd2) + pixels[i+12]* $signed(21'd1);
				Gy[i] = pixels[i+2]* $signed(-21'd1) + pixels[i+3]* $signed(-21'd2) + pixels[i+4]* $signed(-21'd1) + pixels[i+10]* $signed(21'd1) + pixels[i+11]* $signed(21'd2) + pixels[i+12]* $signed(21'd1);
				//$display("%d %d ", Gx[i], Gy[i]);
			end
        end
		
		
		for (i = 0; i < 4; i = i + 1) begin
			Gx_abs[i] = Gx[i][20] == 1 ?  ~Gx[i] + 1 : Gx[i];
			Gy_abs[i] = Gy[i][20] == 1 ?  ~Gy[i] + 1 : Gy[i];
			G[i] = Gx_abs[i] + Gy_abs[i];
			Gy[i] = Gy[i] << 7;
		end
		
		// Determine angle
		for (i = 0; i < 4; i = i + 1) begin
            if (Gx[i][20] ^ Gy[i][20] == 1) begin
				if (Gx[i] == 0 || Gy[i]/Gx[i] < $signed(-21'd309))
					angle[i] = angle90;
				else if (Gy[i]/Gx[i] < $signed(-21'd53))
					angle[i] = angle135;
				else
					angle[i] = angle0;
			end
			else begin
				if (Gy[i]/Gx[i] < $signed(21'd53)) begin
					angle[i] = angle0;
					//$display("%d %d %d ", Gx[i],Gy[i],Gx[i]/Gy[i]);
				end
				else if (Gy[i]/Gx[i] < $signed(21'd309))
					angle[i] = angle45;
				else if (Gx[i] == 0)
					angle[i] = angle90;
				else
					angle[i] = angle90;
			end
        end
		
		for (i = 0; i < 2; i = i + 1) begin
			case(angle[i])
				angle0: begin
					if(G[i] < G[(i+1)%2])
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
				end
				angle45: begin
					if(i==0 && G[i] < G[3])
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
				end
				angle90: begin
					if(G[i] < G[i+2])
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
				end
				angle135: begin
					if(i==1 && G[i] < G[2])
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
				end
				default: Gnms[i] = 0;
			endcase
		end
		
		for (i = 2; i < 4; i = i + 1) begin
			case(angle[i])
				angle0: begin
					if((i == 2 && G[i] < G[3]) ||(i == 3 && G[i] < G[2]) )
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
				end
				angle45: begin
					
					if(i==3 && G[i] < G[0])
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
					//$display("%d %d %d", Gnms[i] , G[i], G[0]);
				end
				angle90: begin
					if(G[i] < G[i-2])
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
				end
				angle135: begin
					if(i==2 && G[i] < G[1])
						Gnms[i] = 0;
					else 
						Gnms[i] = G[i];
				end
				default: Gnms[i] = 0;
			endcase
		end
    end

    assign sobel_nms[0] = Gnms[0];  
	assign sobel_nms[1] = Gnms[1]; 
	assign sobel_nms[2] = Gnms[2]; 
	assign sobel_nms[3] = Gnms[3]; 
endmodule

