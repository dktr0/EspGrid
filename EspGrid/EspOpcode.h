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

#define ESP_NUMBER_OF_OPCODES 10
#define ESP_OPCODE_BEACON 0
#define ESP_OPCODE_ACK 1
#define ESP_OPCODE_PEERINFO 4
#define ESP_OPCODE_CHATSEND 2
#define ESP_OPCODE_KVC 3
#define ESP_OPCODE_ANNOUNCESHARE 5
#define ESP_OPCODE_REQUESTSHARE 6
#define ESP_OPCODE_DELIVERSHARE 7
#define ESP_OPCODE_OSCNOW 8
#define ESP_OPCODE_OSCFUTURE 9

#define ESP_MAXNAMELENGTH

typedef struct {
    EspTimeType sendTime;
    EspTimeType receiveTime;
    char name[ESP_MAXNAMELENGTH];
    char machine[ESP_MAXNAMELENGTH];
    char ip[ESP_MAXNAMELENGTH];
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
    char nameRcvd[ESP_MAXNAMELENGTH];
    char machineRcvd[ESP_MAXNAMELENGTH];
    char ipRcvd[ESP_MAXNAMELENGTH];
    long beaconCount;
    EspTimeType beaconSend;
    EspTimeType beaconReceive;
} EspAckOpcode;

typedef struct {
    EspOpcode header;
    char peerName[ESP_MAXNAMELENGTH];
    char peerMachine[ESP_MAXNAMELENGTH];
    char peerIp[ESP_MAXNAMELENGTH];
    EspTimeType recentLatency;
    EspTimeType lowestLatency;
    EspTimeType averageLatency;
    EspTimeType refBeacon;
    EspTimeType refBeaconAverage;
} EspPeerInfoOpcode;

#define ESP_CHAT_MAXLENGTH 256

typedef struct {
    EspOpcode header;
    char text[ESP_CHAT_MAXLENGTH];
} EspChatOpcode;

#define ESP_KVC_MAXKEYLENGTH 32

#define ESP_KVCTYPE_BOOL 1
#define ESP_KVCTYPE_DOUBLE 2
#define ESP_KVCTYPE_TIME 3
#define ESP_KVCTYPE_INT 4

typedef struct {
  EspOpcode header;
  EspTimeType timeStamp;
  char keyPath[ESP_KVC_MAXKEYLENGTH];
  char authorityPerson[ESP_MAXNAMELENGTH];
  char authorityMachine[ESP_MAXNAMELENGTH];
  int type;
  union KvcValue {
    char boolValue;
    double doubleValue;
    EspTimeType timeValue;
    int intValue;
  } value;
} EspKvcOpcode;

#endif /* EspOpcode_h */
