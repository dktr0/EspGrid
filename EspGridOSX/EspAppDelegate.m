//
//  EspAppDelegate.m
//
//  This file is part of EspGrid.  EspGrid is (c) 2012,2013 by David Ogborn.
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

#import "EspAppDelegate.h"
#import "EspGridDefs.h"

@implementation EspAppDelegate 

@synthesize window = _window;

-(IBAction)bridgeLocalGroup:(id)sender { [[esp bridge] setLocalGroup:[espBridgeLocalGroup stringValue]]; }
-(IBAction)bridgeLocalAddress:(id)sender { [[esp bridge] setLocalAddress:[espBridgeLocalAddress stringValue]]; }
-(IBAction)bridgeLocalPort:(id)sender { [[esp bridge] changeLocalPort:[espBridgeLocalPort intValue]]; }
-(IBAction)bridgeRemoteAdddress:(id)sender { [[esp bridge] setRemoteAddress:[espBridgeRemoteAddress stringValue]]; }
-(IBAction)bridgeRemotePort:(id)sender { [[esp bridge] setRemotePort:[espBridgeRemotePort stringValue]]; }

-(IBAction)logOSCChanged:(id)sender
{
    if([espLogOSC state]) [[EspOsc osc] setEchoToLog:YES];
    else [[EspOsc osc] setEchoToLog:NO];
}

-(IBAction)beatOn:(id)sender
{
    if([beatOn state]) [[esp beat] turnBeatOn];
    else [[esp beat] turnBeatOff];
}

-(IBAction)beatTempo:(id)sender
{
    [[esp beat] changeTempo:beatTempo.doubleValue];
}

-(IBAction)beatCycleLength:(id)sender
{
    [[esp beat] changeCycleLength:[beatCycleLength intValue]];
}

-(IBAction)sendChatMessage:(id)sender
{
    NSString* msg = [sender stringValue];
    if([msg length]>0)
    {
        [[esp chat] sendMessage:[sender stringValue]];
        [espChatMsg setStringValue:@""];
    }
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id nv = [change objectForKey:NSKeyValueChangeNewKey];
    if([keyPath isEqualToString:@"beat.on"]) [beatOn setState:[nv boolValue]];
    else if([keyPath isEqualToString:@"beat.tempo"])[beatTempo setStringValue:nv];
    else if([keyPath isEqualToString:@"beat.cycleLength"]) [beatCycleLength setStringValue:nv];      
    else if([keyPath isEqualToString:@"bridge.localGroup"]) [espBridgeLocalGroup setStringValue:nv];
    else if([keyPath isEqualToString:@"bridge.remoteAddress"]) [espBridgeRemoteAddress setStringValue:nv];
    else if([keyPath isEqualToString:@"bridge.remoteGroup"]) [espBridgeRemoteGroup setStringValue:nv];
    else if([keyPath isEqualToString:@"bridge.remoteClaimedAddress"]) [espBridgeRemoteClaimedAddress setStringValue:nv];
    else if([keyPath isEqualToString:@"bridge.remoteClaimedPort"]) [espBridgeRemoteClaimedPort setStringValue:nv];
    else if([keyPath isEqualToString:@"bridge.remotePackets"]) [espBridgeRemotePackets setStringValue:nv];
    else NSLog(@"PROBLEM: received KVO notification for unexpected keyPath %@",keyPath);
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [esp addObserver:self forKeyPath:@"beat.on" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"beat.tempo" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"beat.cycleLength" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"bridge.localGroup" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"bridge.remoteAddress" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"bridge.remoteGroup" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"bridge.remoteClaimedAddress" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"bridge.remoteClaimedPort" options:NSKeyValueObservingOptionNew context:nil];
    [esp addObserver:self forKeyPath:@"bridge.remotePackets" options:NSKeyValueObservingOptionNew context:nil];
    
    [esp setValue:[esp valueForKeyPath:@"beat.on"] forKeyPath:@"beat.on"];
    [esp setValue:[esp valueForKeyPath:@"beat.tempo"] forKeyPath:@"beat.tempo"];
    [esp setValue:[esp valueForKeyPath:@"beat.cycleLength"] forKeyPath:@"beat.cycleLength"];
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(postChatNotification:) name:@"chat" object:nil];
    [nc addObserver:self selector:@selector(postLogNotification:) name:@"log" object:nil];
    
    [NSTimer scheduledTimerWithTimeInterval:0.25
     target:self
     selector:@selector(updateClock:)
     userInfo:nil
     repeats:YES];
}

-(void) updateClock:(NSTimer*)x
{
    // EspTimeType t = [[esp clock] adjustment];
    EspTimeType t = -1; // *** not applicable anymore!
    NSString* s = [NSString stringWithFormat:@"%lld",t];
    [espClockAdjustment setStringValue:s];
    [espClockFlux setStringValue:[[[esp clock] fluxStatus] copy]];
}

-(void)postChatNotification:(NSNotification*)n
{
    [espChatOutput insertText:[NSString stringWithFormat:@"%@\n",[[n userInfo] objectForKey:@"text"]]];
}

-(void)postLogNotification:(NSNotification*)n
{
    [espLogOutput insertText:[NSString stringWithFormat:@"%@\n",[[n userInfo] objectForKey:@"text"]]];
}

-(IBAction)showPreferences:(id)sender
{
    if(!preferencesPanel)preferencesPanel = [[NSWindowController alloc] initWithWindowNibName:@"EspPreferencesPanel"];
    [preferencesPanel showWindow:self];
}

-(IBAction)showDetailedPeerList:(id)sender
{
    if(!detailedPeerList) detailedPeerList = [[EspDetailedPeerListController alloc] initWithOwner:self];
    [detailedPeerList showWindow:self];
}

-(IBAction)shareClipboard:(id)sender
{
    NSPasteboard* pasteBoard = [NSPasteboard generalPasteboard];
    NSArray* types = [pasteBoard types];
    if([types containsObject:NSStringPboardType]) {
        NSString* text = [pasteBoard stringForType:NSStringPboardType];
        [[esp codeShare] shareCode:text withTitle:@"clipboard"];
    } else postWarning(@"empty clipboard!",self);
}

-(IBAction)grabShare:(id)sender
{
    long c = [[[NSApplication sharedApplication] currentEvent] clickCount];
    long i = [sender selectedRow];
    if(c==2 && i>=0)
    {
        [[[esp codeShare] items] sortUsingDescriptors:[codeShareController sortDescriptors]];
        EspCodeShareItem* item = [[[esp codeShare] items] objectAtIndex:i]; // not crazy about this reaching in...
        NSString* content = [[esp codeShare] getOrRequestItem:item];
        if(content != nil)
        {
            NSPasteboard* pasteBoard = [NSPasteboard generalPasteboard];
            [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
            [pasteBoard setString:content forType:NSStringPboardType];
        }
    }
}

-(IBAction)copyLogToClipboard:(id)sender
{
    NSPasteboard* pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    NSString* logText = [[[espLogOutput textStorage] string] copy];
    [pasteBoard setString:logText forType:NSStringPboardType];
}

-(IBAction)helpPreferences:(id)sender
{
    NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"preferences" inBook:locBookName];
}

-(IBAction)helpPeerList:(id)sender
{
    NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"peerlist" inBook:locBookName];
}

-(IBAction)helpMain:(id)sender
{
    NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"main" inBook:locBookName];
}

-(IBAction)helpCode:(id)sender
{
    NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"code" inBook:locBookName];
}

-(IBAction)tickOnBeatsChanged:(id)sender
{
    NSMenuItem* mi = (NSMenuItem*)sender;
    if([mi state])
    {
        NSLog(@"turning ticking off!!!");
        [[esp beat] stopTicking];
        [mi setState:NO];
    }
    else
    {
        NSLog(@"turning ticking on!!!");
        [mi setState:[[esp beat] startTicking]];
    }
}

@end
