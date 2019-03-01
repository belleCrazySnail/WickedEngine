
#define RAYTRACE_EXIT 128 // doing the path trace in pixel shader will hang the GPU for some reason if we don't set a cap on the trace loop...
#define RAY_BACKFACE_CULLING
#include "raySceneIntersectHF.h"

fragment float4 renderlightmapPS_indirect(VertexToPixel4 input [[stage_in]], constant GlobalData &gd)
{
	float3 P = input.pos3D;
	float3 N = normalize(input.normal);
	float2 uv = input.uv;
	float seed = gd.traced.xTraceRandomSeed;
	float3 direction = SampleHemisphere(N, seed, uv);
	Ray ray = CreateRay(trace_bias_position(P, N), direction);
	float3 finalResult = 0;

	uint bounces = gd.traced.xTraceUserData2.x;
	for (uint i = 0; (i < bounces) && any(bool3(ray.energy)); ++i)
	{
		// Sample primary ray (scene materials, sky, etc):
		RayHit hit = TraceScene(ray, gd);
		finalResult += ray.energy * Shade(ray, hit, seed, uv, gd);

		// We sample explicit lights for every bounce, but only diffuse part. Specular will not be baked here.
		//	Also, because we do it after the primary ray was bounced off, we only get the indirect part.
		//	Dynamic (explicit) lights will contribute to the direct part later (based on render path specific shaders)
//        [loop]
		for (uint iterator = 0; iterator < gd.frame.g_xFrame_LightArrayCount; iterator++)
		{
			ShaderEntityType light = gd.EntityArray[gd.frame.g_xFrame_LightArrayOffset + iterator];

			if (!(light.GetFlags() & ENTITY_FLAG_LIGHT_STATIC))
			{
				continue; // dynamic lights will not be baked into lightmap
			}

            LightingResult result = {};

			float3 L = 0;
			float dist = 0;

			switch (light.GetType())
			{
			case ENTITY_TYPE_DIRECTIONALLIGHT:
			{
				dist = INFINITE_RAYHIT;

				float3 lightColor = light.GetColor().rgb*light.energy;

				L = light.directionWS.xyz;

				result.diffuse = lightColor;
			}
			break;
			case ENTITY_TYPE_POINTLIGHT:
			{
				L = light.positionWS - ray.origin;
				float dist2 = dot(L, L);
				dist = sqrt(dist2);

//                [branch]
				if (dist < light.range)
				{
					L /= dist;

					float3 lightColor = light.GetColor().rgb*light.energy;

					result.diffuse = lightColor;

					float range2 = light.range * light.range;
					float att = saturate(1.0 - (dist2 / range2));
					float attenuation = att * att;

					result.diffuse *= attenuation;
				}
			}
			break;
			case ENTITY_TYPE_SPOTLIGHT:
			{
				L = light.positionWS - ray.origin;
				float dist2 = dot(L, L);
				dist = sqrt(dist2);

//                [branch]
				if (dist < light.range)
				{
					L /= dist;

					float3 lightColor = light.GetColor().rgb*light.energy;

					float SpotFactor = dot(L, light.directionWS);
					float spotCutOff = light.coneAngleCos;

//                    [branch]
					if (SpotFactor > spotCutOff)
					{
						result.diffuse = lightColor;

						float range2 = light.range * light.range;
						float att = saturate(1.0 - (dist2 / range2));
						float attenuation = att * att;
						attenuation *= saturate((1.0 - (1.0 - SpotFactor) * 1.0 / (1.0 - spotCutOff)));

						result.diffuse *= attenuation;
					}
				}
			}
			break;
			case ENTITY_TYPE_SPHERELIGHT:
			{
			}
			break;
			case ENTITY_TYPE_DISCLIGHT:
			{
			}
			break;
			case ENTITY_TYPE_RECTANGLELIGHT:
			{
			}
			break;
			case ENTITY_TYPE_TUBELIGHT:
			{
			}
			break;
			}

			float NdotL = saturate(dot(L, hit.N));

			if (NdotL > 0 && dist > 0)
			{
				result.diffuse = max(0.0f, result.diffuse);

				float3 sampling_offset = float3(rand(seed, uv), rand(seed, uv), rand(seed, uv)) * 2 - 1;

				Ray newRay;
				newRay.origin = ray.origin;
				newRay.direction = L + sampling_offset * 0.025f;
				newRay.direction_inverse = 1.0 / (newRay.direction);
				newRay.energy = 0;
				bool hit = TraceSceneANY(newRay, dist, gd);
				finalResult += ray.energy * (hit ? 0 : NdotL) * (result.diffuse);
			}
		}
	}

	return max(0, float4(finalResult, gd.traced.xTraceUserData));
}
