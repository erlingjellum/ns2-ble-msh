#ifndef ns_agent_ble_mesh_adv_h
#define ns_agent_ble_mesh_adv_h

#include "agent.h"
#include "packet.h"
#include "messpass.h"
#include <vector>

class CircularContainer;

class BleMeshAdvAgent : public Agent {
public:
    BleMeshAdvAgent(int argc, const char*const* argv);
    void relaymsg(Packet* pkt);
    void sendmsg(int uid, const char *flags = 0);
    void sendmsg(Packet* p);
    void recv(Packet* p, Handler*);
    int command(int argc, const char*const* argv);

private:
    unsigned int jitterMax_us; //Maximum jitter for the agent
    int clockDrift_ppm; //The constant clock-drift due to variance between crystals on the microcontrollers
    unsigned int packets_received; 
    int recvd_pkts_buffer_size; 
    CircularContainer* recvd_pkts_buffer; //buffer where packet-ids of previously recived packets are stored
};

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

#endif
