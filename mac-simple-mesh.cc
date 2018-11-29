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

	send_queue = new PacketQueue();
    waitTimer = new MacSimpleMeshWaitTimer(this);
    sendTimer = new MacSimpleMeshSendTimer(this);
    recvTimer = new MacSimpleMeshRecvTimer(this);
    busy_ = 0;

	bind("jitter_max_us_", &jitter_max_us);
	//bind("bandwidth_", &bandwidth);

	// Set the seed to the jitter-generator
	srand(time(NULL) + atoi(argv[0]+2));
}


void MacSimpleMesh::recv(Packet *p, Handler *h){
    /* Should be identical to MacSimple::recv() */

    struct hdr_cmn *hdr = HDR_CMN(p);
	/* let MacSimple::send handle the outgoing packets */
	if (hdr->direction() == hdr_cmn::DOWN) {
		
		send_queue->enque(p);
		

		if (!tx_active_) {
			if (DEBUG) {
				printf("Mac_%s adding p_%d to send_queue len=%d\n", name_, hdr->uid(), send_queue->length());
			}
			send_from_queue();
		} else {
			if (DEBUG) {
				printf("Mac_%s busy with p_%d adding p_%d to send_queue len=%d\n", name_, HDR_CMN(pktTx_)->uid(), hdr->uid(), send_queue->length());
			}
		}
		return;
	}

	/* handle an incoming packet */

	/*
	 * If we are transmitting, then set the error bit in the packet
	 * so that it will be thrown away
	 */

	// If our node is in advertisement mode. Just drop packet
	
	// in full duplex mode it can recv and send at the same time
	if (tx_active_)
	{
		hdr->error() = 1;
		if (DEBUG) {
			printf("MAC_%s busy with p_%d, p_%d=FAIL\n", name_, HDR_CMN(pktTx_)->uid(), hdr->uid());
		}
		Packet::free(p);
		return;
	}

	/*
	 * check to see if we're already receiving a different packet
	 */
	
	if (rx_state_ == MAC_IDLE) {
		/*
		 * We aren't already receiving any packets, so go ahead
		 * and try to receive this one.
		 */

		rx_state_ = MAC_RECV;
		pktRx_ = p;
		/* schedule reception of the packet */
		recvTimer->start(txtime(p));
	} else {
		/*
		 * We are receiving a different packet, so decide whether
		 * the new packet's power is high enough to notice it.
		 */


		if (pktRx_->txinfo_.RxPr / p->txinfo_.RxPr
			>= p->txinfo_.CPThresh) {

				
		           //     printf ("\n pktRx_->txinfo_.RxPr %f p->txinfo_.RxPr %f p->txinfo_.CPThresh %f ",pktRx_->txinfo_.RxPr,p->txinfo_.RxPr,p->txinfo_.CPThresh);
 
			/* power too low, ignore the packet */
			//printf("p_%d=%f, p_%d = %f\n", HDR_CMN(pktRx_)->uid(), p->txinfo_.RxPr, HDR_CMN(p)->uid(), p->txinfo_.RxPr);

			if(DEBUG) {
				printf("MAC_%s dropped p_%d. Already receving p_%d\n", name_, hdr->uid(), HDR_CMN(pktRx_)->uid());
				
    		}
			Packet::free(p);
		} else {
	
			/* power is high enough to result in collision */
			rx_state_ = MAC_COLL;
			//printf("MAC_%s collision between p_%d and p_%d\n", name_, HDR_CMN(pktRx_)->uid(),hdr->uid());
			/*
			 * look at the length of each packet and update the
			 * timer if necessary
			 */

			if (txtime(p) > recvTimer->expire()) {
				recvTimer->stop();
				Packet::free(pktRx_);
				pktRx_ = p;
				recvTimer->start(txtime(pktRx_));
			} else {
				Packet::free(p);

			}
		}
	}
}


void MacSimpleMesh::send_from_queue(){
	
	if (send_queue->length()) {
		
		if(tx_state_ != MAC_IDLE) {
			printf("ERROR ERROR ERROR. Inside send-from-queue. A packet was already being sent when this funciton was called\n");
			return;
		}

		if(rx_state_ == MAC_IDLE) {
			
			pktTx_ = send_queue->deque();
			hdr_cmn* ch = HDR_CMN(pktTx_);
			ch->txtime() = ch->size()/bandwidth_;

			
			tx_state_ = MAC_SEND;
			tx_active_ = 1;

			// Calculate jitter
			double jitter_us = ((double) rand() / RAND_MAX)*jitter_max_us;

			double local_time = Scheduler::instance().clock();
			if (DEBUG) {
				printf("MAC_%s sending p_%d jitter = %f t=%f\n",name_, ch->uid(),jitter_us/1000, local_time);
			}
			

			waitTimer->restart(jitter_us/1000000);
			sendTimer->restart(jitter_us/1000000 + ch->txtime());

			return;
		} else {
			if (DEBUG) {
				printf("Mac_%s postpone next packet due to recv p_%d\n",name_, HDR_CMN(pktRx_)->uid());
			}	
		}
	} else {
		printf("ERROR, queue was empty!\n");
	}
}

void MacSimpleMesh::send(Packet *p, Handler *h) {

    hdr_cmn* ch = HDR_CMN(p);

    /* Store tx time */
    ch->txtime() = Mac::txtime(ch->size());


    /* Confirm that we are idle */
    if (tx_state_ != MAC_IDLE) {
        // Delay packet transmission until after the current is done
        printf("Packet send collision in MacSimpleMesh::send\n");
        return;
    }

    pktTx_ = p;
    txHandler_ = h;

    
    if (rx_state_ == MAC_IDLE) {
        // We are idle and can send right away

        waitHandler();
        sendTimer->restart(ch->txtime());
    }

    else {
        // Wait until we have received the current packet
			if (DEBUG) {

		double local_time = Scheduler::instance().clock();
		printf("MAC IS NOT IDLE packet_%u t=%f\n", HDR_CMN(pktTx_)->uid(),local_time);
	}
        waitTimer->restart(HDR_CMN(pktRx_)->txtime());
        sendTimer->restart(ch->txtime() + HDR_CMN(pktRx_)->txtime());
    }

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
    rx_state_ = MAC_IDLE;

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
		printf("MAC%s dropped incoming package_%u due to packet-errors\n", name_, HDR_CMN(p)->uid());
        drop(p, DROP_MAC_PACKET_ERROR);
    }
    else {
        // Pass packet to LL
		if (DEBUG) {
			printf("MAC_%s sucessfully received p_%d\n", name_, HDR_CMN(p)->uid());
		}
		uptarget_->recv(p, (Handler*) 0); 
    }

	
	if (send_queue->length()) {
		send_from_queue();
	}
	

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

	
	
	if (send_queue->length()) {
		send_from_queue();
	}
	
	// I have to let the guy above me know I'm done with the packet
	//h->handle(p); // ERLING: Seems unneccesary

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
