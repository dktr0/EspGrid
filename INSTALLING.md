# Installing/Using/Building EspGrid

## Installing EspGrid from prebuilt binaries

The quickest way to get started with EspGrid is to download a prebuilt binary. Recent binary builds of EspGrid for OS X and Windows are usually available here: http://esp.mcmaster.ca/?page_id=1759

## Additional installation steps on Windows

On Windows, EspGrid is distributed as "command-line" application called espgridd (for "EspGrid Daemon"). Don't worry if the command line isn't your thing - you won't need to work with it at the command line. For the espgridd binary to work on Windows, however, you'll need to install two basic packages from the free/open-source GNUstep project. Install the "GNUstep MSYS System" and "GNUstep Core".

In some cases, if you've installed the GNUstep packages, you can run espgridd simply by clicking on the espgridd.exe file wherever you have unzipped it to. In other cases, restarting the system can help the first time. In some others cases still, it may help to move the espgridd.exe file to C:\GNUstep\bin\. The provided binaries work for Windows XP and later.

## Linux

On Linux, you'll need to build espgridd from source.  See the section below on Building from Source.

## Using EspGrid

Once you have EspGrid (or espgridd) running, you'll want some way of talking to it from your performance environment.  Currently this is most convenient from SuperCollider. The Esp.sc project provides a SuperCollider quark that can be installed with a single line of SuperCollider code, and then used in a way that should be quite intuitive to SuperCollider artists. Evaluating the following line in SuperCollider will install the Esp quark:
```
Quarks.install("https://github.com/d0kt0r0/Esp.sc.git");
```

Some examples of how to use the Esp.sc SuperCollider quark are visible in the comments at the top of the quark itself, which you can view online with the following link:
https://github.com/d0kt0r0/Esp.sc/blob/master/Esp.sc

In the absence of a "helper" like the SuperCollider quark, you can send and receive OSC messages to EspGrid in any way that makes sense. EspGrid normally listens on UDP port 5510 for incoming OSC messages. You can read more about the protocol for talking to EspGrid in the document OSC.md. As time passes, hopefully more helpers like the SuperCollider quark will be created for other languages/environments.

## Building EspGrid from source

### Building EspGrid on OS X

If you want to build EspGrid from source code on OS X, start by cloning the current source tree from github. Enter the following at the Terminal: git clone https://github.com/d0kt0r0/EspGrid.git

From there, building should simply be a matter of opening the Xcode project file contained therein with Xcode and selecting Build. You can use "Archive" in Xcode to build a freestanding binary like those downloadable from the esp.mcmaster.ca site.

### Building espgridd on Windows

If you want to build EspGrid from source code on Windows, you'll need to download and install the free/open-source GNUstep development environment first. In addition to the "GNUstep MSYS System" and "GNUstep Core" you'll require the "GNUstep Devel" package. It is also recommended to install a Windows version of the git version management software.

After installing the GNUstep packages, open the GNUstep shell and clone the EspGrid source tree from github:
```
git clone https://github.com/d0kt0r0/EspGrid.git
```

Change into the directory containing the EspGrid source as follows:
```
cd EspGrid/EspGrid
```

From there, building espgridd.exe should simply be a matter of invoking make:
```
make
```

### Building espgridd on Linux

Building espgridd on Linux will, in general, be similar to building it on Windows. Make sure you have both the basic and development GNUstep packages on your system. Clone the EspGrid source tree using git. Change into the EspGrid subfolder o the EspGrid source tree and invoke "make".
