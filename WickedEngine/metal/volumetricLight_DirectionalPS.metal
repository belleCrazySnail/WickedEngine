#define DISABLE_TRANSPARENT_SHADOWMAP
#define DISABLE_SOFT_SHADOWS
#include "deferredLightHF.h"

fragment float4 volumetricLight_DirectionalPS(VertexToPixel3 input [[stage_in]], constant GlobalData &gd)
{
	ShaderEntityType light = gd.EntityArray[(uint)gd.misc.g_xColor.x];

	if (!light.IsCastingShadow())
	{
		// Dirlight volume has no meaning without shadows!!
		return float4(0);
	}

	float2 ScreenCoord = input.pos2D.xy / input.pos2D.w * float2(0.5f, -0.5f) + 0.5f;
	float depth = max(input.pos.z, gd.texture_depth.SampleLevel(gd.sampler_linear_clamp, ScreenCoord, 0));
	float3 P = getPosition(ScreenCoord, depth, gd);
	float3 V = gd.camera.g_xCamera_CamPos - P;
	float cameraDistance = length(V);
	V /= cameraDistance;

	float marchedDistance = 0;
	float3 accumulation = 0;

	float3 L = light.directionWS;

	float3 rayEnd = gd.camera.g_xCamera_CamPos;

	const uint sampleCount = 128;
	float stepSize = length(P - rayEnd) / sampleCount;

	// Perform ray marching to integrate light volume along view ray:
//    [loop]
	for (uint i = 0; i < sampleCount; ++i)
	{
		float3 attenuation = 1;

		float4 ShPos = mul(float4(P, 1), gd.MatrixArray[light.GetShadowMatrixIndex() + 0]);
		ShPos.xyz /= ShPos.w;
		float3 ShTex = ShPos.xyz * float3(0.5f, -0.5f, 0.5f) + 0.5f;

//        [branch]
        if (all(bool3(saturate(ShTex) - ShTex)))
		{
			attenuation *= shadowCascade(ShPos, ShTex.xy, light.shadowKernel, light.shadowBias, light.GetShadowMapIndex() + 0, gd);
		}

		attenuation *= GetFog(cameraDistance - marchedDistance, gd);

		accumulation += attenuation;

		marchedDistance += stepSize;
		P = P + V * stepSize;
	}

	accumulation /= sampleCount;

	return max(0, float4(accumulation * light.GetColor().rgb * light.energy, 1));
}
