module alu #(
    parameter INT_W  = 9,
    parameter FRAC_W = 23,
    parameter INST_W = 6,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                     i_clk,
    input                     i_rst_n,
	input                     alu_en,
    input signed [DATA_W-1:0] i_data_a,
    input signed [DATA_W-1:0] i_data_b,
    input        [INST_W-1:0] i_inst,
    output                    o_valid,
    output                    o_busy,
    output       [DATA_W-1:0] o_data,
	output       			  o_cond,
	output       			  ovf
);

    //B0 : reset: : busy and not valid
    //B1 : 1st cycle after reset: not busy and not valid
    //B2 : conseductive state of B1 and B2 : busy and not valid
    //B3 : conseductive state of B2: not busy and valid
    parameter B0 = 0, B1 = 1, B2 = 2, B3 = 3;

    // Instruction maskin
    // Common registers
    reg [1:0] curr_state, next_state;
    reg [DATA_W-1:0] ans, old;
	reg w_cond;
    reg locked;
	reg w_ovf;
    //Combinational logic
    always @ (*) begin
		w_ovf = 0;
        case (i_inst)
            `OP_ADD    : begin 
				ans = add(i_data_a, i_data_b);
				if ( (ans[31] != i_data_a[31]) && (i_data_a[31] == i_data_b[31]))
					w_ovf = 1;
			end
			
            `OP_SUB    : begin 
				ans = add(i_data_a, ~i_data_b + 1);
				if ( (ans[31] != i_data_a[31]) && (i_data_a[31] != i_data_b[31]))
					w_ovf = 1;
			end
			
            `OP_MUL    : begin
				ans = mul(i_data_a, i_data_b);
				
				if (ans[31] != (i_data_a[31] ^ i_data_b[31])) begin
					w_ovf = 1;
            end
        end
            `OP_ADDI   : begin 
				ans = add(i_data_a, i_data_b);
				if ( (ans[31] != i_data_a[31]) && (i_data_a[31] == i_data_b[31])) begin
					w_ovf = 1;
				end
			end
            `OP_LW     : begin 
				ans = add(i_data_a, i_data_b);
				if ( (ans[31] == 1) || ( (ans[31] != i_data_a[31]) && (i_data_a[31] == i_data_b[31])) || ans > 255)
					w_ovf = 1;
			end
            `OP_SW     : begin 
				ans = add(i_data_a, i_data_b);
				if ( (ans[31] == 1) || ( (ans[31] != i_data_a[31]) && (i_data_a[31] == i_data_b[31])) || ans > 255) begin
					w_ovf = 1;
				end
			end
            `OP_AND    : ans = i_data_a & i_data_b;
            `OP_OR     : ans = i_data_a | i_data_b;
            `OP_NOR    : ans = ~(i_data_a | i_data_b);
            `OP_BEQ    : ans = add(i_data_a, ~i_data_b + 1);
			`OP_BNE    :	ans = add(i_data_a, ~i_data_b + 1);
			`OP_SLT    :	ans = slt(i_data_a, i_data_b);
			`OP_FP_ADD :	ans = fp_add(i_data_a, i_data_b);
			`OP_FP_SUB : 	ans = fp_add(i_data_a, {~i_data_b[DATA_W-1] , i_data_b[DATA_W-2:0]});
			`OP_FP_MUL :	ans = fp_mul(i_data_a, i_data_b);
			`OP_SLL    : ans = i_data_a << i_data_b;
			`OP_SRL    : ans = i_data_a >> i_data_b;
			`OP_EOF    :	ans = 16'bxxxxxxxxxxxxxxxx;
            default: ans = 16'bxxxxxxxxxxxxxxxx;
        endcase
		
    end

    function[DATA_W-1:0] add;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
    begin
        add = i_data_a+i_data_b;
    end
    endfunction


    function [DATA_W-1:0] mul;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
    reg   signed [DATA_W*2-1:0] direct_mult;
    begin
        direct_mult = i_data_a*i_data_b;
        mul = direct_mult[31: 0];
    end
    endfunction
	
	
	//Count leading zeros
    function[5:0] count_leading_zeros48;
    input signed [FRAC_W*2+1:0]     i_data_a;
    begin
        casex(i_data_a)
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000: count_leading_zeros48 = 47;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001: count_leading_zeros48 = 46;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_001x: count_leading_zeros48 = 45;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_01xx: count_leading_zeros48 = 44;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1xxx: count_leading_zeros48 = 43;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_xxxx: count_leading_zeros48 = 42;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_001x_xxxx: count_leading_zeros48 = 41;
		48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_01xx_xxxx: count_leading_zeros48 = 40;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1xxx_xxxx: count_leading_zeros48 = 39;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_0001_xxxx_xxxx: count_leading_zeros48 = 38;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_001x_xxxx_xxxx: count_leading_zeros48 = 37;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_01xx_xxxx_xxxx: count_leading_zeros48 = 36;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0000_1xxx_xxxx_xxxx: count_leading_zeros48 = 35;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_0001_xxxx_xxxx_xxxx: count_leading_zeros48 = 34;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_001x_xxxx_xxxx_xxxx: count_leading_zeros48 = 33;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_01xx_xxxx_xxxx_xxxx: count_leading_zeros48 = 32;
        48'bx000_0000_0000_0000_0000_0000_0000_0000_1xxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 31;
        48'bx000_0000_0000_0000_0000_0000_0000_0001_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 30;
        48'bx000_0000_0000_0000_0000_0000_0000_001x_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 29;
        48'bx000_0000_0000_0000_0000_0000_0000_01xx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 28;
        48'bx000_0000_0000_0000_0000_0000_0000_1xxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 27;
        48'bx000_0000_0000_0000_0000_0000_0001_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 26;
        48'bx000_0000_0000_0000_0000_0000_001x_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 25;
        48'bx000_0000_0000_0000_0000_0000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 24;
        48'bx000_0000_0000_0000_0000_0000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 23;
        48'bx000_0000_0000_0000_0000_0001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 22;
        48'bx000_0000_0000_0000_0000_001x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 21;
        48'bx000_0000_0000_0000_0000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 20;
        48'bx000_0000_0000_0000_0000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 19;
        48'bx000_0000_0000_0000_0001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 18;
        48'bx000_0000_0000_0000_001x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 17;
        48'bx000_0000_0000_0000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 16;
        48'bx000_0000_0000_0000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 15;
        48'bx000_0000_0000_0001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 14;
        48'bx000_0000_0000_001x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 13;
        48'bx000_0000_0000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 12;
        48'bx000_0000_0000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 11;
        48'bx000_0000_0001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 10;
		48'bx000_0000_001x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 09;
		48'bx000_0000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 08;
		48'bx000_0000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 07;
		48'bx000_0001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 06;
		48'bx000_001x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 05;
		48'bx000_01xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 04;
		48'bx000_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 03;
		48'bx001_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 02;
		48'bx01x_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 01;
		48'bx1xx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros48 = 00;
		default: count_leading_zeros48 =0;
        endcase
    end
    endfunction
	// Floating point a - b
    function[DATA_W-1:0] fp_add_amb;
    input signed [DATA_W-1:0]     i_data_a;
    input signed [DATA_W-1:0]     i_data_b;
    reg   [FRAC_W*2 +1 :0] mantissa_a, mantissa_b, mantissa_greater;
    reg    [INT_W - 2:0]          exp_a, exp_b, exp_greater;
    reg   [4:0]                   leading_zeros;
    reg                           s, flag;  //signed
    begin
        flag = 0;
        exp_a      = i_data_a[DATA_W-2 -:INT_W-1];
        exp_b      = i_data_b[DATA_W-2 -:INT_W-1];
        mantissa_a = {2'b01,i_data_a[FRAC_W-1 :0], 23'b0};
        mantissa_b = {2'b01,i_data_b[FRAC_W-1 :0], 23'b0};
        if (exp_a > exp_b ) begin
            exp_greater = exp_a;
            mantissa_greater = mantissa_a - (mantissa_b >> (exp_a-exp_b) );
            s = 0;
        end
        else if (exp_a < exp_b ) begin
            exp_greater = exp_b;
            mantissa_greater = mantissa_b - (mantissa_a >> (exp_b-exp_a) );
            s = 1;
        end
        else begin
            if (mantissa_a > mantissa_b) begin
                exp_greater = exp_a;
                mantissa_greater = mantissa_a - mantissa_b;
                s = 0;
            end
            else begin
                exp_greater = exp_b;
                mantissa_greater = mantissa_b - mantissa_a;
                s = 1;
            end
        end

        if (mantissa_greater[FRAC_W*2 + 1]) begin
            exp_greater = exp_greater + 1;
            mantissa_greater = mantissa_greater >> 1;
        end
        leading_zeros = count_leading_zeros48(mantissa_greater);
        mantissa_greater = mantissa_greater << leading_zeros;
        exp_greater = exp_greater - leading_zeros;
        if (leading_zeros == 47) begin 
            exp_greater = 0;
            s = 0;
        end
        exp_greater = exp_greater + mantissa_greater[FRAC_W*2 + 1];
        mantissa_greater = mantissa_greater + ((|mantissa_greater[FRAC_W-2:0] | (mantissa_greater[FRAC_W -:2] == 2'b11))  ? 1<<(FRAC_W-1) : 0);
        if (mantissa_greater[FRAC_W*2 + 1]) begin
            exp_greater = exp_greater + 1;
            mantissa_greater = mantissa_greater >> 1;
        end
        fp_add_amb = {s, exp_greater, mantissa_greater[FRAC_W*2-1 -:FRAC_W]};
    end
    endfunction

    function[DATA_W-1:0] fp_add_apb;
    input signed [DATA_W-1:0]     i_data_a;
    input signed [DATA_W-1:0]     i_data_b;
    reg    [FRAC_W*2 +1 :0]       mantissa_a, mantissa_b, mantissa_greater;
    reg    [INT_W - 2:0]          exp_a, exp_b, exp_greater;
    reg   [4:0]                   leading_zeros;
    reg                           s, flag;  //signed
    begin
        flag = 0;
        exp_a      = i_data_a[DATA_W-2 -:INT_W-1];
        exp_b      = i_data_b[DATA_W-2 -:INT_W-1];
        mantissa_a = {2'b01,i_data_a[FRAC_W-1 :0], 23'b0};
        mantissa_b = {2'b01,i_data_b[FRAC_W-1 :0], 23'b0};
        if (exp_a > exp_b ) begin
            exp_greater = exp_a;
            mantissa_greater = mantissa_a + (mantissa_b >> (exp_a-exp_b) );
            s = 0;
        end
        else  begin
            exp_greater = exp_b;
            mantissa_greater = mantissa_b + (mantissa_a >> (exp_b-exp_a) );
            s = 1;
        end
        if (mantissa_greater[FRAC_W*2 + 1]) begin
            exp_greater = exp_greater + 1;
            mantissa_greater = mantissa_greater >> 1;
            flag = 1;
        end
        leading_zeros = count_leading_zeros48(mantissa_greater);
        exp_greater = exp_greater + mantissa_greater[FRAC_W*2 + 1];
        mantissa_greater = mantissa_greater << leading_zeros;
        exp_greater = exp_greater - leading_zeros;
        mantissa_greater = mantissa_greater + ((|mantissa_greater[FRAC_W-2:0] | (mantissa_greater[FRAC_W -:2] == 2'b11))  ? 1<<(FRAC_W-1) : 0); //(1<<(FRAC_W-1));//
        if (mantissa_greater[FRAC_W*2 + 1]) begin
            exp_greater = exp_greater + 1;
            mantissa_greater = mantissa_greater >> 1;
        end
        fp_add_apb = {i_data_a[DATA_W-1], exp_greater, mantissa_greater[FRAC_W*2-1 -:FRAC_W]};
    end
    endfunction

	function[DATA_W-1:0] fp_add;
    input signed [DATA_W-1:0]     i_data_a;
    input signed [DATA_W-1:0]     i_data_b;

    begin
        if(i_data_a[DATA_W-1]) begin
            // a < 0, b < 0 => -(a + b)
            if(i_data_b[DATA_W-1]) begin
                fp_add = fp_add_apb(i_data_a, i_data_b);
            end
            else begin // a < 0, b > 0 => b - a
                fp_add = fp_add_amb(i_data_b, i_data_a);
            end
        end 
        else if (i_data_b[DATA_W-1]) begin
            // a > 0, b < 0 => a-b
            fp_add = fp_add_amb(i_data_a, i_data_b);
        end
        else begin // a > 0 ,b > 0 => a+b
            fp_add = fp_add_apb(i_data_a, i_data_b);
        end
    end
    endfunction
	
	function [DATA_W-1:0] fp_mul;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
	reg    [FRAC_W   :0]        mantissa_a, mantissa_b;
	reg    [FRAC_W-1   :0]        fp_mantissa_result_shifted;
	reg    [FRAC_W*2 + 1 :0]		mantissa;
    reg signed   [INT_W - 2:0]          exp_a, exp_b, exp;
    reg   [4:0]                   leading_zeros;
    reg                           s;  //signed
	reg Gbit, Rbit, sticky_bit, shift;
	
    begin
		mantissa_a = {2'b1,i_data_a[FRAC_W-1 :0]};
        mantissa_b = {2'b1,i_data_b[FRAC_W-1 :0]};
		exp = i_data_a[DATA_W-1 -:INT_W] + i_data_b[DATA_W-1 -:INT_W];
		mantissa = mantissa_a * mantissa_b;
		shift = 0;
		if (mantissa[47] == 1'b1) begin
			//$display("exp %b mantissa %b i_data_a %b i_data_b %b",exp,mantissa,  i_data_a,  i_data_b);
			fp_mantissa_result_shifted = mantissa[46:24];
			Gbit = mantissa[24];
			Rbit = mantissa[23];
			sticky_bit = (mantissa[22:0] != 0);
			shift = 1;
		end
		else begin
			fp_mantissa_result_shifted = mantissa[45:23];
			Gbit = mantissa[23];
			Rbit = mantissa[22];
			sticky_bit = (mantissa[21:0] != 0);
		end
		if (Rbit & ( sticky_bit | Gbit )) begin
			if (fp_mantissa_result_shifted == 24'b1111_1111_1111_1111_1111_1111 ) begin
				exp = i_data_a[30:23] + i_data_b[30:23] - 126;
			end
			else begin
				exp = i_data_a[30:23] + i_data_b[30:23] - 127;
			end
			fp_mantissa_result_shifted = fp_mantissa_result_shifted + 1;
		end
		else begin
			exp = i_data_a[30:23] + i_data_b[30:23] - 127;
		end
		exp = exp + shift;
		s = i_data_a[DATA_W-1]^ i_data_b[DATA_W-1];
        fp_mul = {s, exp, fp_mantissa_result_shifted};
    end
	
	
    endfunction
	
	function [DATA_W-1:0] slt;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
    reg   signed [DATA_W*2-1:0] direct_mult;
    begin
        direct_mult = i_data_a*i_data_b;
		if(i_data_a < i_data_b) 
			slt = 1;
		else
			slt = 0;
    end
    endfunction
	

    always @ (posedge i_clk) begin
        if(~i_rst_n) begin
            curr_state = B0;
            next_state = B1;
			old <=  0 ;
			w_ovf <= 0;
        end else begin
            curr_state = next_state;
            next_state = next_state == B3? next_state -1 : next_state + 1;
			old <= o_valid? ans : old;
			if (i_inst == 10 ) begin
				w_cond = (ans == 0);
			end else if (i_inst == 11 ) begin
				w_cond = (ans != 0);
			end
			else
				w_cond = 0;
		end
		
    end
	assign ovf = alu_en ? w_ovf : ovf;
	assign o_cond = w_cond;
    assign o_busy  = (curr_state == B0) || (curr_state == B2);
    assign o_valid = (curr_state == B3);
    assign o_data = ans;
endmodule