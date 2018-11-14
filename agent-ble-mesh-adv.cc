#include "agent-ble-mesh-adv.h"
#include <stdlib.h>
#include <time.h>
#include "address.h"
#include "ip.h"
#include "mac.h"
#include "mac-simple-mesh.h"
#include <cmath>
#include <string> 

const bool DEBUG = true;

// TCL bindings
static class BleMeshAdvAgentClass : public TclClass {
public:
    BleMeshAdvAgentClass() : TclClass("Agent/BleMeshAdv") {}
    TclObject* create(int argc, const char*const* argv) {
        return (new BleMeshAdvAgent(argc, argv));
    }    
} class_blemshadv;


BleMeshAdvAgent::BleMeshAdvAgent(int argc, const char*const* argv): Agent(PT_MESSAGE) {

    //THIS NEEDS TO GO ELSEWHERE
    bind("clockDrift_ppm_", &clockDrift_ppm);
    bind("packetSize_", &size_);
    bind("jitterMax_us_", &jitterMax_us);
    bind("packets_received_", &packets_received);
    bind("ttl_", &defttl_);

    recvd_pkts_buffer_size = 100; // NOTE THIS SIZE
    recvd_pkts_buffer = new CircularContainer(recvd_pkts_buffer_size);

    // FIND THE NUMBER IN ARGV[0] and FUCKING EXTRACT IT
    int simple_hash = atoi(argv[0]+2);
    srand(time(NULL)+simple_hash);
}


void BleMeshAdvAgent::relaymsg(Packet* p) {


    Packet* pkt = p->copy(); // Copy the packet that is to be relayed so that we  send out a new one instead

    HDR_IP(pkt)->ttl_--; // Decrement the ttl
    HDR_CMN(pkt)->direction_ = hdr_cmn::DOWN; //Change the packet direction, we wanna send it DOWN again
    double jitter_us = 0;

    if (jitterMax_us > 0) { 
        jitter_us = ((double) rand() / RAND_MAX) * jitterMax_us;
    }
    // Start a new timer for sending the packet later 
    SimpleJitterTimer* jitterTimer = new SimpleJitterTimer(this, pkt);

    if(DEBUG) {
        printf("Agent%s scheduling relay, packet_%u, jitter = %f\n",name_, HDR_CMN(pkt)->uid(), jitter_us/1000);

    }
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

    // THIS PORT HAS TO BE FIXED
    HDR_IP(p)->dst().port_ = 42;

    // Generate a random jitter
    double jitter_us = 0;

    if (jitterMax_us > 0) { 
        jitter_us = rand() % jitterMax_us;
    }
    SimpleJitterTimer* jitterTimer = new SimpleJitterTimer(this, p);
    
    // Account for clock-drift
    double clockDrift_offset = Scheduler::instance().clock() * clockDrift_ppm / 1000000;


    //Add this packet to the received packet buffer, so that we will not relay it
    // when we receive the relayed version back
    recvd_pkts_buffer->push(uid);

    if(DEBUG) {
        
        printf("Agent%s scheduling packet,t=%f, %u, jitter = %f\n",name_, Scheduler::instance().clock(), HDR_CMN(p)->uid(),jitter_us/1000);
        printf("CLOCK DRIFT = %f\n", clockDrift_offset);
    }
    jitterTimer->start(jitter_us+clockDrift_offset);

}


void BleMeshAdvAgent::sendmsg(Packet* p) {
    // Takes in a packet and sends it to the Routing Agent (target_)
    // This is made so that the SimpleJitterTimer can call it after the jitter is over
    double local_time = Scheduler::instance().clock();
    HDR_CMN(p)->timestamp() = local_time;

    if(DEBUG) {
        printf("Agent%s sending packet_%u,t=%f\n",name_, HDR_CMN(p)->uid(), local_time);
    }
    target_->recv(p);

}



void BleMeshAdvAgent::recv(Packet* pkt, Handler*) {

    if (!recvd_pkts_buffer->find(HDR_CMN(pkt)->uid())) {

        if (DEBUG) {
            double local_time = Scheduler::instance().clock();
            printf("Agent%s recv new packet_%u t=%f, ttl=%u\n", name_, HDR_CMN(pkt)->uid(),local_time, HDR_IP(pkt)->ttl());
        }
        packets_received++;
        recvd_pkts_buffer->push(HDR_CMN(pkt)->uid_);

        if ((HDR_IP(pkt)->ttl()) > 0) {
            relaymsg(pkt);
        }
        
    } else {
        if (DEBUG) {
            double local_time = Scheduler::instance().clock();
            printf("Agent%s recv OLD packet_%u,t=%f, ttl=%u\n", name_, HDR_CMN(pkt)->uid(),local_time, HDR_IP(pkt)->ttl());
        }

    }

    Packet::free(pkt); // TODO: Does this ruin things?
    // I.e. Is a new Packet object spawned for each node that picks it up?
    // It should be like this.

}


int BleMeshAdvAgent::command(int argc, const char*const* argv) {
    if (argc == 3) {
        if (strcmp(argv[1], "send_adv") == 0) {
            sendmsg(atoi(argv[2]),0);
            return TCL_OK;
        }
    } 

    return Agent::command(argc, argv);
}


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

    s.schedule(this, &dummyEvent, jitter/1000000);
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



