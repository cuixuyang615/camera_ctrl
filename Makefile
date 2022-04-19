VERDI_HOME = /export/homeO1/synopsys/verdi3-2016.6#/bin/verdi
NOVAS_HOME = /export/homeO1/synopsys/verdi3-2016.6#/bin/verdi
#LD_LIBRARY_PATH = ${NOVAS_HOME}/share/PLI/VCS/LINUX64

#main files
components = ../camera_ctrl.sv ../camera_buffer.sv ../camera2axi.sv

#testbench files
tbFiles =  ../camera_ctrl_tb.sv

files = ${tbFiles} ${components}

#-------------------------------------------------------------------------------------------------------
vcs    :
	cd simulation &&\
	vcs ${files} -F ../filelist.f -fsdb_old -R +vc +v2k -v2k_generate -sverilog -l run.log +lint=TFIPC-L +error+30 \
	-P ${VERDI_DIR}/share/PLI/VCS/LINUX64/novas.tab ${VERDI_DIR}/share/PLI/VCS/LINUX64/pli.a -debug_pp -LDFLAGS -rdynamic
#-------------------------------------------------------------------------------------------------------
verdi  :
	verdi +v2k  -sverilog -ssf ./simulation/pulpino.fsdb -sswr ./waveform/waveform.rc #verdi -sv -uvm -ssf test_mux.fsdb
#-------------------------------------------------------------------------------------------------------
clean  :
	cd simulation && rm -rf  *~  core  csrc  simv*  vc_hdrs.h  ucli.key  urg* *.log  novas.* *.fsdb* verdiLog  64* DVEfiles *.vpd