#ifndef ns_agent_ble_mesh_adv_h
#define ns_agent_ble_mesh_adv_h

#include "agent.h"
#include "packet.h"
#include "messpass.h"
#include "connector.h"
#include <vector>

class CircularContainer;
class PacketsReceivedContainer;

class BleMeshAdvAgent : public Agent {
    // To get access down to MAC layer i need to befriend the following intermediate classes
public:
    BleMeshAdvAgent(int argc, const char*const* argv);
    void relaymsg(Packet* pkt);
    void sendmsg(int uid, const char *flags = 0);
    void sendmsg(Packet* p);
    void recv(Packet* p, Handler*);
    int command(int argc, const char*const* argv);

protected:
    unsigned int jitterMax_us; //Maximum jitter for the agent
    //int clockDrift_ppm; //The constant clock-drift due to variance between crystals on the microcontrollers
    int packets_received; 
    int duplicates_received;
    int node_id;
    int ttl;
    int node_cache_size;
    int recvd_pkts_buffer_size;
    int relay; // Is relay activated for this node? 
    int n_relays;
    int cache_misses;
    CircularContainer* recvd_pkts_buffer; //buffer where packet-ids of previously recived packets are stored
    CircularContainer* node_cache; // Modelling the node cache memory for storing prviously received packets to prevent
    PacketsReceivedContainer* recvd_pkts_stats; //Statstics over where the packets are from
    // relaying packets several times.
};

/*
class SimpleJitterTimer: public Handler {
public:
	SimpleJitterTimer(BleMeshAdvAgent* a, Packet* p): agent(a), pkt(p) {}
	void handle(Event *e);
	void start(double time);

private:
	BleMeshAdvAgent* agent;
    Packet* pkt;
    Event dummyEvent; // This is needed to have something to pass to the scheduler
};

*/

// Class made for storing the received packets in the MAC layer of each mesh node.
// If performance is an issue, we might make improvements here.
class CircularContainer {
public:
    CircularContainer(int max_size) : max_size_(max_size), size_(0) {}
    void push(int element);
    int find(int value);

private:
    std::vector<int> buffer;
    int max_size_;
    int size_;

};

class PacketsReceivedContainer {
public:
    PacketsReceivedContainer() : size(0) {}
    void add(Packet* pkt);
    int get(int n_id);
    

private:
    std::vector<std::vector<int> > pkts_recvd;
    int size;
};

#endif
