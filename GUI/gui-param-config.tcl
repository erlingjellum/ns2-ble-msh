# This file configures the user input parameter to the Simulator.

#{name  label  type  values  trace  state}

# Network parameters
set param_network {}

set param_mode      {mode "Simulation Mode" ttk::combobox {all-to-one one-to-all} "" readonly}
set param_nodes_x   {num_nodes_x  "Num nodes x" entry ""  update_num_nodes  readwrite}
set param_nodes_y   {num_nodes_y  "Num nodes y" entry ""  update_num_nodes  readwrite}
set param_spacing   {spacing_m    "Distance between nodes"  entry  ""  readwrite}



lappend param_network $param_mode $param_nodes_x $param_nodes_y $param_spacing



# Node parameters
set param_nodes {}
set param_ic       {node_type  "Node IC" ttk::combobox {nRF52832 nRF52810 nRF52840} update_node_type}
set para_bitrate    {bitrate     "Bitrate" ttk::combobox {125kb 500kb 1Mb 2Mb} ""}
set param_jitter    {jitter_max  "Max jitter /[us/]" entry "" ""}



# Role parameters
set param_roles {}


# Traffic parameters
set param_traffic {}
