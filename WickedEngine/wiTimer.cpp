#include "wiTimer.h"

#ifdef __APPLE__
#include "wiObjCHelper.h"

double wiTimer::CounterStart = 0;
#else
#include "wiHelper.h"
double wiTimer::PCFreq = 0;
__int64 wiTimer::CounterStart = 0;
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
#ifdef __APPLE__
    CounterStart = wiObjCHelper::getCurrentTime();
#else
    LARGE_INTEGER li;
    if(!QueryPerformanceFrequency(&li))
		wiHelper::messageBox("QueryPerformanceFrequency failed!\n");

    PCFreq = double(li.QuadPart)/1000.0;

    QueryPerformanceCounter(&li);
    CounterStart = li.QuadPart;
#endif
}
double wiTimer::TotalTime()
{
#ifdef __APPLE__
    return wiObjCHelper::getCurrentTime() - CounterStart;
#else
    LARGE_INTEGER li;
    QueryPerformanceCounter(&li);
    return double(li.QuadPart-CounterStart)/PCFreq;
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
