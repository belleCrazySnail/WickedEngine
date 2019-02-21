#include "postProcessHF.h"
#include "reconstructPositionHF.h"
#include "brdf.h"

// Avoid stepping zero distance
static constant float	g_fMinRayStep = 0.01f;
// Crude raystep count
static constant int	g_iMaxSteps = 16;
// Crude raystep scaling
static constant float	g_fRayStep = 1.18f;
// Fine raystep count
static constant int	g_iNumBinarySearchSteps = 16;
// Approximate the precision of the search (smaller is more precise)
static constant float  g_fRayhitThreshold = 0.9f;

inline bool bInsideScreen(float2 vCoord)
{
	if (vCoord.x < 0 || vCoord.x > 1 || vCoord.y < 0 || vCoord.y > 1)
		return false;
	return true;
}

float4 SSRBinarySearch(float3 vDir, thread float3 &vHitCoord, constant GlobalData &gd)
{
	float fDepth;

	for (int i = 0; i < g_iNumBinarySearchSteps; i++)
	{
		float4 vProjectedCoord = float4(vHitCoord, 1.0f) * gd.camera.g_xCamera_Proj;
		vProjectedCoord.xy /= vProjectedCoord.w;
		vProjectedCoord.xy = vProjectedCoord.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);

		fDepth = gd.texture_lineardepth.SampleLevel(gd.sampler_point_clamp, vProjectedCoord.xy, 0) * gd.frame.g_xFrame_MainCamera_ZFarP;
		float fDepthDiff = vHitCoord.z - fDepth;

		if (fDepthDiff <= 0.0f)
			vHitCoord += vDir;

		vDir *= 0.5f;
		vHitCoord -= vDir;
	}

	float4 vProjectedCoord = float4(vHitCoord, 1.0f) * gd.camera.g_xCamera_Proj;
	vProjectedCoord.xy /= vProjectedCoord.w;
	vProjectedCoord.xy = vProjectedCoord.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);

	fDepth = gd.texture_lineardepth.SampleLevel(gd.sampler_point_clamp, vProjectedCoord.xy, 0) * gd.frame.g_xFrame_MainCamera_ZFarP;
	float fDepthDiff = vHitCoord.z - fDepth;

	return float4(vProjectedCoord.xy, fDepth, abs(fDepthDiff) < g_fRayhitThreshold ? 1.0f : 0.0f);
}

float4 SSRRayMarch(float3 vDir, thread float3 &vHitCoord, constant GlobalData &gd)
{
	float fDepth;

	for (int i = 0; i < g_iMaxSteps; i++)
	{
		vHitCoord += vDir;

		float4 vProjectedCoord = float4(vHitCoord, 1.0f) * gd.camera.g_xCamera_Proj;
		vProjectedCoord.xy /= vProjectedCoord.w;
		vProjectedCoord.xy = vProjectedCoord.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);

		fDepth = gd.texture_lineardepth.SampleLevel(gd.sampler_point_clamp, vProjectedCoord.xy, 0) * gd.frame.g_xFrame_MainCamera_ZFarP;

		float fDepthDiff = vHitCoord.z - fDepth;

//        [branch]
		if (fDepthDiff > 0.0f)
			return SSRBinarySearch(vDir, vHitCoord, gd);

		vDir *= g_fRayStep;

	}

	return float4(0.0f, 0.0f, 0.0f, 0.0f);
}

fragment float4 ssr(VertexToPixelPostProcess input [[stage_in]], constant GlobalData &gd)
{
	float3 N = decode(gd.texture_gbuffer1.read(uint2(input.pos.xy)).xy);
	float3 P = getPosition(input.tex, gd.texture_depth.read(uint2(input.pos.xy)), gd);


	//Reflection vector
	float3 vViewPos = (float4(P.xyz, 1) * gd.camera.g_xCamera_View).xyz;
	float3 vViewNor = (float4(N, 0) * gd.camera.g_xCamera_View).xyz;
	float3 vReflectDir = normalize(reflect(vViewPos.xyz, vViewNor.xyz));


	//Raycast
	float3 vHitPos = vViewPos;

	float4 vCoords = SSRRayMarch(vReflectDir /** max( g_fMinRayStep, vViewPos.z )*/, vHitPos, gd);

	float2 vCoordsEdgeFact = float2(1, 1) - pow(saturate(abs(vCoords.xy - float2(0.5f, 0.5f)) * 2), 8);
	float fScreenEdgeFactor = saturate(min(vCoordsEdgeFact.x, vCoordsEdgeFact.y));


	//Color
	float reflectionIntensity =
		saturate(
			fScreenEdgeFactor *		// screen fade
			saturate(vReflectDir.z)	// camera facing fade
			* vCoords.w				// rayhit binary fade
			);


	float3 reflectionColor = xTexture.SampleLevel(gd.sampler_linear_clamp, vCoords.xy, 0).rgb;

	return max(0, float4(reflectionColor, reflectionIntensity));

}
