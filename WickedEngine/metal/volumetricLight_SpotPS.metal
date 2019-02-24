#define DISABLE_TRANSPARENT_SHADOWMAP
#include "deferredLightHF.h"

fragment float4 volumetricLight_SpotPS(VertexToPixel3 input [[stage_in]], constant GlobalData &gd)
{
	ShaderEntityType light = gd.EntityArray[(uint)gd.misc.g_xColor.x];

	float2 ScreenCoord = input.pos2D.xy / input.pos2D.w * float2(0.5f, -0.5f) + 0.5f;
	float depth = max(input.pos.z, gd.texture_depth.SampleLevel(gd.sampler_linear_clamp, ScreenCoord, 0));
	float3 P = getPosition(ScreenCoord, depth, gd);
	float3 V = gd.camera.g_xCamera_CamPos - P;
	float cameraDistance = length(V);
	V /= cameraDistance;

	float marchedDistance = 0;
	float3 accumulation = 0;

	float3 rayEnd = gd.camera.g_xCamera_CamPos;
	// todo: rayEnd should be clamped to the closest cone intersection point when camera is outside volume
	
	const uint sampleCount = 128;
	float stepSize = length(P - rayEnd) / sampleCount;

	// Perform ray marching to integrate light volume along view ray:
//    [loop]
	for (uint i = 0; i < sampleCount; ++i)
	{
		float3 L = light.positionWS - P;
		float dist2 = dot(L, L);
		float dist = sqrt(dist2);
		L /= dist;

		float SpotFactor = dot(L, light.directionWS);
		float spotCutOff = light.coneAngleCos;

//        [branch]
		if (SpotFactor > spotCutOff)
		{
			float range2 = light.range * light.range;
			float att = saturate(1.0 - (dist2 / range2));
			float3 attenuation = att * att;
			attenuation *= saturate((1.0 - (1.0 - SpotFactor) * 1.0 / (1.0 - spotCutOff)));

//            [branch]
			if (light.IsCastingShadow())
			{
				float4 ShPos = mul(float4(P, 1), gd.MatrixArray[light.GetShadowMatrixIndex() + 0]);
				ShPos.xyz /= ShPos.w;
				float2 ShTex = ShPos.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
//                [branch]
				if (all(bool2(saturate(ShTex) - ShTex)))
				{
					attenuation *= shadowCascade(ShPos, ShTex.xy, light.shadowKernel, light.shadowBias, light.GetShadowMapIndex(), gd);
				}
			}

			attenuation *= GetFog(distance(P, gd.camera.g_xCamera_CamPos), gd);

			accumulation += attenuation;
		}

		marchedDistance += stepSize;
		P = P + V * stepSize;
	}

	accumulation /= sampleCount;

	return max(0, float4(accumulation * light.GetColor().rgb * light.energy, 1));
}
