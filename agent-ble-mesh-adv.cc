#include "agent-ble-mesh-adv.h"
#include "random.h"
#include "address.h"
#include "ip.h"
#include "mac.h"

// TCL bindings
static class BleMeshAdvAgentClass : public TclClass {
public:
    BleMeshAdvAgentClass() : TclClass("Agent/BleMeshAdv") {}
    TclObject* create(int, const char*const*) {
        return (new BleMeshAdvAgent());
    }    
} class_BleMeshAdvAgent;


BleMeshAdvAgent::BleMeshAdvAgent(): Agent(PT_MESSAGE) {
    size_ = 46;
    defttl_= 10;
    jitterMax_us = 10000;
    recvd_pkts_buffer_size = 100;

    recvd_pkts_buffer = new CircularContainer(recvd_pkts_buffer_size);

    bind("packetSize_", &size_);
    bind("jitterMax_us_", &jitterMax_us);
    bind("recv_pkt_buffer_size_", &recvd_pkts_buffer_size);
    bind("default_ttl_", &defttl_);
}

int BleMeshAdvAgent::command(int argc, const char*const* argv) {
    return (Agent::command(argc, argv));
}

void BleMeshAdvAgent::relaymsg(Packet* p) {

    Packet* pkt = p->copy();

    HDR_IP(pkt)->ttl_--;
    double jitter_us = Random::random() % jitterMax_us;
    SimpleJitterTimer* jitterTimer = new SimpleJitterTimer(this, pkt);
    jitterTimer->start(jitter_us);
}


void BleMeshAdvAgent::sendmsg(int uid, const char *flags){
    Packet *p;
    p = allocpkt();

    //TODO Verify that the input parameters are correct

    HDR_CMN(p)->size() = size_;
    HDR_CMN(p)->uid() = uid;
    HDR_IP(p)->ttl() = defttl_;
    HDR_IP(p)->dst().addr_ = MAC_BROADCAST;
    HDR_IP(p)->dst().port_ = 1;

    double jitter_us = Random::random() % jitterMax_us;
    SimpleJitterTimer* jitterTimer = new SimpleJitterTimer(this, p);
    jitterTimer->start(jitter_us);

}


void BleMeshAdvAgent::sendmsg(Packet* p) {
    // Takes in a packet and sends it to the Routing Agent (target_)
    // This is made so that the SimpleJitterTimer can call it after the jitter is over
    double local_time = Scheduler::instance().clock();
    HDR_CMN(p)->timestamp() = local_time;
    target_->recv(p);

}



void BleMeshAdvAgent::recv(Packet* pkt, Handler*) {

    if (recvd_pkts_buffer->find(HDR_CMN(pkt)->uid_) && HDR_IP(pkt)->ttl_ < 0) {
        recvd_pkts_buffer->push(HDR_CMN(pkt)->uid_);
        relaymsg(pkt);
    }

    Packet::free(pkt); // TODO: Does this ruin things?
    // I.e. Is a new Packet object spawned for each node that picks it up?
    // It should be like this.

}

/*
int BleMeshAdvAgent::command(int argc, const char*const* argv) {
    return 
}
*/

// SimpleJitterTimer implementation

/* This timer is made to solve the problem of adding jitter to the packets
The jitter could have been added at another layer (e.g. MAC layer), but for simplicity was chosen
to be added here. For each packet to be sent a new Timer object will be created with the Agent and 
the Packet as parameters. It will schedule to call its Handle function after a certain delay.
The Handle function calls the "sendmsg(Packet* p)" routine from the agent and thus passing
the packet downstream. The object then delets itself.


*/

void SimpleJitterTimer::start(double jitter) {
    assert(jitter >= 0);
    Scheduler &s = Scheduler::instance();

    s.schedule(this, &dummyEvent, jitter/1e6);
}

void SimpleJitterTimer::handle(Event* e) {
    agent->sendmsg(pkt);
    delete this; //Is this safe?
}







void CircularContainer::push(int element) {
    if (size_ < max_size_) {
        buffer.push_back(element);
        size_++;
    }
    else {
        for (int i = 0; i<size_-1; i++) {
            buffer[i] = buffer[i+1];
        }
        buffer[size_-1] = element;
    }
}

int CircularContainer::find(int value) {
    for (int i = 0; i<size_; i++) {
        if (buffer[i] == value) {
            return 1;
        }
    }
    return 0;
}



