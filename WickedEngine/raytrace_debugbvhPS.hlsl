#define RAYTRACE_EXIT 256
#include "globals.hlsli"
#include "ShaderInterop_TracedRendering.h"
#include "ShaderInterop_BVH.h"
#include "tracedRenderingHF.hlsli"
#include "raySceneIntersectHF.hlsli"

float4 main(float4 pos : SV_POSITION, float2 clipspace : TEXCOORD) : SV_Target
{
	Ray ray = CreateCameraRay(clipspace);

	uint hitCount = TraceBVH(ray);

	if (hitCount == 0xFFFFFFFF)
	{
		return float4(1, 0, 1, 1); // error: stack overflow (purple)
	}
	if (hitCount == (0xFFFFFFFF - 1))
	{
		return float4(1, 1, 1, 1); // error: exit condition reached (white)
	}

	const float3 mapTex[] = {
		float3(0,0,0),
		float3(0,0,1),
		float3(0,1,1),
		float3(0,1,0),
		float3(1,1,0),
		float3(1,0,0),
	};
	const uint mapTexLen = 5;
	const uint maxHeat = 100;
	float l = saturate((float)hitCount / maxHeat) * mapTexLen;
	float3 a = mapTex[floor(l)];
	float3 b = mapTex[ceil(l)];
	float4 heatmap = float4(lerp(a, b, l - floor(l)), 0.8f);

	return heatmap;
}