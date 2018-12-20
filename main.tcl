source file-io.tcl
source gui.tcl

set PARAMS_FILE_NAME "params.txt"
set NS_EXEC_PATH "/home/user/ns/ns-2.35/nstk"
set NAM_EXEC_PATH "/home/user/ns/ns/nam-1.15/nam"
set TRACEFILE_PATH "tracefiles/tracefile.tr"
set NAMFILE_PATH "tracefiles/namfile.nam"

set VERSION "0.4"
set FONT_SIZE 10

array set param [read_params_from_file $PARAMS_FILE_NAME]

setup_gui
run_gui