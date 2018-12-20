/*
 * PHY Layer for BTLE Mesh
 * 
 * Developed by Erling Rennemo Jellum <erling.jellum@gmail.com> for Nordic Semiconductor
 * 
 * Based on Wireless-PhyExt
 */

#ifndef ns_WirelessPhyBTLE_h
#define ns_WirelessPhyBTLE_h

#include "wireless-phy.h"
#include "timer-handler.h"
#include "queue.h"
#include "mobilenode.h"
#include "packet.h"
#include "math.h"
#include <list>

class Tx_Timer;
class Rx_Timer;
class Ramp_Timer;
class RxDead_Timer;
class BTLEPowerMonitor;

enum PhyState {SCAN = 0, RX = 1, TX = 2, SLEEP = 3,DEAD = 4, SWITCH = 5, RAMP = 6, IDLE = 7};

class WirelessPhyBTLE : public WirelessPhy {
public:
    WirelessPhyBTLE();

    void recv(Packet *p, Handler* h);
    void sendDown(Packet *p);
    void sendUpwards(Packet *p);

    void switchChannel(void);

	int command(int argc, const char* const* argv);

    // Timer Handlers
    void handle_TxTimeout();
    void handle_RxTimeout();
    void handle_RampTimeout();
    void handle_RxDeadTimeout();
    void handle_TxDeadTimeout();

    // Advertisement 
    void enque_packet(Packet *p);
    void advertise();

private:
    int state_;
    int channel_;
    int n_channels_left;

    int tx_active_;

	// Radio parameters
    double CPThresh_;
    double CSThresh_;
    double RXThresh_;
    double Pt_;
    double freq_;
    double L_;
    double lambda_;

	// Delay parameters IC-specific
    double rampDelay_us;
    double rxDeadtime_us;

    Packet *pktRx_;
    Packet *pktTx_;
    
	//Power monitor
	BTLEPowerMonitor *powerMonitor;

    //Timers
    Tx_Timer *tx_timer;
    Rx_Timer *rx_timer;
    Ramp_Timer *ramp_timer;
    RxDead_Timer * rx_dead_timer;

	// Statistics over failed packet receives col = collision
	int col_crc;
	int col_dead;
	int col_ccr;
	int col_ramp;
	int col_tx;

	friend BTLEPowerMonitor;
};

/***********************************************************************************/
// TIMERS

class Tx_Timer : public TimerHandler {
public:
	Tx_Timer(WirelessPhyBTLE * w) :
		TimerHandler() {
		phy = w;
	}
protected:
	void expire(Event *e);
private:
	WirelessPhyBTLE * phy;
};

class Rx_Timer : public TimerHandler {
public:
	Rx_Timer(WirelessPhyBTLE * w) :
		TimerHandler() {
		phy = w;
	}
	void expire(Event *e);

private:
	WirelessPhyBTLE * phy;

};
/*
class ScanInterval_Timer : public TimerHandler {
public:
	ScanInterval_Timer(WirelessPhyBTLE * w) :
		TimerHandler() {
		phy = w;
	}
protected:
	void expire(Event *e);
private:
	WirelessPhyBTLE * phy;
};

class ChannelSwitch_Timer : public TimerHandler {
public:
	ChannelSwitch_Timer(WirelessPhyBTLE * w) :
		TimerHandler() {
		phy = w;
	}
protected:
	void expire(Event *e);
private:
	WirelessPhyBTLE * phy;
};
*/

class Ramp_Timer : public TimerHandler {
public:
	Ramp_Timer(WirelessPhyBTLE * w, double delay_us) :
		TimerHandler() {
		phy = w;
		duration_s = ((double) delay_us) / 1e6;
	}
	void start() {this->resched(duration_s);}
protected:
	void expire(Event *e);
	
private:
	WirelessPhyBTLE * phy;
	double duration_s;
};

class RxDead_Timer : public TimerHandler {
public:
	RxDead_Timer(WirelessPhyBTLE * w, double delay_us) :
		TimerHandler() {
		phy = w;
		duration_s = ((double) delay_us) / 1e6;
	}
	void start() {this->resched(duration_s);}
protected:
	void expire(Event *e);
	
private:
	WirelessPhyBTLE * phy;
	double duration_s;
};

/*
class TxDead_Timer : public TimerHandler {
public:
	TxDead_Timer(WirelessPhyBTLE * w) :
		TimerHandler() {
		phy = w;
	}
protected:
	void expire(Event *e);
private:
	WirelessPhyBTLE * phy;
};
*/


/*
The Power Monitor records the powerlevel of all received packets and stores them
for the duration of the packet. This is used to calculate the SINR for the Phy.

This is more or less copied from the WirelessPhyExt module
*/
struct interf {
      double Pt;
      double end;
};

class BTLEPowerMonitor : public TimerHandler {
public:
	BTLEPowerMonitor(WirelessPhyBTLE *);
	void recordPowerLevel(double power, double duration);
	double getPowerLevel();
	void setPowerLevel(double);
	double SINR(double Pr);
	void expire(Event *); //virtual function, which must be implemented

private:
	double CS_Thresh;
	double monitor_Thresh;//packet with power > monitor_thresh will be recorded in the monitor
	double powerLevel;
	double noise_floor;
	WirelessPhyBTLE * phy;
    list<interf> interfList_;
};



#endif
