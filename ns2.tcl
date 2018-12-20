source file-io.tcl
namespace import ::tcl::mathfunc::*

proc dbm_to_watt {dbm} {
    return [expr pow(10, [expr $dbm*1.0/10])/1000]
}

set res {} ;# Variable for storing the results from the Simulation

proc run_ns {gui_on} {
    global param res a ns n gui_progress . PARAMS_FILE_NAME f NAM_EXEC_PATH TRACEFILE_PATH NAMFILE_PATH

    # Make sure variables that are supposed to be floats, are indeed floats
    set param(advertisement_interval_ms) [expr 1.0 * $param(advertisement_interval_ms)]
    set param(jitterMax_ms) [expr 1.0 * $param(jitterMax_ms)]
    set param(spacing_m) [expr 1.0 * $param(spacing_m)]
    set param(traffic_interval_ms) [expr 1.0 * $param(traffic_interval_ms)]
    set param(ramp_time_us) [expr 1.0 * $param(dead_time_us)]
    
    # Calculate total number of nodes in simulation
    set param(num_nodes) [expr $param(num_nodes_x)*$param(num_nodes_y)]

    

    set MESSAGE_PORT 42 ;# Advertisment message. All Agents are attached to this port of the node.
    # Setting up Pysical Layer properties

    if {$param(node_env) eq "Office"} {
        # See nsnam2 documentation ch. 18.3.1
        Propagation/Shadowing set pathlossExp_ 2.0
        Propagation/Shadowing set std_db_ 4.0
        Propagation/Shadowing set dist0_ 1.0
        Propagation/Shadowing set seed_ 0
        set val(prop) [new Propagation/Shadowing]
    }

    if {$param(node_env) eq "Free-Space"} {
        set val(prop) [new Propagation/FreeSpace]
    }


    # Capture Threshold. I.e. SNR in dBm
    Phy/WirelessPhyBTLE set CPThresh_ 20.0
    Phy/WirelessPhyBTLE set rampDelay_ $param(ramp_time_us)
    Phy/WirelessPhyBTLE set RXDeadtime_ $param(dead_time_us)

    # Set Receiver Sensitivity based on IC and Bandwidth
    # See Product Brief for the various ICs
    if {$param(node_type) eq "nRF52832"} {
        if {$param(bandwidth) eq "1Mb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -96]
        } elseif {$param(bandwidth) eq "2Mb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -89]
        }
    } elseif {$param(node_type) eq "nRF52840"} {
        if {$param(bandwidth) eq "125kb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -103]
        } elseif {$param(bandwidth) eq "500kb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -99]
        } elseif {$param(bandwidth) eq "1Mb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -96]
        } elseif {$param(bandwidth) eq "2Mb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -92]
        }

    } elseif {$param(node_type) eq "nRF52810"} {
        if {$param(bandwidth) eq "1Mb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -96]
        } elseif {$param(bandwidth) eq "2Mb"} {
            Phy/WirelessPhyBTLE set RXThresh_ [dbm_to_watt -93]
        }
    }

    puts "Receiver Sensitivity: [Phy/WirelessPhyBTLE set RXThresh_] W"

    # Antenna strength (0dbm = 1mW)

    # Parse the TX_Power input, remove + sign and convert to watts
    Phy/WirelessPhyBTLE set Pt_ [expr pow(10,[expr [regsub {\+} [lindex [split $param(TX_power) "d"] 0] ""]/10.0])/1000]
    
    # Set receiver frequency BLE is 2.4-2.485Ghz
    Phy/WirelessPhyBTLE set freq_ 2.48e+09
    
    # Antenna parameters. Not changed
    # Antenna/OmniAntenna set X_ 0
    # Antenna/OmniAntenna set Y_ 0
    # Antenna/OmniAntenna set Z_ 1.5
    Antenna/OmniAntenna set Gt_ 1
    Antenna/OmniAntenna set Gr_ 1

    # LinkLayer parameters, not touched
    LL set mindelay_                0
    LL set delay_                   0
    LL set bandwidth_               $param(bandwidth)       ;# not used
    DelayLink set bandwidth_        $param(bandwidth)
    DelayLink set delay_ 0

    # Mac-layer parameters
    Mac/BTLEmesh set jitter_max_us_ [expr int($param(jitterMax_ms)*1000)]
    Mac/BTLEmesh set originator_queue_max_size_ $param(originator_queue_size)
    Mac/BTLEmesh set relay_queue_max_size_ $param(relay_queue_size)
    Mac set bandwidth_ $param(bandwidth)
    

    set val(chan)           Channel/WirelessChannel    ;#Channel Typevar
    set val(netif)          Phy/WirelessPhyBTLE            ;# network interface type
    set val(energy)         "EnergyModel"
    set val(mac)		    Mac/BTLEmesh
    set val(ifq)            Queue/DropTail             ;# interface queue type
    set val(ll)             LL                  ;# link layer type
    set val(ant)            Antenna/OmniAntenna        ;# antenna model
    set val(ifqlen)         50                         ;# max packet in ifq
    set val(rxPower)        0.00001 ;# not important
    set val(txPower)        0.001;#Not important
    set val(initialEnergy)  0.1; #Not important
    set val(rp)             DumbAgent

    set val(size_x)              [expr $param(num_nodes_x) * $param(spacing_m)]
    set val(size_y)              [expr $param(num_nodes_y) * $param(spacing_m)]


    # Create topography
    set topo [new Topography]
    $topo load_flatgrid $val(size_x) $val(size_y)

    # Create General Operations Director
    create-god $param(num_nodes) 

    # Create Simulator object
    set ns [new Simulator]
    set f [open $TRACEFILE_PATH w]

    if {$param(show_nam) eq "Yes"} {
        set nf [open $NAMFILE_PATH w]
        $ns namtrace-all-wireless $nf $val(size_x) $val(size_y)      
    }
    

    $ns trace-all $f


    # Set default node-config
    $ns node-config -adhocRouting $val(rp) \
                -llType $val(ll) \
                -macType $val(mac) \
                -ifqType $val(ifq) \
                -ifqLen $val(ifqlen) \
                -antType $val(ant) \
                -propInstance $val(prop)\
                -phyType $val(netif) \
                -topoInstance $topo \
                -agentTrace ON \
                -routerTrace OFF \
                -macTrace ON \
                -movementTrace OFF \
                -channel [new $val(chan)] \
                #-energyModel $val(energy) \
                #-rxPower $val(rxPower) \
                #-txPower $val(txPower)\
                #-initialEnergy $val(initialEnergy)

    # Creating all nodes
    for {set i 0} {$i < $param(num_nodes_y)} {incr i} {
        for {set j 0} {$j < $param(num_nodes_x)} {incr j} {
            set index [expr ($i*$param(num_nodes_x))+$j];#calculate index in 1-D node array

            # Setup MAC layer stuff
            Mac/BTLEmesh set adv_interval_us_ [expr $param(advertisement_interval_ms) * 1000]
            Mac/BTLEmesh set originator_queue_max_size_ $param(originator_queue_size)
            Mac/BTLEmesh set relay_queue_max_size_ $param(relay_queue_size)


            set n($index) [$ns node];# New node object
            
            # Set the physical position of the node, only based on spacing
            $n($index) set X_ [expr $param(spacing_m)*$j];
            $n($index) set Y_ [expr $param(spacing_m)*$i];
            $n($index) set Z_ 0
            $ns initial_node_pos $n($index) 2
            
            # Attach Transport Protocol Layer to each node
            set a($index) [new Agent/BleMeshAdv]
            $a($index) sett ttl $param(ttl)
            #$a($index) set clockDrift_ppm_ [expr floor(rand()*$param(clock_drift))]
            $n($index) attach $a($index) $MESSAGE_PORT

            # Set the cache-size
            $a($index) sett cache-size $param(node_cache_size)

            # Set node-id
            $a($index) sett node-id $index

            # Set packet size
            $a($index) set packetSize_ [expr 121 + ($param(packet_payload_size) * 8)] 

            # Set relay
            # Set node-specific properties
            if {[lindex $param(node_relay) $index]} {
                $a($index) set relay_ 1 ;#Relay is on
            } else {
                $a($index) set relay_ 0 ;#Relay is off
            }
        }
    
    }



    # Setting up the advertisement packages


    if {$param(mode) eq "one-to-all"} {
        puts "ONE-TO-ALL"

        for {set i 0} {$i < $param(n_packets)} {incr i} {
            $ns at [expr $i*$param(traffic_interval_ms)/1000] "$a($param(master_index)) schedule-adv $i"
        }

        $ns at 0.0 "$a($param(master_index)) start-adv"


    } elseif {$param(mode) eq "all-to-one"} {
        puts "ALL-TO-ONE"
        #for {set index 0} {$index < $param(num_nodes)} {incr index} {
        #    set offset($index) [expr rand() * $param(advertisement_interval_ms)/1000]
        #}

        for {set i 0} {$i < $param(n_packets)} {incr i} {
            for {set j 0} {$j < [expr $param(num_nodes) ]} {incr j} {
                # Check that this is a traffic generating node
                if {[lindex $param(traffic_generator) $j]} { 
                    $ns at [expr $i*$param(traffic_interval_ms)/1000] "$a($j) schedule-adv [expr $i*$param(num_nodes) + $j]"
                }
            }
        }

    }

    # Finish simulation at the time guaranteed to be past all events
    set param(tot_time) [expr $param(n_packets)*$param(traffic_interval_ms)/1000]
    $ns at $param(tot_time) finish

    if {$gui_on eq "True"} {
        # Create events for updating the progressbar
        for {set index 1} {$index < 101} {incr index} {
            $ns at [expr ($index * $param(n_packets) * $param(traffic_interval_ms)/100000)] update_progressbar
    }

    }
    
    # Procedure to be called after Simulation is done.
    proc finish {} {
        global ns n f a param . res NAM_EXEC_PATH
        $ns halt
        $ns flush-trace
        close $f
        
        if {$param(show_nam) eq "Yes"} {
            exec  $NAM_EXEC_PATH ble-mesh.nam &    
        }

        # Extract simulation results
        for {set i 0} {$i < $param(num_nodes)} {incr i} {
            set mac [$n($i) set mac_(0)]
            set phy [$n($i) set netif_(0)]

            set resultPerNode {}
            # 0 Packets successfully received at gateway
            lappend resultPerNode [$a($param(master_index)) get packets-received-from-node $i]
            # 1 Packets received at this node
            lappend resultPerNode [$a($i) set packets_received_]
            # 2 Duplicates received at this node
            lappend resultPerNode [$a($i) get duplicates-received]
            # 3 Originator queue overflows
            lappend resultPerNode [$mac get originator-queue-overflows]
            # 4 Relay queue overflows  
            lappend resultPerNode [$mac get relay-queue-overflows]
            # 5 Number of relayed packet by node
            lappend resultPerNode [$mac get relays]
            # 6 Number of cache-misses
            lappend resultPerNode [$a($i) get cache-misses]
            # 7 CRC collision
            lappend resultPerNode [$phy get crc-collisions]
            # 8 Co-Channel rejections
            lappend resultPerNode [$phy get co-channel-rejections]
            # 9 Dead-Time-Collisions
            lappend resultPerNode [$phy get dead-time-collisions]
            # 10 Collisions while TXing
            lappend resultPerNode [$phy get tx-collisions]
            # 11 Collisions while ramping
            lappend resultPerNode [$phy get ramp-collisions]

            # Append the results for this node to the RES variable
            lappend res $resultPerNode
        }

    }

    $ns run

    return $res

}
