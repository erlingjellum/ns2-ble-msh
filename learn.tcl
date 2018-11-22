#package require tooltip
global gui_progress
global .probar

set num_nodes_x             5
set num_nodes_y             5
set spacing_m               5

set master_index            0

set jitterMax_ms            10
set transmission_period_ms  100
set clock_drift             0
set ttl                     10
set n_packets               100
set mode                    "one-to-all"
set bandwidth               1Mb
set pathloss_exp            6.0
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
set gui_progress            0




#TODO:
# Add the following parameters: node environment, node cache memory, loggin
wm title . "BLE-Mesh Simulator v0.1"

# Menubar
menu .mbar
. configure -menu .mbar

menu .mbar.fl -tearoff 0
.mbar add cascade -menu .mbar.fl -label File -underline 0
.mbar.fl add command -label About... -command {open_about_window}
.mbar.fl add command -label Exit -command {exit}


# Progress bar
ttk::progressbar .probar -mode determinate -orient horizontal -length 100 -variable gui_progress

# ALL USER INPUT PARAMETERS
#####################################################
label .tx_power_label -text "TX power" -justify left
ttk::combobox .tx_power_entry -textvariable TX_power\
                                -state readonly\
                                -values {"-4dBm" "0dBm" "+4dBm"}

label .bw_label -text "Bandwidth" -justify left
ttk::combobox .bw_entry -textvariable bandwidth\
                        -state readonly\
                        -values {250kb 1Mb 2Mb}


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
                          -values {"one-to-all"}\

label .bandwidth_label -text "Bandwidth"
entry .bandwidth_entry -textvariable bandwidth

button .start_button -text "Start" -command "run_ns" 




# Configure the tool-tips for each label 
# tooltip::tooltip .jitter_max_label "The Transport Layer will add a random jitter to each packet"
# tooltip::tooltip .mode_label "one-to-all: One node, index specified by the parameter master, advertises to all other nodes in network \n all-to-one: All nodes except master advertises to the master."
# tooltip::tooltip .num_nodes_x_label "Network layout is a grid. Specify the dimensions of the grid"
# tooltip::tooltip .num_nodes_y_label "Network layout is a grid. Specify the dimensions of the grid"
# tooltip::tooltip .spacing_label "The distant between two adjacent nodes in the grid"
# tooltip::tooltip .txp_label "The interval of advertisememt"
# tooltip::tooltip .n_packets_label "The number of advertisement packets to be sent by each advertiser during the simulation \n A higher number gives more accurate estimation"
# tooltip::tooltip .ttl_label "Time-To-Live for each packet. I.e. how many hops before the packet is dismissed"
# tooltip::tooltip .clock_drift_label "The ppm clock drift for the nodes"
# tooltip::tooltip .master_index_label "The node index of the master node. One-To-All: Master = Advertiser. All-To-One: Master = Receiver\n The index is given as the position in the flattend out node matrix. For node (i,j) index = i*num_nodes_x + j"
# tooltip::tooltip .disable_relay_index_label "Give a space separated list of the indices of the nodes that should, for any reason, not relay messages received\nIn BLE Mesh the standard is that all nodes relays all new packets, but this can saturate the channel and therefore, some nodes can be configured to not relay received packets." 



# Procedures for the TK GUI
###############################################################################3

# Procedure to call each time the dimensions of the grid has changed
# And we need to update the node_list
proc update_node_list {name1 name2 op} {
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

proc open_about_window {} {
    toplevel .a
    wm title .a "About"
    label .a.text -text "BLE Mesh Simulator\nVersion 0.1\nCopyright 2018 Nordic Semiconductor ASA\nSimulates a grid of BLE nodes running the BLE Mesh protocol with NS2" 

    grid .a.text
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

# Configure the layout of the GUI 
######################################

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
grid .probar          -row $i   -column 1


#########################################################
##############   SETUP AND SIMULATION ####################
##########################################################

proc run_ns {} {
    global num_nodes_x num_nodes_y spacing_m master_index jitterMax_ms\
            transmission_period_ms clock_drift ttl n_packets mode bandwidth\
            TX_power node_env node_relay ns f a num_nodes n gui_progress

    set num_nodes [expr $num_nodes_x*$num_nodes_y]

    # Print the input parameters from the GUI
    puts "num_nodes_x = $num_nodes_x"; puts "num_nodes_y = $num_nodes_y"
    puts "Spacing between nodes = $spacing_m"; puts "Index of master = $master_index"
    puts "jitterMax = $jitterMax_ms"; puts "TxP = $transmission_period_ms";
    puts "Clock Drift = $clock_drift"; puts "n_packets = $n_packets"
    puts "Mode = $mode"; puts "Bandwidth = $bandwidth"; puts "TX Power = $TX_power"
    puts "Node environment = $node_env"

    set MESSAGE_PORT 42 ;# Advertisment message. All Agents are attached to this port of the node.
    # Setting up Pysical Layer properties

    if {$node_env eq "free-space"} {
        # See nsnam2 documentation ch. 18.3.1
        Propagation/Shadowing set pathlossExp_ 2.0
        Propagation/Shadowing set std_db_ 4.0
        Propagation/Shadowing set dist0_ 1.0
        Propagation/Shadowing set seed_ 0
    }

    # Capture Threshold. I.e. SNR 
    Phy/WirelessPhy set CPThresh_ 12.0

    # Receiver sensitivity. Using indep-tools/propagation/threshold.cc to find it
    Phy/WirelessPhy set RXThresh_ 9.27e-10
    
    # Antenna strength (0dbm = 1mW)
    if {$TX_power eq "-4dBm"} {
        Phy/WirelessPhy set Pt_ 0.0004
    } elseif {$TX_power eq "0dBm"} {
        Phy/WirelessPhy set Pt_ 0.001
    } elseif {$TX_power eq "+4Bdm"} {
        Phy/WirelessPhy set Pt_ 0.0025
    }

    # Set receiver frequency BLE is 2.4-2.485Ghz
    Phy/WirelessPhy set freq_ 2.48e+09
    
    # Antenna parameters. Not changed
    # Antenna/OmniAntenna set X_ 0
    # Antenna/OmniAntenna set Y_ 0
    # Antenna/OmniAntenna set Z_ 1.5
    # Antenna/OmniAntenna set Gt_ 1
    # Antenna/OmniAntenna set Gr_ 1

    # LinkLayer parameters, not touched
    LL set mindelay_                0
    LL set delay_                   0
    LL set bandwidth_               $bandwidth       ;# not used
    DelayLink set bandwidth_        $bandwidth
    DelayLink set delay_ 0


    Mac set bandwidth_ $bandwidth

    set val(chan)           Channel/WirelessChannel    ;#Channel Typevar
    set val(prop)           Propagation/Shadowing   ;# radio-propagation model
    set val(netif)          Phy/WirelessPhy            ;# network interface type
    set val(energy)         "EnergyModel"
    set val(mac)		    Mac/SimpleMesh
    set val(ifq)            Queue/DropTail             ;# interface queue type
    set val(ll)             LL                         ;# link layer type
    set val(ant)            Antenna/OmniAntenna        ;# antenna model
    set val(ifqlen)         50                         ;# max packet in ifq
    set val(rxPower)        0.00001 ;# not important
    set val(txPower)        0.001;#Not important
    set val(initialEnergy)  0.1; #Not important
    set val(rp) DumbAgent

    set val(size_x)              [expr $num_nodes_x * $spacing_m]
    set val(size_y)              [expr $num_nodes_y * $spacing_m]

    # Create topography
    set topo [new Topography]
    $topo load_flatgrid $val(size_x) $val(size_y)

    # Create General Operations Director
    create-god $num_nodes 

    # Create Simulator object
    set ns [new Simulator]
    set f [open simple-adv.tr w]
    set nf [open ble-mesh.nam w]

    $ns namtrace-all-wireless $nf $val(size_x) $val(size_y)  

    $ns trace-all $f


    # Set default node-config
    $ns node-config -adhocRouting $val(rp) \
                -llType $val(ll) \
                -macType $val(mac) \
                -ifqType $val(ifq) \
                -ifqLen $val(ifqlen) \
                -antType $val(ant) \
                -propType $val(prop)\
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

    for {set i 0} {$i < $num_nodes_y} {incr i} {
        for {set j 0} {$j < $num_nodes_x} {incr j} {
            set index [expr ($i*$num_nodes_x)+$j];#calculate index in 1-D node array

            # Set node-specific properties
            if {$node_relay($index)} {
                Mac/SimpleMesh set node_role_ 1 ;#Relay is on
            } else {
                Mac/SimpleMesh set node_role_ 2 ;#Relay is off
            }

            set n($index) [$ns node];# New node object
            
            # Set the physical position of the node, only based on spacing
            $n($index) set X_ [expr $spacing_m*$j];
            $n($index) set Y_ [expr $spacing_m*$i];
            $n($index) set Z_ 0
            $ns initial_node_pos $n($index) 20
            puts "Node_$index X = [$n($index) set X_], Y = [$n($index) set Y_]"
            
            # Attach Transport Protocol Layer to each node
            set a($index) [new Agent/BleMeshAdv]
            $a($index) set ttl_ $ttl
            $a($index) set jitterMax_us_ [expr int($jitterMax_ms*1000)]
            $a($index) set clockDrift_ppm_ [expr floor(rand()*$clock_drift)]
            $n($index) attach $a($index) $MESSAGE_PORT

            
        }
    
    }

    for {set index 0} {$index < $num_nodes} {incr index} {
            puts "Node_$index X = [$n($index) set X_], Y = [$n($index) set Y_]"
        }



    # Setting up the advertisement packages

    if {$mode eq "one-to-all"} {
        puts "ONE-TO-ALL"
        for {set i 0} {$i < $n_packets} {incr i} {
            $ns at [expr $i*$transmission_period_ms/1000] "$a($master_index) send_adv $i"
        }
    } elseif {$mode eq "all-to-one"} {
        puts "ALL-TO-ONE"
        for {set i 0} {$i < $n_packets} {incr i} {
            for {set j 0} {$j < [expr $num_nodes + 1]} {incr j} {
                if {$j != $master} {
                    $ns at [expr $i*$transmission_period_ms/1000] "$a($j) send_adv [expr $i*$num_nodes + $j]"
                }
            }
    }   }

    # Finish simulation at the time guaranteed to be past all events
    $ns at [expr (($n_packets+$ttl)*$transmission_period_ms/1000)*2] finish

    # Create events for updating the progressbar
    for {set index 1} {$index < 101} {incr index} {
        $ns at [expr ($index * $n_packets * $transmission_period_ms/100000)] update_progressbar
    }

    # Procedure to be called after Simulation is done.
    proc finish {} {
        global ns n f mode a transmission_period_ms n_packets num_nodes num_nodes_x num_nodes_y
        $ns flush-trace
        close $f

        for {set index 0} {$index < $num_nodes} {incr index} {
            puts "Node_$index X = [$n($index) set X_], Y = [$n($index) set Y_]"
        }

        if {$mode eq "one-to-all"} {
            set total_success 0
            array set packets_per_link {}

            for {set i 0} {$i < [expr $num_nodes_x*$num_nodes_y]} {incr i} {
                set packets_per_link($i) [$a($i) set packets_received_]
                set total_success [expr $total_success + $packets_per_link($i)]
                puts "Master->Node_$i $packets_per_link($i)/$n_packets packets received"
                puts "Bandwidth = [expr $packets_per_link($i)*369000/($transmission_period_ms*$n_packets)] kbps"
            }

            puts "TOTAL PACKETS = $total_success/[expr $n_packets*($num_nodes_x*$num_nodes_y-1)]"
            puts "TOTAL BANDWIDTH = [expr $total_success*369000/($transmission_period_ms*$n_packets)] kbps"

        } elseif {$mode eq "all-to-one"} {
            puts "MODE: ALL TO ONE"
        }

        #exec  ../../ns/nam-1.15/nam ble-mesh.nam &

        exit 0
    }

    proc update_progressbar {} {
        global gui_progress
        incr gui_progress
        update idletasks


    }

    $ns run
}
    
    

############################################################################






    


