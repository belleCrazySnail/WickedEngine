#include "wiTimer.h"
#include "wiHelper.h"

#ifdef _WIN32
double wiTimer::PCFreq = 0;
__int64 wiTimer::CounterStart = 0;
#elif __APPLE__
#import <Foundation/Foundation.h>

double wiTimer::CounterStart = 0;
#endif

wiTimer::wiTimer()
{
	if(CounterStart==0)
		Start();
	record();
}


wiTimer::~wiTimer()
{
}

void wiTimer::Start()
{
#ifdef _WIN32
    LARGE_INTEGER li;
    if(!QueryPerformanceFrequency(&li))
		wiHelper::messageBox("QueryPerformanceFrequency failed!\n");

    PCFreq = double(li.QuadPart)/1000.0;

    QueryPerformanceCounter(&li);
    CounterStart = li.QuadPart;
#elif __APPLE__
    CounterStart = CFAbsoluteTimeGetCurrent();
#endif
}
double wiTimer::TotalTime()
{
#ifdef _WIN32
    LARGE_INTEGER li;
    QueryPerformanceCounter(&li);
    return double(li.QuadPart-CounterStart)/PCFreq;
#elif __APPLE__
    return CFAbsoluteTimeGetCurrent() - CounterStart;
#endif
}

void wiTimer::record()
{
	lastTime = TotalTime();
}
double wiTimer::elapsed()
{
	return TotalTime() - lastTime;
}
