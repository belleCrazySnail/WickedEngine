#pragma once
#include "CommonInclude.h"

class wiTimer
{
private:
#ifdef _WIN32
	static double PCFreq;
	static __int64 CounterStart;
#elif __APPLE__
    static double CounterStart;
#endif
    
	double lastTime;
public:
	wiTimer();
	~wiTimer();

	static void Start();
	static double TotalTime(); 

	//start recording
	void record();
	//elapsed time since record()
	double elapsed();
};

