verdiWindowResize -win $_Verdi_1 "0" "25" "1920" "1004"
debImport "+v2k" "-sverilog"
wvCreateWindow
wvSetPosition -win $_nWave2 {("G1" 0)}
wvOpenFile -win $_nWave2 {/home/xycui/Work/camera_ctrl/simulation/pulpino.fsdb}
wvRestoreSignal -win $_nWave2 "./waveform/waveform.rc" -overWriteAutoAlias on
wvSelectGroup -win $_nWave2 {G4}
wvSelectGroup -win $_nWave2 {G4}
wvSelectSignal -win $_nWave2 {( "G4" 1 )} 
wvSelectSignal -win $_nWave2 {( "G4" 1 2 )} 
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G2" 8)}
wvSelectGroup -win $_nWave2 {G4}
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G2" 8)}
wvSelectGroup -win $_nWave2 {G5}
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G2" 8)}
wvSetPosition -win $_nWave2 {("G3" 13)}
wvSetPosition -win $_nWave2 {("G3" 13)}
wvSetPosition -win $_nWave2 {("G2" 8)}
wvSelectGroup -win $_nWave2 {G1}
wvSelectGroup -win $_nWave2 {G1}
wvRenameGroup -win $_nWave2 {G1} {External Signals}
wvSelectGroup -win $_nWave2 {External Signals}
wvSelectGroup -win $_nWave2 {G2}
wvMoveSelected -win $_nWave2
wvRenameGroup -win $_nWave2 {G2} {AXI signals}
wvSelectSignal -win $_nWave2 {( "External Signals" 4 )} 
wvSelectGroup -win $_nWave2 {G3}
wvRenameGroup -win $_nWave2 {G3} {AXI control}
wvSelectGroup -win $_nWave2 {External Signals}
wvSelectGroup -win $_nWave2 {AXI signals}
wvRenameGroup -win $_nWave2 {AXI signals} {AXI Signals}
wvSelectGroup -win $_nWave2 {AXI control}
wvRenameGroup -win $_nWave2 {AXI control} {AXI Controls}
wvSelectSignal -win $_nWave2 {( "AXI Signals" 10 )} 
wvSelectSignal -win $_nWave2 {( "AXI Signals" 10 )} 
wvSelectSignal -win $_nWave2 {( "AXI Signals" 10 )} 
wvSelectSignal -win $_nWave2 {( "AXI Signals" 10 )} 
wvSelectGroup -win $_nWave2 {External Signals}
wvSelectGroup -win $_nWave2 {External Signals}
wvSetPosition -win $_nWave2 {("AXI Controls" 13)}
wvSelectGroup -win $_nWave2 {G4}
debExit
