# Bluetooth Mesh Simulator 

Version 0.4


## Quick start
Open up the folder ns2-ble-msh on the desktop and press SIMULATOR.sh to start the simulator




## Explanation of input parameters
Simulation Mode: Choose the scenario you want to simulate. All-to-one: Gateway receiving packets from all nodes. One-to-all: Master advertising packets to all nodes in Network
Node Environment: Set the environment the nodes will be in. This will decide the radio propegation model
Show Graphic Visualization: If true, Network Animator (NAM) will open after simulation is done. You can then view the layout of your network
Node Grid Size X: How many nodes in x-direction of the grid
Node Grid Size Y: How many nodes in y-direction of the grid
Distance Between Nodes: Distance between two adjacant nodes in the grid
Traffic Generation Interval: At what interval will each traffic generating node generate a new advertisment packet
Advertisement Interval: At what interval will each advertising node enter the Advertisment Window and, if it has any packet in the queue, send a packet on the radio
Number of packets sent per node: How many packets will each traffic generating node generate, i.e. how many traffic generation intervals will we simulate
Payload size: What is the BLE payload of the packets. Access Address (32bit), PDU headers(8bit), CRC(8bit), is not included here
Max Jitter: What is the maximum random jitter added to each advertisment interval
Node IC: Which IC is in the node
TX power: What is the transmitting power of the node
Bitrate: Pick the bitrate for the node (BLE = 1Mb)
TTL: Time-To-Live for each packet
Cache Size: The size of the cache in each node storing the last received packets to avoid relaying duplicates
Originator Queue size: The max-size of the queue for originator packets
Relay Queue Size: Max-size for the packet queue for relay-packets
Radio Dead-Time after receive: The radio dead time after a packet receive
Advertisement Roles: Number of advertising roles running on the node
Retransmissions: The number of times each packet is retransmitted
Priority: Will Originator packets or Relayed packets be prioritized
Original Packets: The node will push its _own_ packet to the head of the packet queue, thus giving its own packets higher priority than relays
Allow RX to postpone Advertisment Window: Accept an incoming packet so close to the next advertisment window that it will be postponed by receiving the packet in question
Node: Select an individual node to set node-specific parameters
Gateway: Pick the selected node as the Master/Gateway node
Traffic Generator: A traffic generator generates its own packets at the traffic generating interval
Relay: A relaying node will relay packets received that are not addressed to itself


## Explanation of results
First the results for the Gateway is showed, then for all the remaining nodes. The result variables are:
Packets received: Unique packets successfully received at this node, also includes broadcasting packets.
Packets received at Gateway: Number of originator packets from this node that where successfully received at the gateway
Duplicates received: Duplicate packets successfully received at this node.
Throughput (Gateway): The total throughput INTO the gateway
Throughput (Node): The total throughput of originator packets from this node to the gateway
Originator Queue Overflows: Number of overflows in the originator queue of this node
Relay Queue Overflows: Number of overflows/dropped packets in the relay queue of this node
Relayed packets: Number of packets this node relayed
Cache-misses: Number of times this node mistook a received duplicate for a unique packet due to cache-overflow
CRC-collisions: Number of packets dropped due to CRC error (due to a collision). This number include BOTH the packet with the CRC error and all the packets that had an on-air collision that resulted in bitflips
Co-Channel-Rejections: Number of packets dropped because the node was already receiving a stronger packet
Dead-Time-Collisions: Number of packets dropped because the radio was Dead when they arrived
Collision while TXing: Number of packets dropped because the radio was TXing a packet when they arrived
Collision while ramp-up/ramp-down: Number of packets dropped because the radio was in Ramp-Up/Ramp-Down



## Explanation of model
The Simulator used is NS2 which allows you to model the whole protocol stack. I have made a simpler version of the BLE Mesh stack.
We have three custom layers, starting from bottom up.

WirelessPHYBTLE (PHY):
This models the Radio Peripheral. It models the radio dead time after a receive, ramp up/ramp down delay for
switching between RX and TX. Its default state is scanning, and it is not possible to set a smaller Scan Window.
It keeps a statistic, which is printed in the Result page, of failed receptions. It keeps track of:
col_dead = packets dropped because radio was dead
col_tx = packets dropped because radio was tx-ing
col_crc = packets failed because of collision and bit flips (this number includes the packets received with bitflips AND the packets that caused the bitflips)
col_ccr = Co-channel rejections. Packets dropped because of other, stronger, packets being received or a strong background noise
col_ramp = packets dropped because radio was ramping between TX and RX.

If a higher layer hands a packet to the PHY, it will stop whatever it is doing (even packet reception), and ramp up to TX and send that packet.
PHY only supports single channel transmission and reception.


Mac/BTLEmesh (MAC).
This layer represent the Link Layer of the BTLE Mesh protocol stack. It controls the advertisement window of the node 
and it keeps the queues of outgoing packets. The Advertisment Interval is specified as an input parameters, so is jitter.
The MAC schedules one Adv Window into the future, adding a random jitter each time. In each Adv Window the MAC sends ONE
packet down to PHY if he has any in the queues. If not he does nothing and the PHY stays in SCAN.
The MAC keeps one queue for Originator Packets (originating from an Agent attached to this Node) and one for Relays.
The sizes of these queues are specified by the user. MAC will always empty the Originator queue before he relays anything.
The MAC receives successfully received packets from PHY, if there is a CRC error, he drops them (no request for retransmission).
If everything OK, he sends them upwards to the Role-layers.
The MAC also keeps track of
n_originator_overflows = Number of originator packets that were dropped due to overflow of the queue
n_relay_overflows = Number of relay packets that where dropped due to overflow

Agent/BLEMeshAdvAgent (AGENT)
The AGENT represents a Role of the Mesh node. We currently only support one role per node. The AGENT receives 
packets from the MAC. Received packets are added to a limitied cache. If ta packet is not addressed to him, 
and if it is not already in the cache (previously received) and he is configured for relays he will send it down to the MAC as a relay. 
The AGENT keeps statistics over:
All unique packets received
n_duplicates_received = number of duplicate packets received
cache_misses = number of times the agent mistook a duplicate for an unique due too limited cache size

The AGENT, if he is a Traffic Generator (input parameter), will generate a new broadcasting packet at each 
Traffic Generation Interval. THe packet is sent down to the MAC which queues it, and eventually 
sends it down to the PHY which puts it out on the channel.




