global texts

# Hovertips
set texts(hovertips_mode_label) "Choose the scenario you want to simulate.\nAll-to-on = 1 Gateway receiving packets from all nodes\nOne-to-all = 1 Master advertising packets to all nodes in Network"
set texts(hovertips_node_env_label) "Set the environment the nodes will be in. This will decide the radio propegation model"
set texts(hovertips_show_nam_label) "If true, Network Animator (NAM) will open after simulation is done. You can then view the layout of your network"
set texts(hovertips_num_nodes_x_label) "How many nodes in x-direction of the grid"
set texts(hovertips_num_nodes_y_label) "How many nodes in y-direction of the grid"
set texts(hovertips_spacing_label) "Distance between two adjacant nodes in the grid"
set texts(hovertips_traffic_interval_label) "At what interval will each traffic generating node generate a new advertisment packet"
set texts(hovertips_txp_label) "At what interval will each advertising node enter the Advertisment Window and, if it has any packet in the queue, send a packet on the radio"
set texts(hovertips_n_packets_label) "How many packets will each traffic generating node generate, i.e. how many traffic generation intervals will we simulate"
set texts(hovertips_packet_size_label) "What is the BLE payload of the packets. Access Address (32bit), PDU headers(8bit), CRC(8bit), is not included here"
set texts(hovertips_jitter_max_label)  "What is the maximum random jitter added to each advertisment interval"
set texts(hovertips_node_type_label) "Which IC is in the node"
set texts(hovertips_tx_power_label) "What is the transmitting power of the node"
set texts(hovertips_bw_label) "Pick the bitrate for the node (BLE = 1Mb)"
set texts(hovertips_ttl_label) "Time-To-Live for each packet"
set texts(hovertips_node_cache_size_label) "The size of the cache in each node storing the last received packets to avoid relaying duplicates"
set texts(hovertips_rx_dead_time_label) "The radio dead time after a packet receive"
set texts(hovertips_adv_roles_label) "The number of packets sent per Advertisement Window"
set texts(hovertips_retransmissions_label) "The number of times each packet is retransmitted"
set texts(hovertips_priority_label) "Original Packets: The node will push its _own_ packet to the head of the packet queue, thus giving its own packets higher priority than relays"
set texts(hovertips_allow_rx_postpone_label) "Accept an incoming packet so close to the next advertisment window that it will be postponed by receiving the packet in question"
set texts(hovertips_node_select_label) "Select an individual node to set node-specific parameters"
set texts(hovertips_node_master_label) "Select the Master/Gateway node"
set texts(hovertips_traffic_generator_label) "A traffic generator generates its own packets at the traffic generating interval"
set texts(hovertips_node_relay_label) "A relaying node will relay packets received that are not addressed to itself"
set texts(hovertips_clock_drift_label) "The clock drift in PPM (parts-per-million) of the clock source of the node"