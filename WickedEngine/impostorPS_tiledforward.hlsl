#include "globals.hlsli"
#include "impostorHF.hlsli"
#include "objectHF.hlsli"

[earlydepthstencil]
GBUFFEROutputType_Thin main(VSOut input)
{
	float3 uv_col = input.tex;
	float3 uv_nor = uv_col + impostorCaptureAngles;
	float3 uv_sur = uv_nor + impostorCaptureAngles;

	float4 color = impostorTex.Sample(sampler_linear_clamp, uv_col);
	float4 normal = impostorTex.Sample(sampler_linear_clamp, uv_nor);
	float4 surfaceparams = impostorTex.Sample(sampler_linear_clamp, uv_sur);

	float3 N = normal.rgb;

	float ao = surfaceparams.r;
	float roughness = surfaceparams.g;
	float metalness = surfaceparams.b;
	float reflectance = surfaceparams.a;

	float3 V = g_xCamera_CamPos - input.pos3D;
	float dist = length(V);
	V /= dist;
	Surface surface = CreateSurface(input.pos3D, input.nor, V, color, ao, roughness, metalness, reflectance);
	float2 pixel = input.pos.xy;
	float depth = input.pos.z;
	float3 diffuse = 0;
	float3 specular = 0;
	float3 reflection = 0;
	float2 velocity = ((input.pos2DPrev.xy / input.pos2DPrev.w - g_xFrame_TemporalAAJitterPrev) - (input.pos2D.xy / input.pos2D.w - g_xFrame_TemporalAAJitter)) * float2(0.5f, -0.5f);

	TiledLighting(pixel, surface, diffuse, specular, reflection);

	ApplyLighting(surface, diffuse, specular, color);

	ApplyFog(dist, color);

	return CreateGbuffer_Thin(color, surface, velocity);
}