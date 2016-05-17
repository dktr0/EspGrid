//
//  EspOpcode.h
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2016 by David Ogborn.
//
//  EspGrid is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  EspGrid is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with EspGrid.  If not, see <http://www.gnu.org/licenses/>.

#ifndef EspOpcode_h
#define EspOpcode_h

#include "EspGridDefs.h"

typedef struct {
    EspTimeType sendTime;
    EspTimeType receiveTime;
    char name[16];
    char machine[16];
    char ip[16];
    int port;
    int length;
    char opcode;
} EspOpcode;

typedef struct {
    EspOpcode header;
    char data[2048];
} EspOldOpcode;

typedef struct {
    EspOpcode header;
    int beaconCount;
    char majorVersion;
    char minorVersion;
    char subVersion;
    char syncMode;
} EspBeaconOpcode;

typedef struct {
    EspOpcode header;
    char nameRcvd[16];
    char machineRcvd[16];
    char ipRcvd[16];
    long beaconCount;
    EspTimeType beaconSend;
    EspTimeType beaconReceive;
} EspAckOpcode;

typedef struct {
    EspOpcode header;
    char peerName[16];
    char peerMachine[16];
    char peerIp[16];
    EspTimeType recentLatency;
    EspTimeType lowestLatency;
    EspTimeType averageLatency;
    EspTimeType refBeacon;
    EspTimeType refBeaconAverage;    
} EspPeerInfoOpcode;

#endif /* EspOpcode_h */
