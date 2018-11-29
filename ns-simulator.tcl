
# First open params.txt and read all parameters that were set by the GUI

set fp [open "params.txt" r]
set params [read $fp]
close $fp

set param_line [split $params "\n"]

set num_nodes_x  [lindex $param_line 0]
set num_nodes_y  [lindex $param_line 1]
set spacing_m    [lindex $param_line 2]
set master_index [lindex $param_line 3]
set jitterMax_ms [lindex $param_line 4] 
set transmission_period_ms [lindex $param_line 5]
set clock_drift [lindex $param_line 6]
set n_packets [lindex $param_line 7]
set mode [lindex $param_line 8]
set bandwidth [lindex $param_line 9]
set TX_power [lindex $param_line 10]
set node_env [lindex $param_line 11]
set ttl [lindex $param_line 12]
set node_relay [split [lindex $param_line 13] " "]


puts "num_nodes_x = $num_nodes_x"; puts "num_nodes_y = $num_nodes_y"
puts "Spacing between nodes = $spacing_m"; puts "Index of master = $master_index"
puts "jitterMax = $jitterMax_ms"; puts "TxP = $transmission_period_ms";
puts "Clock Drift = $clock_drift"; puts "n_packets = $n_packets"
puts "Mode = $mode"; puts "Bandwidth = $bandwidth"; puts "TX Power = $TX_power"
puts "Node environment = $node_env"


######################################
####### Now starts the acutal setup ########
########################################



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
Phy/WirelessPhy set RXThresh_ 1.87e-09

# Antenna strength (0dbm = 1mW)
if {$TX_power eq "-4dm"} {
    Phy/WirelessPhy set Pt_ 0.0004
} elseif {$TX_power eq "0dm"} {
    Phy/WirelessPhy set Pt_ 0.001
} elseif {$TX_power eq "+4dm"} {
    Phy/WirelessPhy set Pt_ 0.0025
}

# Antenna parameters. Not changed
Antenna/OmniAntenna set X_ 0
Antenna/OmniAntenna set Y_ 0
Antenna/OmniAntenna set Z_ 1.5
Antenna/OmniAntenna set Gt_ 1
Antenna/OmniAntenna set Gr_ 1

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

set val(size_x)              [expr $num_nodes_x * 10]
set val(size_y)              [expr $num_nodes_y * 10]

# Create topography
set topo [new Topography]
$topo load_flatgrid $val(size_x) $val(size_y)

# Create General Operations Director
create-god [expr $num_nodes_x * $num_nodes_y]

# Create Simulator object
set ns [new Simulator]
set f [open simple-adv.tr w]
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
            -agentTrace OFF \
            -routerTrace OFF \
            -macTrace OFF \
            -movementTrace OFF \
            -channel [new $val(chan)] \
            -energyModel $val(energy) \
            -rxPower $val(rxPower) \
            -txPower $val(txPower)\
            -initialEnergy $val(initialEnergy)

# Creating all nodes

for {set i 0} {$i < $num_nodes_y} {incr i} {
    for {set j 0} {$j < $num_nodes_x} {incr j} {
        set index [expr ($i*$num_nodes_x)+$j];#calculate index in 1-D node array
        # Set node-specific properties
        if {[lindex $node_relay $index]} {
            Mac/SimpleMesh set node_role_ 1
        } else {
            Mac/SimpleMesh set node_role_ 2
        }

        set n($index) [$ns node];# New node object
        
        # Set the physical position of the node, only based on spacing
        $n($index) set X_ $spacing_m*$j;
        $n($index) set Y_ $spacing_m*$i;
        $n($index) set Z_ 0
        
        # Attach Transport Protocol Layer to each node
        set a($index) [new Agent/BleMeshAdv]
        $a($index) set ttl_ $ttl
        $a($index) set jitterMax_us_ [expr int($jitterMax_ms*1000)]
        $a($index) set clockDrift_ppm_ [expr floor(rand()*$clock_drift)]
        $n($index) attach $a($index) $MESSAGE_PORT
    }

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

############################################################################




# Procedure to be called after Simulation is done.
proc finish {} {
    global ns mode a transmission_period_ms n_packets num_nodes_x num_nodes_y
    $ns flush-trace

    if {$mode eq "one-to-all"} {
        set total_success 0
        array set packets_per_link {}

        for {set i 0} {$i < [expr $num_nodes_x*$num_nodes_y]} {incr i} {
            set packets_per_link($i) [$a($i) set packets_received_]
            $total_success = [expr $total_success + $packets_per_link($i)]
            puts "Master->Node_$i $packets_per_link($i)/$n_packets packets received"
            puts "Bandwidth = [expr $packets_per_link($i)*369000/($transmission_period_ms*$n_packets)]"
        }

        puts "TOTAL PACKETS = $total_success/[expr $n_packets*($num_nodes_x*$num_nodes_y-1)]"
        puts "TOTAL BANDWIDTH = [expr $total_success*369000/($transmission_period_ms*$n_packets)]"

    } else if {$mode eq "all-to-one"} {

    }


}
    



$ns run