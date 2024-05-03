module alu #(
    parameter INT_W  = 6,
    parameter FRAC_W = 10,
    parameter INST_W = 4,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                     i_clk,
    input                     i_rst_n,
    input signed [DATA_W-1:0] i_data_a,
    input signed [DATA_W-1:0] i_data_b,
    input        [INST_W-1:0] i_inst,
    output                    o_valid,
    output                    o_busy,
    output       [DATA_W-1:0] o_data
);

    //B0 : reset: : busy and not valid
    //B1 : 1st cycle after reset: not busy and not valid
    //B2 : conseductive state of B1 and B2 : busy and not valid
    //B3 : conseductive state of B2: not busy and valid
    parameter B0 = 0, B1 = 1, B2 = 2, B3 = 3;

    // Instruction masking
    parameter FXADD = 4'b0000;
    parameter FXSUB = 4'b0001;
    parameter FXMUL = 4'b0010;
    parameter FXMAC = 4'b0011;
    parameter GELU  = 4'b0100;
    parameter CLZ   = 4'b0101;
    parameter LRCW  = 4'b0110;
    parameter LFSR  = 4'b0111;
    parameter FPADD = 4'b1000;
    parameter FPSUB = 4'b1001;

    // Common registers
    reg [1:0] curr_state, next_state;
    reg [DATA_W-1:0] ans;
    reg locked;

    //Combinational logic
    always @ (*) begin
        case (i_inst)
            FXADD: ans = fx_add(i_data_a, i_data_b);
            FXSUB: ans = fx_add(i_data_a, ~i_data_b + 1);
            FXMUL: ans = fx_mul(i_data_a, i_data_b);
            FXMAC: ans = fx_mac(i_data_a, i_data_b, ans);
            GELU:  ans = gelu(i_data_a);
            CLZ:   ans = clz(i_data_a);
            LRCW:  ans = lrcw(i_data_a, i_data_b);
            LFSR:  ans = lfsr(i_data_a, i_data_b);
            FPADD: ans = fp_add(i_data_a, i_data_b);
            FPSUB: ans = fp_add(i_data_a, {~i_data_b[DATA_W-1] , i_data_b[DATA_W-2:0]});
            default: ans = 16'bxxxxxxxxxxxxxxxx;
        endcase
    end

    function[DATA_W-1:0] fx_add;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
    reg   signed [DATA_W:0] tmp;
    begin
        tmp = i_data_a+i_data_b;
        if(tmp < $signed(17'b1_1000_0000_0000_0000) ) begin
            fx_add = 16'b1000_0000_0000_0000; 
        end
        else  if(tmp > $signed(17'b0_0111_1111_1111_1111) ) begin
            fx_add = 16'b0111_1111_1111_1111;
        end 
        else begin
            fx_add = tmp[DATA_W-1:0];
        end
    end
    endfunction


    function [DATA_W-1:0] fx_mul;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
    reg   signed [DATA_W*2-1:0] direct_mult;
    reg   [5:0] sticky;
    begin
        direct_mult = i_data_a*i_data_b;
        sticky = |direct_mult[FRAC_W-2 : 0];
        if (i_data_a == 16'b0010101100000000) begin
        $display("direct_mult: %b", direct_mult);
        end
        if (direct_mult < $signed(32'b11111110000000000000000000000000) ) begin
            fx_mul = 16'b1000000000000000;
        end else if (direct_mult > $signed(32'b00000001111111111111111111111111) ) begin
            fx_mul = 16'b0111111111111111;
        end
        else begin
            //direct_mult =  direct_mult +  ((sticky  || (direct_mult[FRAC_W -: 2] == 2'b11)) ?   (1 << (FRAC_W-1)) : 0);
            fx_mul = direct_mult[DATA_W*2-INT_W - 1 -:DATA_W] + ((sticky  || (direct_mult[FRAC_W -: 2] == 2'b11)) ?   (direct_mult[FRAC_W - 1]) : 0);
        end
        
    end
    endfunction

    function [DATA_W-1:0] fx_mac;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
    input signed [DATA_W-1:0] old_val;
    reg   signed [DATA_W*2-1:0] direct_mult;
    logic sticky;
    //reg signed   [DATA_W*2-1:0]    32bold_val; 
    begin
        direct_mult = i_data_a * i_data_b;
        direct_mult = direct_mult + {old_val[DATA_W-1] ? 6'b111111:6'b000000, old_val, 10'b0000000000};
        sticky = |direct_mult[FRAC_W-2 : 0];
        if (direct_mult < $signed(32'b11111110000000000000000000000000) ) begin
            fx_mac = 16'b1000000000000000;
        end else if (direct_mult > $signed(32'b00000001111111111111111111111111) ) begin
            fx_mac = 16'b0111111111111111;
        end
        else begin 
            fx_mac = direct_mult[DATA_W*2-INT_W - 1 -:DATA_W] + ((sticky  || (direct_mult[FRAC_W -: 2] == 2'b11)) ?   (direct_mult[FRAC_W - 1]) : 0);
        end
    end
    endfunction

    function [DATA_W-1:0] round_tanh_x;
    input signed [DATA_W-1:0] x;
    reg   signed [DATA_W*2-1:0] direct_mult, b_old_val;
    begin
        if (x < $signed(16'b1111101000000000)) begin   // x < -1.5
            round_tanh_x = $signed(16'b1111110000000000) ; // -1
        end
        else if (x < $signed(16'b1111111000000000))begin  // x < -0.5
            round_tanh_x = fx_add(x[0] ? x + 1 >> 1 : x >> 1, $signed(16'b1111111100000000));
        end
        else if (x < $signed(16'b0000001000000000))begin  // x < 0.5
            round_tanh_x = x;
        end
        else if (x < $signed(16'b0000011000000000))begin  // x < 1.5
            round_tanh_x = fx_add(x[0] ? x + 1 >> 1 : x >> 1, $signed(16'b0000000100000000));
        end
        else begin
            round_tanh_x = 16'b0000010000000000;
        end
    end
    endfunction


    function [DATA_W-1:0] gelu_first;
    input signed [DATA_W-1:0] x;
    reg   signed [DATA_W*5-1:0] direct_mult;
    reg   signed [DATA_W*2-1:0] x_square;
    reg   signed [DATA_W*3-1:0] minor;
    reg   signed [DATA_W-1:0] tmp_x;
    begin
        x_square = x*x;
        minor    = x_square*16'b0000000000101110;
        minor    = minor + (1<<(FRAC_W*3));
        direct_mult = minor*x;
        direct_mult = direct_mult*16'b0000001100110001;
        
        //$display("direct_mult %b", direct_mult);
        if (direct_mult < $signed(80'b111111_111111_111111_111111_100000_0000000000_0000000000_0000000000_0000000000_0000000000) ) begin
            gelu_first = 16'b1000000000000000;
        end else if (direct_mult > $signed(80'b000000_000000_000000_000000_011111_1111111111_1111111111_1111111111_1111111111_1111111111) ) begin
            gelu_first = 16'b0111111111111111;
        end
        else begin 
            direct_mult = direct_mult +  ( (|direct_mult[FRAC_W*4-2 : 0]  || (direct_mult[FRAC_W*4 -: 2] == 2'b11))  ?   (1 << (FRAC_W*4-1)) : 0);
            gelu_first =  direct_mult[DATA_W*5 - INT_W*4 -1 -: DATA_W];
        end
        
    end
    endfunction


    function [DATA_W-1:0] gelu;
    input signed [DATA_W-1:0] i_data_a;

    reg signed [DATA_W-1:0] first, second;
    reg signed [DATA_W*2-1:0]  third;
    begin
        
        first  = gelu_first(i_data_a);
        second = round_tanh_x(first);
        third  =  fx_add($signed(16'b0000_0100_0000_0000), second);
        third  = third*i_data_a;
        third  = third  >> 1;
        
        
        gelu   = third[25:10] + third[FRAC_W-1];//( (|third[FRAC_W-2: 0]  | (third[FRAC_W -: 2] == 2'b11))  ?   third[FRAC_W-1]: 0);
    end
    endfunction

    function [DATA_W-1:0] clz;
    input signed [DATA_W-1:0] i_data_a;
    begin
        casex (i_data_a[DATA_W-1:0] )
            16'b0000000000000000: clz = 16;
            16'b0000000000000001: clz = 15;
            16'b000000000000001x: clz = 14;
            16'b00000000000001xx: clz = 13;
            16'b0000000000001xxx: clz = 12;
            16'b000000000001xxxx: clz = 11;
            16'b00000000001xxxxx: clz = 10;
            16'b0000000001xxxxxx: clz = 09;
            16'b000000001xxxxxxx: clz = 08;
            16'b00000001xxxxxxxx: clz = 07;
            16'b0000001xxxxxxxxx: clz = 06;
            16'b000001xxxxxxxxxx: clz = 05;
            16'b00001xxxxxxxxxxx: clz = 04;
            16'b0001xxxxxxxxxxxx: clz = 03;
            16'b001xxxxxxxxxxxxx: clz = 02;
            16'b01xxxxxxxxxxxxxx: clz = 01;
            16'b1xxxxxxxxxxxxxxx: clz = 00;
            default: clz = 0;
        endcase
    end
    endfunction


    function [DATA_W-1:0] cpop;
    input signed [DATA_W-1:0] i_data_a;
    integer i, cnt;
    begin
        for( i = 0; i < DATA_W; i=i+1) begin
            if (i == 0) cnt = 0;
            if (i_data_a[0]) cnt++;
            i_data_a = i_data_a >> 1;
        end
        cpop = cnt;
    end
    endfunction

    function [DATA_W-1:0] lrcw;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;
    reg   signed [5:0] cpopa;
    
    begin
        cpopa = cpop(i_data_a);
        lrcw = (i_data_b << cpopa) | ~((i_data_b >> (DATA_W - cpopa)  | (16'hffff << cpopa)));
    end
    endfunction

    function [DATA_W-1:0] lfsr;
    input signed [DATA_W-1:0] i_data_a;
    input signed [DATA_W-1:0] i_data_b;

    reg xor1, xor2, xor3;
    
    begin
        for (integer i = 0; i < i_data_b; i = i + 1) begin
            xor1 = i_data_a[15] ^ i_data_a[13];
            xor2 =  i_data_a[12] ^ xor1;
            xor3 =  i_data_a[10] ^ xor2;
            i_data_a = (i_data_a << 1) | xor3;
        end
        lfsr = i_data_a;
    end
    endfunction

    //Count leading zeros
    function[5:0] count_leading_zeros22;
    input signed [FRAC_W*2+1:0]     i_data_a;
    begin
        casex(i_data_a)

        22'bx0_0000_0000_0000_0000_0000: count_leading_zeros22 = 21;
        22'bx0_0000_0000_0000_0000_0001: count_leading_zeros22 = 20;
        22'bx0_0000_0000_0000_0000_001x: count_leading_zeros22 = 19;
        22'bx0_0000_0000_0000_0000_01xx: count_leading_zeros22 = 18;
        22'bx0_0000_0000_0000_0000_1xxx: count_leading_zeros22 = 17;
        22'bx0_0000_0000_0000_0001_xxxx: count_leading_zeros22 = 16;
        22'bx0_0000_0000_0000_001x_xxxx: count_leading_zeros22 = 15;
        22'bx0_0000_0000_0000_01xx_xxxx: count_leading_zeros22 = 14;
        22'bx0_0000_0000_0000_1xxx_xxxx: count_leading_zeros22 = 13;
        22'bx0_0000_0000_0001_xxxx_xxxx: count_leading_zeros22 = 12;
        22'bx0_0000_0000_001x_xxxx_xxxx: count_leading_zeros22 = 11;
        22'bx0_0000_0000_01xx_xxxx_xxxx: count_leading_zeros22 = 10;
        22'bx0_0000_0000_1xxx_xxxx_xxxx: count_leading_zeros22 = 09;
        22'bx0_0000_0001_xxxx_xxxx_xxxx: count_leading_zeros22 = 08;
        22'bx0_0000_001x_xxxx_xxxx_xxxx: count_leading_zeros22 = 07;
        22'bx0_0000_01xx_xxxx_xxxx_xxxx: count_leading_zeros22 = 06;
        22'bx0_0000_1xxx_xxxx_xxxx_xxxx: count_leading_zeros22 = 05;
        22'bx0_0001_xxxx_xxxx_xxxx_xxxx: count_leading_zeros22 = 04;
        22'bx0_001x_xxxx_xxxx_xxxx_xxxx: count_leading_zeros22 = 03;
        22'bx0_01xx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros22 = 02;
        22'bx0_1xxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros22 = 01;
        22'bx1_xxxx_xxxx_xxxx_xxxx_xxxx: count_leading_zeros22 = 00;
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
        mantissa_a = {2'b01,i_data_a[FRAC_W-1 :0], 10'b0};
        mantissa_b = {2'b01,i_data_b[FRAC_W-1 :0], 10'b0};
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
        leading_zeros = count_leading_zeros22(mantissa_greater);
        mantissa_greater = mantissa_greater << leading_zeros;
        exp_greater = exp_greater - leading_zeros;
        if (leading_zeros == 21) begin 
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
        mantissa_a = {2'b01,i_data_a[FRAC_W-1 :0], 10'b0};
        mantissa_b = {2'b01,i_data_b[FRAC_W-1 :0], 10'b0};
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
        leading_zeros = count_leading_zeros22(mantissa_greater);
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

    always @ (posedge i_clk) begin
        if(~i_rst_n) begin
            curr_state = B0;
            next_state = B1;
        end else begin
            curr_state = next_state;
            next_state = next_state == B3? next_state -1 : next_state + 1;
        end
    end

    assign o_busy  = (curr_state == B0) || (curr_state == B2);
    assign o_valid = (curr_state == B3);
    assign o_data = ans;
endmodule