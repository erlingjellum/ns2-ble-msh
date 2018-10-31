set num_nodes_x 2
set num_nodes_y 2
set num_nodes [expr $num_nodes_x*$num_nodes_y]
set spacing_m 1 ;# Spacing between the nodes in the grid

set transmission_period_ms 100
set nPackets               10
set jitterMax_ms           10
set ttl                    10
set clock_drift            0

set mode                "one-to-all" ;# Simulation mode
set master                  0  ;#In a one-to-all or all-to-one which node number is the "one"

Mac/Simple set bandwidth_ 1Mb

Propagation/Shadowing set pathlossExp_ 6.0
Propagation/Shadowing set std_db_ 1.0
Propagation/Shadowing set dist0_ 1.0
Propagation/Shadowing set seed_ 0

Mac set bandwidth_ 1000kbps


Phy/WirelessPhy set CPThresh_ 0.01
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
set size_x              500
set size_y              500



set ns [new Simulator]

set f [open simple-adv.tr w]
$ns trace-all $f

$ns use-newtrace

# set up topography object
set topo       [new Topography]

$topo load_flatgrid $size_x $size_y

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
                -propType $val(prop) \
                -phyType $val(netif) \
                -topoInstance $topo \
                -agentTrace ON \
                -routerTrace OFF \
                -macTrace ON \
                -movementTrace OFF \
                -channel [new $val(chan)] \
                -energyModel val(energy) \
                -rxPower val(rxPower) \
                -txPower val(txPower)\
                -initialEnergy 0.1 




for {set i 0} {$i < $num_nodes_x} {incr i} {
    for {set j 0} {$j < $num_nodes_y} {incr j} {
        set index [expr ($i*$num_nodes_x)+$j];#calculate index in 1-D node array
        puts $index
        set n($index) [$ns node];# New node object
        
        # Set the physical position of the node, only based on spacing
        $n($index) set X_ $i*$spacing_m;
        $n($index) set Y_ $j*$spacing_m;
        $n($index) set Z_ 0
        
        # Attach Transport Protocol Layer to each node
        set a($index) [new Agent/BleMeshAdv]
        $n($index) attach $a($index) $MESSAGE_PORT
    }
}

# Setting up the periodic advertisement events:
# Choose between a few predefined "modes"

if { [string equal mode "one-to-all"] == 0 } {

    for {set i 0} {$i < $nPackets} {incr i} {

        # Setting up the advertisement packet sends:
        # See agent-ble-mesh-adv.cc for the implementation of "send_adv". 
        # The only parameter is a unique packet identifier that has to be unique for each
        # packet.
        # Jitter (and soon clock drift) will automatically be added in the TP layer. 
    
        #$ns at [expr $i*$transmission_period_ms/1000] "$a($master) send_adv $i"
    }
}


$ns at 1.0 "$a($master) send_adv 1"
$ns at 2.5 "$a($master) send_adv 2"
$ns at 3.0 "$a($master) send_adv 3"


# Stop simulation after some time that guarantees that all events have passed.
$ns at [expr (($nPackets+$ttl)*$transmission_period_ms/1000) + 5] finish

proc finish {} {
    global ns f val
    $ns flush-trace
    close $f
    

    exit 0
}

$ns run
