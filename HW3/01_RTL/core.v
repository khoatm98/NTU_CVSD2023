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


parameter FETCH           = 4'd0;
parameter DECODE          = 4'd1;
parameter SCALE_DOWN      = 4'd2; //0010
parameter SCALE_UP        = 4'd3; //0011
parameter SHIFT_RIGHT     = 4'd4; //0100
parameter SHIFT_LEFT      = 4'd5; //0101
parameter SHIFT_UP        = 4'd6; //0110
parameter SHIFT_DOWN      = 4'd7; //0111  
parameter LOAD_MAP        = 4'd8; // 1000       
parameter DISPLAY         = 4'd9; //1001
parameter CONV_CALC       = 4'd10;//1010
parameter CONV_DISPLAY    = 4'd11;//1010
parameter MED_FILTER      = 4'd12;//1011
parameter SOBER_NMS       = 4'd13;//1100
parameter SRAM_READ       = 4'd14;//1101
parameter IDLE            = 4'd15;//1110

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
wire 	   display_done;
wire 	   convolution_reading_done;
reg 	   convolution_reading_done_r, convolution_reading_done_w;
wire 	   convolution_display_done;
reg 	   convolution_display_done_r, convolution_display_done_w;
// Flag for med filter operation
wire 	   med_filter_done;

// Flag for sobber nms operation
wire 	   sober_nms_done;

reg [5:0]  depth_r, depth_w;

reg [11:0] cnt, target_sticks;
reg [3:0]  origin_index_x_r, origin_index_x_w;
reg [3:0]  origin_index_y_r, origin_index_y_w;
reg signed [4:0]  new_x, new_x_delay1, new_x_delay2;
reg signed [4:0]  new_y, new_y_delay1, new_y_delay2;
reg signed [5:0]  new_z;

reg [10:0]     index_delay_r[2:0], index_delay_w;
reg [13:0]    conv_sum;
reg [13:0]    conv_partial_sum_w[15:0], conv_partial_sum_r[15:0];
reg [13:0]    med_filter_partial_sum[3:0][3:0];
reg [4:0] 	 counter_r, counter_w;
reg [13:0] out_data_w, out_data_r;
reg        out_valid_delay_w;
reg [2:0]  out_valid_delay_r;

reg        out_valid_w;
reg        out_valid_r;
reg [3:0]  out_data_sram_index_r[2:0];
reg [3:0]  out_data_sram_index_w;
//reg 	   o_in_ready_w, o_in_ready_r;
reg [16:0] out_data_w_17;

reg [2:0] out_counter_w, out_counter_r;
reg [7:0] i_r[15:0];
reg [7:0] i_r_w[15:0];
wire [7:0]o_med_data[3:0];
wire [13:0]o_sobel_nms[3:0];
wire         activate_median_filter, activate_sobel_nms;

reg  [3:0]       activate_median_filter_r;
reg				activate_median_filter_w;
reg  [4:0]       activate_sobel_nms_r;
reg				 activate_sobel_nms_w;
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


wire [7:0] sram_data0;
wire sram_wen0, sram_cen0;

//assign sram_wen0 = sram_wen[0];
//assign sram_cen0 = sram_cen[0];
//assign sram_data0 = sram_data[0];
// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
genvar SRAM_inst, i;
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

median_filter u_med_filter_inst0 (i_r[0], i_r[1], i_r[2], i_r[3], i_r[4], i_r[5], i_r[6], i_r[7], i_r[8], i_r[9], i_r[10], i_r[11], i_r[12], i_r[13], i_r[14], i_r[15], i_clk, activate_median_filter, o_med_data[3], o_med_data[2], o_med_data[1], o_med_data[0]);


sobel_nms sobel_nms_inst0(i_r[0], i_r[1], i_r[2], i_r[3], i_r[4], i_r[5], i_r[6], i_r[7], i_r[8], i_r[9], i_r[10], i_r[11], i_r[12], i_r[13], i_r[14], i_r[15], i_clk, activate_sobel_nms, o_sobel_nms[3], o_sobel_nms[2], o_sobel_nms[1], o_sobel_nms[0]);
 

assign load_map_done = cnt == 2048;
assign display_done  = (cnt == 4*(depth_r));  // one extra cycle for DECODE
assign convolution_reading_done  = convolution_reading_done_r;
assign convolution_display_done  = convolution_display_done_r;
assign med_filter_done = index_delay_r[2] >= (87); // 64 + 16 ( 4 cyles for output) + 7 ( 7 cycles for first output)
assign sober_nms_done  = index_delay_r[2] >= (89); // 64 + 16 ( 4 cyles for output) + 7 ( 7 cycles for first output) 
assign o_op_ready = (state == FETCH) && i_rst_n;
assign o_in_ready = (state == LOAD_MAP) && ~load_map_done;
assign o_out_valid = out_valid_r;

assign o_out_data  = out_data_r; //sram_data_out[out_data_sram_index_r[2]];





// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //


// Origin and depth transform
always @(*) begin
	casez(state)
		SCALE_UP: begin
			depth_w =  (depth_r == 32  ? depth_r: depth_r<<1); 
			origin_index_x_w = origin_index_x_r;
			origin_index_y_w = origin_index_y_r;
		end
		SCALE_DOWN: begin
			depth_w =  (depth_r == 8 ? depth_r : depth_r>>1); 
			origin_index_x_w = origin_index_x_r;
			origin_index_y_w = origin_index_y_r;
		end
		4'b01zz      : begin
			if(state[1]==0) begin
				origin_index_x_w = state[0] == 0 ? (origin_index_x_r == (MAP_COL-2) ? origin_index_x_r: origin_index_x_r + 1): (origin_index_x_r == 0 ? origin_index_x_r : origin_index_x_r - 1); 
				origin_index_y_w = origin_index_y_r;
				depth_w = depth_r;
			end
			else begin
				origin_index_x_w = origin_index_x_r;
				origin_index_y_w = state[0] == 1 ? (origin_index_y_r == (MAP_ROW-2) ? origin_index_y_r: origin_index_y_r + 1): (origin_index_y_r == 0 ? origin_index_y_r : origin_index_y_r - 1); 
				depth_w = depth_r;
			end
		end
		default: begin
			depth_w = depth_r;
			origin_index_x_w = origin_index_x_r;
			origin_index_y_w = origin_index_y_r;
		end
	endcase
end 



always @(*) begin
	case(state)
		LOAD_MAP: begin
			new_z = cnt/64;
			new_x = (cnt%64)%8;
			new_y = (cnt%64)/8;
		end
		DISPLAY: begin
			new_z = cnt[7:2];
			new_x = origin_index_x_r + ((cnt%4) %2 == 1); 
			new_y = origin_index_y_r + ((cnt%4)     > 1);
		end
		CONV_CALC: begin
			new_z = index_delay_r[0] >= 16*depth_r? depth_r : (index_delay_r[0])/16;
			new_x = origin_index_x_r - 1; 
			new_y = origin_index_y_r + (index_delay_r[0]%16)/4 - 1;
		end
		default: begin
			new_z = index_delay_r[0] >= 16*depth_r? depth_r : (index_delay_r[0])/16;
			new_x = origin_index_x_r - 1; 
			new_y = origin_index_y_r + (index_delay_r[0]%16)/4 - 1;
		end
	endcase
end


always @(*) begin
	case(state)
		LOAD_MAP: begin
			sram_addr_delay_w[0] = sram_addr_delay_r[0][0];
			sram_addr_delay_w[1] = sram_addr_delay_r[1][0];
			sram_addr_delay_w[2] = sram_addr_delay_r[2][0];
			sram_addr_delay_w[3] = sram_addr_delay_r[3][0];
			sram_addr_delay_w[4] = sram_addr_delay_r[4][0];
			sram_addr_delay_w[5] = sram_addr_delay_r[5][0];
			sram_addr_delay_w[6] = sram_addr_delay_r[6][0];
			sram_addr_delay_w[7] = sram_addr_delay_r[7][0];
			if(new_y%2 == 0) begin
				sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
			end
			else begin
				sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
			end
		end
		DISPLAY: begin
			sram_addr_delay_w[0] = sram_addr_delay_r[0][0];
			sram_addr_delay_w[1] = sram_addr_delay_r[1][0];
			sram_addr_delay_w[2] = sram_addr_delay_r[2][0];
			sram_addr_delay_w[3] = sram_addr_delay_r[3][0];
			sram_addr_delay_w[4] = sram_addr_delay_r[4][0];
			sram_addr_delay_w[5] = sram_addr_delay_r[5][0];
			sram_addr_delay_w[6] = sram_addr_delay_r[6][0];
			sram_addr_delay_w[7] = sram_addr_delay_r[7][0];
			if(new_y%2 == 0) begin
				sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
			end
			else begin
				sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
			end
		end
		CONV_CALC: begin
			sram_addr_delay_w[0] = sram_addr_delay_r[0][0];
			sram_addr_delay_w[1] = sram_addr_delay_r[1][0];
			sram_addr_delay_w[2] = sram_addr_delay_r[2][0];
			sram_addr_delay_w[3] = sram_addr_delay_r[3][0];
			sram_addr_delay_w[4] = sram_addr_delay_r[4][0];
			sram_addr_delay_w[5] = sram_addr_delay_r[5][0];
			sram_addr_delay_w[6] = sram_addr_delay_r[6][0];
			sram_addr_delay_w[7] = sram_addr_delay_r[7][0];
			if(new_y%2 == 0) begin
				if(new_x >= 0) begin
					sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
					sram_addr_delay_w[(new_x+4)%8] = new_y + 1 + new_z*MAP_ROW;
				end 
				if (new_x < MAP_COL - 3) begin
					sram_addr_delay_w[new_x + 3] = new_y + new_z*MAP_ROW;
					sram_addr_delay_w[(new_x+3+4)%8] = new_y + 1 + new_z*MAP_ROW;
				end
				sram_addr_delay_w[new_x + 1] = new_y + new_z*MAP_ROW;
				sram_addr_delay_w[new_x + 2] = new_y + new_z*MAP_ROW;
				sram_addr_delay_w[(new_x+1+4)%8] = new_y + 1 + new_z*MAP_ROW;
				sram_addr_delay_w[(new_x+2+4)%8] = new_y + 1 + new_z*MAP_ROW;
			end
			else begin
				
				if(new_x >= 0) begin
					sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
					sram_addr_delay_w[new_x] = (new_y + 1) + new_z*MAP_ROW;
				end 
				if (new_x < (MAP_COL - 3)) begin
					sram_addr_delay_w[(new_x+3+4)%8] = new_y + new_z*MAP_ROW;
					sram_addr_delay_w[new_x + 3] = (new_y + 1) + new_z*MAP_ROW;
				end
				sram_addr_delay_w[new_x + 1] = (new_y + 1) + new_z*MAP_ROW;
				sram_addr_delay_w[new_x + 2] = (new_y + 1) + new_z*MAP_ROW;
				sram_addr_delay_w[(new_x+1+4)%8] = new_y + new_z*MAP_ROW;
				sram_addr_delay_w[(new_x+2+4)%8] = new_y  + new_z*MAP_ROW;
			end
		end
		MED_FILTER: begin
			sram_addr_delay_w[0] = sram_addr_delay_r[0][0];
			sram_addr_delay_w[1] = sram_addr_delay_r[1][0];
			sram_addr_delay_w[2] = sram_addr_delay_r[2][0];
			sram_addr_delay_w[3] = sram_addr_delay_r[3][0];
			sram_addr_delay_w[4] = sram_addr_delay_r[4][0];
			sram_addr_delay_w[5] = sram_addr_delay_r[5][0];
			sram_addr_delay_w[6] = sram_addr_delay_r[6][0];
			sram_addr_delay_w[7] = sram_addr_delay_r[7][0];
			if (med_filter_done || sober_nms_done) begin

			end
			else begin
				
				if (index_delay_r[0] < 16*depth_r) begin
					if(new_y%2 == 0) begin
						if(new_x >= (0)) begin
							sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+4)%8] = new_y + 1 + new_z*MAP_ROW;
						end 
						if (new_x < MAP_COL - 3) begin
							sram_addr_delay_w[new_x + 3] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + 1 + new_z*MAP_ROW;
						end
						sram_addr_delay_w[new_x + 1] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + 1 + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y + 1 + new_z*MAP_ROW;
					end
					else begin
						
						if(new_x >= (0)) begin
							sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x] = (new_y + 1) + new_z*MAP_ROW;
						end 
						if (new_x < (MAP_COL - 3)) begin
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x + 3] = (new_y + 1) + new_z*MAP_ROW;
						end
						sram_addr_delay_w[new_x + 1] = (new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = (new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y  + new_z*MAP_ROW;
					end
				end
			end
		end
		SOBER_NMS: begin
			sram_addr_delay_w[0] = sram_addr_delay_r[0][0];
			sram_addr_delay_w[1] = sram_addr_delay_r[1][0];
			sram_addr_delay_w[2] = sram_addr_delay_r[2][0];
			sram_addr_delay_w[3] = sram_addr_delay_r[3][0];
			sram_addr_delay_w[4] = sram_addr_delay_r[4][0];
			sram_addr_delay_w[5] = sram_addr_delay_r[5][0];
			sram_addr_delay_w[6] = sram_addr_delay_r[6][0];
			sram_addr_delay_w[7] = sram_addr_delay_r[7][0];
			if (med_filter_done || sober_nms_done) begin

			end
			else begin
				
				if (index_delay_r[0] < 16*depth_r) begin
					if(new_y%2 == 0) begin
						if(new_x >= (0)) begin
							sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+4)%8] = new_y + 1 + new_z*MAP_ROW;
						end 
						if (new_x < MAP_COL - 3) begin
							sram_addr_delay_w[new_x + 3] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + 1 + new_z*MAP_ROW;
						end
						sram_addr_delay_w[new_x + 1] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + 1 + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y + 1 + new_z*MAP_ROW;
					end
					else begin
						
						if(new_x >= (0)) begin
							sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x] = (new_y + 1) + new_z*MAP_ROW;
						end 
						if (new_x < (MAP_COL - 3)) begin
							sram_addr_delay_w[(new_x+3+4)%8] = new_y + new_z*MAP_ROW;
							sram_addr_delay_w[new_x + 3] = (new_y + 1) + new_z*MAP_ROW;
						end
						sram_addr_delay_w[new_x + 1] = (new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[new_x + 2] = (new_y + 1) + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+1+4)%8] = new_y + new_z*MAP_ROW;
						sram_addr_delay_w[(new_x+2+4)%8] = new_y  + new_z*MAP_ROW;
					end
				end
			end
		end
		default: begin
			sram_addr_delay_w[0] = sram_addr_delay_r[0][0];
			sram_addr_delay_w[1] = sram_addr_delay_r[1][0];
			sram_addr_delay_w[2] = sram_addr_delay_r[2][0];
			sram_addr_delay_w[3] = sram_addr_delay_r[3][0];
			sram_addr_delay_w[4] = sram_addr_delay_r[4][0];
			sram_addr_delay_w[5] = sram_addr_delay_r[5][0];
			sram_addr_delay_w[6] = sram_addr_delay_r[6][0];
			sram_addr_delay_w[7] = sram_addr_delay_r[7][0];
		end
	endcase
end


//sram_wen_w combinational circuit
always @(state) begin
	case(state)
		LOAD_MAP: begin
			sram_wen_w[0]  = 0;
			sram_wen_w[1]  = 0; 
			sram_wen_w[2]  = 0;
			sram_wen_w[3]  = 0;
			sram_wen_w[4]  = 0;
			sram_wen_w[5]  = 0; 
			sram_wen_w[6]  = 0;
			sram_wen_w[7]  = 0;
		end

		default: begin
			sram_wen_w[0]  = 1;
			sram_wen_w[1]  = 1; 
			sram_wen_w[2]  = 1;
			sram_wen_w[3]  = 1;
			sram_wen_w[4]  = 1;
			sram_wen_w[5]  = 1; 
			sram_wen_w[6]  = 1;
			sram_wen_w[7]  = 1;
		end
	endcase
end

//sram_cen_w combinational circuit
always @(*) begin
	case(state)
		LOAD_MAP: begin
			sram_cen_w[0]  = 1;
			sram_cen_w[1]  = 1; 
			sram_cen_w[2]  = 1;
			sram_cen_w[3]  = 1;
			sram_cen_w[4]  = 1;
			sram_cen_w[5]  = 1; 
			sram_cen_w[6]  = 1;
			sram_cen_w[7]  = 1;
			if (load_map_done) begin

			end
			else begin

				if(new_y%2 == 0) begin
					//sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
					sram_cen_w[new_x] = 0; 
				end
				else begin
					//sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
					sram_cen_w[(new_x+4)%8] = 0; 
				end
			end
		end
		DISPLAY: begin
			sram_cen_w[0]  = 1;
			sram_cen_w[1]  = 1; 
			sram_cen_w[2]  = 1;
			sram_cen_w[3]  = 1;
			sram_cen_w[4]  = 1;
			sram_cen_w[5]  = 1; 
			sram_cen_w[6]  = 1;
			sram_cen_w[7]  = 1;
			
			
			if (display_done) begin
			end
			else begin
				if(new_y%2 == 0) begin
					//sram_addr_delay_w[new_x] = new_y + new_z*MAP_ROW;
					sram_cen_w[new_x] = 0; 
				end
				else begin
					//sram_addr_delay_w[(new_x+4)%8] = new_y + new_z*MAP_ROW;
					sram_cen_w[(new_x+4)%8] = 0; 
				end
			end
		end
		CONV_CALC: begin
			sram_cen_w[0]  = 1;
			sram_cen_w[1]  = 1; 
			sram_cen_w[2]  = 1;
			sram_cen_w[3]  = 1;
			sram_cen_w[4]  = 1;
			sram_cen_w[5]  = 1; 
			sram_cen_w[6]  = 1;
			sram_cen_w[7]  = 1;
			if (index_delay_r[0] < 16*depth_r) begin
				if(new_y%2 == 0) begin
					if(new_x >= 0) begin
						sram_cen_w[new_x] = 0; 
						sram_cen_w[(new_x+4)%8] = 0; 
					end 
					if (new_x < MAP_COL - 3) begin
						sram_cen_w[new_x + 3] = 0; 
						sram_cen_w[(new_x+3+4)%8] = 0; 
					end
					sram_cen_w[new_x + 1] = 0; 
					sram_cen_w[(new_x+1+4)%8] = 0; 
					sram_cen_w[new_x + 2] = 0; 
					sram_cen_w[(new_x+2+4)%8] = 0; 
				end
				else begin
					
					if(new_x >= 0) begin
						sram_cen_w[new_x] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+4)%8] = new_y < 0 ? 1 : 0; 
					end 
					if (new_x < (MAP_COL - 3)) begin
						sram_cen_w[new_x + 3] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+3+4)%8] = new_y < (0) ? 1 : 0; 
					end
					sram_cen_w[new_x + 1] = new_y >= MAP_COL-2 ? 1 :0; 
					sram_cen_w[(new_x+1+4)%8] = new_y < (0) ? 1 : 0; 
					sram_cen_w[new_x + 2] = new_y >= MAP_COL-2 ? 1 :0; 
					sram_cen_w[(new_x+2+4)%8] = new_y < (0) ? 1 : 0; 
				end
			end
			else begin

			end
		end
		MED_FILTER: begin
			sram_cen_w[0]  = 1;
			sram_cen_w[1]  = 1; 
			sram_cen_w[2]  = 1;
			sram_cen_w[3]  = 1;
			sram_cen_w[4]  = 1;
			sram_cen_w[5]  = 1; 
			sram_cen_w[6]  = 1;
			sram_cen_w[7]  = 1;
			if (med_filter_done || sober_nms_done) begin

			end else begin
				if (index_delay_r[0] < 16*depth_r) begin
					if(new_y%2 == 0) begin
						if(new_x >= (0)) begin
							sram_cen_w[new_x] = 0; 
							sram_cen_w[(new_x+4)%8] = 0; 
						end 
						if (new_x < MAP_COL - 3) begin
							sram_cen_w[new_x + 3] = 0; 
							sram_cen_w[(new_x+3+4)%8] = 0; 
						end
						sram_cen_w[new_x + 1] = 0; 
						sram_cen_w[(new_x+1+4)%8] = 0; 
						sram_cen_w[new_x + 2] = 0; 
						sram_cen_w[(new_x+2+4)%8] = 0; 
					end
					else begin
						
						if(new_x >= 0) begin
							sram_cen_w[new_x] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+4)%8] = new_y < 0 ? 1 : 0; 
						end 
						if (new_x < (MAP_COL - 3)) begin
							sram_cen_w[new_x + 3] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+3+4)%8] = new_y < 0 ? 1 : 0; 
						end
						sram_cen_w[new_x + 1] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+1+4)%8] = new_y < 0 ? 1 : 0; 
						sram_cen_w[new_x + 2] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+2+4)%8] = new_y < 0 ? 1 : 0; 
					end
				end
			end
		end
		SOBER_NMS: begin
			sram_cen_w[0]  = 1;
			sram_cen_w[1]  = 1; 
			sram_cen_w[2]  = 1;
			sram_cen_w[3]  = 1;
			sram_cen_w[4]  = 1;
			sram_cen_w[5]  = 1; 
			sram_cen_w[6]  = 1;
			sram_cen_w[7]  = 1;
			if (med_filter_done || sober_nms_done) begin

			end else begin
				if (index_delay_r[0] < 16*depth_r) begin
					if(new_y%2 == 0) begin
						if(new_x >= (0)) begin
							sram_cen_w[new_x] = 0; 
							sram_cen_w[(new_x+4)%8] = 0; 
						end 
						if (new_x < MAP_COL - 3) begin
							sram_cen_w[new_x + 3] = 0; 
							sram_cen_w[(new_x+3+4)%8] = 0; 
						end
						sram_cen_w[new_x + 1] = 0; 
						sram_cen_w[(new_x+1+4)%8] = 0; 
						sram_cen_w[new_x + 2] = 0; 
						sram_cen_w[(new_x+2+4)%8] = 0; 
					end
					else begin
						
						if(new_x >= 0) begin
							sram_cen_w[new_x] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+4)%8] = new_y < 0 ? 1 : 0; 
						end 
						if (new_x < (MAP_COL - 3)) begin
							sram_cen_w[new_x + 3] = new_y >= MAP_COL-2 ? 1 :0; 
							sram_cen_w[(new_x+3+4)%8] = new_y < 0 ? 1 : 0; 
						end
						sram_cen_w[new_x + 1] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+1+4)%8] = new_y < 0 ? 1 : 0; 
						sram_cen_w[new_x + 2] = new_y >= MAP_COL-2 ? 1 :0; 
						sram_cen_w[(new_x+2+4)%8] = new_y < 0 ? 1 : 0; 
					end
				end
			end
		end
		default: begin
			sram_cen_w[0]  = 1;
			sram_cen_w[1]  = 1; 
			sram_cen_w[2]  = 1;
			sram_cen_w[3]  = 1;
			sram_cen_w[4]  = 1;
			sram_cen_w[5]  = 1; 
			sram_cen_w[6]  = 1;
			sram_cen_w[7]  = 1;
		end
	endcase
end

always @(*) begin
	case(state)
		DISPLAY: begin
			out_data_w = sram_data_out[out_data_sram_index_r[1]];
		end
		CONV_DISPLAY: begin
			if(out_counter_r<4) begin
				if (out_counter_r <=1) begin
				out_data_w_17 = ((conv_partial_sum_r[out_counter_r])    )    + 
								((conv_partial_sum_r[1+out_counter_r] ) <<1)   + 
								((conv_partial_sum_r[2+out_counter_r] ) )    + 
								((conv_partial_sum_r[4+out_counter_r] ) <<1)    + 
								((conv_partial_sum_r[5+out_counter_r] ) <<2)   + 
								((conv_partial_sum_r[6+out_counter_r] ) <<1)   + 
								((conv_partial_sum_r[8+out_counter_r] ) )   + 
								((conv_partial_sum_r[9+out_counter_r] ) <<1)  + 
								((conv_partial_sum_r[10+out_counter_r]) );
				end
				else begin
				out_data_w_17 = ((conv_partial_sum_r[2 +out_counter_r])    )    + 
								((conv_partial_sum_r[3 +out_counter_r] ) <<1)   + 
								((conv_partial_sum_r[4 +out_counter_r] ) )    + 
								((conv_partial_sum_r[6 +out_counter_r] ) <<1)    + 
								((conv_partial_sum_r[7 +out_counter_r] ) <<2)   + 
								((conv_partial_sum_r[8 +out_counter_r] ) <<1)   + 
								((conv_partial_sum_r[10 +out_counter_r] ) )   + 
								((conv_partial_sum_r[11 +out_counter_r] ) <<1)  + 
								((conv_partial_sum_r[12+out_counter_r]) );
				end
				out_data_w = (out_data_w_17 >> 4) + out_data_w_17[3];
			end else begin
				out_data_w = 0;
			end
		end
		MED_FILTER: begin
			if(out_counter_r > 0)
				out_data_w = o_med_data[4-out_counter_r];
			else
				out_data_w = out_data_r;
		end
		SOBER_NMS: begin
			if(out_counter_r > 0)
				out_data_w = o_sobel_nms[4-out_counter_r];
			else
				out_data_w = out_data_r;
		end
		default: begin
			out_data_w = sram_data_out[out_data_sram_index_r[1]];
		end
	endcase
end

always @(*) begin
	case(state)
		DISPLAY: begin
			out_valid_w = out_valid_delay_r[1];
			if (display_done) begin
				out_valid_delay_w = 0;
			end
			else begin
				out_valid_delay_w = 1;
			end
		end
		CONV_CALC: begin
			out_valid_w = 0;
			out_valid_delay_w = 0;
		end
		CONV_DISPLAY: begin
			if (convolution_display_done_r)
				out_valid_w = 0;
			else
				out_valid_w = 1;
			out_valid_delay_w = 0;
		end
		MED_FILTER: begin
			out_valid_delay_w = 0;
			if(out_counter_r > 0) begin
				out_valid_w = 1;
			end else
				out_valid_w = 0;
		end
		SOBER_NMS: begin
			out_valid_delay_w = 0;
			if(out_counter_r > 0) begin
				out_valid_w = 1;
			end else
				out_valid_w = 0;
		end
		default: begin
			out_valid_w = out_valid_delay_r[1];
			out_valid_delay_w = 0;
		end
	endcase
end

always @(*) begin
	case(state)
		DISPLAY: begin
			if(new_y%2 == 0) begin
				out_data_sram_index_w = new_x;
			end
			else begin
				out_data_sram_index_w = (new_x+4)%8;
			end
		end
		default: begin
			out_data_sram_index_w = 0;
		end
	endcase
end

always @(*) begin
	case(state)
		CONV_CALC: begin
			index_delay_w = index_delay_r[0] + 8;
			convolution_reading_done_w = index_delay_r[1] >= 16*depth_r;
			convolution_display_done_w = 0;
			counter_w = 0;
			out_counter_w = 0;
			activate_median_filter_w = 0;
			activate_sobel_nms_w = 0;
		end
		CONV_DISPLAY: begin
			index_delay_w = index_delay_r[2];
			convolution_reading_done_w = 0;
			convolution_display_done_w = out_counter_r == 3;
			counter_w = 0;
			out_counter_w = out_counter_r + 1;
			activate_median_filter_w = 0;
			activate_sobel_nms_w = 0;
		end
		MED_FILTER: begin
			if(index_delay_r[0]/16 <= counter_r) begin
				index_delay_w = index_delay_r[0] + 8;
			end else
				index_delay_w = index_delay_r[0];
				
			if(index_delay_r[1]/16 > counter_r) begin
				activate_median_filter_w = 1;
				counter_w = counter_r + 1;
			end else begin
				activate_median_filter_w = 0;
				counter_w = counter_r;
			end
			
			if(activate_median_filter_r[3]) begin
				out_counter_w = 4;
			end else begin
				out_counter_w = out_counter_r > 0 ? out_counter_r - 1 : out_counter_r;
			end
			convolution_reading_done_w = 0;
			convolution_display_done_w = 0;
			activate_sobel_nms_w = 0;
		end
		SOBER_NMS: begin
			if(index_delay_r[0]/16 <= counter_r) begin
				index_delay_w = index_delay_r[0] + 8;
			end else
				index_delay_w = index_delay_r[0];
				
			if(index_delay_r[1]/16 > counter_r) begin
				activate_sobel_nms_w = 1;
				counter_w = counter_r + 1;
			end else begin
				activate_sobel_nms_w = 0;
				counter_w = counter_r;
			end
			
			if(activate_sobel_nms_r[4]) begin
				out_counter_w = 4;
			end else begin
				out_counter_w = out_counter_r > 0 ? out_counter_r - 1 : out_counter_r;
			end
			convolution_reading_done_w = 0;
			convolution_display_done_w = 0;
			activate_median_filter_w = 0;
		end
		default: begin
			activate_median_filter_w = 0;
			index_delay_w = 0;
			convolution_reading_done_w = 0;
			convolution_display_done_w = 0;
			counter_w = 0;
			out_counter_w = 0;
			activate_sobel_nms_w = 0;
		end
	endcase
end



always @(*) begin
	case(state)
		CONV_CALC: begin
			conv_partial_sum_w[0] =  conv_partial_sum_r[0] ;
			conv_partial_sum_w[1] =  conv_partial_sum_r[1] ;
			conv_partial_sum_w[2] =  conv_partial_sum_r[2] ;
			conv_partial_sum_w[3] =  conv_partial_sum_r[3] ;
			conv_partial_sum_w[4] =  conv_partial_sum_r[4] ;
			conv_partial_sum_w[5] =  conv_partial_sum_r[5] ;
			conv_partial_sum_w[6] =  conv_partial_sum_r[6] ;
			conv_partial_sum_w[7] =  conv_partial_sum_r[7] ;
			conv_partial_sum_w[8] =  conv_partial_sum_r[8] ;
			conv_partial_sum_w[9] =  conv_partial_sum_r[9] ;
			conv_partial_sum_w[10] = conv_partial_sum_r[10];
			conv_partial_sum_w[11] = conv_partial_sum_r[11];
			conv_partial_sum_w[12] = conv_partial_sum_r[12];
			conv_partial_sum_w[13] = conv_partial_sum_r[13];
			conv_partial_sum_w[14] = conv_partial_sum_r[14];
			conv_partial_sum_w[15] = conv_partial_sum_r[15];
			if(((sram_cen_r[1][1] == 0 && sram_wen_r[1][1] == 1) || (sram_cen_r[5][1] == 0 && sram_wen_r[5][1] == 1))) begin //SRAM READ 
				if(new_y_delay2%2 == 0) begin
					if(new_x_delay2 >= 0) begin
						conv_partial_sum_w[index_delay_r[2]%16]     = conv_partial_sum_r[index_delay_r[2]%16] + sram_data_out[new_x_delay2];
						conv_partial_sum_w[index_delay_r[2]%16 + 4] = conv_partial_sum_r[index_delay_r[2]%16 + 4] + sram_data_out[(new_x_delay2+4)%8];
					end 
					if (new_x_delay2 < MAP_COL - 3) begin
						conv_partial_sum_w[index_delay_r[2]%16 + 3] = conv_partial_sum_r[index_delay_r[2]%16 + 3] + sram_data_out[new_x_delay2 + 3];
						conv_partial_sum_w[index_delay_r[2]%16 + 7] = conv_partial_sum_r[index_delay_r[2]%16 + 7] + sram_data_out[(new_x_delay2+3+4)%8];
					end
					
					conv_partial_sum_w[index_delay_r[2]%16 + 1] = conv_partial_sum_r[index_delay_r[2]%16 + 1] + sram_data_out[new_x_delay2 + 1];
					conv_partial_sum_w[index_delay_r[2]%16 + 2] = conv_partial_sum_r[index_delay_r[2]%16 + 2] + sram_data_out[new_x_delay2 + 2];
					conv_partial_sum_w[index_delay_r[2]%16 + 5] = conv_partial_sum_r[index_delay_r[2]%16 + 5] + sram_data_out[(new_x_delay2+1+4)%8];
					conv_partial_sum_w[index_delay_r[2]%16 + 6] = conv_partial_sum_r[index_delay_r[2]%16 + 6] + sram_data_out[(new_x_delay2+2+4)%8];
				end
				else begin
					if(new_x_delay2 >= 0) begin
						conv_partial_sum_w[index_delay_r[2]%16]     = new_y_delay2 < 0 ? conv_partial_sum_r[index_delay_r[2]%16]             : conv_partial_sum_r[index_delay_r[2]%16]    + sram_data_out[(new_x_delay2+4)%8];
						conv_partial_sum_w[index_delay_r[2]%16 + 4] = new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum_r[index_delay_r[2]%16+4 ]  :conv_partial_sum_r[index_delay_r[2]%16 + 4] + sram_data_out[new_x_delay2];
					end 
					if (new_x_delay2 < MAP_COL - 3) begin
						conv_partial_sum_w[index_delay_r[2]%16 + 3] = new_y_delay2 < 0 ? conv_partial_sum_r[index_delay_r[2]%16+3]           : conv_partial_sum_r[index_delay_r[2]%16 + 3] + sram_data_out[(new_x_delay2+3+4)%8];
						conv_partial_sum_w[index_delay_r[2]%16 + 7] = new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum_r[index_delay_r[2]%16+7]  : conv_partial_sum_r[index_delay_r[2]%16 + 7] + sram_data_out[new_x_delay2 + 3   ];
					end
					
					conv_partial_sum_w[index_delay_r[2]%16 + 1] = new_y_delay2 < 0 ? conv_partial_sum_r[index_delay_r[2]%16 + 1]  : conv_partial_sum_r[index_delay_r[2]%16 + 1] + sram_data_out[(new_x_delay2+1+4)%8];
					conv_partial_sum_w[index_delay_r[2]%16 + 2] = new_y_delay2 < 0 ? conv_partial_sum_r[index_delay_r[2]%16 + 2]  : conv_partial_sum_r[index_delay_r[2]%16 + 2] + sram_data_out[(new_x_delay2+2+4)%8];
					conv_partial_sum_w[index_delay_r[2]%16 + 5] = new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum_r[index_delay_r[2]%16 + 5]  : conv_partial_sum_r[index_delay_r[2]%16 + 5] + sram_data_out[new_x_delay2 + 1];
					conv_partial_sum_w[index_delay_r[2]%16 + 6] = new_y_delay2 >= MAP_ROW-2 ? conv_partial_sum_r[index_delay_r[2]%16 + 6]  : conv_partial_sum_r[index_delay_r[2]%16 + 6] + sram_data_out[new_x_delay2 + 2];
				end
			end
		end
		CONV_DISPLAY: begin
			conv_partial_sum_w[0] =  conv_partial_sum_r[0] ;
			conv_partial_sum_w[1] =  conv_partial_sum_r[1] ;
			conv_partial_sum_w[2] =  conv_partial_sum_r[2] ;
			conv_partial_sum_w[3] =  conv_partial_sum_r[3] ;
			conv_partial_sum_w[4] =  conv_partial_sum_r[4] ;
			conv_partial_sum_w[5] =  conv_partial_sum_r[5] ;
			conv_partial_sum_w[6] =  conv_partial_sum_r[6] ;
			conv_partial_sum_w[7] =  conv_partial_sum_r[7] ;
			conv_partial_sum_w[8] =  conv_partial_sum_r[8] ;
			conv_partial_sum_w[9] =  conv_partial_sum_r[9] ;
			conv_partial_sum_w[10] = conv_partial_sum_r[10];
			conv_partial_sum_w[11] = conv_partial_sum_r[11];
			conv_partial_sum_w[12] = conv_partial_sum_r[12];
			conv_partial_sum_w[13] = conv_partial_sum_r[13];
			conv_partial_sum_w[14] = conv_partial_sum_r[14];
			conv_partial_sum_w[15] = conv_partial_sum_r[15];
		end
		default: begin
			conv_partial_sum_w[0] =  0;
			conv_partial_sum_w[1] =  0;
			conv_partial_sum_w[2] =  0;
			conv_partial_sum_w[3] =  0;
			conv_partial_sum_w[4] =  0;
			conv_partial_sum_w[5] =  0;
			conv_partial_sum_w[6] =  0;
			conv_partial_sum_w[7] =  0;
			conv_partial_sum_w[8] =  0;
			conv_partial_sum_w[9] =  0;
			conv_partial_sum_w[10] = 0;
			conv_partial_sum_w[11] = 0;
			conv_partial_sum_w[12] = 0;
			conv_partial_sum_w[13] = 0;
			conv_partial_sum_w[14] = 0;
			conv_partial_sum_w[15] = 0;
		end
	endcase
end

always @(*) begin
	case(state)
		MED_FILTER: begin
			i_r_w[0]  = i_r[0] ;
			i_r_w[1]  = i_r[1] ;
			i_r_w[2]  = i_r[2] ;
			i_r_w[3]  = i_r[3] ;
			i_r_w[4]  = i_r[4] ;
			i_r_w[5]  = i_r[5] ;
			i_r_w[6]  = i_r[6] ;
			i_r_w[7]  = i_r[7] ;
			i_r_w[8]  = i_r[8] ;
			i_r_w[9]  = i_r[9] ;
			i_r_w[10] = i_r[10];
			i_r_w[11] = i_r[11];
			i_r_w[12] = i_r[12];
			i_r_w[13] = i_r[13];
			i_r_w[14] = i_r[14];
			i_r_w[15] = i_r[15];
			if(((sram_cen_r[1][1] == 0 && sram_wen_r[1][1] == 1) || (sram_cen_r[5][1] == 0 && sram_wen_r[5][1] == 1))) begin //SRAM READ 
				if(new_y_delay2%2 == 0) begin
					if(new_x >= (0)) begin
						i_r_w[index_delay_r[2]%16] =  sram_data_out[new_x];
						i_r_w[index_delay_r[2]%16 + 4] =  sram_data_out[(new_x+4)%8];
					end 
					if (new_x < MAP_COL - 3) begin
						i_r_w[index_delay_r[2]%16 + 3] =  sram_data_out[new_x + 3];
						i_r_w[index_delay_r[2]%16 + 7] =  sram_data_out[(new_x+3+4)%8];
					end
					
					i_r_w[index_delay_r[2]%16 + 1] =  sram_data_out[new_x + 1];
					i_r_w[index_delay_r[2]%16 + 2] =  sram_data_out[new_x + 2];
					i_r_w[index_delay_r[2]%16 + 5] =  sram_data_out[(new_x+1+4)%8];
					i_r_w[index_delay_r[2]%16 + 6] =  sram_data_out[(new_x+2+4)%8];
				end
				else begin
					if(new_x >= (0)) begin
						i_r_w[index_delay_r[2]%16]     = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16]  :  sram_data_out[(new_x+4)%8];
						i_r_w[index_delay_r[2]%16 + 4] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16+4]  :  sram_data_out[new_x];
						//$display("%d %d %d %d",index_delay_r[2], new_x, new_y_delay2, sram_data_out[new_x]);
					end 
					if (new_x < MAP_COL - 3) begin
						i_r_w[index_delay_r[2]%16 + 3] = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16+3]  :  sram_data_out[(new_x+3+4)%8];
						i_r_w[index_delay_r[2]%16 + 7] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16+7]  :  sram_data_out[new_x + 3   ];
					end
					
					i_r_w[index_delay_r[2]%16 + 1] = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16 + 1]  :  sram_data_out[(new_x+1+4)%8];
					i_r_w[index_delay_r[2]%16 + 2] = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16 + 2]  :  sram_data_out[(new_x+2+4)%8];
					i_r_w[index_delay_r[2]%16 + 5] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16 + 5]  :  sram_data_out[new_x + 1];
					i_r_w[index_delay_r[2]%16 + 6] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16 + 6]  :  sram_data_out[new_x + 2];
				end
			end
		end
		SOBER_NMS: begin
			i_r_w[0]  = i_r[0] ;
			i_r_w[1]  = i_r[1] ;
			i_r_w[2]  = i_r[2] ;
			i_r_w[3]  = i_r[3] ;
			i_r_w[4]  = i_r[4] ;
			i_r_w[5]  = i_r[5] ;
			i_r_w[6]  = i_r[6] ;
			i_r_w[7]  = i_r[7] ;
			i_r_w[8]  = i_r[8] ;
			i_r_w[9]  = i_r[9] ;
			i_r_w[10] = i_r[10];
			i_r_w[11] = i_r[11];
			i_r_w[12] = i_r[12];
			i_r_w[13] = i_r[13];
			i_r_w[14] = i_r[14];
			i_r_w[15] = i_r[15];
			if(((sram_cen_r[1][1] == 0 && sram_wen_r[1][1] == 1) || (sram_cen_r[5][1] == 0 && sram_wen_r[5][1] == 1))) begin //SRAM READ 
				if(new_y_delay2%2 == 0) begin
					if(new_x >= (0)) begin
						i_r_w[index_delay_r[2]%16] =  sram_data_out[new_x];
						i_r_w[index_delay_r[2]%16 + 4] =  sram_data_out[(new_x+4)%8];
					end 
					if (new_x < MAP_COL - 3) begin
						i_r_w[index_delay_r[2]%16 + 3] =  sram_data_out[new_x + 3];
						i_r_w[index_delay_r[2]%16 + 7] =  sram_data_out[(new_x+3+4)%8];
					end
					
					i_r_w[index_delay_r[2]%16 + 1] =  sram_data_out[new_x + 1];
					i_r_w[index_delay_r[2]%16 + 2] =  sram_data_out[new_x + 2];
					i_r_w[index_delay_r[2]%16 + 5] =  sram_data_out[(new_x+1+4)%8];
					i_r_w[index_delay_r[2]%16 + 6] =  sram_data_out[(new_x+2+4)%8];
				end
				else begin
					if(new_x >= (0)) begin
						i_r_w[index_delay_r[2]%16]     = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16]  :  sram_data_out[(new_x+4)%8];
						i_r_w[index_delay_r[2]%16 + 4] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16+4]  :  sram_data_out[new_x];
						//$display("%d %d %d %d",index_delay_r[2], new_x, new_y_delay2, sram_data_out[new_x]);
					end 
					if (new_x < MAP_COL - 3) begin
						i_r_w[index_delay_r[2]%16 + 3] = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16+3]  :  sram_data_out[(new_x+3+4)%8];
						i_r_w[index_delay_r[2]%16 + 7] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16+7]  :  sram_data_out[new_x + 3   ];
					end
					
					i_r_w[index_delay_r[2]%16 + 1] = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16 + 1]  :  sram_data_out[(new_x+1+4)%8];
					i_r_w[index_delay_r[2]%16 + 2] = new_y_delay2 < (0) ? i_r_w[index_delay_r[2]%16 + 2]  :  sram_data_out[(new_x+2+4)%8];
					i_r_w[index_delay_r[2]%16 + 5] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16 + 5]  :  sram_data_out[new_x + 1];
					i_r_w[index_delay_r[2]%16 + 6] = new_y_delay2 >= MAP_ROW-2 ? i_r_w[index_delay_r[2]%16 + 6]  :  sram_data_out[new_x + 2];
				end
			end
		end
		default: begin
			i_r_w[0]  = 0;
			i_r_w[1]  = 0;
			i_r_w[2]  = 0;
			i_r_w[3]  = 0;
			i_r_w[4]  = 0;
			i_r_w[5]  = 0;
			i_r_w[6]  = 0;
			i_r_w[7]  = 0;
			i_r_w[8]  = 0;
			i_r_w[9]  = 0;
			i_r_w[10] = 0;
			i_r_w[11] = 0;
			i_r_w[12] = 0;
			i_r_w[13] = 0;
			i_r_w[14] = 0;
			i_r_w[15] = 0;
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
			if (convolution_reading_done) begin
				next_state = CONV_DISPLAY;
			end
			else begin
				next_state = CONV_CALC;
			end
		end
		CONV_DISPLAY: begin
			if (convolution_display_done) begin
				next_state = FETCH;
			end
			else begin
				next_state = CONV_DISPLAY;
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
			if (sober_nms_done) begin
				next_state = FETCH;
			end
			else begin
				next_state = SOBER_NMS;
			end
		end
		IDLE       : begin
			next_state = IDLE;
		end
		default	   : next_state = IDLE;
	endcase	
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
// State transition
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state <= FETCH;
	end else
		state <= next_state;
end
 
//sram_data_udpate
generate
for(SRAM_inst=0; SRAM_inst<NUM_SRAM; SRAM_inst=SRAM_inst+1) begin: sram_data_udpate 
	always @( posedge i_clk or negedge i_rst_n) begin
		if(~i_rst_n) begin
			sram_data_r[SRAM_inst] <= 0;
		end else
			sram_data_r[SRAM_inst] <= sram_data_w[SRAM_inst];
	end
end
endgenerate


//sram_data_udpate
generate
for(SRAM_inst=0; SRAM_inst<NUM_SRAM; SRAM_inst=SRAM_inst+1) begin: sram_cen_wen_udpate 
	always @( posedge i_clk or negedge i_rst_n) begin
		if(~i_rst_n) begin
			sram_cen_r[SRAM_inst]  <= 3'b111;
			//sram_cen_w[SRAM_inst]  <= 1;
			sram_wen_r[SRAM_inst]  <= 3'b000;
			//sram_wen_w[SRAM_inst]  <= 0;
		end else begin
			sram_wen_r[SRAM_inst][0] <= sram_wen_w[SRAM_inst];
			sram_wen_r[SRAM_inst][1] <= sram_wen_r[SRAM_inst][0];
			sram_wen_r[SRAM_inst][2] <= sram_wen_r[SRAM_inst][1];
			sram_cen_r[SRAM_inst][0] <= sram_cen_w[SRAM_inst];
			sram_cen_r[SRAM_inst][1] <= sram_cen_r[SRAM_inst][0];
			sram_cen_r[SRAM_inst][2] <= sram_cen_r[SRAM_inst][1];
		end
	end
end
endgenerate
// Store current instruction
/* always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		o_in_ready_r  <= 0;
	end else
		o_in_ready_r  <= o_in_ready_w ;
end
 */
always @( posedge i_clk) begin
	convolution_reading_done_r  <= convolution_reading_done_w ;
	convolution_display_done_r  <= convolution_display_done_w ;
end
// Store current sram address in last 2 cycle
generate
	for(SRAM_inst = 0; SRAM_inst < NUM_SRAM; SRAM_inst = SRAM_inst + 1) begin:SRAM_loop1
		always @( posedge i_clk or negedge i_rst_n) begin
			if(~i_rst_n) begin
				sram_addr_delay_r[SRAM_inst][0] <= 0;
				sram_addr_delay_r[SRAM_inst][1] <= 0;
				sram_addr_delay_r[SRAM_inst][2] <= 0;
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
	end
	else begin
		index_delay_r[0] <= index_delay_w;
		index_delay_r[1] <= index_delay_r[0];
		index_delay_r[2] <= index_delay_r[1];
	end
end

// Counter increment
always @( posedge i_clk) begin
	if(state == LOAD_MAP || state == DISPLAY)
		cnt <= cnt + 1;
	else
		cnt <= 0;
end
//input for med filter and sober nms udpate
generate
for(i=0; i<16; i=i+1) begin: med_filter_sober_data_udpate 
	always @( posedge i_clk) begin
		i_r[i] <= i_r_w[i];
	end
end
endgenerate

// Output data
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		out_data_r <= 0;
	end
	else begin
		out_data_r <= out_data_w;
	end
end

// Output data valid
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		out_valid_delay_r <= 3'b00;
		out_valid_r <= 0;
	end
	else begin
		//out_valid_r <= {out_valid_r[2:1], out_valid_w};
		out_valid_delay_r[0] <= out_valid_delay_w;
		out_valid_delay_r[1] <= out_valid_delay_r[0];
		out_valid_delay_r[2] <= out_valid_delay_r[1];
		out_valid_r <= out_valid_w;
	end
end

// Output data valid
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		out_data_sram_index_r[0] <= 0;
		out_data_sram_index_r[1] <= 0;
		out_data_sram_index_r[2] <= 0;
	end
	else begin
		out_data_sram_index_r[0] <= out_data_sram_index_w;
		out_data_sram_index_r[1] <= out_data_sram_index_r[0];
		out_data_sram_index_r[2] <= out_data_sram_index_r[1];
	end
end

// Accumlate sum for convolution
always @( posedge i_clk) begin
	conv_partial_sum_r[0]  <= conv_partial_sum_w[0] ;
	conv_partial_sum_r[1]  <= conv_partial_sum_w[1] ;
	conv_partial_sum_r[2]  <= conv_partial_sum_w[2] ;
	conv_partial_sum_r[3]  <= conv_partial_sum_w[3] ;
	conv_partial_sum_r[4]  <= conv_partial_sum_w[4] ;
	conv_partial_sum_r[5]  <= conv_partial_sum_w[5] ;
	conv_partial_sum_r[6]  <= conv_partial_sum_w[6] ;
	conv_partial_sum_r[7]  <= conv_partial_sum_w[7] ;
	conv_partial_sum_r[8]  <= conv_partial_sum_w[8] ;
	conv_partial_sum_r[9]  <= conv_partial_sum_w[9] ;
	conv_partial_sum_r[10] <= conv_partial_sum_w[10];
	conv_partial_sum_r[11] <= conv_partial_sum_w[11];
	conv_partial_sum_r[12] <= conv_partial_sum_w[12];
	conv_partial_sum_r[13] <= conv_partial_sum_w[13];
	conv_partial_sum_r[14] <= conv_partial_sum_w[14];
	conv_partial_sum_r[15] <= conv_partial_sum_w[15];
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

// Output counter
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		activate_median_filter_r <= 3'b000;
		activate_sobel_nms_r <= 4'b0000;
	end
	else begin
		activate_median_filter_r <= {activate_median_filter_r[2:0], activate_median_filter_w};
		activate_sobel_nms_r <= {activate_sobel_nms_r[3:0], activate_sobel_nms_w};
	end
end
assign activate_median_filter = activate_median_filter_r[0];
assign activate_sobel_nms     = activate_sobel_nms_r[0]; 


// Delay coordinate
always @( posedge i_clk) begin
	new_y_delay1 <= new_y;
	new_y_delay2 <= new_y_delay1;
	new_x_delay1 <= new_x;
	new_x_delay2 <= new_x_delay1;
end


// Store input data for median filter and sobel nms module
/* always @( posedge i_clk or negedge i_rst_n) begin
	
end */

//assign in_valid = index_delay_r[2]%16 

// Accumlate sum for convolution
/* always @( posedge i_clk or negedge i_rst_n) begin
	
end
 */



// Sram chip enable and write enable pins
/* always @( posedge i_clk or negedge i_rst_n) begin
	
end */


// Origin transition
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		origin_index_x_r <= 0;
		origin_index_y_r <= 0;
	end else begin
		origin_index_x_r <= origin_index_x_w;
		origin_index_y_r <= origin_index_y_w;
	end
end

// Depth transition
always @( posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		depth_r <= 32;
	end else begin
		depth_r <= depth_w;
	end
end
endmodule




module median_filter_submodule(
    input wire [7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9,
	input wire clk,
    output wire [7:0] median
);

	// Internal wires to hold the sorted values
	wire [7:0] sorted [0:8];

	// sorted vertically
	reg [7:0] a1, a2, a3, a4, a5, a6, a7, a8, a9;
	wire a14;
	wire a17;
	wire a47;
	wire a25;
	wire a28;
	wire a58;
	wire a36;
	wire a39;
	wire a68;
	
	
	assign a14 = (p1 < p4);
	assign a17 = (p1 < p7);
	assign a47 = (p4 < p7);
	assign a25 = (p2 < p5);
	assign a28 = (p2 < p8);
	assign a58 = (p5 < p8);
	assign a36 = (p3 < p6);
	assign a39 = (p3 < p9);
	assign a69 = (p6 < p9);
	
	always @(posedge clk) begin
		case({a14,a17,a47})
			3'b000: begin //3 2 1
				a1 <= p1;
				a4 <= p4;
				a7 <= p7;
			end
			3'b001: begin //3 1 2
				a1 <= p1;
				a4 <= p7;
				a7 <= p4;
			end
			3'b011:  begin //2 1 3
				a1 <= p7;
				a4 <= p1;
				a7 <= p4;
			end
			3'b100:  begin //2 3 1
				a1 <= p4;
				a4 <= p1;
				a7 <= p7;
			end
			3'b110: begin //1 3 2
				a1 <= p4;
				a4 <= p7;
				a7 <= p1;
			end
			3'b111: begin //1 2 3
				a1 <= p7;
				a4 <= p4;
				a7 <= p1;
			end
			default: begin
				a1 <= p1;
				a4 <= p4;
				a7 <= p7;
			end
		endcase
		
		case({a25,a28,a58})
			3'b000: begin //3 2 1
				a2 <= p2;
				a5 <= p5;
				a8 <= p8;
			end
			3'b001: begin //3 1 2
				a2 <= p2;
				a5 <= p8;
				a8 <= p5;
			end
			3'b011:  begin //2 1 3
				a2 <= p8;
				a5 <= p2;
				a8 <= p5;
			end
			3'b100:  begin //2 3 1
				a2 <= p5;
				a5 <= p2;
				a8 <= p8;
			end
			3'b110: begin //1 3 2
				a2 <= p5;
				a5 <= p8;
				a8 <= p2;
			end
			3'b111: begin //1 2 3
				a2 <= p8;
				a5 <= p5;
				a8 <= p2;
			end
			default: begin
				a2 <= p2;
				a5 <= p5;
				a8 <= p8;
			end
		endcase
		case({a36,a39,a69})
			3'b000: begin //3 2 1
				a3 <= p3;
				a6 <= p6;
				a9 <= p9;
			end
			3'b001: begin //3 1 2
				a3 <= p3;
				a6 <= p9;
				a9 <= p6;
			end
			3'b011:  begin //2 1 3
				a3 <= p9;
				a6 <= p3;
				a9 <= p6;
			end
			3'b100:  begin //2 3 1
				a3 <= p6;
				a6 <= p3;
				a9 <= p9;
			end
			3'b110: begin //1 3 2
				a3 <= p6;
				a6 <= p9;
				a9 <= p3;
			end
			3'b111: begin //1 2 3
				a3 <= p9;
				a6 <= p6;
				a9 <= p3;
			end
			default: begin
				a3 <= p3;
				a6 <= p6;
				a9 <= p9;
			end
		endcase
	end
	
	// sorted vertically
	reg [7:0] b1, b2, b3, b4, b5, b6, b7, b8, b9;
	wire b13;
	wire b12;
	wire b23;
	wire b46;
	wire b45;
	wire b56;
	wire b78;
	wire b79;
	wire b89;
	
	
	assign b13 = (a1 < a3);
	assign b12 = (a1 < a2);
	assign b23 = (a2 < a3);
	assign b46 = (a4 < a6);
	assign b45 = (a4 < a5);
	assign b56 = (a5 < a6);
	assign b78 = (a7 < a8);
	assign b79 = (a7 < a9);
	assign b89 = (a8 < a9);
	

	always @(posedge clk) begin
		case({b12,b13,b23})
			3'b000: begin //3 2 1
				b1 <= a3;
			end
			3'b001: begin //3 1 2
				b1 <= a2;
			end
			3'b011:  begin //2 1 3
				b1 <= a2;
			end
			3'b100:  begin //2 3 1
				b1 <= a3;
			end
			3'b110: begin //1 3 2
				b1 <= a1;
			end
			3'b111: begin //1 2 3
				b1 <= a1;
			end
			default: begin
				b1 <= a1;
			end
		endcase
		
		case({b45,b46,b56})
			3'b000: begin //3 2 1
				b5 <= a5;
			end
			3'b001: begin //3 1 2
				b5 <= a6;
			end
			3'b011:  begin //2 1 3
				b5 <= a4;
			end
			3'b100:  begin //2 3 1
				b5 <= a4;
			end
			3'b110: begin //1 3 2
				b5 <= a6;
			end
			3'b111: begin //1 2 3
				b5 <= a5;
			end
			default: begin
				b5 <= a5;
			end
		endcase
		
		case({b78,b79,b89})
			3'b000: begin //3 2 1
				b9 <= a7;
			end
			3'b001: begin //3 1 2
				b9 <= a7;
			end
			3'b011:  begin //2 1 3
				b9 <= a9;
			end
			3'b100:  begin //2 3 1
				b9 <= a8;
			end
			3'b110: begin //1 3 2
				b9 <= a8;
			end
			3'b111: begin //1 2 3
				b9 <= a9;
			end
			default: begin
				b9 <= a7;
			end
		endcase
	end

	// sorted diagonally
	reg [7:0] c1, c2, c3;
	wire c13;
	wire c12;
	wire c23;
	
	assign c13 = (b1 < b9);
	assign c12 = (b1 < b5);
	assign c23 = (b5 < b9);


	always @(posedge clk) begin
		case({c12,c13,c23})
			3'b000: begin //3 2 1
				c2 <= b5;
			end
			3'b001: begin //3 1 2
				c2 <= b9;
			end
			3'b011:  begin //2 1 3
				c2 <= b1;
			end
			3'b100:  begin //2 3 1
				c2 <= b1;
			end
			3'b110: begin //1 3 2
				c2 <= b9;
			end
			3'b111: begin //1 2 3
				c2 <= b5;
			end
			default: begin
				c2 <= b5;
			end
		endcase
		
		
	end
	
	
	// Finding the median value (middle value in sorted list)
	assign median = c2;

endmodule

module median_filter(
	input signed[7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16,
	input clk,
	input i_in_valid,
	output [7:0] median3,
	output [7:0] median2,
	output [7:0] median1,
	output [7:0] median0
);
	reg [7:0] pixels[15:0];
	wire [7:0] sub_median[3:0];
	always @(posedge clk) begin
		if (i_in_valid) begin
			pixels[0]  <= p1;
			pixels[1]  <= p2;
			pixels[2]  <= p3;
			pixels[3]  <= p4;
			pixels[4]  <= p5;
			pixels[5]  <= p6;
			pixels[6]  <= p7;
			pixels[7]  <= p8;
			pixels[8]  <= p9;
			pixels[9]  <= p10;
			pixels[10] <= p11;
			pixels[11] <= p12;
			pixels[12] <= p13;
			pixels[13] <= p14;
			pixels[14] <= p15;
			pixels[15] <= p16;
		end else begin
			pixels[0]  <= pixels[0] ;
			pixels[1]  <= pixels[1] ;
			pixels[2]  <= pixels[2] ;
			pixels[3]  <= pixels[3] ;
			pixels[4]  <= pixels[4] ;
			pixels[5]  <= pixels[5] ;
			pixels[6]  <= pixels[6] ;
			pixels[7]  <= pixels[7] ;
			pixels[8]  <= pixels[8] ;
			pixels[9]  <= pixels[9] ;
			pixels[10] <= pixels[10];
			pixels[11] <= pixels[11];
			pixels[12] <= pixels[12];
			pixels[13] <= pixels[13];
			pixels[14] <= pixels[14];
			pixels[15] <= pixels[15];
		end
	end
	median_filter_submodule u_submodule_inst0 (pixels[10], pixels[9], pixels[8] , pixels[6] , pixels[5] , pixels[4] , pixels[2], pixels[1], pixels[0], clk,   sub_median[0]);
	median_filter_submodule u_submodule_inst1 (pixels[11], pixels[10], pixels[9], pixels[7] , pixels[6] , pixels[5] , pixels[3], pixels[2], pixels[1], clk,   sub_median[1]);
	median_filter_submodule u_submodule_inst2 (pixels[14], pixels[13], pixels[12], pixels[10], pixels[9], pixels[8] , pixels[6], pixels[5], pixels[4], clk,   sub_median[2]);
	median_filter_submodule u_submodule_inst3 (pixels[15], pixels[14], pixels[13], pixels[11], pixels[10], pixels[9], pixels[7], pixels[6], pixels[5], clk,   sub_median[3]);
	
	assign median3 = sub_median[3];
	assign median2 = sub_median[2];
	assign median1 = sub_median[1];
	assign median0 = sub_median[0];
endmodule


module sobel_nms(
    input signed[7:0] p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16,
	input clk,
	input i_in_valid,
	output [13:0] sobel_nms3,
	output [13:0] sobel_nms2,
	output [13:0] sobel_nms1,
	output [13:0] sobel_nms0
);
	localparam angle0   = 2'd0;
	localparam angle45  = 2'd1;
	localparam angle90  = 2'd2;
	localparam angle135 = 2'd3;
	
    wire [7:0] sorted[8:0];
    reg  [13:0] G[3:0],Gnms[3:0] ;
	reg signed [20:0]  tan[3:0];
	reg signed [20:0]  Gx[3:0], Gx1[3:0], Gy[3:0], Gy7[3:0], Gx_abs[3:0], Gy_abs[3:0];
	reg [1:0] angle[3:0];
	wire [1:0] a0, a1, a2, a3;
	wire [13:0] g0, g1, g2, g3;
	wire signed [20:0] gx1, gy1;

    // Store the input pixels in an array for easier sorting
    reg [7:0] pixels[15:0];
	always @(posedge clk) begin
		if (i_in_valid) begin
			pixels[0]  <= p1;
			pixels[1]  <= p2;
			pixels[2]  <= p3;
			pixels[3]  <= p4;
			pixels[4]  <= p5;
			pixels[5]  <= p6;
			pixels[6]  <= p7;
			pixels[7]  <= p8;
			pixels[8]  <= p9;
			pixels[9]  <= p10;
			pixels[10] <= p11;
			pixels[11] <= p12;
			pixels[12] <= p13;
			pixels[13] <= p14;
			pixels[14] <= p15;
			pixels[15] <= p16;
		end else begin
			pixels[0]  <= pixels[0] ;
			pixels[1]  <= pixels[1] ;
			pixels[2]  <= pixels[2] ;
			pixels[3]  <= pixels[3] ;
			pixels[4]  <= pixels[4] ;
			pixels[5]  <= pixels[5] ;
			pixels[6]  <= pixels[6] ;
			pixels[7]  <= pixels[7] ;
			pixels[8]  <= pixels[8] ;
			pixels[9]  <= pixels[9] ;
			pixels[10] <= pixels[10];
			pixels[11] <= pixels[11];
			pixels[12] <= pixels[12];
			pixels[13] <= pixels[13];
			pixels[14] <= pixels[14];
			pixels[15] <= pixels[15];
		end
	end
	
	always @(posedge clk) begin
		Gx[0] <= pixels[0]* $signed(-21'd1) + pixels[0+4]* $signed(-21'd2) + pixels[0+8]* $signed(-21'd1) + pixels[0+2]* $signed(21'd1) + pixels[0+6]* $signed(21'd2) + pixels[0+10]* $signed(21'd1);
		Gy[0] <= pixels[0]* $signed(-21'd1) + pixels[0+1]* $signed(-21'd2) + pixels[0+2]* $signed(-21'd1) + pixels[0+8]* $signed(21'd1) + pixels[0+9]* $signed(21'd2) + pixels[0+10]* $signed(21'd1);
		Gx[1] <= pixels[1]* $signed(-21'd1) + pixels[1+4]* $signed(-21'd2) + pixels[1+8]* $signed(-21'd1) + pixels[1+2]* $signed(21'd1) + pixels[1+6]* $signed(21'd2) + pixels[1+10]* $signed(21'd1);
		Gy[1] <= pixels[1]* $signed(-21'd1) + pixels[1+1]* $signed(-21'd2) + pixels[1+2]* $signed(-21'd1) + pixels[1+8]* $signed(21'd1) + pixels[1+9]* $signed(21'd2) + pixels[1+10]* $signed(21'd1);
		Gx[2] <= pixels[2+2]* $signed(-21'd1) + pixels[2+6]* $signed(-21'd2) + pixels[2+10]* $signed(-21'd1) + pixels[2+4]* $signed(21'd1)  + pixels[2+8]* $signed(21'd2)  + pixels[2+12]* $signed(21'd1);
		Gy[2] <= pixels[2+2]* $signed(-21'd1) + pixels[2+3]* $signed(-21'd2) + pixels[2+4]* $signed(-21'd1)  + pixels[2+10]* $signed(21'd1) + pixels[2+11]* $signed(21'd2) + pixels[2+12]* $signed(21'd1);
		Gx[3] <= pixels[3+2]* $signed(-21'd1) + pixels[3+6]* $signed(-21'd2) + pixels[3+10]* $signed(-21'd1) + pixels[3+4]* $signed(21'd1)  + pixels[3+8]* $signed(21'd2)  + pixels[3+12]* $signed(21'd1);
		Gy[3] <= pixels[3+2]* $signed(-21'd1) + pixels[3+3]* $signed(-21'd2) + pixels[3+4]* $signed(-21'd1)  + pixels[3+10]* $signed(21'd1) + pixels[3+11]* $signed(21'd2) + pixels[3+12]* $signed(21'd1);
		
		
	end
	
	genvar i;
	
	
	generate
		for(i = 0; i < 4; i = i + 1) begin: sober_nms_loop0
			always @(posedge clk) begin
				Gx_abs[i] <= Gx[i][20] == 1 ?  ~Gx[i] + 1 : Gx[i];
				Gy_abs[i] <= Gy[i][20] == 1 ?  ~Gy[i] + 1 : Gy[i];
				
				Gy7[i] <= Gy[i] <<< 7;
				Gx1[i] <= Gx[i];
			end
		end
	endgenerate
	
	
	// Determine angle
	generate
		for(i = 0; i < 4; i = i + 1) begin: sober_nms_loop1
			always @(posedge clk) begin
				if (Gx1[i][20] ^ Gy7[i][20] == 1) begin
					if (Gx1[i] == 0 || Gy7[i]/Gx1[i] < $signed(-21'd309))
						angle[i] <= angle90;
					else if (Gy7[i]/Gx1[i] < $signed(-21'd53))
						angle[i] <= angle135;
					else
						angle[i] <= angle0;
				end
				else begin
					if (Gy7[i]/Gx1[i] < $signed(21'd53)) begin
						angle[i] <= angle0;
						//$display("%d %d %d ", Gx[i],Gy[i],Gx[i]/Gy[i]);
					end
					else if (Gy7[i]/Gx1[i] < $signed(21'd309))
						angle[i] <= angle45;
					else if (Gx1[i] == 0)
						angle[i] <= angle90;
					else
						angle[i] <= angle90;
				end
				
				G[i] <= Gx_abs[i] + Gy_abs[i];
			end
        end
	endgenerate
	
	generate
		for (i = 0; i < 2; i = i + 1) begin: sober_nms_loop2
			always @(posedge clk) begin
				case(angle[i])
					angle0: begin
						if(G[i] < G[(i+1)%2])
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
					end
					angle45: begin
						if(i==0 && G[i] < G[3])
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
					end
					angle90: begin
						if(G[i] < G[i+2])
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
					end
					angle135: begin
						if(i==1 && G[i] < G[2])
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
					end
					default: Gnms[i] <= 0;
				endcase
			end
		end
	endgenerate
	
	generate
		for (i = 2; i < 4; i = i + 1) begin: sober_nms_loop3
			always @(posedge clk) begin
				case(angle[i])
					angle0: begin
						if((i == 2 && G[i] < G[3]) ||(i == 3 && G[i] < G[2]) )
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
					end
					angle45: begin
						
						if(i==3 && G[i] < G[0])
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
						//$display("%d %d %d", Gnms[i] , G[i], G[0]);
					end
					angle90: begin
						if(G[i] < G[i-2])
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
					end
					angle135: begin
						if(i==2 && G[i] < G[1])
							Gnms[i] <= 0;
						else 
							Gnms[i] <= G[i];
					end
					default: Gnms[i] <= 0;
				endcase
			end
		end
	endgenerate
	
    assign sobel_nms0 = Gnms[0];  
	assign sobel_nms1 = Gnms[1]; 
	assign sobel_nms2 = Gnms[2]; 
	assign sobel_nms3 = Gnms[3]; 
endmodule
 
