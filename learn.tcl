package require tooltip

set num_nodes_x             10
set num_nodes_y             10
set spacing_m               2

set master_index            0

set jitterMax_ms            10
set transmission_period_ms  100
set clock_drift             0
set ttl                     10
set n_packets                100
set mode                    "one-to-all"
set bandwidth               1Mbps
set pathloss_exp             6.0
set std_db                  1.0
set dist0                   1.0
set seed                    0

set CP_thresh                0.01
set CS_thres                 5.011e-13
set RX_thresh                5.011e-13
set Pt                      0.005

set RX_power                 0.00001
set TX_power                 "0dBm"
set inital_energy            0.1

set node_env                 "free-space"

set node_list {}
array set node_relay {}
set node_select               "(0,0)"


#TODO:
# Add the following parameters: node environment, node cache memory, logging
# TX power, RX power. Try to make things as drop-down menus instead
# Consider what and how the results should be made
#



label .tx_power_label -text "TX power" -justify left
ttk::combobox .tx_power_entry -textvariable TX_power\
                                -state readonly\
                                -values {"-4dBm" "0dBm" "+4dBm"}

label .bw_label -text "Bandwidth" -justify left
ttk::combobox .bw_entry -textvariable bandwidth\
                        -state readonly\
                        -values {250kbs 1Mbps 2Mbps}


label .node_master_label -text "Master" -justify left
checkbutton .node_master_button -command update_master

label .node_select_label -text "Node" -justify left
ttk::combobox .node_select_entry -textvariable node_select\
                                -values $node_list\
                                -state readonly
trace add variable node_select write update_node_options

label .node_env_label -text "Node environment" -justify left
ttk::combobox .node_env_entry -textvariable node_env\
                            -values {"office" "free-space"}\
                            -state readonly


label .node_relay_label -text "Relay" -justify left
checkbutton .node_relay_button -variable node_relay(0)

label .jitter_max_label -text "JitterMax (ms)" -justify left
entry .jitter_max_entry -textvariable jitterMax_ms

label .master_index_label -text "Index of master node" -justify left
entry .master_index_entry -textvariable master_index

label .disable_relay_index_label -text "Disable relay index (list)"
entry .disable_relay_index_entry -textvariable disable_relay_index

label .num_nodes_x_label -text "Node grid size x" -justify left
entry .num_nodes_x_entry  -textvariable num_nodes_x
trace add variable num_nodes_x write update_node_list

label .num_nodes_y_label -text "Node grid size y" -justify left
entry .num_nodes_y_entry -textvariable num_nodes_y
trace add variable num_nodes_y write update_node_list


label .spacing_label -text "Distance between nodes (m)" -justify left
entry .spacing_entry -textvariable spacing_m

label .txp_label -text "Transmission period (ms)"
entry .txp_entry -textvariable transmission_period_ms

#TODO: Clock drift should be drop-down menu with 
label .clock_drift_label -text "Clock drift (ppm)"
entry .clock_drift_entry -textvariable clock_drift

label .ttl_label -text "TTL"
entry .ttl_entry -textvariable ttl

label .n_packets_label -text "Number of packets sent"
entry .n_packets_entry -textvariable n_packets

label .mode_label -text "Simulation Mode"
ttk::combobox .mode_entry -textvariable mode\
                         -state readonly\
                          -values {"one-to-all" "all-to-one"}\

label .bandwidth_label -text "Bandwidth"
entry .bandwidth_entry -textvariable bandwidth

button .start_button -text "Start" -command "run" 




# Configure the tool-tips for each label
tooltip::tooltip .jitter_max_label "The Transport Layer will add a random jitter to each packet"
tooltip::tooltip .mode_label "one-to-all: One node, index specified by the parameter master, advertises to all other nodes in network \n all-to-one: All nodes except master advertises to the master."
tooltip::tooltip .num_nodes_x_label "Network layout is a grid. Specify the dimensions of the grid"
tooltip::tooltip .num_nodes_y_label "Network layout is a grid. Specify the dimensions of the grid"
tooltip::tooltip .spacing_label "The distant between two adjacent nodes in the grid"
tooltip::tooltip .txp_label "The interval of advertisememt"
tooltip::tooltip .n_packets_label "The number of advertisement packets to be sent by each advertiser during the simulation \n A higher number gives more accurate estimation"
tooltip::tooltip .ttl_label "Time-To-Live for each packet. I.e. how many hops before the packet is dismissed"
tooltip::tooltip .clock_drift_label "The ppm clock drift for the nodes"
tooltip::tooltip .master_index_label "The node index of the master node. One-To-All: Master = Advertiser. All-To-One: Master = Receiver\n The index is given as the position in the flattend out node matrix. For node (i,j) index = i*num_nodes_x + j"
tooltip::tooltip .disable_relay_index_label "Give a space separated list of the indices of the nodes that should, for any reason, not relay messages received\nIn BLE Mesh the standard is that all nodes relays all new packets, but this can saturate the channel and therefore, some nodes can be configured to not relay received packets." 

# add traces to trigger procedures from changes in values

#Call the update_node_list() whenever we changes these values


proc run {} {
    global jitterMax_ms num_nodes_x
    puts "jitter is "
    puts $jitterMax_ms
    puts $num_nodes_x


}
 

# Procedure to call each time the dimensions of the grid has changed
# And we need to update the node_list
proc update_node_list {name1 name2 op} {
    puts "Updating node list"
    global num_nodes_x num_nodes_y node_list .node_select_entry node_relay
    set node_list {}
    array set node_relay {}

    for {set i 0} {$i < $num_nodes_y} {incr i} {
        for {set j 0} {$j < $num_nodes_x} {incr j} {
            set index [expr $i*$num_nodes_x + $j]
            lappend node_list "($i, $j)"
            set node_relay($index) 1
    }

    .node_select_entry configure -textvariable node_select\
                                -values $node_list\
                                -state readonly

}

}



# Proc to call when we select a node and need to change the variable that thelse {
# Master checkbutton and the relay checkbutton are connected to
proc update_node_options {name1 nam2 op} {
    global node_select num_nodes_x num_nodes_y node_relay .node_relay_button .node_master_button master_index
    set ij [regexp -all -inline -- {[0-9]+} $node_select]
    set index [expr [lindex $ij 0]*$num_nodes_x + [lindex $ij 1]]
    .node_relay_button configure -variable node_relay($index)
    puts $node_relay($index)
    if {$node_relay($index)} {
        .node_relay_button select
    }

    if {$master_index == $index} {
        .node_master_button select
    } else {
        .node_master_button deselect
    }
}

proc update_master {} {
    global node_select num_nodes_x num_nodes_y master_index
    set ij [regexp -all -inline -- {[0-9]+} $node_select]
    set master_index [expr [lindex $ij 0]*$num_nodes_x + [lindex $ij 1]]

}

update_node_list 1 2 3 
update_node_options 1 2 3 

set i 0

grid .mode_label    -row $i  -column 0
grid .mode_entry    -row $i  -column 1
grid .node_env_label -row [incr i] -column 0
grid .node_env_entry -row $i        -column 1

grid .num_nodes_x_label -row [incr i] -column 0
grid .num_nodes_x_entry -row $i -column 1
grid .num_nodes_y_label -row [incr i] -column 0
grid .num_nodes_y_entry -row $i -column 1
grid .spacing_label     -row [incr i] -column 0
grid .spacing_entry     -row $i -column 1

grid .n_packets_label   -row [incr i] -column 0
grid .n_packets_entry   -row $i -column 1
grid .txp_label         -row [incr i] -column 0
grid .txp_entry         -row $i -column 1
grid .jitter_max_label  -row [incr i] -column 0
grid .jitter_max_entry  -row $i -column 1


grid .tx_power_label -row [incr i] -column 0
grid .tx_power_entry -row $i        -column 1

grid .bw_label -row [incr i] -column 0
grid .bw_entry -row $i        -column 1


grid .ttl_label         -row [incr i] -column 0
grid .ttl_entry         -row $i -column 1
grid .clock_drift_label -row [incr i] -column 0
grid .clock_drift_entry -row $i -column 1


grid .node_select_label -row [incr i] -column 0
grid .node_select_entry -row $i -column 1
grid .node_relay_label  -row [incr i] -column 0
grid .node_relay_button -row $i -column 1
grid .node_master_label -row [incr i] -column 0
grid .node_master_button -row $i -column 1


grid .start_button   -row [incr i] -column 0