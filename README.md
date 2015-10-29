# EspGrid

EspGrid is a software system to streamline the sharing of timing, beats and code in electronic ensembles, from duos and trios through larger laptop orchestras to globally distributed ensembles.  

Here's how it works: Each member of the ensemble runs the EspGrid software on any computers they are using.  Behind the scenes, all of the individual copies of EspGrid talk to each other and run various algorithms to estimate timing differences between them, as well as to share things like musical definitions and events. Then, other software can "ask" EspGrid about the situation (using a simple OSC protocol), receiving an accurate answer while being shielded from much of the complexity of the question.

EspGrid's development began in the busy rehearsal and performance environment of McMaster University’s Cybernetic Orchestra, originally as part of the project "Scalable, Collective Traditions of Electronic Sound Performance" supported by Canada’s Social Sciences and Humanities Research Council (SSHRC), and the Arts Research Board of McMaster University. Aspects of its design and use have been discussed in contributions to the Audio Engineering Society and Computer Music Journal.

A number of features distinguish EspGrid from most other synchronization and sharing systems for electronic music:

- a collection of different algorithms to estimate time differences are included, and can be selected on the fly
- it is a freestanding application, not built on top of or dependent upon, common audio programming environments
- a rudimentary "bridge" system allows the construction of ensembles spanning local-area/wide-area networks

# Where to next?  

To learn more about installing or building EspGrid, and getting started, see the document INSTALLING.md.

To learn more about the simple OSC protocol used to receive information from EspGrid, and to control it, see the document OSC.md.

To learn more about the internal protocol used for communication between EspGrid instances, see the document internal.md.
