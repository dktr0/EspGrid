/*
Esp -- SuperCollider classes to connect with EspGrid (classes Esp and EspClock)
by David Ogborn <ogbornd@mcmaster.ca>
Version-date: 7 June 2014 (EspGrid 0.51.1)

Installation Instructions:
1. Place this file in your SuperCollider extensions folder
2. Launch SuperCollider (or Reboot Interpreter, or Recompile Class Library)

Examples of Use:
Esp.version; // display version of this code (and verify that it is installed!)
Esp.chat("hi there"); // send a chat message with EspGrid
TempoClock.default = EspClock.new; // make the default clock a new EspClock
TempoClock.default.start; // if the beat is paused/was-never-started, make it go
TempoClock.default.tempo = 1.8; // change tempo in normal SC way (all changes shared via EspGrid)
TempoClock.default.pause; // pause the beat
*/

Esp {
	// public properties
    classvar <version; // a string describing the update-date of this class definition
	classvar <gridAddress; // string pointing to network location of EspGrid (normally loopback)
	classvar <send; // cached NetAddr for communication from SC to EspGrid
    classvar <>clockAdjust; // manual adjustment for when you have a high latency, remote EspGrid (NOT recommended)

	*gridAddress_ { |x| gridAddress = x; send = NetAddr(gridAddress,5510); }

	*chat { |x| send.sendMsg("/esp/chat/send",x); }

	*initClass {
		version = "7 June 2014 (EspGrid 0.51.1)";
		("Esp.sc: " + version).postln;
		gridAddress = "127.0.0.1";
		send = NetAddr(gridAddress,5510);
        clockAdjust = 0.0;

		StartUp.add {
			OSCdef(\espChat,
				{
					|msg,time,addr,port|
					var chat = msg;
					(msg[1] ++ " says: " ++ msg[2]).postln;
				}
				,"/esp/chat/receive"
			).permanent_(true);
		}
	}
}


EspClock : TempoClock {

	// private variables:
	var clockDiff; // difference between SystemClock.seconds and EspGrid time
    var refOn,refFreq,refTime,refBeat;

	// public methods:
	pause { Esp.send.sendMsg("/esp/beat/on",0); }
	start { Esp.send.sendMsg("/esp/beat/on",1); }
	tempo { ^if(refOn==1,refFreq,0); }
	tempo_ {|t| if(t<10,{Esp.send.sendMsg("/esp/beat/tempo", t * 60);},{"tempo too high".postln;});}

 	init {
		| tempo,beats,seconds,queueSize |
		super.init(0.000000001,beats,seconds,queueSize);
		permanent = true;

		OSCdef(\espClock,
			{
				| msg,time,addr,port |
				clockDiff = msg[1]+(msg[2]*0.000000001) + Esp.clockAdjust - SystemClock.seconds;
				// Note: this is an estimate of the difference between the monotonic machine clock
				// and SuperCollider's SystemClock.  Internally, SuperCollider has an exact unchanging
				// value for this, but there seems to be no way of accessing it at the moment.
				// Synchronization accuracy would be improved if there were a method like:
				// SystemClock.startTime (returning the monotonic startup time SC uses to
				// generate SystemClock.seconds as something where 0 is startup time)
 			},
			"/esp/clock/r").permanent_(true);

		OSCdef(\espTempo,
			{
				| msg,time,addr,port |
                refOn = msg[1];
                refFreq = msg[2]/60;
                refTime = msg[3] + (msg[4]*0.000000001);
                refBeat = msg[5];
				if(clockDiff.notNil) { // synchronize only if system clock adjustment known
					if(refOn==0,
						{ // if tempo is off
							this.setTempoAtSec(0.000000001,SystemClock.seconds); // SC doesn't pause...
						},
						{ // if tempo is on
							var target = (SystemClock.seconds - refTime + clockDiff) * refFreq + refBeat;
							var adjust = (target - this.beats * 40);
							var freq = (refFreq + adjust).clip(0.000000001,200); // ***
							if(adjust != 0) {
								{
									this.setTempoAtSec(freq,SystemClock.seconds);
									0.025.wait;
									this.setTempoAtSec(refFreq,SystemClock.seconds);
								}.fork(SystemClock);
							};
						}
					);
				};
			},
			"/esp/tempo/r").permanent_(true);

		Esp.send.sendMsg("/esp/clock/q");
        SkipJack.new( {Esp.send.sendMsg("/esp/tempo/q");}, 0.05, clock: SystemClock);
        SkipJack.new( {Esp.send.sendMsg("/esp/clock/q");}, 10.0, clock: SystemClock);
	}

}
