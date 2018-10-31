#include "ll.h"
#include "mac.h"
#include "mac-simple-mesh.h"
#include "cmu-trace.h"

const bool DEBUG = true;

//Binding the c++ class til otcl
static class MacSimpleMeshClass : public TclClass {
public:
    MacSimpleMeshClass() : TclClass("Mac/SimpleMesh") {}
    TclObject* create(int, const char*const*) {
        return new MacSimpleMesh();
    }
} class_macsimplemesh;


// Implementation of the MAC class
MacSimpleMesh::MacSimpleMesh() : Mac() {
    rx_state_ = tx_state_ = MAC_IDLE;
    tx_active_ = 0;
    waitTimer = new MacSimpleMeshWaitTimer(this);
    sendTimer = new MacSimpleMeshSendTimer(this);
    recvTimer = new MacSimpleMeshRecvTimer(this);
    busy_ = 0;
}


void MacSimpleMesh::recv(Packet *p, Handler *h){
    /* Should be identical to MacSimple::recv() */

    struct hdr_cmn *hdr = HDR_CMN(p);
	/* let MacSimple::send handle the outgoing packets */
	if (hdr->direction() == hdr_cmn::DOWN) {
		send(p,h);
		return;
	}

	/* handle an incoming packet */

	/*
	 * If we are transmitting, then set the error bit in the packet
	 * so that it will be thrown away
	 */
	
	// in full duplex mode it can recv and send at the same time
	if (tx_active_)
	{
		hdr->error() = 1;
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
			if(DEBUG) {
				printf("MAC%s dropped incoming package_%u because it was already recv strong signal\n", name_, HDR_CMN(p)->uid());
    		}
			Packet::free(p);
		} else {
	
			/* power is high enough to result in collision */
			rx_state_ = MAC_COLL;

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

		if (DEBUG) {

		double local_time = Scheduler::instance().clock();
		printf("MAC was IDLE packet_%u to downtarget t=%f\n", HDR_CMN(pktTx_)->uid(),local_time);
		}

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
        Packet::free(p);
    }

    else if (state == MAC_COLL) {
        // Recv collision
		printf("MAC%s dropped incoming package_%u due to receive collision\n", name_, HDR_CMN(p)->uid());
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
        uptarget_->recv(p, (Handler*) 0); 
    }

}

void MacSimpleMesh::waitHandler() {
    tx_state_ = MAC_SEND;
	tx_active_ = 1;

	if (DEBUG) {

		double local_time = Scheduler::instance().clock();
		printf("MAC sends packet_%u to downtarget t=%f\n", HDR_CMN(pktTx_)->uid(),local_time);
	}
	
	downtarget_->recv(pktTx_, txHandler_);
}

void MacSimpleMesh::sendHandler() {
    Handler *h = txHandler_;
	Packet *p = pktTx_;

	pktTx_ = 0;
	txHandler_ = 0;
	tx_state_ = MAC_IDLE;
	tx_active_ = 0;
	
	
	// I have to let the guy above me know I'm done with the packet
	h->handle(p); // ERLING: Seems unneccesary

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
