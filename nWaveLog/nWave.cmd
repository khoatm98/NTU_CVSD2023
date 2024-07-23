verdiSetActWin -win $_nWave1
wvConvertFile -win $_nWave1 -o \
           "/home/MingKe/Study/NTU_CVSD2023/HW2/01_RTL/core.vcd.fsdb" \
           "/home/MingKe/Study/NTU_CVSD2023/HW2/01_RTL/core.vcd"
wvSetPosition -win $_nWave1 {("G1" 0)}
wvOpenFile -win $_nWave1 \
           {/home/MingKe/Study/NTU_CVSD2023/HW2/01_RTL/core.vcd.fsdb}
wvResizeWindow -win $_nWave1 0 23 1920 1009
wvSelectGroup -win $_nWave1 {G1}
wvSelectGroup -win $_nWave1 {G1}
wvSelectGroup -win $_nWave1 {G1}
wvSelectGroup -win $_nWave1 {G1}
wvExit
