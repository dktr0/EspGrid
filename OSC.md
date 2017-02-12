# EspGrid's OpenSoundControl (OSC) protocol

The normal way of using EspGrid is to run it alongside whatever your chosen applications (or live coding languages) are, sending OSC messages to EspGrid to ask about shared matters of interest, and receiving responses from EspGrid. Note that in some cases, people may have already created "helper software" so that you don't need to worry about this OSC interface. For example, the Esp.sc project on github provides SuperCollider classes that already "talk" this OSC protocol and make it unnecessary to work with the OSC protocol directly. By default, OSC messages are sent to EspGrid on port 5510 (for example, in many cases the relevant address would be 127.0.0.1:5510). In some cases, EspGrid responds to those messages directly - either to the port/host that sent the message or to another one if indicated by optional arguments. In other cases, EspGrid sends messages to a list of subscribers that it maintains (and OSC messages can be used to add to and remove from the list of subscribers).

## Shared metre/tempo

Probably the most important set of messages concerns shared tempo/metre. Like many parts of EspGrid's OSC interface this involves a pair of "query" and response. You send the query to EspGrid, and get the response. In many cases, the query is simply an OSC address with no arguments, but if it is desired that the response comes to a different address and port than the query came from, some optional arguments to the query allow this to take place.

Query: /esp/tempo/q [port::int32,optional] [host::string,optional]

- where port is an optional UDP port to which the response should be sent, defaults to the port from which the query was sent
- and where host is an optional IP address to which the response should be sent, defaults to the host from which the query was sent
- (this pattern is used in many other query and response pairs of EspGrid's OSC interface)

Response: /esp/tempo/r on tempo seconds nanoseconds n

- on :: int32, where 1 is tempo running and 0 is tempo paused
- tempo :: float32, is current tempo in beats per minute
- seconds :: int32, is a reference time in seconds for the current metric grid
- nanoseconds :: int32, is a reference time in nanoseconds (added to seconds) for the current metric grid
- n :: int32, the number(count) of the beat which took or will take place at seconds+nanoseconds

The following messages can be sent to EspGrid in order to change the parameters of the metre, as of the next whole number beat:

- /esp/beat/on [on::int32, 1 or 0]
- /esp/beat/tempo [tempo::float32 in beats per minute]

## Subscriptions

- /esp/subscribe [port::int32,optional] [host::string,optional]
- /esp/unsubscribe [port::int32,optional] [host::string,optional]

Sending the subscribe message above will ask EspGrid to automatically and immediately (i.e. as soon as possible) send a number of messages to the port and host from which the subscription came (for example, another application on your machine). The unsubscribe message will cancel such a subscription (rarely necessary, because in most cases users will simply terminate the EspGrid application and restart it later, in another context). Subscriptions are necessary to receive notification of incoming chat messages, and to receive arbitrary OSC messages "forwarded" by EspGrid (see below under "Immediate and scheduled message passing").

## Chat

- /esp/chat/send [message::string]

This message will send the chat message represented by the string to all EspGrid instances.  Each EspGrid will forward the chat message to local subscribers using the following message (where name is the "name" of the source EspGrid instance for the chat message, based on configuration settings):

- /esp/chat/receive [name::string] [message::string]

## Code-Sharing

EspGrid maintains a database of shared code fragments.  To add code to this database use the following OSC message, where title will be a descriptive title/handle for the fragment in question (in Esp.sc this is just set to "SuperCollider" by default):

- /esp/codeShare/post [title::string] [code::string]

## Immediate and scheduled message passing

Sending the following messages to your local instance of EspGrid will cause corresponding messages to be sent from all EspGrid instances to all message subscribers. This is like "broadcast" UDP messages but with the ability to schedule messages at synchronized times in the short or not-so-short future, and with more reliability.

- /esp/msg/now [address::string] [rest of arguments...]
- /esp/msg/soon [address::string] [rest of arguments...]
- /esp/msg/future [seconds::int32] [nanoseconds::int32] [address::string] [rest of arguments...]

"now" sends its message as soon as possible, "soon" sends it a synchronized time in the immediate future according to a latency value within EspGrid (but is still basically right away), while future sends its message at a synchronized future time relative to one's local machine clock. There are three additional variants in this system (all with addresses ending in "Stamp") - the only difference between these and the messages above is that with these the first two arguments of the locally issued OSC message contain the scheduled time of the message in local terms (seconds and nanoseconds as in all of these other messages).

- /esp/msg/nowStamp [address::string] [rest of arguments...]
- /esp/msg/soonStamp [address::string] [rest of arguments...]
- /esp/msg/futureStamp [seconds::int32] [nanoseconds::int32] [address::string] [rest of arguments...]

For example:

- /esp/msg/futureStamp 456789 123456789 /my/osc/message 1234 blah

Would produce a synchronized issue of the following message:

- /my/osc/message 123456 987654321 1234 blah

(where 123456 987654321 is a made-up guess at what the scheduled clock-time might be on a second machine from the one that originally issued the /esp/msg/futureStamp)

## Configuration queries, responses and setters

Everything about the EspGrid application is configurable via OSC messages. The following section documents OSC messages that can be sent to EspGrid to set and query various configuration parameters, as well as the responses that will be received from EspGrid.

Each instance of EspGrid should have a name identifying the person/performer using it:

- /esp/person/s [name::string]
- /esp/person/q [port::int32,optional] [host::string,optional]
- /esp/person/r [name::string]

Each instance should also have a name identifying the machine. This is to support cases where the same performer is using multiple machines (for example, a laptop on which they are live coding and a tablet/control surface used for gestural data):

- /esp/machine/s [name::string]
- /esp/machine/q [port::int32,optional] [host::string,optional]
- /esp/machine/r [name::string]

In most cases, the default broadcast address of 255.255.255.255 will be correct. But in some circumstances, the ability to change the way that EspGrid instances connect with eachother on the LAN is required, and if so, these messages are the way to change the broadcast address:

- /esp/broadcast/s [address::string]
- /esp/broadcast/q [port::int32,optional] [host::string,optional]
- /esp/broadcast/r [address::string]

One of the key virtues of the EspGrid system has been the idea of supporting different ways of estimating the clock differences between the machines. This should be better documented in the future. In the meantime, mode 5 (the default) is a good choice. It uses reference beacon algorithms when there are 3 or more nodes in the system, and Cristian's algorithm when there are only 2 nodes:

- /esp/clockMode/s [mode::int32]
- /esp/clockMode/q [port::int32,optional] [host::string,optional]
- /esp/clockMode/r [mode::int32]

The following message will return the major version, minor version and "sub version" of EspGrid as a single OSC string. Minor versions change whenever either EspGrid's internal communications protocol OR this OSC interface change. The sub versions, by contrast, are incremented for smaller fixes, improvements and changes that do not change the fundamental protocols:

- /esp/version/q [port::int32,optional] [host::string,optional]
- /esp/version/r [version::string]

### Forming Wide Area Network bridges between multiple Local Area Networks

In a very common use-case, EspGrid instances will talk to eachother via broadcast UDP packets on the local network. It is possible, however, to connect EspGrid instances in other ways (and this will be expanded in the future).  The following methods set these parameters on the local EspGrid instance, and make it reach out to connect with another EspGrid instance (for example, over the Internet):

- /esp/bridge/host [address::string = the IP address of a remote group to connect to]
- /esp/bridge/port [port::int32 = the port on which to attempt to connect to the remote group]

## OSC interface for "special cases"

EspGrid uses the low-level monotonic clock of your machine to represent times. Normally, this means you would have some way of querying that clock from your working context to schedule things appropriately. In some cases, you may not have this access and so EspGrid provides a work-around to let you get an approximate time from this clock via the OSC interface. Naturally, the values reported in this way will be slightly inaccurate because of the delay incurred in processing the request via OSC:

- /esp/clock/q [port::int32,optional] [host::string,optional]]
- /esp/clock/r [seconds::int32] [nanoseconds::int32]
