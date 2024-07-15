// opcode definition
`define OP_MAP_LOADING      0
`define OP_R_SHIFT          1
`define OP_L_SHIFT          2
`define OP_U_SHIFT          3
`define OP_D_SHIFT          4
`define OP_SCALE_DOWN       5
`define OP_SCALE_UP         6
`define OP_DISPLAY          7
`define OP_CONV             8   
`define OP_MED_FILTER       9
`define OP_SOBEL_NMS       10


// STATEs definition
`define FSM_FETCH           = 0;
`define FSM_DECODE          = 1;
`define FSM_SCALE_DOWN      = 2; //0010
`define FSM_SCALE_UP        = 3; //0011
`define FSM_SHIFT_RIGHT     = 4; //0100
`define FSM_SHIFT_LEFT      = 5; //0101
`define FSM_SHIFT_UP        = 6; //0110
`define FSM_SHIFT_DOWN      = 7; //0111  
`define FSM_LOAD_MAP        = 8; // 1000       
`define FSM_DISPLAY         = 9; //1001
`define FSM_CONV_CALC       = 10;//1010
`define FSM_MED_FILTER      = 11;//1011
`define FSM_SOBER_NMS       = 12;//1100
`define FSM_SRAM_READ       = 13;//1101
`define FSM_IDLE            = 14;//1110

