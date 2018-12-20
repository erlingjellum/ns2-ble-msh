#include "mac-btle-mesh.h"
#include <cmath>
#include <time.h>


#define DEBUG false


//Binding the c++ class til otcl
static class MacBTLEmeshClass : public TclClass {
public:
    MacBTLEmeshClass() : TclClass("Mac/BTLEmesh") {}
    TclObject* create(int argc, const char*const* argv) {
        return new MacBTLEmesh(argc, argv);
    }
} class_macbtlemesh;


MacBTLEmesh::MacBTLEmesh(int argc, const char*const* argv) : Mac(){
    originator_queue = new PacketQueue();
    relay_queue = new PacketQueue();
    ack_queue = new PacketQueue();
    adv_timer = new AdvertiseTimer(this);

    // Stats
    n_relays = 0;
    originator_overflows = 0;
    relay_overflows = 0;
    ack_overflows = 0;

    bind("jitter_max_us_", &jitter_max_us);
    bind("adv_interval_us_", &adv_interval_us);
    bind("adv_roles_", &adv_roles);
    bind("originator_queue_max_size_", &originator_queue_max_size);
    bind("relay_queue_max_size_", &relay_queue_max_size);
    bind("ack_queue_max_size_", &ack_queue_max_size);

    // Seed the RNG
    srand(time(NULL) + atoi(argv[0]+2));

    //Calculate jitter
    double jitter_us = ((double) rand() / RAND_MAX)*jitter_max_us;
    adv_timer->resched((adv_interval_us + jitter_us) / 1e6);

    
}

void MacBTLEmesh::recv(Packet* p, Handler *h) {
    struct hdr_cmn *ch = HDR_CMN(p);

    // Outgoing Packet
    if(ch->direction() == hdr_cmn::DOWN) {
        // Packet is from Host layer

        // Update the txtime based on the bitrate
        ch->txtime_ = ((double) ch->size_)/bandwidth();
       if(ch->iface_ == -1) {
            // Its a relay
            if (relay_queue->length() < relay_queue_max_size) {

                if (DEBUG) {
                    double local_time = Scheduler::instance().clock();
                    printf("t=%f. MAC_%s add p=%i to RELAY_QEUE\n",local_time,name_, ch->uid());
                }

                relay_queue->enque(p);

                
            } else {
                relay_overflows++;
            }
        } else {
            // its an original packet from this Host
            if (originator_queue->length() < originator_queue_max_size) {
                
                if (DEBUG) {
                    double local_time = Scheduler::instance().clock();
                    printf("t=%f. MAC_%s add p=%i to ORIGINATOR_QUEUE\n",local_time,name_, ch->uid());
                }

                originator_queue->enque(p);

                
            } else {
                originator_overflows++;
            }
        }
        return;
    }


    // Incoming Packet
    if (ch->direction() == hdr_cmn::UP) {
        // Check for errors
        if (ch->error()) {
            // Ask for retransmission?
            Packet::free(p);
            return;
        }
        uptarget_->recv(p,h);
    }
}

int MacBTLEmesh::command(int argc, const char* const* argv) {
	Tcl& tcl = Tcl::instance();
    if(argc == 3) {
		if (strcmp(argv[1], "get") == 0) {
			if (strcmp(argv[2], "originator-queue-overflows") == 0) {
				tcl.resultf("%d", originator_overflows);
				return TCL_OK;
			}

            if (strcmp(argv[2], "ack-queue-overflows") == 0) {
				tcl.resultf("%d", ack_overflows);
				return TCL_OK;
			}

            if (strcmp(argv[2], "relay-queue-overflows") == 0) {
				tcl.resultf("%d", relay_overflows);
				return TCL_OK;
			}

			if (strcmp(argv[2], "relays") == 0) {
				tcl.resultf("%d", n_relays);
				return TCL_OK;
			}

		}
	}    
	return Mac::command(argc, argv);
}


void MacBTLEmesh::handle_AdvertiseTimeout() {
    // Send advertisements
    if (originator_queue->length() > 0 || relay_queue->length() > 0) {
        Packet * p;
        if (p = originator_queue->deque()) {
            downtarget_->recv(p);
        } else if (p = relay_queue->deque()) {
            n_relays++;
            downtarget_->recv(p);
        }

         if (DEBUG) {
            double local_time = Scheduler::instance().clock();
            printf("t=%f. MAC_%s starts Adv Window\n",local_time,name_);
        }
    
    }
    // Schedule the next advertisement window
    double jitter_us = ((double) rand() / RAND_MAX)*jitter_max_us;
    adv_timer->resched((adv_interval_us + jitter_us) / 1e6);
}


/********************************************************************************/

void AdvertiseTimer::expire(Event *) {
    mac->handle_AdvertiseTimeout();
}

