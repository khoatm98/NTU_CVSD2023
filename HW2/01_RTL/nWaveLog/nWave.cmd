verdiSetActWin -win $_nWave1
wvResizeWindow -win $_nWave1 0 23 1920 1009
wvConvertFile -win $_nWave1 -o \
           "/home/MingKe/Study/NTU_CVSD2023/HW2/01_RTL/core.vcd.fsdb" \
           "/home/MingKe/Study/NTU_CVSD2023/HW2/01_RTL/core.vcd"
wvSetPosition -win $_nWave1 {("G1" 0)}
wvOpenFile -win $_nWave1 \
           {/home/MingKe/Study/NTU_CVSD2023/HW2/01_RTL/core.vcd.fsdb}
wvSelectGroup -win $_nWave1 {G1}
wvSelectGroup -win $_nWave1 {G1}
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/testbed"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvSetPosition -win $_nWave1 {("G1" 17)}
wvSetPosition -win $_nWave1 {("G1" 17)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/testbed/u_core/ALUPCRes\[31:0\]} \
{/testbed/u_core/ALUcond} \
{/testbed/u_core/ALUen} \
{/testbed/u_core/ALUinputA\[31:0\]} \
{/testbed/u_core/ALUinputB\[31:0\]} \
{/testbed/u_core/ALUopcode\[5:0\]} \
{/testbed/u_core/ALUout\[31:0\]} \
{/testbed/u_core/ALUovf} \
{/testbed/u_core/MemToReg} \
{/testbed/u_core/PCsrc} \
{/testbed/u_core/ReadA\[31:0\]} \
{/testbed/u_core/ReadB\[31:0\]} \
{/testbed/u_core/Reg2Loc} \
{/testbed/u_core/RegA\[4:0\]} \
{/testbed/u_core/RegB\[4:0\]} \
{/testbed/u_core/WriteData\[31:0\]} \
{/testbed/u_core/WriteReg\[4:0\]} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 \
           )} 
wvSetPosition -win $_nWave1 {("G1" 17)}
wvGetSignalClose -win $_nWave1
wvResizeWindow -win $_nWave1 0 23 1920 1009
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/testbed"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/u_reg_file"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_data_mem"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/u_reg_file"
wvGetSignalClose -win $_nWave1
wvSelectSignal -win $_nWave1 {( "G1" 17 )} 
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/testbed"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/u_reg_file"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_data_mem"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/u_reg_file"
wvGetSignalClose -win $_nWave1
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/testbed"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/u_reg_file"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/u_reg_file"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvSetPosition -win $_nWave1 {("G1" 19)}
wvSetPosition -win $_nWave1 {("G1" 19)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/testbed/u_core/ALUPCRes\[31:0\]} \
{/testbed/u_core/ALUcond} \
{/testbed/u_core/ALUen} \
{/testbed/u_core/ALUinputA\[31:0\]} \
{/testbed/u_core/ALUinputB\[31:0\]} \
{/testbed/u_core/ALUopcode\[5:0\]} \
{/testbed/u_core/ALUout\[31:0\]} \
{/testbed/u_core/ALUovf} \
{/testbed/u_core/MemToReg} \
{/testbed/u_core/PCsrc} \
{/testbed/u_core/ReadA\[31:0\]} \
{/testbed/u_core/ReadB\[31:0\]} \
{/testbed/u_core/Reg2Loc} \
{/testbed/u_core/RegA\[4:0\]} \
{/testbed/u_core/RegB\[4:0\]} \
{/testbed/u_core/WriteData\[31:0\]} \
{/testbed/u_core/WriteReg\[4:0\]} \
{/testbed/u_core/i_i_inst\[31:0\]} \
{/testbed/u_core/state\[3:0\]} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 18 19 )} 
wvSetPosition -win $_nWave1 {("G1" 19)}
wvGetSignalClose -win $_nWave1
wvSelectSignal -win $_nWave1 {( "G1" 10 )} 
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/testbed"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/u_reg_file"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core/alu1"
wvGetSignalSetScope -win $_nWave1 "/testbed/u_core"
wvSetPosition -win $_nWave1 {("G1" 21)}
wvSetPosition -win $_nWave1 {("G1" 21)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/testbed/u_core/ALUPCRes\[31:0\]} \
{/testbed/u_core/ALUcond} \
{/testbed/u_core/ALUen} \
{/testbed/u_core/ALUinputA\[31:0\]} \
{/testbed/u_core/ALUinputB\[31:0\]} \
{/testbed/u_core/ALUopcode\[5:0\]} \
{/testbed/u_core/ALUout\[31:0\]} \
{/testbed/u_core/ALUovf} \
{/testbed/u_core/MemToReg} \
{/testbed/u_core/PCsrc} \
{/testbed/u_core/ReadA\[31:0\]} \
{/testbed/u_core/ReadB\[31:0\]} \
{/testbed/u_core/Reg2Loc} \
{/testbed/u_core/RegA\[4:0\]} \
{/testbed/u_core/RegB\[4:0\]} \
{/testbed/u_core/WriteData\[31:0\]} \
{/testbed/u_core/WriteReg\[4:0\]} \
{/testbed/u_core/i_i_inst\[31:0\]} \
{/testbed/u_core/state\[3:0\]} \
{/testbed/u_core/current_pc\[31:0\]} \
{/testbed/u_core/current_pc\[31:0\]} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 21 )} 
wvSetPosition -win $_nWave1 {("G1" 21)}
wvGetSignalClose -win $_nWave1
wvZoomOut -win $_nWave1
wvSetCursor -win $_nWave1 2271.980182 -snap {("G2" 0)}
wvSetCursor -win $_nWave1 1928.639893 -snap {("G1" 21)}
wvZoomIn -win $_nWave1
wvZoomIn -win $_nWave1
wvZoomOut -win $_nWave1
wvZoomOut -win $_nWave1
wvZoomIn -win $_nWave1
wvZoomIn -win $_nWave1
wvSetCursor -win $_nWave1 1751.671288 -snap {("G1" 21)}
wvZoomIn -win $_nWave1
wvZoomIn -win $_nWave1
wvZoomOut -win $_nWave1
wvZoomOut -win $_nWave1
wvZoomIn -win $_nWave1
wvZoomOut -win $_nWave1
wvZoomOut -win $_nWave1
wvZoomIn -win $_nWave1
wvZoomIn -win $_nWave1
wvZoomOut -win $_nWave1
wvSelectSignal -win $_nWave1 {( "G1" 18 )} 
wvSelectSignal -win $_nWave1 {( "G1" 18 )} 
wvSetRadix -win $_nWave1 -format Bin
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 16 )} 
wvSelectSignal -win $_nWave1 {( "G1" 17 )} 
wvSetCursor -win $_nWave1 1660.537754 -snap {("G1" 16)}
wvSetCursor -win $_nWave1 1747.432519 -snap {("G1" 21)}
wvSelectSignal -win $_nWave1 {( "G1" 21 )} 
wvSetCursor -win $_nWave1 8682.058597 -snap {("G1" 21)}
wvSetCursor -win $_nWave1 8546.417989 -snap {("G1" 21)}
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSelectSignal -win $_nWave1 {( "G1" 21 )} 
wvSelectSignal -win $_nWave1 {( "G1" 1 )} 
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSelectSignal -win $_nWave1 {( "G1" 12 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSelectSignal -win $_nWave1 {( "G1" 12 )} 
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSelectSignal -win $_nWave1 {( "G1" 12 )} 
wvSelectSignal -win $_nWave1 {( "G1" 14 )} 
wvSelectSignal -win $_nWave1 {( "G1" 15 )} 
wvSetCursor -win $_nWave1 8418.195227 -snap {("G1" 14)}
wvSelectSignal -win $_nWave1 {( "G1" 10 )} 
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSelectSignal -win $_nWave1 {( "G1" 12 )} 
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSetCursor -win $_nWave1 8458.463532 -snap {("G1" 14)}
wvSetCursor -win $_nWave1 5539.011386 -snap {("G1" 20)}
wvSetCursor -win $_nWave1 7552.426659 -snap {("G1" 21)}
wvSetCursor -win $_nWave1 7141.266067 -snap {("G1" 21)}
wvSetCursor -win $_nWave1 8323.882617 -snap {("G1" 21)}
wvSetCursor -win $_nWave1 8331.300462 -snap {("G1" 21)}
wvSetCursor -win $_nWave1 8342.957077 -snap {("G1" 20)}
wvSetCursor -win $_nWave1 8350.374923 -snap {("G1" 19)}
wvSetCursor -win $_nWave1 8750.938593 -snap {("G1" 19)}
wvSelectSignal -win $_nWave1 {( "G1" 12 )} 
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSelectSignal -win $_nWave1 {( "G1" 12 )} 
wvExit
