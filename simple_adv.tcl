namespace import ::tcl::mathfunc::*

set num_nodes_x 2
set num_nodes_y 2

set spacing_m 1 ;# Spacing between the nodes in the grid

set transmission_period_ms 40.0
set nPackets               1000
set jitterMax_ms           0
set ttl                    0
set clock_drift            0.0

set packet_size_bits        369

set mode                "all-to-one" ;# Simulation mode
set network_layout      "circle-net"
set master                  0  ;#In a one-to-all or all-to-one which node number is the "one"

if { $network_layout eq "circle-net"} {
    set num_nodes 10
    set master 0
} else {
    set num_nodes [expr $num_nodes_x*$num_nodes_y]
}

set PI 3.142

Propagation/Shadowing set pathlossExp_ 0.0
Propagation/Shadowing set std_db_ 0.0
Propagation/Shadowing set dist0_ 1.0
Propagation/Shadowing set seed_ 0

Mac set bandwidth_ 1000kbps


Phy/WirelessPhy set CPThresh_ 10.0
Phy/WirelessPhy set CSThresh_ 5.011e-13
Phy/WirelessPhy set RXThresh_ 5.011e-13
Phy/WirelessPhy set Pt_ 0.005

Antenna/OmniAntenna set X_ 0
Antenna/OmniAntenna set Y_ 0
Antenna/OmniAntenna set Z_ 1.5

Antenna/OmniAntenna set Gt_ 1
Antenna/OmniAntenna set Gr_ 1


LL set mindelay_                0
LL set delay_                   0
LL set bandwidth_               1Mb       ;# not used


DelayLink set bandwidth_ 1Mb
DelayLink set delay_ 0

set MESSAGE_PORT 42

set val(chan)           Channel/WirelessChannel    ;#Channel Typevar
set val(prop)           Propagation/Shadowing   ;# radio-propagation model
set val(netif)          Phy/WirelessPhy            ;# network interface type
set val(energy)         "EnergyModel"

set val(mac)		Mac/SimpleMesh


set val(ifq)            Queue/DropTail             ;# interface queue type
set val(ll)             LL                         ;# link layer type
set val(ant)            Antenna/OmniAntenna        ;# antenna model
set val(ifqlen)         50                         ;# max packet in ifq

set val(rxPower)        0.00001
set val(txPower)        0.001
set val(initialEnergy)  0.1

# DumbAgent, AODV, and DSDV work.  DSR is broken
set val(rp) DumbAgent



# size of the topography
set val(size_x)              500
set val(size_y)              50



set ns [new Simulator]

set f [open simple-adv.tr w]
$ns trace-all $f

set nf [open wireless-flooding-$val(rp).nam w]
$ns namtrace-all-wireless $nf $val(size_x) $val(size_y)

$ns use-newtrace

# set up topography object
set topo       [new Topography]

$topo load_flatgrid $val(size_x) $val(size_y)

#
# Create God
#
create-god $num_nodes


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
                -energyModel $val(energy) \
                -rxPower $val(rxPower) \
                -txPower $val(txPower)\
                -initialEnergy 0.1 



if {$network_layout eq "circle-net"} {

    Mac/SimpleMesh set node_role_ 1
    set n(0) [$ns node]
    $n(0) set X_ 0
    $n(0) set Y_ 0
    $n(0) set Z_ 0
    set a(0) [new Agent/BleMeshAdv]
    $n(0) attach $a(0) $MESSAGE_PORT
    $a(0) set ttl_ $ttl

    Mac/SimpleMesh set node_role_ 2
    

    for {set i 1} {$i < [expr $num_nodes+1]} {incr i} {
        set n($i) [$ns node]
        $n($i) set X_ [expr $spacing_m * [sin [expr 2*$PI*$i/$num_nodes]]]
        $n($i) set Y_ [expr $spacing_m * [cos [expr 2*$PI*$i/$num_nodes]]]
        $n($i) set Z_ 0
        
        # Attach Transport Protocol Layer to each node
        set a($i) [new Agent/BleMeshAdv]
        $n($i) attach $a($i) $MESSAGE_PORT
        $a($i) set ttl_ $ttl
        $a($i) set jitterMax_us_ [expr int($jitterMax_ms*1000)]

    }

} else {
    for {set i 0} {$i < $num_nodes_x} {incr i} {
        for {set j 0} {$j < $num_nodes_y} {incr j} {
            set index [expr ($i*$num_nodes_x)+$j];#calculate index in 1-D node array
            set n($index) [$ns node];# New node object
            
            # Set the physical position of the node, only based on spacing
            $n($index) set X_ $spacing_m;
            $n($index) set Y_ $spacing_m;
            $n($index) set Z_ 0
            
            # Attach Transport Protocol Layer to each node
            set a($index) [new Agent/BleMeshAdv]
            $n($index) attach $a($index) $MESSAGE_PORT
        }
    }
}


# Setting up the periodic advertisement events:
# Choose between a few predefined "modes"

if {$mode eq "one-to-all"} {
    puts "ONE-TO-ALL"
    for {set i 0} {$i < $nPackets} {incr i} {
        # Setting up the advertisement packet sends:
        # See agent-ble-mesh-adv.cc for the implementation of "send_adv". 
        # The only parameter is a unique packet identifier that has to be unique for each
        # packet.
        # Jitter (and soon clock drift) will automatically be added in the TP layer. 
        $ns at [expr $i*$transmission_period_ms/1000] "$a($master) send_adv $i"
    }
} elseif {$mode eq "all-to-one"} {
    puts "ALL-TO-ONE"
    for {set i 0} {$i < $nPackets} {incr i} {
        for {set j 0} {$j < [expr $num_nodes + 1]} {incr j} {
            if {$j != $master} {
               # $ns at [expr $i*$transmission_period_ms/1000] "$a($j) send_adv [expr $i*$num_nodes + $j]"
            }
        }
    }

    $ns at 1.00 "$a(1) send_adv 1"
    $ns at 1.000367 "$a(2) send_adv 2"

    $ns at 1.000734 "$a(3) send_adv 3"
    
} 



# Stop simulation after some time that guarantees that all events have passed.
$ns at [expr (($nPackets+$ttl)*$transmission_period_ms/1000) + 5] finish




proc finish {} {
    global ns f nf val a master transmission_period_ms nPackets
    $ns flush-trace
    close $f
    close $nf
    puts [$a($master) set packets_received_]

    puts [expr [$a($master) set packets_received_]*369000/($transmission_period_ms*$nPackets)]
    

    exit 0
}

$ns run
