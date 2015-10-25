COMPILE = gcc
FLAGS = -c -std=gnu99 $(shell gnustep-config --objc-flags)
LDFLAGS = $(shell gnustep-config --base-libs)
OBJECTS = EspBeat.o EspBridge.o EspChat.o EspChannel.o EspClock.o EspCodeShareItem.o EspCodeShare.o EspOscSubscribers.o EspKeyValueController.o EspMessage.o EspMovingAverage.o EspPeer.o EspPeerList.o EspQueue.o EspSocket.o EspNetwork.o EspOsc.o EspGrid.o main.o

espgridd: $(OBJECTS)
	$(COMPILE) $(OBJECTS) $(LDFLAGS) -o $@

%.o: %.m
	$(COMPILE) $(FLAGS) $< -o $@

all: espgridd

clean:
	rm -f espgridd espgridd.exe *.o *.d