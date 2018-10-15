
/* This class is based of the Mac Simple class */

#ifndef ns_mac_simple_mesh_h
#define ns_mac_simple_mesh_h

#include "mac-simple.h"


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
	MacSimpleWaitTimer *waitTimer;
	MacSimpleSendTimer *sendTimer;
	MacSimpleRecvTimer *recvTimer;
	int busy_ ;



};


#endif
