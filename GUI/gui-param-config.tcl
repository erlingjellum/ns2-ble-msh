# This file configures the user input parameter to the Simulator.

#[name, label, type, values, trace]

# Network parameters
set param_network {}

set param_mode      {mode, "Simulation Mode",entry,"",""}
set param_nodes_x   {num_nodes_x, "Num nodes x",entry,"",update_num_nodes}
set param_nodes_y   {num_nodes_y, "Num nodes y",entry,"",update_num_nodes}
set param_spacing   {spacing_m,   "Distance between nodes",entry,"",""}



lappend $param_network $param_mode $param_nodes_x $param_nodes_y $param_spacing



# Node parameters
set param_nodes {}
set param_ic       {node_type, "Node IC",ttk::combobox,"",update_node_type}
set param_jitter    {jitter_max, "Max jitter /[us/]",entry,"",""}


# Role parameters
set param_roles {}

# Traffic parameters
set param_traffic {}

