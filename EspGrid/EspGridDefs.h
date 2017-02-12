//
//  EspGridDefs.h
//
//  This file is part of EspGrid.  EspGrid is (c) 2012-2015 by David Ogborn.
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

#ifndef EspGrid_EspGridDefs_h
#define EspGrid_EspGridDefs_h

#define ESPGRID_MAJORVERSION 0
#define ESPGRID_MINORVERSION 57 // changes to external/internal protocol MUST increment MINORVERSION
#define ESPGRID_SUBVERSION 0

#define ESP_NUMBER_OF_OPCODES 10
#define ESP_OPCODE_BEACON 0
#define ESP_OPCODE_ACK 1
#define ESP_OPCODE_PEERINFO 4
#define ESP_OPCODE_CHATSEND 2
#define ESP_OPCODE_KVC 3
#define ESP_OPCODE_ANNOUNCESHARE 5
#define ESP_OPCODE_REQUESTSHARE 6
#define ESP_OPCODE_DELIVERSHARE 7
#define ESP_OPCODE_OSCNOW 8
#define ESP_OPCODE_OSCFUTURE 9

#define ESP_POST_CHAT 1
#define ESP_POST_LOG 2

#define VALIDATE_OPCODE_NSSTRING(vx) \
 do { \
    if(vx == nil) { postWarning(@"opcode with no " #vx,self); return; } \
    if(![vx isKindOfClass:[NSString class]]) { postWarning(@"opcode with " #vx " not NSString",self); return; } \
    if([vx length]==0){ postWarning(@"opcode with zero length " #vx,self); return; } \
 } while(0)

#define VALIDATE_OPCODE_NSNUMBER(vx) \
 do { \
    if(vx == nil) { postWarning(@"opcode with no " #vx,self); return; } \
    if(![vx isKindOfClass:[NSNumber class]]) { postWarning(@"opcode with " #vx " not NSString",self); return; } \
 } while(0)


void postChat(NSString* s);
void postWarning(NSString* s,id sender);
void postProblem(NSString* s,id sender);
void postLog(NSString* s,id sender);
void postLogHighVolume(NSString* s,id sender);

#import <sys/time.h>

#ifdef _WIN32
#include <Windows.h>
#endif

#ifndef GNUSTEP
#import <mach/mach_time.h>
typedef SInt64 EspTimeType;
#else
typedef int64_t EspTimeType;
#endif

inline static EspTimeType systemTime(void) {
#ifndef _WIN32
 // OS X and Linux (MINGW/GNUSTEP)
    struct timeval t;
    gettimeofday(&t, NULL);
    return (t.tv_sec*1000000000) + (t.tv_usec*1000);
#else
 // Windows (MINGW/GNUSTEP)
  SYSTEMTIME s;
  FILETIME f;
  GetSystemTime(&s);
  SystemTimeToFileTime(&s,&f);
  EspTimeType r;
  r = f.dwLowDateTime;
  r += ((uint64_t)f.dwHighDateTime) <<32;
  r -= 116444736000000000ULL; // epoch adjustment (Windows to UNIX)
  r *= 100; // one hundred nanoseconds per Windows tick
  return r;
#endif
}

inline static EspTimeType monotonicTime(void) {
#ifndef GNUSTEP
	// OS X
    return mach_absolute_time();
#else
#ifdef _WIN32
	// Windows (MINGW/GNUSTEP)
  extern LARGE_INTEGER performanceFrequency;
	LARGE_INTEGER t;
	QueryPerformanceCounter(&t);
	EspTimeType x = t.QuadPart / performanceFrequency.QuadPart * 1000000000L; // whole seconds in nanoseconds
	EspTimeType y = t.QuadPart % performanceFrequency.QuadPart * 1000000000L / performanceFrequency.QuadPart; // remainder
	return x+y;
#else
	// Linux (GNUSTEP)
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC,&t);
    // NSLog(@"in monotonic time %ld %ld",t.tv_sec,t.tv_nsec);
    EspTimeType w = (EspTimeType)t.tv_sec*(EspTimeType)1000000000+(EspTimeType)t.tv_nsec;
    // return (t.tv_sec*1000000000) + (t.tv_nsec);
    return w;
#endif
#endif
}

#ifdef GNUSTEP

#ifdef _WIN32
// GNUSTEP/MINGW (Windows)
#include <stdlib.h>
typedef uint32_t UInt32;
typedef float Float32;
typedef double Float64;
inline static UInt32 EspSwapInt32(UInt32 x) { return htonl(x); }
inline static Float32 EspSwapFloat32(const Float32 x) {
	unsigned char* c = (unsigned char*)&x;
	uint32_t y = c[3] + (c[2] << 8) + (c[1] << 16) + (c[0] << 24);
	float z = *((float*)&y);
	return z;
}
inline static Float64 EspSwapFloat64(double x) { return __builtin_bswap64(x); }
#endif

#ifndef _WIN32
// GNUSTEP/Linux
#include <endian.h>
typedef uint32_t UInt32;
typedef float Float32;
typedef double Float64;
inline static UInt32 EspSwapInt32(UInt32 x) { return htobe32(x); }
inline static Float32 EspSwapFloat32(Float32 x) { return htobe32(x); }
inline static Float64 EspSwapFloat64(double x) { return htobe64(x); }
#endif

#endif

#ifndef GNUSTEP
// Cocoa/OSX
inline static UInt32 EspSwapInt32(UInt32 x) {return CFSwapInt32(x); }
inline static Float32 EspSwapFloat32(Float32 x) {
    CFSwappedFloat32 y = CFConvertFloatHostToSwapped(x);
    return *((Float32*)(&y));
}
inline static Float64 EspSwapFloat64(double x) { return CFSwapInt64(*((UInt64*)&x)); }
#endif

#endif
