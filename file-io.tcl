proc read_params_from_file {fname} {
    set fp [open $fname r]
    set params [read $fp]
    close $fp

    set param_line [split $params "\n"]

    set i 0;

    set param(num_nodes_x)  [lindex $param_line $i]
    set param(num_nodes_y)  [lindex $param_line [incr i]]
    set param(num_nodes)    [lindex $param_line [incr i]]
    set param(spacing_m)    [lindex $param_line [incr i]]
    set param(master_index) [lindex $param_line [incr i]]
    set param(jitterMax_ms) [lindex $param_line [incr i]] 
    set param(advertisement_interval_ms) [lindex $param_line [incr i]]
    set param(clock_drift) [lindex $param_line [incr i]]
    set param(ttl) [lindex $param_line [incr i]]
    set param(n_packets) [lindex $param_line [incr i]]
    set param(mode) [lindex $param_line [incr i]]
    set param(bandwidth) [lindex $param_line [incr i]]
    set param(TX_power) [lindex $param_line [incr i]]
    set param(node_env) [lindex $param_line [incr i]]
    set param(show_nam) [lindex $param_line [incr i]]
    set param(node_type) [lindex $param_line [incr i]]

    set param(adv_roles) 1
    set param(retransmissions) 1
    set param(priority) "Original Packets"
    set param(allow_rx_postpone) "No"

    set param(node_cache_size) [lindex $param_line [incr i]]
    set param(packet_payload_size) [lindex $param_line [incr i]]
    set param(traffic_interval_ms) [lindex $param_line [incr i]]
    set param(dead_time_us) [lindex $param_line [incr i]]
    set param(node_relay) [split [lindex $param_line [incr i]] " "]
    set param(traffic_generator) [split [lindex $param_line [incr i]] " "]

    return [array get param]
}


proc write_params_to_file {fname arrName} {

    upvar param $arrName
    set fp [open $fname w]

    puts $fp $param(num_nodes_x)            
    puts $fp $param(num_nodes_y)
    puts $fp $param(num_nodes)                         
    puts $fp $param(spacing_m)              
    puts $fp $param(master_index)           
    puts $fp $param(jitterMax_ms)            
    puts $fp $param(advertisement_interval_ms)  
    puts $fp $param(clock_drift)            
    puts $fp $param(ttl)                     
    puts $fp $param(n_packets)              
    puts $fp $param(mode)                   
    puts $fp $param(bandwidth)              
    puts $fp $param(TX_power)               
    puts $fp $param(node_env)               
    puts $fp $param(show_nam)               
    puts $fp $param(node_type)              
    puts $fp $param(node_cache_size)  
    puts $fp $param(packet_payload_size)
    puts $fp $param(traffic_interval_ms) 
    puts $fp $param(dead_time_us)     

    for {set index 0} {$index < $param(num_nodes)} {incr index} {
        puts -nonewline $fp [lindex $param(node_relay) $index]
        puts -nonewline $fp " "
    }

    puts -nonewline $fp "\n"
    for {set index 0} {$index < $param(num_nodes)} {incr index} {
        puts -nonewline $fp [lindex $param(traffic_generator) $index]
        puts -nonewline $fp " "


    }

    close $fp

}

proc save_results_to_file {textbox} {
    set fname [tk_getSaveFile -initialdir "Saved Results" -filetypes {{{Text Files} {.txt}}}]
    set fp [open $fname "w"]
    puts $fp [$textbox get 0 end]
    close $fp   
}