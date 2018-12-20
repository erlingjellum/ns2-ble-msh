# Bluetooth Mesh Simulator 

Version 0.4


## Quick start
Open up the folder ns2-ble-msh on the desktop and press SIMULATOR.sh to start the simulator




## Explanation of input parameters



## Explanation of results



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




