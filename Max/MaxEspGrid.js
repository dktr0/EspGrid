inlets = 3;
outlets = 2;

var refOn;
var refTempo;
var refSeconds;
var refNanos;
var refBeat;
var adjustSeconds;
var adjustNanos;

function list(a) {
	if(inlet == 2) {
		if(arguments.length != 2) {
			post("third inlet expects list of 2 items (seconds/nanoseconds)");
			return;
		}
		adjustSeconds = arguments[0];
		adjustNanos = arguments[1];
	}
	if(inlet == 1) {
		if(arguments.length != 5) {
			post("second inlet excepts list of 5 items from /esp/tempoCPU/r");
			post();
			return;
		}
		refOn = arguments[0];
		refTempo = arguments[1];
		refSeconds = arguments[2];
		refNanos = arguments[3];
		refBeat = arguments[4];
	}
}

function msg_float(a) {
	if(adjustSeconds == null) {
		post("haven't got adjustSeconds yet...");
		post();
		return;
	}
	if(refOn == null) {
		post("haven't got /esp/tempoCPU/r values yet...");
		post();
		return;
	}
	var seconds = Math.floor(a/1000);
	var nanos = Math.floor((a % 1000.0) * 1000000)
	seconds = seconds + adjustSeconds;
	nanos = nanos + adjustNanos;
	
	var secondsSince = seconds - refSeconds;
	var nanosSince = nanos - refNanos;
	if(nanosSince<0) {
		nanosSince = nanosSince + 1000000000;
		secondsSince = secondsSince - 1;
	}
	
	var beatsSince = secondsSince * (refTempo/60.0);
	beatsSince = beatsSince + (nanosSince/1000000000.0*(refTempo/60));
	beatsNow = refBeat + beatsSince;
	unitsNow = Math.floor(beatsNow*480);
	
	outlet(1,unitsNow);
	outlet(0,["tempo",refTempo]);
	outlet(0,refOn);
}
