source ns2.tcl


proc test_most_basic {} {
    global param
    set success 1
    set param(num_nodes_x)                      3
    set param(num_nodes_y)                      1                           
    set param(spacing_m)                        6.0
    set param(master_index)                     0
    set param(jitterMax_ms)                     10
    set param(advertisement_interval_ms)        20
    set param(traffic_interval_ms)              40    
    set param(clock_drift)                      0
    set param(ttl)                              10
    set param(n_packets)                        1000
    set param(mode)                             all-to-one
    set param(bandwidth)                        1Mb
    set param(TX_power)                         0dBm
    set param(node_env)                         free-space 
    set param(show_nam)                         No
    set param(node_type)                        "nRF52"
    set param(adv_roles)                        1
    set param(retransmissions)                  1
    set param(priority)                         "Original Packets"
    set param(allow_rx_postpone)                "No"
    set param(node_cache_size)                  50
    set param(packet_payload_size)              11
    
    set param(dead_time_us)                     150
    set param(node_relay)                       {0 0 1}
    set param(traffic_generator)                {0 1 1}


    set res [run_ns false]

    set gw [lindex $res 0]
    if {[lindex $gw 1] != $param(n_packets)} {
        puts "Error in packets received at Gateway. Should be $param(n_packets). Was [lindex $gw 1]"
        set success 0
    }

    if {[lindex $gw 2] > 0} {
        puts "Error in duplicates received. Should be 0 was [lindex $gw 2]."
        set success 0
    }

    if {[lindex $gw 5] > 0 || [lindex $gw 6] > 0 || [lindex $gw 7] > 0} {
        puts "Error. Should not be any collisions"
        set success 0
    }

    set n1 [lindex $res 1]
    set n2 [lindex $res 2]

    if {[lindex $n1 0] != $param(n_packets)} {
        puts "Error. Node1 not expected number of sucessfull packets"
        set success 0
    }

    if {[lindex $n1 3] != 0} {
        puts "Error. Node1 not expected number of duplicate packets"
        set success 0
    }

    if {[lindex $n1 4] != 0} {
        puts "Error. Node1 not expected send_queue length"
        set success 0
    }


    if {[lindex $n2 0] != 0} {
        puts "Error. Node2 not expected number of sucessfull packets"
        set success 0
    }

    return $success
}

test_most_basic