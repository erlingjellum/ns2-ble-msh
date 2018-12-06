#include "ll.h"
#include "mac.h"
#include "mac-simple-mesh.h"
#include "cmu-trace.h"
#include <cmath>
#include <time.h>


const bool DEBUG = false;

//Binding the c++ class til otcl
static class MacSimpleMeshClass : public TclClass {
public:
    MacSimpleMeshClass() : TclClass("Mac/SimpleMesh") {}
    TclObject* create(int argc, const char*const* argv) {
        return new MacSimpleMesh(argc, argv);
    }
} class_macsimplemesh;


// Implementation of the MAC class
MacSimpleMesh::MacSimpleMesh(int argc, const char* const* argv) : Mac() {
    rx_state_ = tx_state_ = MAC_IDLE;
    tx_active_ = 0;
	advertise_waiting_ = false;

	send_queue = new PacketQueue();
    	waitTimer = new MacSimpleMeshWaitTimer(this);
    	sendTimer = new MacSimpleMeshSendTimer(this);
    	recvTimer = new MacSimpleMeshRecvTimer(this);
	advTimer = new MacSimpleMeshAdvertiseTimer(this);
	deadTimer = new MacSimpleMeshRXDeadTimer(this);
	powerMonitor = new SimplePowerMonitor(this);
    	busy_ = 0;
	relays = 0;
	col_dead = 0;
	col_ccrejection = 0;
	col_crc = 0;


	bind("jitter_max_us_", &jitter_max_us);
	bind("adv_interval_us_", &adv_interval_us);
	bind("retransmissions_", &retransmissions);
	bind("adv_roles_", &adv_roles);
	bind("dead_time_us_", &dead_time_us);
	bind("bandwidth_", &bandwidth);

}


int MacSimpleMesh::command(int argc, const char* const* argv) {
	Tcl& tcl = Tcl::instance();

	if(argc == 3) {
		if (strcmp(argv[1], "get") == 0) {
			if (strcmp(argv[2], "send-queue") == 0) {
				tcl.resultf("%d", send_queue->length());
				return TCL_OK;
			}

			if (strcmp(argv[2], "crc-collisions") == 0) {
				tcl.resultf("%d", col_crc);
				return TCL_OK;
			}

			if (strcmp(argv[2], "co-channel-rejections") == 0) {
				tcl.resultf("%d", col_ccrejection);
				return TCL_OK;
			}

			if (strcmp(argv[2], "dead-time-collisions") == 0) {
				tcl.resultf("%d", col_dead);
				return TCL_OK;
			}

			if (strcmp(argv[2], "relays") == 0) {
				tcl.resultf("%d", relays);
				return TCL_OK;
			}

		}
	}    

	

	return Mac::command(argc, argv);

    
}

void MacSimpleMesh::recv(Packet *p, Handler *h){
    /* Should be identical to MacSimple::recv() */

    struct hdr_cmn *hdr = HDR_CMN(p);
	/* let MacSimple::send handle the outgoing packets */
	if (hdr->direction() == hdr_cmn::DOWN) {
		
		if (hdr->uid() == -1) {
			// This is the signal to start off the advertising.
			// This is a wild hack
			if (DEBUG) {
				printf("MAC_%s starts advertising!\n", name_);
			}

			srand(time(NULL) + hdr->iface_); // Set the seed to the jitter generator
			double jitter_us = ((double) rand() / RAND_MAX)*jitter_max_us;
		
			advTimer->restart((jitter_us)/1000000);
			Packet::free(p);
			return;
		}

		if (hdr->iface_ == -1) {
			// This is a relaying message
			send_queue->enque(p);
			if (DEBUG) {
			//	printf("MAC_%s enqueus RELAY p_%d\n", name_, hdr->uid());
			}
			return;

		}
		
		send_queue->enqueHead(p);
		if (DEBUG) {
		//		printf("MAC_%s enqueus ORIGINAL p_%d\n", name_, hdr->uid());
		}
		return;
	}


	if (DEBUG) {
		double local_time = Scheduler::instance().clock();
		printf("t=%f. MAC_%s enter RECV  p = %d\n",local_time,name_, hdr->uid());

	}


	/* handle an incoming packet */
	if (tx_state_ == MAC_SEND)
	{
		if (DEBUG) {
			printf("MAC_%s busy with sending p_%d, p_%d=FAIL\n", name_, HDR_CMN(pktTx_)->uid(), hdr->uid());
		}
		// Update the power monitor
		powerMonitor->recordPowerLevel(p->txinfo_.RxPr, txtime(p));
		col_dead++;
		Packet::free(p);
		return;
	}

	if (rx_state_ == MAC_DEAD) {
		if (DEBUG) {
			printf("MAC_%s DEAD, p_%d=FAIL\n", name_, hdr->uid());
		}
		// Update power monitor
		powerMonitor->recordPowerLevel(p->txinfo_.RxPr, txtime(p));
		col_dead++;
		return;
	}

	if (rx_state_ == MAC_IDLE) {
		/*
		 * We aren't already receiving any packets, so go ahead
		 * and try to receive this one.
		 */

		// Check the powerMonitor
		
		// Check if we are too close to our TX window to accept it
		if(advTimer->busy()) {
			if((txtime(p) + (dead_time_us/1e6))>(advTimer->expire())) {
				if (DEBUG) {
					printf("MAC_%s dropped incoming packet because too close to TX window\n", name_);
				}
				powerMonitor->recordPowerLevel(p->txinfo_.RxPr, txtime(p));
				col_dead++;
				Packet::free(p);
				return;
			}
		}
		double powerLevel = powerMonitor->getPowerLevel();
		if (powerLevel > 0) {
			if ((p->txinfo_.RxPr /powerLevel)
			< p->txinfo_.CPThresh) {
				powerMonitor->recordPowerLevel(p->txinfo_.RxPr, txtime(p));
				printf("**********************Power monitor works: %.10f********************************\n", powerLevel);
				col_ccrejection++;
				return;
			}
		
		}
		
		// New packet is strong enough
		rx_state_ = MAC_RECV;
		pktRx_ = p;
		/* schedule reception of the packet */
		recvTimer->start(txtime(p));

		if (DEBUG) {
			printf("MAC_%s receiving, p_%d\n", name_, HDR_CMN(pktRx_)->uid());
			printf("PM = %.8f, p_%d = %.8f\n", powerMonitor->getPowerLevel(), HDR_CMN(pktRx_)->uid(), pktRx_->txinfo_.RxPr);
			
		}


	}
	else if (rx_state_ == MAC_RECV) {
		/*
		 * We are receiving a different packet, so decide whether
		 * the new packet's power is high enough to notice it.
		 */
		printf("pktRX_:%f p:%f CPThresh:%f", pktRx_->txinfo_.RxPr,p->txinfo_.RxPr,p->txinfo_.CPThresh);

		if (pktRx_->txinfo_.RxPr / p->txinfo_.RxPr
			>= p->txinfo_.CPThresh) {
			if(DEBUG) {
				printf("MAC_%s dropped p_%d. Already receving p_%d\n", name_, hdr->uid(), HDR_CMN(pktRx_)->uid());
				
    		}
			powerMonitor->recordPowerLevel(p->txinfo_.RxPr, txtime(p));
			col_ccrejection++;
			Packet::free(p);

		} else {

			// Update powerMonitor
			powerMonitor->recordPowerLevel(p->txinfo_.RxPr, txtime(p));
	
			/* power is high enough to result in collision */
			//printf("MAC_%s collision between p_%d and p_%d\n", name_, HDR_CMN(pktRx_)->uid(),hdr->uid());
			/*
			 * look at the length of each packet and update the
			 * timer if necessary
			 */

			if(DEBUG) {
				printf("MAC_%s COLLISION p_%d and p_%d\n", name_, hdr->uid(), HDR_CMN(pktRx_)->uid());
    		}
			
			// Update error flag on the current received packet
			HDR_CMN(pktRx_)->error() = 1;
			Packet::free(p);
			col_crc++;

		}
	} else {
		printf("ERROR IN MAC RECV. PACKET NOT CAUGHT BY ANY IF CLAUSE\n");
	}
}

void MacSimpleMesh::advertise() {
	// This will be called at each advertise interval and will send the first packet in the queue.
	if(tx_state_ != MAC_IDLE) {
		printf("TX IS BUSY when calling advertise! %d\n", int (tx_state_));
		advertise_waiting_ = true; //It is DEAD after a receive
		return;
	}
	
	if(rx_state_ == MAC_RECV) {
		// Assume we have RX priority then postpone the TX slot until after
		// we have finished receiving this packet
		printf("A RX is postponing the advertisement slot\n");
		advertise_waiting_ = true;
		return;
	}

	if (send_queue->length()) {
		// If we have some packets in the queue send them


		if (DEBUG) {
			double local_time = Scheduler::instance().clock();
			printf("t=%f. MAC_%s enter ADVERTISE  queue = %d\n",local_time,name_, send_queue->length());

		}


		pktTx_ = send_queue->deque();
		hdr_cmn* ch = HDR_CMN(pktTx_);

		ch->txtime_ = ((double) ch->size_)/this->bandwidth;
			
		tx_state_ = MAC_SEND;
		tx_active_ = 1;

		if (ch->iface_ == -1) {
			relays++;
		}
		sendTimer->restart(ch->txtime_);
		waitHandler(); //Starts packet transmission this function should be renamed
		// Schedule the finishing of packet transmission
		
		
	}

	// Schedule next advertisement;
	double jitter_us = ((double) rand() / RAND_MAX)*jitter_max_us;
	//printf("jitter = %f\n", jitter_us);
	advTimer->restart((adv_interval_us + jitter_us)/1000000);

}

double MacSimpleMesh::txtime(Packet *p) {
    struct hdr_cmn *ch = HDR_CMN(p);
    double t = ch->txtime();
    if (t < 0.0) {
        t = 0.0;
    }
    return t;
}


void MacSimpleMesh::recvHandler() {


    hdr_cmn *ch = HDR_CMN(pktRx_);
    Packet* p = pktRx_;
    MacState state = rx_state_;
    pktRx_ = 0;

	

    // Get the destination from the packet header
    int dst = hdr_dst((char*) HDR_MAC(p));
    

    if (tx_active_) {
        // We are currently sending another packet
        // TODO THIS SHOULD BE LOGGED
		printf("Mac_%s sending p_%d while receiving p_%d ERROR ERRROR ERRROR\n", name_, HDR_CMN(pktTx_)->uid(), HDR_CMN(p)->uid());
        Packet::free(p);
    }

    else if (state == MAC_COLL) {
        // Recv collision
		//printf("MAC%s dropped incoming package_%u due to receive collision\n", name_, HDR_CMN(p)->uid());
        drop(p, DROP_MAC_COLLISION);
    }

    else if (dst != index_ && (u_int32_t)dst != MAC_BROADCAST) {
		printf("MAC%s dropped incoming package_%u due to wrong DST\n", name_, HDR_CMN(p)->uid());
        Packet::free(p);
    }

    else if(ch->error()) {
        // Packet arrived with errors
        // Check that collisions don't result in this
		//printf("MAC%s dropped incoming package_%u due to packet-errors\n", name_, HDR_CMN(p)->uid());
        drop(p, DROP_MAC_PACKET_ERROR);
    }
    else {
        // Pass packet to LL
		if (DEBUG) {
			printf("MAC_%s sucessfully received p_%d\n", name_, HDR_CMN(p)->uid());
		}
		uptarget_->recv(p, (Handler*) 0); 
    }

	// Set Radio to DEAD after the packet receive
	rx_state_ = MAC_DEAD;
	tx_state_ = MAC_DEAD;

	deadTimer->restart(dead_time_us/1000000);

}

void MacSimpleMesh::waitHandler() {
	
	if (rx_state_ == MAC_RECV) {
		printf(" WHAT THE FUCK ASDJKASDJJAKKKKKKKKKKKKKKKS\n");
	}
	
    tx_state_ = MAC_SEND;
	tx_active_ = 1;

	if (DEBUG) {
		double local_time = Scheduler::instance().clock();
		printf("MAC_%s sending packet_%d, t=%f, queue-length = %d\n", name(), HDR_CMN(pktTx_)->uid(),local_time, send_queue->length());
	}
	

	downtarget_->recv(pktTx_, txHandler_);
}

void MacSimpleMesh::sendHandler() {
    //Handler *h = txHandler_;
	//Packet *p = pktTx_;
	if (DEBUG) {

		double local_time = Scheduler::instance().clock();
		printf("MAC_%s finished sending p_%d, t=%f, queue=%d\n", name_, HDR_CMN(pktTx_)->uid(),local_time, send_queue->length());
	}
	pktTx_ = 0;
	txHandler_ = 0;
	tx_state_ = MAC_IDLE;
	tx_active_ = 0;

	// I have to let the guy above me know I'm done with the packet
	//h->handle(p); // ERLING: Seems unneccesary

}

void MacSimpleMesh::deadTimeHandler() {
	tx_state_ = MAC_IDLE;
	rx_state_ = MAC_IDLE;

	if (DEBUG) {
		double local_time = Scheduler::instance().clock();
		printf("MAC_%s Dead time over: t=%f",name_, local_time);
	}
	
	if (advertise_waiting_) {
		// The packet recv causing this dead time was postponing an advertisement slot.
		// Move to advertisement
		double jitter_us = ((double) rand() / RAND_MAX)*jitter_max_us;
		advTimer->restart(jitter_us/1000000);
	}
}


//  Timers

void MacSimpleMeshTimer::restart(double time)
{
	if (busy_)
		stop();
	start(time);
}

	

void MacSimpleMeshTimer::start(double time)
{
	Scheduler &s = Scheduler::instance();

	assert(busy_ == 0);
	
	busy_ = 1;
	stime = s.clock();
	rtime = time;
	assert(rtime >= 0.0);

	s.schedule(this, &intr, rtime);
}

void MacSimpleMeshTimer::stop(void)
{
	Scheduler &s = Scheduler::instance();

	assert(busy_);
	s.cancel(&intr);
	
	busy_ = 0;
	stime = rtime = 0.0;
}


void MacSimpleMeshWaitTimer::handle(Event *)
{
	busy_ = 0;
	stime = rtime = 0.0;

	mac->waitHandler();
}

void MacSimpleMeshSendTimer::handle(Event *)
{
	busy_ = 0;
	stime = rtime = 0.0;

	mac->sendHandler();
}

void MacSimpleMeshRecvTimer::handle(Event *)
{
	busy_ = 0;
	stime = rtime = 0.0;

	mac->recvHandler();
}

void MacSimpleMeshAdvertiseTimer::handle(Event *)
{
	busy_ = 0;
	stime = rtime = 0.0;
	mac->advertise();
}


void MacSimpleMeshRXDeadTimer::handle(Event *) {
	busy_ = 0;
	stime = rtime = 0.0;
	mac->deadTimeHandler();
}



void SimplePowerMonitor::recordPowerLevel(double signalPower, double duration) {
	interf timerEntry;
	timerEntry.Pt = signalPower;
	timerEntry.end = Scheduler::instance().clock() + duration;

	list<interf>::iterator i;
	for(i=interfList.begin(); i != interfList.end() && i->end <= timerEntry.end; i++) { }
	interfList.insert(i, timerEntry);

	// Reschedule
	resched((interfList.begin())->end - Scheduler::instance().clock());

	// Update power level if signalPower > powerLevel
	if(signalPower > powerLevel) {powerLevel=signalPower;}
}


double SimplePowerMonitor::getPowerLevel() {
	return powerLevel;
}

void SimplePowerMonitor::expire(Event *) {
	double time = Scheduler::instance().clock();
	bool new_power_level = false;

	list<interf>::iterator i;
	i = interfList.begin();
	while(i != interfList.end() && i->end <= time) {
		if (i->Pt >= powerLevel) {new_power_level = true;}
		interfList.erase(i++);
	}

	if (!interfList.empty()) {
		resched((interfList.begin()->end) - time);
		if (new_power_level) {
			powerLevel = 0;
			for(i=interfList.begin(); i != interfList.end(); i++) {
				if (i->Pt > powerLevel) {
					powerLevel = i->Pt;
				}
			}
		}
	} else { powerLevel = -1;}
}
