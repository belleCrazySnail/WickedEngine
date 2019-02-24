#define DISABLE_TRANSPARENT_SHADOWMAP
#include "globals.h"
#include "lightingHF.h"
#include "reconstructPositionHF.h"

fragment float4 volumetricLight_PointPS(VertexToPixel3 input [[stage_in]], constant GlobalData &gd)
{
	ShaderEntityType light = gd.EntityArray[(uint)gd.misc.g_xColor.x];

	float2 ScreenCoord = input.pos2D.xy / input.pos2D.w * float2(0.5f, -0.5f) + 0.5f;
	float depth = max(input.pos.z, gd.texture_depth.SampleLevel(gd.sampler_linear_clamp, ScreenCoord, 0));
	float3 P = getPosition(ScreenCoord, depth, gd);
	float3 V = gd.camera.g_xCamera_CamPos - P;
	float cameraDistance = length(V);
	V /= cameraDistance;

	float marchedDistance = 0;
	float accumulation = 0;

	float3 rayEnd = gd.camera.g_xCamera_CamPos;
	if (length(rayEnd - light.positionWS) > light.range)
	{
		// if we are outside the light volume, then rayEnd will be the traced sphere frontface:
		float t = Trace_sphere(rayEnd, -V, light.positionWS, light.range);
		rayEnd = rayEnd - t * V;
	}

	const uint sampleCount = 128;
	float stepSize = length(P - rayEnd) / sampleCount;

	// Perform ray marching to integrate light volume along view ray:
//    [loop]
	for(uint i = 0; i < sampleCount; ++i)
	{
		float3 L = light.positionWS - P;
		float dist2 = dot(L, L);
		float dist = sqrt(dist2);
		L /= dist;

		float range2 = light.range * light.range;
		float att = saturate(1.0 - (dist2 / range2));
		float attenuation = att * att;

//        [branch]
		if (light.IsCastingShadow()) {
			attenuation *= gd.texture_shadowarray_cube.SampleCmpLevelZero(gd.sampler_cmp_depth, -L, light.GetShadowMapIndex(), 1 - dist / light.range * (1 - light.shadowBias));
		}

		attenuation *= GetFog(cameraDistance - marchedDistance, gd);

		accumulation += attenuation;

		marchedDistance += stepSize;
		P = P + V * stepSize;
	}

	accumulation /= sampleCount;

	return max(0, float4(float3(accumulation) * light.GetColor().rgb * light.energy, 1));
}
