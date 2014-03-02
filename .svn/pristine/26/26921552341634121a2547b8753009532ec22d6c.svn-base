// esp.ck - Chuck code to interact with EspGrid
// by David Ogborn, 2011-13, http://esp.mcmaster.ca

public class Esp {
    static int clockSeconds;
    static int clockNanoseconds;
    static int tempoOn;
    static float tempoBpm;
    static int tempoSeconds;
    static int tempoNanoseconds;
    static int tempoN;
    static int tempoLength;
    
    fun static void 
}

OscSend s;
s.setHost("127.0.0.1",5510);
OscRecv r;
5512 => r.port;
r.listen();
r.event("/clock/offset/r, i i") @=> OscEvent clock;
r.event("/esp/tempo/r, i f i i i i") @=> OscEvent tempo;
spork~ clockListener();
spork~ tempoListener();

while(true) {
    s.startMsg("/clock/offset/q, i"); 
    s.addInt(5512); // request response on port 5512
    25::ms => now;
    s.startMsg("/esp/tempo/q, i");
    s.addInt(5512); // request response on port 5512
    25::ms => now;
}

function void clockListener() {
    while(true) {
        clock => now;
        while(clock.nextMsg()!=0) {
            clock.getInt() => Esp.clockSeconds;
            clock.getInt() => Esp.clockNanoseconds;
        }
    }
}

function void tempoListener() {
    while(true) {
        tempo => now;
        while(tempo.nextMsg()!=0) {
            tempo.getInt() => Esp.tempoOn;
            tempo.getFloat() => Esp.tempoBpm;
            tempo.getInt() => Esp.tempoSeconds;
            tempo.getInt() => Esp.tempoNanoseconds;
            tempo.getInt() => Esp.tempoN;
            tempo.getInt() => Esp.tempoLength;
        }
    }
}
