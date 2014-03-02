COMPILE = gcc
FLAGS = -c -std=gnu99 $(shell gnustep-config --objc-flags)
LDFLAGS = $(shell gnustep-config --base-libs)
OBJECTS = EspBeat.o EspBridge.o EspChat.o EspClock.o EspCodeShareItem.o EspCodeShare.o EspKeyValueController.o EspMessage.o EspPeerList.o EspQueue.o EspSocket.o EspInternalProtocol.o EspOsc.o EspGrid.o main.o

espgridd: $(OBJECTS)
	$(COMPILE) $(OBJECTS) $(LDFLAGS) -o $@

%.o: %.m
	$(COMPILE) $(FLAGS) $< -o $@

all: espgridd
