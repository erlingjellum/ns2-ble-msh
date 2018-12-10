
/* This is the first try in implementing BTLE Mesh in NS2 */

#ifndef ns_mac_simple_mesh_h
#define ns_mac_simple_mesh_h

//#include "mac-simple.h"
#include "queue.h"
#include <list>
#include "timer-handler.h"

class MacSimpleMeshWaitTimer;
class MacSimpleMeshSendTimer;
class MacSimpleMeshRecvTimer;
class MacSimpleMeshAdvertiseTimer;
class MacSimpleMeshRXDeadTimer;
class SimplePowerMonitor;

// enum Role {ADV_RECV = 1, ADV_ONLY = 2, RECV_ONLY = 3};

class MacSimpleMesh : public Mac {
public:
	MacSimpleMesh(int argc, const char*const* argv);

	int command(int argc, const char*const* argv);

	void recv(Packet *p, Handler *h);

	void advertise(); // In BTLE Mesh this is called at each advertise interval. It will then send the first packet in the queue

	void waitHandler(void);
	void sendHandler(void);
	void recvHandler(void);
	void deadTimeHandler(void);
	double txtime(Packet *p);
	double jitter_max_us;
	PacketQueue* send_queue; //The packet queue for transmissions


private:
	Packet *	pktRx_;
	Packet *	pktTx_;
	
	double		adv_interval_us; // The interval between transmission for this node
	int			retransmissions; // Number of retransmissions per packet
	int			adv_roles;		// Max number of advertisements per adv_interval
	int			adv_roles_left; // To control the number of adv packets sent per adv window
	double		dead_time_us;

	// Stats
	int 		col_crc;
	int			col_ccrejection;
	int			col_dead;
	int			relays;

	SimplePowerMonitor* powerMonitor;
	
	// Node role should probably be implemented somewhere else.
    MacState        rx_state_;      // incoming state (MAC_RECV or MAC_IDLE)
	MacState        tx_state_;      // outgoing state
    int             tx_active_;
	bool			advertise_waiting_;	// state variable. Is set if a RX is postponing th TX slot.
	Handler * 	txHandler_;
	MacSimpleMeshWaitTimer *waitTimer;
	MacSimpleMeshSendTimer *sendTimer;
	MacSimpleMeshRecvTimer *recvTimer;
	MacSimpleMeshAdvertiseTimer *advTimer;
	MacSimpleMeshRXDeadTimer *deadTimer;
	int busy_ ;
	double bandwidth;
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

// Timer used for scheduling advertisement
class MacSimpleMeshAdvertiseTimer: public MacSimpleMeshTimer {
public:
	MacSimpleMeshAdvertiseTimer(MacSimpleMesh *m) : MacSimpleMeshTimer(m) {}
	void handle(Event *e);
};

// Timer used for receiver dead time after packet RX

class MacSimpleMeshRXDeadTimer: public MacSimpleMeshTimer {
public:
	MacSimpleMeshRXDeadTimer(MacSimpleMesh *m) : MacSimpleMeshTimer(m) {}
	void handle(Event *e);
};


// SimplePowerMonitor to store the noise on the radio channel while the MAC is TXing or in DEAD mode.
struct interf {
      double Pt;
      double end;
};


class SimplePowerMonitor: public TimerHandler {
public:
	SimplePowerMonitor(MacSimpleMesh *m): mac(m), powerLevel(-1) {}
	void recordPowerLevel(double power, double duration);
	double getPowerLevel();
	virtual void expire(Event *);

private:
	MacSimpleMesh* mac;
	PacketQueue* packets;
	double powerLevel;
	list<interf> interfList;
	
};


#endif
