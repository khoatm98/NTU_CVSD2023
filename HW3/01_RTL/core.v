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
reg [ 7:0]  current_op_r, current_op_w;
// Flag for loading img
wire 	  load_map_done;
// Flag for display operation
reg 	  display_done;
// Flag for med filter operation
reg 	  med_filter_done;
// Flag for sobber nms operation
reg 	  sober_nms_done;
reg [5:0]  depth;

reg [12:0] cnt;
reg [3:0]  origin_index_x;
reg [3:0]  origin_index_y;
reg signed [3:0]  new_x;
reg signed [3:0]  new_y;
reg  [5:0]  new_z;

reg [10:0]     conv_index_r, conv_index_w, last_2index_r, last_2index_w, last_1index_r, last_1index_w;
reg [13:0]    conv_sum;
reg [13:0]    conv_partial_sum[15:0], test_sum;
reg [13:0]    med_filter_partial_sum[3:0][3:0];
reg [4:0] 	 counter_r, counter_w;
reg [13:0] out_data_w, out_data_r;
reg        out_valid_w, out_valid_r;
reg 	   o_in_ready_w, o_in_ready_r;
reg [16:0] out_data_w_17;


reg [13:0] conv_partial_sum0 ;
reg [13:0] conv_partial_sum1 ;
reg [13:0] conv_partial_sum2 ;
reg [13:0] conv_partial_sum3 ;
reg [13:0] conv_partial_sum4 ;
reg [13:0] conv_partial_sum5 ;
reg [13:0] conv_partial_sum6 ;
reg [13:0] conv_partial_sum7 ;
reg [13:0] conv_partial_sum8 ;
reg [13:0] conv_partial_sum9 ;
reg [13:0] conv_partial_sum10 ;
reg [13:0] conv_partial_sum11;
reg [13:0] conv_partial_sum12;
reg [13:0] conv_partial_sum13;
reg [13:0] conv_partial_sum14;
reg [13:0] conv_partial_sum15;


reg [6:0] med_filter_index_r, med_filter_index_w, sober_nms_index_r, sober_nms_index_w;
reg [2:0] out_counter_w, out_counter_r;
reg [7:0] i_r[15:0];
wire [7:0]o_med_data[3:0];
wire [13:0]o_sobel_nms[3:0];
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

median_filter u_med_filter_inst0 (i_r[10], i_r[9], i_r[8], i_r[6], i_r[5], i_r[4], i_r[2], i_r[1], i_r[0], o_med_data[0]);
median_filter u_med_filter_inst1 (i_r[11], i_r[10], i_r[9], i_r[7], i_r[6], i_r[5], i_r[3], i_r[2], i_r[1], o_med_data[1]);
median_filter u_med_filter_inst2 (i_r[14], i_r[13], i_r[12], i_r[10], i_r[9], i_r[8], i_r[6], i_r[5], i_r[4], o_med_data[2]);
median_filter u_med_filter_inst3 (i_r[15], i_r[14], i_r[13], i_r[11], i_r[10], i_r[9], i_r[7], i_r[6], i_r[5], o_med_data[3]);


sobel_nms sobel_nms_inst0(i_r[0], i_r[1], i_r[2], i_r[3], i_r[4], i_r[5], i_r[6], i_r[7], i_r[8], i_r[9], i_r[10], i_r[11], i_r[12], i_r[13], i_r[14], i_r[15], o_sobel_nms[3:0]);
assign load_map_done = cnt == 2048;
assign display_done  = cnt == 4*(depth) + 1;  // one extra cycle for DECODE
assign convolution_done  = (conv_index_r >= 16*depth + 2)  && counter_r == 4;  
assign convolution_calc_done  = (conv_index_r >= 16*depth +2 ) && counter_r <= 4; 


assign med_filter_done  = med_filter_index_r == 69; 

assign sober_nms_done = med_filter_index_r == 69; 
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
	if(next_state[3:1] == 3'b001) begin// SCALE
		depth = next_state[0]? (depth == 32  ? depth: depth<<1): (depth == 8 ? depth : depth>>1); 
		
	end
	else if(next_state[3:2] == 2'b01) begin// SHIFT
		//right
		//left
		if(next_state[1]==0)
			origin_index_x = next_state[0] == 0 ? (origin_index_x == (MAP_COL-2) ? origin_index_x: origin_index_x + 1): (origin_index_x == 0 ? origin_index_x : origin_index_x - 1); 
		//up
		//down
		else begin
			origin_index_y = next_state[0] == 1 ? (origin_index_y == (MAP_ROW-2) ? origin_index_y: origin_index_y + 1): (origin_index_y == 0 ? origin_index_y : origin_index_y - 1); 
		end
			
	end
end


always @(*) begin
	casez(state)
		FETCH      : begin
			sram_cen_w  = 1;
			o_in_ready_w = 0;
			out_valid_w = 0;
			out_valid_r = 0;
		end
		DECODE     : begin
			cnt  = 0;
			if      (i_op_mode == `OP_MAP_LOADING) begin // MAP LOADING
				sram_wen_w  = 0;
				sram_cen_w  = 0;
				o_in_ready_w = 1;
				current_op_w = `OP_MAP_LOADING;
			end
			else if (i_op_mode == `OP_R_SHIFT       )begin //SHIFT
				current_op_w = `OP_R_SHIFT;
			end                                      
			else if (i_op_mode == `OP_L_SHIFT       )begin // SHIFT
				current_op_w = `OP_L_SHIFT;
			end                                      
			else if (i_op_mode == `OP_U_SHIFT       )begin // SHIFT
				current_op_w = `OP_U_SHIFT;
			end                                    
			else if (i_op_mode == `OP_D_SHIFT       )begin // SHIFT
			    current_op_w = `OP_D_SHIFT;
			end                                    
			else if (i_op_mode == `OP_SCALE_DOWN  )begin // SCALE
				current_op_w = `OP_SCALE_DOWN;
			end
			else if (i_op_mode == `OP_SCALE_UP)begin // SCALE
				current_op_w = `OP_SCALE_UP;
			end
			else if (i_op_mode == `OP_DISPLAY       )begin // DISPLAY
				// Start reading sram 1 cycle earlier
				sram_addr_w = origin_index_x + origin_index_y*MAP_COL;
				sram_wen_w  = 1;
				sram_wen_r  = 1;
				sram_cen_w  = 0;
				sram_cen_r  = 0;
				current_op_w = `OP_DISPLAY;
			end
			else if (i_op_mode == `OP_CONV         ) begin // CONV
				conv_index_w = 0;
				sram_cen_w  = 0;
				sram_wen_w  = 1;
				counter_w = 0;
				current_op_w = `OP_CONV;
				for(integer i=0; i<16; i=i+1) begin
					conv_partial_sum[i] = 0;
				end
				
			end
			else if (i_op_mode == `OP_MED_FILTER   )begin // MED filter
				current_op_w = `OP_MED_FILTER;
				med_filter_index_w = 0;
				sram_cen_w  = 0;
				sram_wen_w  = 1;
				counter_w = 0;
				out_counter_w = 0;
				for(integer i=0; i<16; i=i+1) begin
					i_r[i] = 0;
				end
			end
			else if (i_op_mode ==`OP_SOBEL_NMS    )begin
				current_op_w = `OP_SOBEL_NMS;
				med_filter_index_w = 0;
				sram_cen_w  = 0;
				sram_wen_w  = 1;
				counter_w = 0;
				out_counter_w = 0;
				for(integer i=0; i<16; i=i+1) begin
					i_r[i] = 0;
				end
			end
			else begin
			end
		end
		LOAD_MAP   : begin
			if (load_map_done) begin
				sram_cen_w  = 1;
				sram_cen_r  = 1;
			end
			else begin
				sram_addr_w = cnt;
			end
				
		end
		
		4'b001z      : begin
		end
		
		4'b01zz      : begin
		end
		DISPLAY    : begin
			if (display_done) begin
				out_valid_w = 0;
				sram_cen_w  = 1;
				sram_cen_r  = 1;
			end
			else begin
				out_valid_w = 1;
				out_data_w = sram_data_out;
				new_z = cnt>>2;
				new_x = origin_index_x + ((cnt%4) %2 == 1); 
				new_y = origin_index_y + ((cnt%4)     > 1);
				sram_addr_w = new_x + new_y*MAP_COL + new_z*MAP_COL*MAP_ROW;
			end
		end
		CONV_CALC  : begin
			if (convolution_calc_done) begin
				out_valid_w = 1;
				if (counter_r <=1) begin
				out_data_w_17 = ((conv_partial_sum[counter_r])    )    + 
								((conv_partial_sum[1+counter_r] ) <<1)   + 
								((conv_partial_sum[2+counter_r] ) )    + 
								((conv_partial_sum[4+counter_r] ) <<1)    + 
								((conv_partial_sum[5+counter_r] ) <<2)   + 
								((conv_partial_sum[6+counter_r] ) <<1)   + 
								((conv_partial_sum[8+counter_r] ) )   + 
								((conv_partial_sum[9+counter_r] ) <<1)  + 
								((conv_partial_sum[10+counter_r]) );
				end
				else begin
				out_data_w_17 = ((conv_partial_sum[2 +counter_r])    )    + 
								((conv_partial_sum[3 +counter_r] ) <<1)   + 
								((conv_partial_sum[4 +counter_r] ) )    + 
								((conv_partial_sum[6 +counter_r] ) <<1)    + 
								((conv_partial_sum[7 +counter_r] ) <<2)   + 
								((conv_partial_sum[8 +counter_r] ) <<1)   + 
								((conv_partial_sum[10 +counter_r] ) )   + 
								((conv_partial_sum[11 +counter_r] ) <<1)  + 
								((conv_partial_sum[12+counter_r]) );
				end
				out_data_w = (out_data_w_17 >> 4) + out_data_w_17[3];
				//$display("%d %d %d %d %d %d %d %d %d",  conv_partial_sum[counter_r]>>4,conv_partial_sum[1+counter_r]>>3,conv_partial_sum[2+counter_r]>>4 ,conv_partial_sum[4+counter_r]>>3 ,conv_partial_sum[5+counter_r]>>2 ,conv_partial_sum[6+counter_r]>>3,conv_partial_sum[8+counter_r]>>4 ,conv_partial_sum[9+counter_r]>>3,conv_partial_sum[10+counter_r]>>4);
				if (convolution_done) begin
					out_valid_w = 0;
					//conv_index_r = 0;
					conv_index_w = 0;
					sram_cen_w  = 1;
					sram_cen_r  = 1;
					last_2index_w = 0;
					last_1index_w = 0;
				end
				else begin
				
					counter_w = counter_r + 1;
					conv_index_w = conv_index_r + 1;
				end
				
			end
			else begin
				last_2index_w = last_1index_r;
				last_1index_w = conv_index_r;
				
				new_z = (conv_index_r)%depth;
				new_x = origin_index_x + ((conv_index_r/depth)% 4) - 1; 
				new_y = origin_index_y + ((conv_index_r/depth)>>2) - 1;
				if(new_x < $signed(0) || new_y <$signed(0) || new_x >= MAP_COL || new_y >= MAP_ROW || new_z >= depth) begin
					if (conv_index_r < 16*depth) begin
						conv_index_r = conv_index_r + depth;
					end
					else
						conv_index_w = conv_index_r + 1;
					
				end
				
				else begin
					conv_index_w = conv_index_r + 1;
					sram_addr_w = new_x + new_y*MAP_COL + new_z*MAP_COL*MAP_ROW;
				end
				
			end
		end
		MED_FILTER : begin
			
			if (med_filter_done) begin
				last_2index_w = 0;
				last_1index_w = 0;
				sram_cen_w  = 1;
				sram_cen_r  = 1;
				med_filter_index_w = 0;
			end
			else begin
				if(out_counter_r > 0) begin
					out_valid_r = 1;
					//out_valid_w = 1;
					out_data_r  = conv_partial_sum[4-out_counter_r];
					out_counter_w = out_counter_r - 1;
					//$display("%d %d", counter_w, counter_r);
				end
				else begin
					out_valid_r = 0;
					out_valid_w = 0;
				end
				last_2index_w = last_1index_r;
				last_1index_w = med_filter_index_r;
				new_z = (med_filter_index_r)/16;
				new_x = origin_index_x + (med_filter_index_r% 4) - 1; 
				new_y = origin_index_y + (med_filter_index_r>>2)%4 - 1;
				if(new_x < $signed(0) || new_y <$signed(0) || new_x >= MAP_COL || new_y >= MAP_ROW || new_z >= 4) begin
					if(med_filter_index_r>=64) begin
						med_filter_index_w = med_filter_index_r + 1;
						sram_cen_w  = 1;
						//sram_cen_r  = 1;
					end else begin
						i_r[med_filter_index_r%16] = 0;
						if(med_filter_index_r/16 > counter_r) begin
							counter_w = counter_r + 1;
							out_counter_w = 4;
						end
						//$display("%d %d %d", med_filter_index_r, counter_w, counter_r);
						med_filter_index_r = med_filter_index_r + 1;
						med_filter_index_w = med_filter_index_r;
					end
				end
				else begin
					
					med_filter_index_w = med_filter_index_r + 1;
					sram_addr_w = new_x + new_y*MAP_COL + new_z*MAP_COL*MAP_ROW;
				end
				
				if(med_filter_index_r/16 > counter_r) begin
					counter_w = counter_r + 1;
					out_counter_w = 4;
				end
				
			end
			
		end
		SOBER_NMS  : begin
			if (sober_nms_done)begin
				last_2index_w = 0;
				last_1index_w = 0;
				sram_cen_w  = 1;
				sram_cen_r  = 1;
				med_filter_index_w = 0;
			end
			else begin
				if(out_counter_r > 0) begin
					out_valid_r = 1;
					//out_valid_w = 1;
					out_data_r  = conv_partial_sum[4-out_counter_r];
					out_counter_w = out_counter_r - 1;
					//$display("%d %d", counter_w, counter_r);
				end
				else begin
					out_valid_r = 0;
					out_valid_w = 0;
				end
				last_2index_w = last_1index_r;
				last_1index_w = med_filter_index_r;
				new_z = (med_filter_index_r)/16;
				new_x = origin_index_x + (med_filter_index_r% 4) - 1; 
				new_y = origin_index_y + (med_filter_index_r>>2)%4 - 1;
				if(new_x < $signed(0) || new_y <$signed(0) || new_x >= MAP_COL || new_y >= MAP_ROW || new_z >= 4) begin
					if(med_filter_index_r>=64) begin
						med_filter_index_w = med_filter_index_r + 1;
						sram_cen_w  = 1;
						sram_cen_r  = 1;
					end else begin
						i_r[med_filter_index_r%16] = 0;
						if(med_filter_index_r/16 > counter_r) begin
							counter_w = counter_r + 1;
							out_counter_w = 4;
						end
						//$display("%d %d %d", med_filter_index_r, counter_w, counter_r);
						med_filter_index_r = med_filter_index_r + 1;
						med_filter_index_w = med_filter_index_r;
					end
				end
				else begin
					
					med_filter_index_w = med_filter_index_r + 1;
					sram_addr_w = new_x + new_y*MAP_COL + new_z*MAP_COL*MAP_ROW;
				end
				
				if(med_filter_index_r/16 > counter_r) begin
					counter_w = counter_r + 1;
					out_counter_w = 4;
				end
			end
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
			end
			else begin
				next_state = DISPLAY;
			end
		end
		CONV_CALC  : begin
			if (convolution_calc_done) begin
				if (convolution_done) begin
					next_state = FETCH;
				end
				else begin
					next_state = CONV_CALC;
				end
				
			end
			else begin
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
always @(*) begin
	if (state == SOBER_NMS && out_counter_w >= 3) begin
		conv_partial_sum0 = o_sobel_nms[0];
		conv_partial_sum1 = o_sobel_nms[1];
		conv_partial_sum2 = o_sobel_nms[2];
		conv_partial_sum3 = o_sobel_nms[3];
		conv_partial_sum[0] = o_sobel_nms[0];
		conv_partial_sum[1] = o_sobel_nms[1];
		conv_partial_sum[2] = o_sobel_nms[2];
		conv_partial_sum[3] = o_sobel_nms[3];
		//$display("%d", o_sobel_nms[3]);
	end
	if (state == MED_FILTER && out_counter_w > 2) begin
		conv_partial_sum0 <= o_med_data[0];
				conv_partial_sum1 <= o_med_data[1];
				conv_partial_sum2 <= o_med_data[2];
				conv_partial_sum3 <= o_med_data[3];
				conv_partial_sum[0] <= o_med_data[0];
				conv_partial_sum[1] <= o_med_data[1];
				conv_partial_sum[2] <= o_med_data[2];
				conv_partial_sum[3] <= o_med_data[3];
		//$display("%d", o_sobel_nms[3]);
	end
end
// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
reg[15:0] counter;
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state <= FETCH;
		depth <= 32; // default channel dept 32
		sram_cen_w  <= 1;
		sram_cen_r  <= 1;
		origin_index_x <= 0;
		origin_index_y <= 0;
		counter <=0;
		test_sum <= 0;
	end else begin
		state <= next_state;
		if ((state == LOAD_MAP && i_in_valid)) begin
			if (sram_addr_w%64 ==32 ) begin
				test_sum = test_sum+sram_data_r;
				//$display("%d %d",test_sum, sram_data_r);
				
			end
				
			cnt <= cnt + 1;
		end else if (next_state == DISPLAY || next_state == CONV_CALC|| next_state == MED_FILTER|| next_state == SOBER_NMS)
			cnt <= cnt + 1;
			
		sram_data_r <= sram_data_w;
		
		out_data_r  <= out_data_w;
		out_valid_r <= out_valid_w;
		sram_cen_r  <= sram_cen_w;
		sram_wen_r  <= sram_wen_w;
		o_in_ready_r <= o_in_ready_w;
		counter <= out_valid_w? counter + 1: counter;
		if (cnt > 1 && state == CONV_CALC && counter_w < 2) begin
			conv_partial_sum[(last_1index_r)/depth] <= conv_partial_sum[(last_1index_r)/depth] + sram_data_out;
			conv_partial_sum0  <= conv_partial_sum[0 ];
			conv_partial_sum1  <= conv_partial_sum[1 ];
			conv_partial_sum2  <= conv_partial_sum[2 ];
			conv_partial_sum3  <= conv_partial_sum[3 ];
			conv_partial_sum4  <= conv_partial_sum[4 ];
			conv_partial_sum5  <= conv_partial_sum[5 ];
			conv_partial_sum6  <= conv_partial_sum[6 ];
			conv_partial_sum7  <= conv_partial_sum[7 ];
			conv_partial_sum8  <= conv_partial_sum[8 ];
			conv_partial_sum9  <= conv_partial_sum[9 ];
			conv_partial_sum10 <= conv_partial_sum[10];
			conv_partial_sum11 <= conv_partial_sum[11];
			conv_partial_sum12 <= conv_partial_sum[12];
			conv_partial_sum13 <= conv_partial_sum[13];
			conv_partial_sum14 <= conv_partial_sum[14];
			conv_partial_sum15 <= conv_partial_sum[15];
		end
		if (cnt > 1 && (state == MED_FILTER || state == SOBER_NMS)) begin
			i_r[last_1index_r%16] <= sram_data_out;
		end
		
		/* if (out_counter_w > 2) begin
			if (state == MED_FILTER) begin
				conv_partial_sum0 <= o_med_data[0];
				conv_partial_sum1 <= o_med_data[1];
				conv_partial_sum2 <= o_med_data[2];
				conv_partial_sum3 <= o_med_data[3];
				conv_partial_sum[0] <= o_med_data[0];
				conv_partial_sum[1] <= o_med_data[1];
				conv_partial_sum[2] <= o_med_data[2];
				conv_partial_sum[3] <= o_med_data[3];
			end
			
		end */
		conv_index_r <= conv_index_w; 
		counter_r <= counter_w;
		out_counter_r <= out_counter_w;
		med_filter_index_r <= med_filter_index_w;
		
		last_2index_r <= last_2index_w;
		last_1index_r <= last_1index_w;
		
		current_op_r <= current_op_w;
	end
end

endmodule




module median_filter(
    input [7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9,
    output [7:0] median
);
    wire [7:0] sorted[8:0];
    reg [7:0] temp;
    integer i, j;

    // Store the input pixels in an array for easier sorting
    reg [7:0] pixels[8:0];

    always @(*) begin
        pixels[0] = p1;
        pixels[1] = p2;
        pixels[2] = p3;
        pixels[3] = p4;
        pixels[4] = p5;
        pixels[5] = p6;
        pixels[6] = p7;
        pixels[7] = p8;
        pixels[8] = p9;

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


module sobel_nms(
    input signed[7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16,
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