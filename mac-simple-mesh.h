
/* This class is based of the Mac Simple class */

#ifndef ns_mac_simple_mesh_h
#define ns_mac_simple_mesh_h

#include "mac-simple.h"

class MacSimpleMeshWaitTimer;
class MacSimpleMeshSendTimer;
class MacSimpleMeshRecvTimer;

class MacSimpleMesh : public Mac {

public:
	MacSimpleMesh();
	void recv(Packet *p, Handler *h);
	void send(Packet *p, Handler *h);

	void waitHandler(void);
	void sendHandler(void);
	void recvHandler(void);
	double txtime(Packet *p);


private:
	Packet *	pktRx_;
	Packet *	pktTx_;
    MacState        rx_state_;      // incoming state (MAC_RECV or MAC_IDLE)
	MacState        tx_state_;      // outgoing state
    int             tx_active_;
	Handler * 	txHandler_;
	MacSimpleMeshWaitTimer *waitTimer;
	MacSimpleMeshSendTimer *sendTimer;
	MacSimpleMeshRecvTimer *recvTimer;
	int busy_ ;
};

// The Timer class is more or less copied from mac-simple.cc 
// TODO: Find a more convinient way to use inheritance to reuse that class
// rather than copying almost everything.

class MacSimpleMeshTimer: public Handler {
public:
	MacSimpleMeshTimer(MacSimpleMesh* m) : mac(m) {
	  busy_ = 0;
	}
	virtual void handle(Event *e) = 0;
	virtual void restart(double time);
	virtual void start(double time);
	virtual void stop(void);
	inline int busy(void) { return busy_; }
	inline double expire(void) {
		return ((stime + rtime) - Scheduler::instance().clock());
	}

protected:
	MacSimpleMesh	*mac;
	int		busy_;
	Event		intr;
	double		stime;
	double		rtime;
	double		slottime;
};

// Timer to use for delaying the sending of packets
class MacSimpleMeshWaitTimer: public MacSimpleMeshTimer {
public: 
	MacSimpleMeshWaitTimer(MacSimpleMesh *m) : MacSimpleMeshTimer(m) {}
	void handle(Event *e);
};

//  Timer to use for finishing sending of packets
class MacSimpleMeshSendTimer: public MacSimpleMeshTimer {
public:
	MacSimpleMeshSendTimer(MacSimpleMesh *m) : MacSimpleMeshTimer(m) {}
	void handle(Event *e);
};

// Timer to use for finishing reception of packets
class MacSimpleMeshRecvTimer: public MacSimpleMeshTimer {
public:
	MacSimpleMeshRecvTimer(MacSimpleMesh *m) : MacSimpleMeshTimer(m) {}
	void handle(Event *e);
};


#endif