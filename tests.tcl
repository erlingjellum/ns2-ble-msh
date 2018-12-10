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


proc test_all_packet_accounted_for {} {
    global param
    set success 1
    set param(num_nodes_x)                      5
    set param(num_nodes_y)                      5                           
    set param(spacing_m)                        0.1
    set param(master_index)                     0
    set param(jitterMax_ms)                     10
    set param(advertisement_interval_ms)        10
    set param(traffic_interval_ms)              1000   
    set param(clock_drift)                      0
    set param(ttl)                              10
    set param(n_packets)                        100
    set param(mode)                             all-to-one
    set param(bandwidth)                        1Mb
    set param(TX_power)                         0dBm
    set param(node_env)                         free-space 
    set param(show_nam)                         No
    set param(node_type)                        "nRF52"
    set param(adv_roles)                        2
    set param(retransmissions)                  1
    set param(priority)                         "Original Packets"
    set param(allow_rx_postpone)                "No"
    set param(node_cache_size)                  50
    set param(packet_payload_size)              11
    
    set param(dead_time_us)                     150
    set param(node_relay)                       {0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1}
    set param(traffic_generator)                {0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1}


    set res [run_ns false]

    set tot_crc 0
    set tot_dead 0
    set tot_ccr 0
    set tot_recv 0
    set tot_relays 0

    for {set i 0} {$i < $param(num_nodes)} {incr i} {
        set n [lindex $res $i]
        set tot_recv    [expr $tot_recv + [lindex $n 1] + [lindex $n 2]]
        set tot_relays  [expr $tot_relays + [lindex $n 4]]
        set tot_crc     [expr $tot_crc + [lindex $n 6]]
        set tot_dead    [expr $tot_dead + [lindex $n 8]]
        set tot_ccr     [expr $tot_ccr + [lindex $n 7]]
    }

    set tot_sent [expr (($param(num_nodes)-1)*$param(n_packets) + $tot_relays)*($param(num_nodes)-1)]

    if {$tot_sent != [expr $tot_recv + $tot_crc + $tot_ccr + $tot_dead]} {
        puts "Not all packets accounted for!"
        puts "Total Sent: $tot_sent \nTotal Relay: $tot_relays\nTotal Recv: $tot_recv\nTotal CRC: $tot_crc\n Total CCR: $tot_ccr\n Total Dead: $tot_dead"
        puts "TOTAL RECV = [expr $tot_recv + $tot_crc + $tot_ccr + $tot_dead]"
        set success 0
    }


    return $success


}


test_most_basic
test_all_packet_accounted_for

