/* MAC Layer for BTLE Mesh protocol stack. It simply forwards all packets between PHY and LL */

#ifndef ns_MacBTLEmesh_h
#define ns_MacBTLEmesh_h

#include "queue.h"
#include "timer-handler.h"
#include "packet.h"
#include "mac.h"
#include "wireless-phy-btle.h"


class AdvertiseTimer;


class MacBTLEmesh : public Mac {
public:
	MacBTLEmesh(int argc, const char*const* argv);

	void recv(Packet *p, Handler *h);
    int command(int argc, const char* const* argv);
    void handle_AdvertiseTimeout();

private:
    PacketQueue* relay_queue;
    PacketQueue* originator_queue;
    PacketQueue* ack_queue;

    double adv_interval_us; // Interval between each advertisement window (send window)
    int relay_queue_max_size;
    int originator_queue_max_size;
    int ack_queue_max_size;
    int adv_roles; // Number of packets sent per Adv Window
    AdvertiseTimer *adv_timer; // Timer to schedule the Adv Windows
    double jitter_max_us;
    

    // Stats
    int n_relays;
    int originator_overflows;
    int relay_overflows;
    int ack_overflows;
    // Other layers

};


class AdvertiseTimer : public TimerHandler {
public:
	AdvertiseTimer(MacBTLEmesh * m) :
		TimerHandler() {
		mac = m;
	}
    
protected:
	void expire(Event *e);
private:
	MacBTLEmesh * mac;
};

#endif