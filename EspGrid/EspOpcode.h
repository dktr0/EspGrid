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

#define ESP_NUMBER_OF_OPCODES 15
#define ESP_OPCODE_BEACON 0
#define ESP_OPCODE_ACK 1
#define ESP_OPCODE_CHATSEND 2
#define ESP_OPCODE_PEERINFO 4
#define ESP_OPCODE_INT 10
#define ESP_OPCODE_FLOAT 11
#define ESP_OPCODE_TIME 12
#define ESP_OPCODE_STRING 13
#define ESP_OPCODE_METRE 14
#define ESP_OPCODE_OSCNOW 8
#define ESP_OPCODE_OSCFUTURE 9

#define ESP_MAXNAMELENGTH 16

typedef struct {
    EspTimeType sendTime;
    EspTimeType receiveTime;
    char name[ESP_MAXNAMELENGTH];
    char ip[ESP_MAXNAMELENGTH];
    uint16_t port;
    uint16_t length;
    uint16_t opcode;
} EspOpcode __attribute__((aligned(8)));

typedef struct {
    EspOpcode header;
    char data[2048];
} EspOldOpcode;

typedef struct {
    EspOpcode header;
    uint32_t beaconCount;
    unsigned char majorVersion;
    unsigned char minorVersion;
    unsigned char subVersion;
    unsigned char syncMode;
} EspBeaconOpcode;

typedef struct {
    EspOpcode header;
    char nameRcvd[ESP_MAXNAMELENGTH];
    char ipRcvd[ESP_MAXNAMELENGTH];
    EspTimeType beaconSend;
    EspTimeType beaconReceive;
    uint32_t beaconCount;
} EspAckOpcode;

typedef struct {
    EspOpcode header;
    char peerName[ESP_MAXNAMELENGTH];
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

#define ESP_SCOPE_SYSTEM 0
#define ESP_SCOPE_GLOBAL 1
#define ESP_SCOPE_LOCAL 2

typedef struct {
  char path[ESP_MAXNAMELENGTH];
  char authority[ESP_MAXNAMELENGTH];
  EspTimeType timeStamp;
  char scope;
} EspVariableInfo;

typedef struct {
  EspOpcode header;
  EspVariableInfo info;
  uint32_t value;
} EspIntOpcode;

typedef struct {
  EspOpcode header;
  EspVariableInfo info;
  Float32 value;
} EspFloatOpcode;

typedef struct {
  EspOpcode header;
  EspVariableInfo info;
  EspTimeType value;
} EspTimeOpcode;

typedef struct {
  EspOpcode header;
  EspVariableInfo info;
  char value[1024];
} EspStringOpcode;

typedef struct {
  EspTimeType time;
  uint32_t on;
  uint32_t beat;
  Float32 tempo;
} EspMetre;

typedef struct {
  EspOpcode header;
  EspVariableInfo info;
  EspMetre metre;
} EspMetreOpcode;

#endif /* EspOpcode_h */
