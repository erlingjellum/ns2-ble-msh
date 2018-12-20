#include  "wireless-phy-btle.h"

#define PHY_DBG false

static class WirelessPhyBTLEClass : public TclClass {
    public:
    WirelessPhyBTLEClass() :
        TclClass("Phy/WirelessPhyBTLE") {

    }
    TclObject* create (int, const char*const*) {
        return (new WirelessPhyBTLE);
    }
} class_WirelessPhyBTLE;


WirelessPhyBTLE::WirelessPhyBTLE() : WirelessPhy() {
    
    bind("CPThresh_", &CPThresh_);
	bind("RXThresh_", &RXThresh_);
	bind("CSThresh_", &CSThresh_);
	bind("Pt_", &Pt_);
	bind("L_", &L_);
    bind("rampDelay_", &rampDelay_us);
    bind("RXDeadtime_", &rxDeadtime_us);

    state_ = SCAN;
    tx_active_ = 0;
    pktRx_ = 0;
    pktTx_ = 0;
    node_ = 0;
    ant_ = 0;
    propagation_ = 0;

    // Initialize to channel 37
    channel_ = 37;
    freq_ = 2402e6;
    lambda_ = SPEED_OF_LIGHT / freq_;
    powerMonitor = new BTLEPowerMonitor(this);

    // Timers
    tx_timer            = new Tx_Timer(this);
    rx_timer            = new Rx_Timer(this);
    ramp_timer          = new Ramp_Timer(this, rampDelay_us);
    rx_dead_timer       = new RxDead_Timer(this, rxDeadtime_us);

    // stats
    col_crc = 0;
	col_dead = 0;
	col_ccr = 0;
	col_ramp = 0;
	col_tx = 0;
}

void WirelessPhyBTLE::recv(Packet* p, Handler*)
{
	struct hdr_cmn *hdr = HDR_CMN(p);	

	switch(hdr->direction()) {
	case hdr_cmn::DOWN :
        // Outgoing packet.
        sendDown(p);
		break;
	case hdr_cmn::UP :
		sendUpwards(p);
		break;
	default:
		printf("Direction for pkt-flow not specified\n");
        break;
    }
}

void WirelessPhyBTLE::sendUpwards(Packet* p) {
    // We are receiving a packet on the radio
    
    // First check that its on the right channel
    if (p->txinfo_.getLambda() != lambda_) {
        return;
    }

    struct hdr_cmn *ch = HDR_CMN(p);
    double Pr;
    // Calculate received power
    PacketStamp s;
    s.stamp((MobileNode*) node(), ant_, 0, lambda_);
    Pr = propagation_->Pr(&p->txinfo_, &s, this);
    
    if (Pr < RXThresh_) {
        // If packet is below the Receive Threshold
        Packet::free(p);
        return;
    }

    switch (state_)
    {
        case TX:
            // We are already TXing. Record Power and free packet
            if (PHY_DBG) {
                double local_time = Scheduler::instance().clock(); 
                printf("T=%f, Phy_%s, COL_TX++ P_%i\n",local_time, name_, ch->uid());
            }

            col_tx++;
            powerMonitor->recordPowerLevel(Pr,ch->txtime());
            Packet::free(p);
            break;
    
        case RX:
            // We are Receiving a different packet (pktRX_)

            // Record power and see if it results in collision
            powerMonitor->recordPowerLevel(Pr, ch->txtime());
            if(powerMonitor->SINR(pktRx_->txinfo_.RxPr) < CPThresh_) {
                // Now the background noise is high enough to cause collision
                col_crc++;
                HDR_CMN(pktRx_)->error() = 1;

                if (PHY_DBG) {
                    double local_time = Scheduler::instance().clock(); 
                    printf("T=%f, Phy_%s, COL_CRC++ P_%i\n",local_time, name_, ch->uid());
                }

                Packet::free(p);
            } else {
                // Co Channel Rejection
                if (PHY_DBG) {
                    double local_time = Scheduler::instance().clock(); 
                    printf("T=%f, Phy_%s, COL_CCR++ P_%i\n",local_time, name_, ch->uid());
                }

                col_ccr++;
                Packet::free(p);
            }

            break;
            
        case SCAN:
            // We are scanning. See if packet is strong enough, compared to the background noise, to be picked up

            if (powerMonitor->SINR(Pr) > CPThresh_) {
                // Strong enough packet. Start reception
                state_ = RX;

                // Store the packet locally
                pktRx_ = p;
                // Update the Receive Power
                pktRx_->txinfo_.RxPr = Pr;
                // Start the receive timer
                rx_timer->resched(ch->txtime());
            } else {
                // Record power
                powerMonitor->recordPowerLevel(Pr, ch->txtime());
                col_ccr++;

                if (PHY_DBG) {
                    double local_time = Scheduler::instance().clock(); 
                    printf("T=%f, Phy_%s, COL_CCR++ P_%i\n",local_time, name_, ch->uid());
                }
                Packet::free(p);
            }
            break;

        case DEAD:
            // Packet received while radio was in DEAD state after another RX
            // Record Power
            powerMonitor->recordPowerLevel(Pr, ch->txtime());
            col_dead++;
            if (PHY_DBG) {
                double local_time = Scheduler::instance().clock(); 
                printf("T=%f, Phy_%s, COL_DEAD++ P_%i\n",local_time, name_, ch->uid());
            }

            Packet::free(p);
            break;
        
        case RAMP:
            // Packet received while radio was in RAMP state => Switching between TX and SCAN
            // Record Power
            powerMonitor->recordPowerLevel(Pr, ch->txtime());
            col_ramp++;

            if (PHY_DBG) {
                double local_time = Scheduler::instance().clock(); 
                printf("T=%f, Phy_%s, COL_RAMP++ P_%i\n",local_time, name_, ch->uid());
            }

            Packet::free(p);
            break;
    }

    return;

}

void WirelessPhyBTLE::sendDown(Packet* p) {

    
    switch (state_)
    {
        case RX:
            // The TX will override the current RX. Remove the packet and stop the timer
            if (PHY_DBG) {
                double local_time = Scheduler::instance().clock(); 
                printf("T=%f, Phy_%s, COL_TX++ P_%i\n",local_time, name_, HDR_CMN(pktRx_)->uid());
            }

            pktRx_ = 0;
            rx_timer->cancel();

            
            col_tx++;
            break;
        case TX:
            // MAC layer should not allow this scenario
            printf("ERROR COULD NOT SEND PACKET = %i AS IT WAS ALREADY SENDING ANOTHER PACKET", HDR_CMN(p)->uid());
            return;

        case DEAD:
            // A little hack. If we are trying to send a packet while radio is in DEAD state.
            // We allow it, cancel the dead timer and go to ramp up
            rx_dead_timer->cancel();
            break;

        case RAMP:
            // If we are in RAMP state, probably because we just sent another packet.
            // Ignore it, and restart ramping to TX.
            break;
    }
    
    tx_active_ = 1;
    pktTx_ = p;

    // Ramp up to TX
    state_ = RAMP;
    ramp_timer->start();

}


void WirelessPhyBTLE::switchChannel(void) {
    // This function increments the channel/freq/lambda in the 37,38,39 hop pattern
    
    switch (channel_)
    {
        case 37:
            channel_ = 38;
            freq_ =2426e6;
            lambda_ = SPEED_OF_LIGHT / freq_;
            break;
    
        case 38:
            channel_ = 39;
            freq_ =2480e6;
            lambda_ = SPEED_OF_LIGHT / freq_;
            break;

        case 39:
            channel_ = 37;
            freq_ =2402e6;
            lambda_ = SPEED_OF_LIGHT / freq_;
            break;

        default:
            printf("Unknown channel = %i, switchChannel not doing anything!\n", channel_);
            break;
    }
}

// Timer handlers

void WirelessPhyBTLE::handle_TxTimeout() {
    // Now ramp up to SCAN
    state_ = RAMP;
    tx_active_ = 0;
    pktTx_ = 0;

    ramp_timer->start();

    return;
}

void WirelessPhyBTLE::handle_RxTimeout() {

    // Update for CRC errors
    if (HDR_CMN(pktRx_)->error()) {
        if (PHY_DBG) {
                double local_time = Scheduler::instance().clock(); 
                printf("T=%f, Phy_%s, COL_CRC++ P_%i\n",local_time, name_, HDR_CMN(pktRx_)->uid());
            }
        col_crc++;
    } else {
        if (PHY_DBG) {
            double local_time = Scheduler::instance().clock(); 
            printf("T=%f, Phy_%s, RECV P_%i\n",local_time, name_, HDR_CMN(pktRx_)->uid());
        }
    }

    // Send received packet to MAC
    uptarget_->recv(pktRx_, (Handler *) 0);

    // Go to DEAD state
    state_ = DEAD;
    rx_dead_timer->start();
}



void WirelessPhyBTLE::handle_RampTimeout() {
    if(tx_active_) {
        struct hdr_cmn *ch = HDR_CMN(pktTx_);
        // Stamp the packet
        pktTx_->txinfo_.stamp((MobileNode*)node(), ant_->copy(), Pt_, lambda_);

        if (PHY_DBG) {
            double local_time = Scheduler::instance().clock(); 
            printf("T=%f, Phy_%s, SEND P_%i\n",local_time, name_, HDR_CMN(pktTx_)->uid());
        }
        // Send the packet and set the timer
        state_ = TX;
        double txtime = ch->txtime();
        downtarget_->recv(pktTx_, this);
        tx_timer->resched(txtime);
    } else {
        state_ = SCAN;
        return;
    }
}

void WirelessPhyBTLE::handle_RxDeadTimeout() {
    // After post receive dead time:
    state_ = SCAN;
    return;
}


int WirelessPhyBTLE::command(int argc, const char* const* argv) {
	Tcl& tcl = Tcl::instance();

	if(argc == 3) {
		if (strcmp(argv[1], "get") == 0) {

			if (strcmp(argv[2], "crc-collisions") == 0) {
				tcl.resultf("%d", col_crc);
				return TCL_OK;
			}

			if (strcmp(argv[2], "co-channel-rejections") == 0) {
				tcl.resultf("%d", col_ccr);
				return TCL_OK;
			}

			if (strcmp(argv[2], "dead-time-collisions") == 0) {
				tcl.resultf("%d", col_dead);
				return TCL_OK;
			}

			if (strcmp(argv[2], "tx-collisions") == 0) {
				tcl.resultf("%d", col_tx);
				return TCL_OK;
			}

            if (strcmp(argv[2], "ramp-collisions") == 0) {
				tcl.resultf("%d", col_ramp);
				return TCL_OK;
			}

		}
	}    

	

	return WirelessPhy::command(argc, argv);

    
}




/*********************************************************************************/
// Timers

void Tx_Timer::expire(Event *) {
	this->phy->handle_TxTimeout();
	return;
}

void Rx_Timer::expire(Event *) {
	phy->handle_RxTimeout();
	return;
}
/*
void ScanInterval_Timer::expire(Event *) {
    phy->handle_ScanIntervalTimeout();
    return;
}

void ChannelSwitch_Timer::expire(Event *) {
    phy->handle_ChannelSwitchTimeout();
    return;
}
*/

void Ramp_Timer::expire(Event *) {
    phy->handle_RampTimeout();
    return;
}

void RxDead_Timer::expire(Event *) {
    phy->handle_RxDeadTimeout();
    return;
}

/*
void TxDead_Timer::expire(Event *) {
    phy->handle_TxDeadTimeout();
    return;
}
*/
/****************************************************************************************/
// Power Monitor
BTLEPowerMonitor::BTLEPowerMonitor(WirelessPhyBTLE * phy) {
	// initialize, the NOISE is the environmental noise
	this->phy = phy;
	monitor_Thresh = phy->RXThresh_;
    noise_floor = 4.0e-14; // -104 dBm (nRF52840 has minimum RXThresh_ of -130dBm)
	powerLevel = noise_floor; // noise floor is -99dbm
}

void BTLEPowerMonitor::recordPowerLevel(double signalPower, double duration) {
	// to reduce the number of entries recorded in the interfList
	if (signalPower < monitor_Thresh )
		return;

	interf timerEntry;
    timerEntry.Pt  = signalPower;
    timerEntry.end = Scheduler::instance().clock() + duration;

    list<interf>:: iterator i;
    for (i=interfList_.begin();  i != interfList_.end() && i->end <= timerEntry.end; i++) { }
    interfList_.insert(i, timerEntry);

	resched((interfList_.begin())->end - Scheduler::instance().clock());

    powerLevel += signalPower; // update the powerLevel
}

double BTLEPowerMonitor::getPowerLevel() {
	if (powerLevel > noise_floor)
		return powerLevel;
	else
		return noise_floor;
}

void BTLEPowerMonitor::setPowerLevel(double power) {
	powerLevel = power;
}

double BTLEPowerMonitor::SINR(double Pr) {
	// Return the delta dBm between Pr and PowerLevel if it returns a negative number then Powerlevel is greater than Pr
    double dBmPr = 10 * log(1000 * Pr); // RSSI for received packet (dBm)
    double dBmPM = 10 * log(1000 * getPowerLevel()); // Background Noise Strength (dBm)
	return (dBmPr - dBmPM);
}


void BTLEPowerMonitor::expire(Event *) {
	double time = Scheduler::instance().clock();

   	list<interf>:: iterator i;
   	i=interfList_.begin();
   	while(i != interfList_.end() && i->end <= time) {
       	powerLevel -= i->Pt;
       	interfList_.erase(i++);
   	}
	if (!interfList_.empty()) {
		resched((interfList_.begin())->end - Scheduler::instance().clock());
    }
}