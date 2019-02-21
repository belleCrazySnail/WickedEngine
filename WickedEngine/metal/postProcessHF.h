#ifndef _POSTPROCESS_HF_
#define _POSTPROCESS_HF_

#include "imageHF.h"
#include "packHF.h"

inline float2 GetVelocity(int2 pixel, constant GlobalData &gd)
{
#ifdef DILATE_VELOCITY_BEST_3X3 // search best velocity in 3x3 neighborhood

	float bestDepth = 1;
	int2 bestPixel = int2(0, 0);

//    [loop]
	for (int i = -1; i <= 1; ++i)
	{
//        [unroll]
		for (int j = -1; j <= 1; ++j)
		{
			int2 curPixel = pixel + int2(i, j);
			float depth = gd.texture_lineardepth.read(uint2(curPixel));
//            [flatten]
			if (depth < bestDepth)
			{
				bestDepth = depth;
				bestPixel = curPixel;
			}
		}
	}

	return gd.texture_gbuffer1.read(uint2(bestPixel)).zw;

#elif defined DILATE_VELOCITY_BEST_FAR // search best velocity in a far reaching 5-tap pattern

	float bestDepth = 1;
	int2 bestPixel = int2(0, 0);

	// top-left
	int2 curPixel = pixel + int2(-2, -2);
	float depth = gd.texture_lineardepth.read(uint2(curPixel));
//    [flatten]
	if (depth < bestDepth)
	{
		bestDepth = depth;
		bestPixel = curPixel;
	}

	// top-right
	curPixel = pixel + int2(2, -2);
	depth = gd.texture_lineardepth.read(uint2(curPixel));
//    [flatten]
	if (depth < bestDepth)
	{
		bestDepth = depth;
		bestPixel = curPixel;
	}

	// bottom-right
	curPixel = pixel + int2(2, 2);
	depth = gd.texture_lineardepth.read(uint2(curPixel));
//    [flatten]
	if (depth < bestDepth)
	{
		bestDepth = depth;
		bestPixel = curPixel;
	}

	// bottom-left
	curPixel = pixel + int2(-2, 2);
	depth = gd.texture_lineardepth.read(uint2(curPixel));
//    [flatten]
	if (depth < bestDepth)
	{
		bestDepth = depth;
		bestPixel = curPixel;
	}

	// center
	curPixel = pixel;
	depth = gd.texture_lineardepth.read(uint2(curPixel));
//    [flatten]
	if (depth < bestDepth)
	{
		bestDepth = depth;
		bestPixel = curPixel;
	}

	return gd.texture_gbuffer1.read(uint2(bestPixel)).zw;

#elif defined DILATE_VELOCITY_AVG_FAR

	float2 velocity_TL = gd.texture_gbuffer1.read(uint2(pixel + int2(-2, -2))).zw;
	float2 velocity_TR = gd.texture_gbuffer1.read(uint2(pixel + int2(2, -2))).zw;
	float2 velocity_BL = gd.texture_gbuffer1.read(uint2(pixel + int2(-2, 2))).zw;
	float2 velocity_BR = gd.texture_gbuffer1.read(uint2(pixel + int2(2, 2))).zw;
	float2 velocity_CE = gd.texture_gbuffer1.read(uint2(pixel)).zw;

	return (velocity_TL + velocity_TR + velocity_BL + velocity_BR + velocity_CE) / 5.0f;

#else

	return gd.texture_gbuffer1.read(uint2(pixel)).zw;

#endif // DILATE_VELOCITY
}

#endif // _POSTPROCESS_HF_
