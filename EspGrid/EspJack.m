//
//  EspJack.m
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

#import "EspJack.h"
// #include <stdio.h>
// #include <errno.h>
// #include <unistd.h>
// #include <stdlib.h>
// #include <string.h>
#import <jack/jack.h>

static int processCallback(jack_nframes_t nframes, void *arg);
static void shutdownCallback(void* arg);

@implementation EspJack

-(id) init 
{
    self = [super init];
    jack_status_t openStatus;
    client = jack_client_open("esp",JackNoStartServer,&openStatus);
    if(!client)
    {
        NSLog(@"EspJack: jack server not running?");
        return nil;
    }
    jack_set_process_callback (client, processCallback, (void*)self);
    jack_on_shutdown (client, shutdownCallback, (void*)self);
    NSLog(@"Jack sample rate: %d",jack_get_sample_rate(client));

    input = jack_port_register (client, "send", JACK_DEFAULT_AUDIO_TYPE, JackPortIsInput, 0);
    output = jack_port_register (client, "receive", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);

    if (jack_activate (client))
    {
        NSLog(@"EspJack: cannot activate client");
        return nil;
    }

    return self;
}

-(void) dealloc
{
    jack_client_close (client);
    [super dealloc];
}

-(int) process: (int)jack_nframes_t
{
    // jack_default_audio_sample_t *out = (jack_default_audio_sample_t *) jack_port_get_buffer (output_port, nframes);
    // jack_default_audio_sample_t *in = (jack_default_audio_sample_t *) jack_port_get_buffer (input_port, nframes);
    // memcpy (out, in, sizeof (jack_default_audio_sample_t) * nframes);
    return 0;
}

-(void) shutdown
{
    NSLog(@"Jack shutdown received");
}

static int processCallback(jack_nframes_t nframes, void *arg)
{
    EspJack* j = (__bridge EspJack*)arg;
    return [j process:nframes];
}

static void shutdownCallback(void* arg)
{
    EspJack* j = (__bridge EspJack*)arg;
    [j shutdown];
}

@end
