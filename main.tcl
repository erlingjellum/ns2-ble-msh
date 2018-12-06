source file-io.tcl
source gui.tcl

set PARAMS_FILE_NAME "params2.txt"
set NS_EXEC_PATH "/root/ns-allinone-2.35/ns-2.35/nstk"
set NAM_EXEC_PATH "/root/ns-allinone-2.35/ns/nam-1.15/nam"
set VERSION "0.3"
set FONT_SIZE 14

array set param [read_params_from_file $PARAMS_FILE_NAME]

setup_gui
run_gui
