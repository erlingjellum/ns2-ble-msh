#include "agent-ble-mesh-adv.h"
#include <stdlib.h>
#include <time.h>
#include "address.h"
#include "ip.h"
#include "mac.h"
#include "mac-simple-mesh.h"
#include "ll.h"
#include "dumb-agent.h"
#include <cmath>
#include <string> 

const bool DEBUG = false;

// TCL bindings
static class BleMeshAdvAgentClass : public TclClass {
public:
    BleMeshAdvAgentClass() : TclClass("Agent/BleMeshAdv") {}
    TclObject* create(int argc, const char*const* argv) {
        return (new BleMeshAdvAgent(argc, argv));
    }    
} class_blemshadv;


BleMeshAdvAgent::BleMeshAdvAgent(int argc, const char*const* argv): Agent(PT_MESSAGE) {

    //TODO: packets received and cache size should not be bound but should rather have getters to
    // return them. Changing them from the TCL scripts makes no sense
    //bind("clockDrift_ppm_", &clockDrift_ppm);
    bind("packetSize_", &size_);
    bind("jitterMax_us_", &jitterMax_us);
    bind("packets_received_", &packets_received);
    bind("ttl_", &ttl);
    bind("cache_size_", &node_cache_size);
    bind("node_id_", &node_id);
    bind("relay_", &relay);
    

    cache_misses = 0;
    duplicates_received = 0;

    int simple_hash = atoi(argv[0]+2);
    srand(time(NULL)+simple_hash);

    // Create the cache memory
    node_cache = new CircularContainer(node_cache_size);

    // Create the packet memory each node can max store 10 000 packets. Thats probably enough.
    recvd_pkts_buffer = new CircularContainer(10000);

    recvd_pkts_stats = new PacketsReceivedContainer();
    
}


void BleMeshAdvAgent::relaymsg(Packet* p) {


    Packet* pkt = p->copy(); // Copy the packet that is to be relayed so that we  send out a new one instead

    HDR_IP(pkt)->ttl_--; // Decrement the ttl
    HDR_CMN(pkt)->direction_ = hdr_cmn::DOWN; //Change the packet direction, we wanna send it DOWN again
    HDR_CMN(pkt)->iface_ = -1; //This means that its a relay msg
    if(DEBUG) {
        printf("Agent%s scheduling relay, packet_%u\n",name_, HDR_CMN(pkt)->uid());

    }
    sendmsg(pkt);
}


void BleMeshAdvAgent::sendmsg(int uid, const char *flags){
    Packet *p;
    p = allocpkt();

    //TODO Verify that the input parameters are correct
    HDR_CMN(p)->size() = size_;
    HDR_CMN(p)->uid() = uid;
    HDR_CMN(p)->iface_ = node_id;
    HDR_IP(p)->ttl() = ttl;
    HDR_IP(p)->dst().addr_ = MAC_BROADCAST;
    HDR_IP(p)->src().addr_ = node_id;


    // THIS PORT HAS TO BE FIXED
    HDR_IP(p)->dst().port_ = 42;

   
    //SimpleJitterTimer* jitterTimer = new SimpleJitterTimer(this, p);
    
    // Account for clock-drift
    //double clockDrift_offset = Scheduler::instance().clock() * clockDrift_ppm / 1000000;


    //Add this packet to the received packet buffer, so that we will not relay it
    // when we receive the relayed version back
    //recvd_pkts_buffer->push(uid);
    node_cache->push(uid);

    if(DEBUG) {
        
        printf("Agent%s scheduling packet,t=%f, %u\n",name_, Scheduler::instance().clock(), HDR_CMN(p)->uid());
        //printf("CLOCK DRIFT = %f\n", clockDrift_offset);
    }
    sendmsg(p);

    //jitterTimer->start(clockDrift_offset);

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

    if (!node_cache->find(HDR_CMN(pkt)->uid())) {
        // This packet is not in the (limited) node cache memory

        if (DEBUG) {
            double local_time = Scheduler::instance().clock();
            printf("Agent%s recv new packet_%u t=%f, ttl=%u\n", name_, HDR_CMN(pkt)->uid(),local_time, HDR_IP(pkt)->ttl());
        }

        node_cache->push(HDR_CMN(pkt)->uid_);

        if(!recvd_pkts_buffer->find(HDR_CMN(pkt)->uid())) {
            // This packet was really never received here
            packets_received++;
            recvd_pkts_buffer->push(HDR_CMN(pkt)->uid_);
            recvd_pkts_stats->add(pkt);

        } else {
            if (DEBUG) {
                printf("CACHE MISS !!!!!!!!!!\n");
            }

            duplicates_received++;
            
            cache_misses++;
        }

        if ((HDR_IP(pkt)->ttl()) > 0 && relay) {
            relaymsg(pkt);
        } 
        
    } else {
        if (DEBUG) {
            double local_time = Scheduler::instance().clock();
            printf("Agent%s recv OLD packet_%u,t=%f, ttl=%u\n", name_, HDR_CMN(pkt)->uid(),local_time, HDR_IP(pkt)->ttl());
        }
        duplicates_received++;

    }

    Packet::free(pkt); // TODO: Does this ruin things?
    // I.e. Is a new Packet object spawned for each node that picks it up?
    // It should be like this.

}


int BleMeshAdvAgent::command(int argc, const char*const* argv) {
    if (argc == 2) {
        if (strcmp(argv[1], "start-adv") == 0) {
            // This command will start off the advertisment interval clock in the MAC layer
            // uid = -1 => this is checked in MAC.recv and triggers the advertisement to begin
            sendmsg(-1,0);
            return TCL_OK;
        }
    }

    if (argc == 3) { // Send an advertisement message
        if (strcmp(argv[1], "schedule-adv") == 0) {
            sendmsg(atoi(argv[2]),0);
            return TCL_OK;
        }

        if (strcmp(argv[1], "get") == 0) {
            Tcl& tcl = Tcl::instance();

            if (strcmp(argv[2], "cache-misses") == 0) {
                tcl.resultf("%d", cache_misses);
                return TCL_OK;    
            }

            if (strcmp(argv[2], "duplicates-received") == 0) {
                tcl.resultf("%d", duplicates_received);
                return TCL_OK;
            }
            
        }

        
        
        
    } else if (argc == 4) {
        if (strcmp(argv[1], "sett") == 0) {
            if (strcmp(argv[2], "cache-size") == 0) { //Change the cache size (should only be called during initalization)
                node_cache_size = atoi(argv[3]);
                node_cache = new CircularContainer(node_cache_size);
                return TCL_OK;
            }

            if (strcmp(argv[2],"node-id") == 0) {
                node_id = atoi(argv[3]);
                return TCL_OK;
            }

            if (strcmp(argv[2], "ttl") == 0) {
                ttl = atoi(argv[3]);
                return TCL_OK;
            }
        }

        if (strcmp(argv[1], "get") == 0) {
            Tcl& tcl = Tcl::instance();
            if (strcmp(argv[2], "packets-received-from-node") == 0) {
                tcl.resultf("%d",recvd_pkts_stats->get(atoi(argv[3])));
                return TCL_OK;
            }

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




void SimpleJitterTimer::start(double jitter) {
    assert(jitter >= 0);
    Scheduler &s = Scheduler::instance();

    s.schedule(this, &dummyEvent, jitter/1000000);
}

void SimpleJitterTimer::handle(Event* e) {
    agent->sendmsg(pkt);
    delete this; //Is this safe?
}





*/

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



// Packets Recevied per node container


// A few thoughts:
// 1. Make Node ID a part of the construction of the agent (an int is passed as it is constructed). ID will
// also need to be a public variable of the agent
// 2. Edit the packet sending mechanism so that the SRC field is written with the node_id
// 3. Index the PacketsReceived with this node_id


void PacketsReceivedContainer::add(Packet* pkt) {
    
    for(int i = 0; i < size; i++)
    {
        if (pkts_recvd[i][0] == HDR_IP(pkt)->src().addr_) {
            pkts_recvd[i][1]++;
            return;
        }
    }
    
    // First packet we receive from this node
    std::vector<int> new_entry(2,1);
    new_entry[0] = HDR_IP(pkt)->src().addr_;
    pkts_recvd.push_back(new_entry);
    size++;
}


int PacketsReceivedContainer::get(int n_id){
    for(int i = 0; i < size; i++) {
        if (pkts_recvd[i][0] == n_id) {
            return pkts_recvd[i][1];
           
        }
    }
   return 0;
}
