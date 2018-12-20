
global . gui_progress node_select texts
source ns2.tcl
source gui-texts.tcl
source tooltip.tcl


proc setup_gui {} {
    global gui_progress . param node_select myFont FONT_SIZE relay traffic_generator texts VERSION
    set gui_progress 0
    set node_list {}
    set node_select             "(0,0)"
    set gui_progress            0
    set relay [lindex $param(node_relay) 0]
    set traffic_generator [lindex $param(traffic_generator) 0]


    # Initialize the node_list (just for GUI)
    for {set i 0} {$i < $param(num_nodes_y)} {incr i} {   
        for {set j 0} {$j < $param(num_nodes_x)} {incr j} {
            set index [expr $i*$param(num_nodes_x) + $j]
            lappend node_list "($j, $i)"  
        }
    }


    # set result variables
    set res(n_packets) 0
    wm title . "BLE-Mesh Simulator v$VERSION"

    # Menubar
    menu .mbar
    . configure -menu .mbar

    menu .mbar.fl -tearoff 0
    .mbar add cascade -menu .mbar.fl -label File -underline 0
    .mbar.fl add command -label About... -command {open_about_window}
    .mbar.fl add command -label Exit -command {exit}


    # Progress bar
    ttk::progressbar .probar -mode determinate -orient horizontal -length 100 -variable gui_progress

    # Font
    font create myFont -family Times -size $FONT_SIZE -weight normal
    # ALL USER INPUT PARAMETERS
    #####################################################

   label .mode_label -font myFont -text "Simulation Mode"
    ttk::combobox .mode_entry -font myFont -font myFont -textvariable  param(mode)\
                            -values {"one-to-all" "all-to-one"}\
                            -state disabled
    trace add variable param(mode) write update_mode
    tooltip::tooltip .mode_label $texts(hovertips_mode_label)


    label .node_env_label -font myFont -text "Node Environment" -justify left
    ttk::combobox .node_env_entry -font myFont -textvariable  param(node_env)\
                                -values {"Free-Space" "Office" }\
                                -state readonly
    tooltip::tooltip .node_env_label $texts(hovertips_node_env_label)

    label .show_nam_label -font myFont -text "Show graphic visualization" -justify left
    ttk::combobox .show_nam_entry -font myFont -textvariable  param(show_nam)\
                                    -state disabled\
                                    -values {"Yes" "No"}
    tooltip::tooltip .show_nam_label $texts(hovertips_show_nam_label)

    label .num_nodes_x_label -font myFont -text "Node grid size x \[\]" -justify left
    entry .num_nodes_x_entry  -font myFont -textvariable  param(num_nodes_x)
    trace add variable param(num_nodes_x) write update_node_list
    tooltip::tooltip .num_nodes_x_label $texts(hovertips_num_nodes_x_label)

    label .num_nodes_y_label -font myFont -text "Node grid size y \[\]" -justify left
    entry .num_nodes_y_entry -font myFont -textvariable  param(num_nodes_y)
    trace add variable param(num_nodes_y) write update_node_list
    tooltip::tooltip .num_nodes_y_label $texts(hovertips_num_nodes_y_label)

    label .spacing_label -font myFont -text "Distance between nodes \[m\]" -justify left
    entry .spacing_entry -font myFont -textvariable  param(spacing_m)
    tooltip::tooltip .spacing_label $texts(hovertips_spacing_label)


    label .traffic_interval_label -font myFont -text "Traffic Generation Interval \[ms\]" -justify left
    entry .traffic_interval_entry -font myFont -textvariable  param(traffic_interval_ms) -justify left
    tooltip::tooltip .traffic_interval_label $texts(hovertips_traffic_interval_label)

    label .txp_label -font myFont -text "Advertisment Interval \[ms\]"
    entry .txp_entry -font myFont -textvariable  param(advertisement_interval_ms)
    tooltip::tooltip .txp_label $texts(hovertips_txp_label)

    label .n_packets_label -font myFont -text "Number of packets sent per node \[\]"
    entry .n_packets_entry -font myFont -textvariable  param(n_packets)
    tooltip::tooltip .n_packets_label $texts(hovertips_n_packets_label)

    label .packet_size_label -font myFont -text "Payload size \[Bytes\]" -justify left
    entry .packet_size_entry -font myFont -textvariable  param(packet_payload_size)
    tooltip::tooltip .packet_size_label $texts(hovertips_packet_size_label)

    label .jitter_max_label -font myFont -text "Max jitter \[ms\]" -justify left
    entry .jitter_max_entry -font myFont -textvariable  param(jitterMax_ms)
    tooltip::tooltip .jitter_max_label $texts(hovertips_jitter_max_label)


    label .node_type_label -font myFont -text "Node IC" -justify left
    ttk::combobox .node_type_entry -font myFont -textvariable  param(node_type)\
                                    -state readonly\
                                    -values {"nRF52840" "nRF52832" "nRF52810"}
    tooltip::tooltip .node_type_label $texts(hovertips_node_type_label)
    trace add variable param(node_type) write update_node_type                                

    label .tx_power_label -font myFont -text "TX power" -justify left
    ttk::combobox .tx_power_entry -font myFont -textvariable  param(TX_power)\
                                    -state readonly\
                                    -values {"-20dBm" "-16dBm" "-12dBm" "-8dBm" "-4dBm" "0dBm" "+2dBm" "+3dBm" "+4dBm"}
                        
    tooltip::tooltip .tx_power_label $texts(hovertips_tx_power_label)

    label .bw_label -font myFont -text "Bitrate" -justify left
    ttk::combobox .bw_entry -font myFont -textvariable  param(bandwidth)\
                            -state readonly\
                            -values {125kb 250kb 1Mb 2Mb}
    tooltip::tooltip .bw_label $texts(hovertips_bw_label)

    label .ttl_label -font myFont -text "TTL \[\]"
    entry .ttl_entry -font myFont -textvariable  param(ttl)
    tooltip::tooltip .ttl_label $texts(hovertips_ttl_label)
    
    label .node_cache_size_label -font myFont -text "Cache size \[n packets\]" -justify left
    entry .node_cache_size_entry -font myFont -textvariable  param(node_cache_size)
    tooltip::tooltip .node_cache_size_label $texts(hovertips_node_cache_size_label)

    label .originator_queue_size_label -font myFont -text "Originator queue size \[n packets\]" -justify left
    entry .originator_queue_size_entry -font myFont -textvariable  param(originator_queue_size)
    #tooltip::tooltip .node_cache_size_label $texts(hovertips_node_cache_size_label)

    label .relay_queue_size_label -font myFont -text "Relay queue size \[n packets\]" -justify left
    entry .relay_queue_size_entry -font myFont -textvariable  param(relay_queue_size)
    tooltip::tooltip .node_cache_size_label $texts(hovertips_node_cache_size_label)
    

    label .rx_dead_time_label -font myFont -text "Radio Dead-time after receive \[us\]" -justify left
    entry .rx_dead_time_entry -font myFont -textvariable  param(dead_time_us) -justify left
    tooltip::tooltip .rx_dead_time_label $texts(hovertips_rx_dead_time_label)

    label .ramp_time_label -font myFont -text "Radio Ramp-Up-time\[us\]" -justify left
    entry .ramp_time_entry -font myFont -textvariable  param(ramp_time_us) -justify left
    #tooltip::tooltip .ramp_time_label $texts(hovertips_rx_dead_time_label)

    label .clock_drift_label -font myFont -text "Clock Drift \[ppm\]"
    entry .clock_drift_entry -font myFont -textvariable  param(clock_drift) -state readonly
    tooltip::tooltip .clock_drift_label $texts(hovertips_clock_drift_label)


    label .adv_roles_label -font myFont -text "Advertisement Roles"
    entry .adv_roles_entry -font myFont -textvariable  param(adv_roles) -state readonly
    tooltip::tooltip .adv_roles_label $texts(hovertips_adv_roles_label)

    label .retransmissions_label -font myFont -text "Retransmissions"
    entry .retransmissions_entry -font myFont -textvariable  param(retransmissions) -state readonly
    tooltip::tooltip .retransmissions_label $texts(hovertips_retransmissions_label)

    label .priority_label -font myFont -text "Priority"
    entry .priority_entry -font myFont -textvariable  param(priority) -state readonly
    tooltip::tooltip .priority_label $texts(hovertips_priority_label)

    label .allow_rx_postpone_label -font myFont -text "Allow RX to postpone Advertisement Window"
    entry .allow_rx_postpone_entry -font myFont -textvariable  param(allow_rx_postpone) -state readonly
    tooltip::tooltip .allow_rx_postpone_label $texts(hovertips_allow_rx_postpone_label)

    label .node_select_label -font myFont -text "Node" -justify left
    ttk::combobox .node_select_entry -font myFont -textvariable  node_select\
                                    -values $node_list\
                                    -state readonly
    trace add variable node_select write update_node_options
    tooltip::tooltip .node_select_label $texts(hovertips_node_select_label)

    label .node_master_label -font myFont -text "Master" -justify left
    checkbutton .node_master_button -command update_master
    tooltip::tooltip .node_master_label $texts(hovertips_node_master_label)

    label .traffic_generator_label -font myFont -text "Traffic Generator"
    checkbutton .traffic_generator_button -variable traffic_generator
    trace add variable traffic_generator write update_traffic_generators
    tooltip::tooltip .traffic_generator_label $texts(hovertips_traffic_generator_label)

    label .node_relay_label -font myFont -text "Relay" -justify left
    checkbutton .node_relay_button -variable relay
    trace add variable relay write update_node_relay
    tooltip::tooltip .node_relay_label $texts(hovertips_node_relay_label)

    button .start_button -font myFont -text "Start" -command "run_simulation" 

}


proc update_node_list {name1 name2 op} {
    global param node_list .node_select_entry myFont
    set node_list {}
    set param(node_relay) {}
    set param(traffic_generator) {}
    set param(num_nodes) [expr $param(num_nodes_x) * $param(num_nodes_y)]

    for {set i 0} {$i < $param(num_nodes_y)} {incr i} {
        for {set j 0} {$j < $param(num_nodes_x)} {incr j} {
            set index [expr $i*$param(num_nodes_x) + $j]
            lappend node_list "($i, $j)"
            if {$index != $param(master_index)} {
                lappend param(node_relay) 1
                lappend param(traffic_generator) 1    
            } else {
                lappend param(node_relay) 0
                lappend param(traffic_generator) 0
            }
            
        }

    .node_select_entry configure -textvariable node_select\
                                -values $node_list\
                                -state readonly\
                                -font myFont

    }

}


proc update_node_relay {name1, name2, op} {
    # Called when user checks/unchecks the button for relay
    global param relay node_select

    set ij [regexp -all -inline -- {[0-9]+} $node_select]
    set index [expr [lindex $ij 0]*$param(num_nodes_x) + [lindex $ij 1]]

    lset param(node_relay) $index $relay
}

proc update_traffic_generators {name1 name2 op} {
    #`Called when user checks/unchecks the button for traffic generator
    global param traffic_generator node_select

    set ij [regexp -all -inline -- {[0-9]+} $node_select]
    set index [expr [lindex $ij 0]*$param(num_nodes_x) + [lindex $ij 1]]

    lset param(traffic_generator) $index $traffic_generator
}

proc update_mode {name1 nam2 op} {
    # Called when user changes the "MODE". We need to disable traffic generator options
    global param .traffic_generator_button
    set param(traffic_generator) {}

    if {$param(mode) eq "one-to-all"} {
        .traffic_generator_button configure -state disabled
        for {set index 0} {$index < $param(num_nodes)} {incr index} {
            if {$index == $param(master_index)} {
                lappend param(traffic_generator) 1
            } else {
                lappend param(traffic_generator) 0
            }
        }
        

    } elseif {$param(mode) eq "all-to-one"} {
        .traffic_generator_button configure -state normal
        for {set index 0} {$index < $param(num_nodes)} {incr index} {
            if {$index == $param(master_index)} {
                lappend param(traffic_generator) 0
            } else {
                lappend param(traffic_generator) 1
            }
        }
        
    }
}

proc update_node_type {name1 name2 op} {
    # Update available TX power modes based on which IC we choose.
    global param .tx_power_entry .bw_entry

    if {$param(node_type) eq "nRF52832"} {
        .tx_power_entry configure -values {"-20dBm" "-16dBm" "-12dBm" "-8dBm" "-4dBm" "0dBm" "+4dBm"}
        .bw_entry configure -values {1Mb 2Mb}
    } elseif {$param(node_type) eq "nRF52840"} {
        .tx_power_entry configure -values {"-20dBm" "-16dBm" "-12dBm" "-8dBm" "-4dBm" "0dBm" "+4dBm" "+8dBm"}        
        .bw_entry configure -values {125kb 500kb 1Mb 2Mb}
    } elseif {$param(node_type) eq "nRF52810"} {
        .tx_power_entry configure -values {"-20dBm" "-16dBm" "-12dBm" "-8dBm" "-4dBm" "0dBm" "+4dBm"}
        .bw_entry configure -values {1Mb 2Mb}
    }
    
}

proc open_about_window {} {
    global VERSION
    toplevel .a
    wm title .a "About"
    label .a.text -font myFont -text "BLE Mesh Simulator\nVersion $VERSION\nCopyright 2018 Nordic Semiconductor ASA\nSimulates a grid of BLE nodes running the BLE Mesh protocol with NS2" 

    grid .a.text
}



# Proc to call when we select a node and need to change the variable that thelse {
# Master checkbutton and the relay checkbutton are connected to
proc update_node_options {name1 nam2 op} {
    global node_select param .node_relay_button .node_master_button .traffic_generator_button
    set ij [regexp -all -inline -- {[0-9]+} $node_select]
    set index [expr [lindex $ij 0]*$param(num_nodes_x) + [lindex $ij 1]]
    if {[lindex $param(node_relay) $index]} {
        .node_relay_button select
    } else {
        .node_relay_button deselect
    }

    if {[lindex $param(traffic_generator) $index]} {
        .traffic_generator_button select
    } else {
        .traffic_generator_button deselect
    }


    if {$param(master_index) == $index} {
        .node_master_button select
    } else {
        .node_master_button deselect
    }
}

proc update_master {} {
    global node_select param
    set ij [regexp -all -inline -- {[0-9]+} $node_select]
    set param(master_index) [expr [lindex $ij 0]*$param(num_nodes_x) + [lindex $ij 1]]

}


proc run_gui {} {
    global .
    update_node_options 1 2 3 

    # Configure the layout of the GUI 
    ######################################

    set i 0

    # Stupid HACK to create "blank" rows in the GUI for better readability
    label .empty_label1
    label .empty_label2
    label .empty_label3


    grid .mode_label    -row $i  -column 0
    grid .mode_entry    -row $i  -column 1

    grid .node_env_label -row [incr i] -column 0
    grid .node_env_entry -row $i        -column 1


    grid .show_nam_label -row [incr i] -column 0
    grid .show_nam_entry -row $i -column 1

    grid .num_nodes_x_label -row [incr i] -column 0
    grid .num_nodes_x_entry -row $i -column 1
    grid .num_nodes_y_label -row [incr i] -column 0
    grid .num_nodes_y_entry -row $i -column 1
    grid .spacing_label     -row [incr i] -column 0
    grid .spacing_entry     -row $i -column 1

    ## Add space
    grid .empty_label1       -row [incr i] -column 0

    grid .traffic_interval_label -row [incr i] -column 0
    grid .traffic_interval_entry -row $i    -column 1

    grid .txp_label         -row [incr i] -column 0
    grid .txp_entry         -row $i -column 1

    grid .n_packets_label   -row [incr i] -column 0
    grid .n_packets_entry   -row $i -column 1

    grid .packet_size_label -row [incr i] -column 0
    grid .packet_size_entry -row $i -column 1

    grid .jitter_max_label  -row [incr i] -column 0
    grid .jitter_max_entry  -row $i -column 1

    ## Add space
    grid .empty_label2       -row [incr i] -column 0


    grid .node_type_label -row [incr i] -column 0
    grid .node_type_entry -row $i        -column 1

    grid .tx_power_label -row [incr i] -column 0
    grid .tx_power_entry -row $i        -column 1

    grid .bw_label -row [incr i] -column 0
    grid .bw_entry -row $i        -column 1


    grid .ttl_label         -row [incr i] -column 0
    grid .ttl_entry         -row $i -column 1

    grid .node_cache_size_label -row [incr i] -column 0
    grid .node_cache_size_entry -row $i        -column 1

    grid .originator_queue_size_label -row [incr i] -column 0
    grid .originator_queue_size_entry -row $i        -column 1

    grid .relay_queue_size_label -row [incr i] -column 0
    grid .relay_queue_size_entry -row $i        -column 1
    
    grid .rx_dead_time_label -row [incr i] -column 0
    grid .rx_dead_time_entry -row $i -column 1

    grid .ramp_time_label -row [incr i] -column 0
    grid .ramp_time_entry -row $i -column 1

    grid .adv_roles_label -row [incr i] -column 0
    grid .adv_roles_entry -row $i -column 1

    grid .retransmissions_label -row [incr i] -column 0
    grid .retransmissions_entry -row $i -column 1    

    grid .priority_label -row [incr i] -column 0
    grid .priority_entry -row $i -column 1

    grid .allow_rx_postpone_label -row [incr i] -column 0
    grid .allow_rx_postpone_entry -row $i -column 1


    # Add space
    grid .empty_label3       -row [incr i] -column 0

    grid .node_select_label -row [incr i] -column 0
    grid .node_select_entry -row $i -column 1

    grid .node_master_label -row [incr i] -column 0
    grid .node_master_button -row $i -column 1

    grid .traffic_generator_label -row [incr i] -column 0
    grid .traffic_generator_button -row $i -column 1

    grid .node_relay_label  -row [incr i] -column 0
    grid .node_relay_button -row $i -column 1



    grid .start_button   -row [incr i] -column 0
    grid .probar          -row $i   -column 1
}

proc disable_gui {} {
    global .
    .mode_entry configure -state disabled  
    .show_nam_entry configure -state disabled
    .node_env_entry configure -state disabled
    .node_type_entry configure -state disabled
    .num_nodes_x_entry configure -state disabled 
    .num_nodes_y_entry configure -state disabled
    .spacing_entry configure -state disabled    
    .n_packets_entry configure -state disabled 
    .txp_entry configure -state disabled
    .jitter_max_entry configure -state disabled
    .tx_power_entry configure -state disabled
    .bw_entry configure -state disabled
    .node_cache_size_entry configure -state disabled
    .originator_queue_size_entry configure -state disabled
    .relay_queue_size_entry configure -state disabled
    .ttl_entry configure -state disabled
    .clock_drift_entry configure -state disabled
    .node_select_entry configure -state disabled
    .node_relay_button configure -state disabled
    .node_master_button configure -state disabled
    .packet_size_entry configure -state disabled
    .traffic_interval_entry configure -state disabled
    .rx_dead_time_entry configure -state disabled
    .ramp_time_entry configure -state disabled
    .traffic_generator_button configure -state disabled
    .allow_rx_postpone_entry configure -state disabled
    .retransmissions_entry configure -state disabled
    .adv_roles_entry configure -state disabled
    .priority_entry configure -state disabled
}    

proc update_progressbar {} {
    global gui_progress
    incr gui_progress
    update idletasks
    update
}


proc run_simulation {} {
    global . param PARAMS_FILE_NAME myFont
    # This function is bound to the "Start" button on the GUI and invokes "run_ns" from ns2.tcl
    disable_gui
    .start_button configure -text Abort -command restart -font myFont
    #Write parameters to file
    write_params_to_file $PARAMS_FILE_NAME param

    set results [run_ns "True"]

    .start_button configure -text "New Simulation" -font myFont

    display_results $results
    
}

proc restart {} {
    global NS_EXEC_PATH
    exec $NS_EXEC_PATH main.tcl &
    exit 0
}


proc display_results {res} {
    global param . myFont

    toplevel .f
    wm title .f "Simulation Results"
    tk::listbox .f.text -font myFont -yscrollcommand ".f.scroll set" -height 50 -width 100
    #Make a scrollbar
    scrollbar .f.scroll -command ".f.text yview" -orient vertical 

    #Make a menu
    menu .f.mbar
    .f configure -menu .f.mbar

    menu .f.mbar.file -tearoff 0
    .f.mbar add cascade -menu .f.mbar.file -label File -underline 0
    .f.mbar.file add command -label Save -command {save_results .f.text}
    .f.mbar.file add command -label Exit -command {wm withdraw .f}


    .f.text insert end "SIMULATION RESULTS: "

    # For ALL-TO-ONE MODE
    if {$param(mode) eq "all-to-one"} {
        # Extract results for the Gateway
        set node_res [lindex $res $param(master_index)]
        .f.text insert end "## Gateway ##"
        .f.text insert end "Packets received = [lindex $node_res 1]/[expr $param(n_packets)*($param(num_nodes_x)*$param(num_nodes_y)-1)]"
        .f.text insert end "Throughput =  [expr [lindex $node_res 1]*$param(packet_payload_size)*8/($param(tot_time)*1000)] kbps\n"
        .f.text insert end  "Duplicates received = [lindex $node_res 2]"
        .f.text insert end  "CRC-Collision = [lindex $node_res 7] Co-Channel-Rejections = [lindex $node_res 8] Dead-Time-Collisions: [lindex $node_res 9]"
        .f.text insert end  "Collision while TXing = [lindex $node_res 10] Collision while ramp-up/ramp-down = [lindex $node_res 11]" 
        .f.text insert end "Packets relayed = [lindex $node_res 5]"

       # Extract results for all other nodes
        for {set i 0} {$i < $param(num_nodes_y)} {incr i} {
            for {set j 0} {$j < $param(num_nodes_x)} {incr j} {
                set index [expr ($i*$param(num_nodes_x))+$j]
                if {$index != $param(master_index)} {
                    set node_res [lindex $res $index]
                    .f.text insert end "### Node_($j-$i) ###"
                    .f.text insert end  "Packets successfully received at Gateway = [lindex $node_res 0]/$param(n_packets)"
                    .f.text insert end  "Throughput = [expr [lindex $node_res 0]*$param(packet_payload_size)*8/($param(tot_time)*1000)] kbps"
                    .f.text insert end  "Originator Queue Overflows =  [lindex $node_res 3]"
                    .f.text insert end  "Relay Queue Overflows =  [lindex $node_res 4]"
                    .f.text insert end  "Packets Received = [lindex $node_res 1]"
                    .f.text insert end  "Relayed packets = [lindex $node_res 5] Cache-misses = [lindex $node_res 6]"
                    .f.text insert end  "Duplicates received = [lindex $node_res 2]"
                    .f.text insert end  "CRC-Collision = [lindex $node_res 7] Co-Channel-Rejections = [lindex $node_res 8] Dead-Time-Collisions: [lindex $node_res 9]"
                    .f.text insert end  "Collision while TXing = [lindex $node_res 10] Collision while ramp-up/ramp-down = [lindex $node_res 11]"    
                }
                
            }
        }
        
    } elseif {$param(mode) eq "one-to-all"} {
        # Extract results for the Gateway
        
        set gateway_index [.f.text index end]
        set total_packets_recv_from_master 0
        # Extract results for all other nodes
        for {set i 0} {$i < $param(num_nodes_y)} {incr i} {
            for {set j 0} {$j < $param(num_nodes_x)} {incr j} {
                set index [expr ($i*$param(num_nodes_x))+$j]
                if {$index != $param(master_index)} {
                    set node_res [lindex $res $index]
                    set total_packets_recv_from_master [expr $total_packets_recv_from_master + [lindex $node_res 1]]
                    .f.text insert end "### Node_($j-$i) ###"
                    .f.text insert end  "Packets successfully received from Master = [lindex $node_res 1]/$param(n_packets)"
                    .f.text insert end  "Throughput from master = [expr [lindex $node_res 1]*$param(packet_payload_size)*8/($param(tot_time)*1000)] kbps"
                    .f.text insert end  "Originator Queue Overflows =  [lindex $node_res 3]"
                    .f.text insert end  "Relay Queue Overflows =  [lindex $node_res 4]"
                    .f.text insert end  "Relayed packets = [lindex $node_res 5] Cache-misses = [lindex $node_res 6]"
                    .f.text insert end  "Duplicates received = [lindex $node_res 2]"
                    .f.text insert end  "CRC-Collision = [lindex $node_res 7] Co-Channel-Rejections = [lindex $node_res 8] Dead-Time-Collisions: [lindex $node_res 9]"
                    .f.text insert end  "Collision while TXing = [lindex $node_res 10] Collision while ramp-up/ramp-down = [lindex $node_res 11]"   
                }
                
            }
        }
        set node_res [lindex $res $master_index]
        .f.text insert $gateway_index "## Gateway ##"
        .f.text insert [incr gateway_index] "Packets received = $total_packets_recv_from_master/[expr $param(n_packets)*($param(num_nodes_x)*$param(num_nodes_y)-1)]"
        .f.text insert [incr gateway_index] "Throughput =  [expr $total_packets_recv_from_master*$param(packet_payload_size)*8/($param(tot_time)*1000)] kbps\n"
        .f.text insert [incr gateway_index] "Duplicates received = [lindex $node_res 2]"
        .f.text insert [incr gateway_index] "CRC-Collision = [lindex $node_res 7] Co-Channel-Rejections = [lindex $node_res 8] Dead-Time-Collisions: [lindex $node_res 9]"
        .f.text insert [incr gateway_index] "Collision while TXing = [lindex $node_res 10] Collision while ramp-up/ramp-down = [lindex $node_res 11]"    

    }

    # Pack the textbox
    grid .f.text -sticky nwes -column 0 -row 0
    grid .f.scroll -column 1 -row 0 -sticky ew

}

proc save_results {textbox} {
    global param
    set i 0
    $textbox insert $i "SIMULATION PARAMETERS:"
    $textbox insert [incr i] "Simulation Mode = $param(mode)"
    $textbox insert [incr i] "Node environment = $param(node_env)"
    $textbox insert [incr i] "Grid size x-direction = $param(num_nodes_x)"
    $textbox insert [incr i] "Grid size y-direction = $param(num_nodes_y)"
    $textbox insert [incr i] "Spacing between nodes \[m\] = $param(spacing_m)"
    $textbox insert [incr i] "Traffic Generation interval \[ms\] = $param(traffic_interval_ms)"
    $textbox insert [incr i] "Advertisement interval \[ms\] = $param(advertisement_interval_ms)"
    $textbox insert [incr i] "Number of packets sent per node = $param(n_packets)"
    $textbox insert [incr i] "Packet Payload Size \[Bytes\] = $param(packet_payload_size)"
    $textbox insert [incr i] "Max Jitter \[ms\] = $param(jitterMax_ms)"
    $textbox insert [incr i] "Node IC = $param(node_type)"
    $textbox insert [incr i] "TX Power = $param(TX_power)"
    $textbox insert [incr i] "Bitrate = $param(bandwidth)"
    $textbox insert [incr i] "TTL = $param(ttl)"
    $textbox insert [incr i] "Cache-Size \[n packets\] = $param(node_cache_size)"
    $textbox insert [incr i] "Originator queue size \[n packets\] = $param(originator_queue_size)"
    $textbox insert [incr i] "Relay queue size \[n packets\] = $param(relay_queue_size)"
    $textbox insert [incr i] "Radio deadtime after RX \[us\]= $param(dead_time_us)"
    $textbox insert [incr i] "Radio Ramp Up Time \[us\] = $param(ramp_time_us)"
    $textbox insert [incr i] "Retransmissions = $param(retransmissions)"
    $textbox insert [incr i] "Advertisement roles = $param(adv_roles)"
    $textbox insert [incr i] "Priority = $param(priority)"
    $textbox insert [incr i] "Allow RX to postpone Adv. Window = $param(allow_rx_postpone)"
    $textbox insert [incr i] "Master/Gateway index = $param(master_index)"
    $textbox insert [incr i] "Traffic Generators = $param(traffic_generator)"
    $textbox insert [incr i] "Relayers = $param(node_relay)"

    save_results_to_file $textbox

}
