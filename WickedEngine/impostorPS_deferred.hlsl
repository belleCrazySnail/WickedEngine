#include "globals.hlsli"
#include "impostorHF.hlsli"
#include "ditherHF.hlsli"
#include "objectHF.hlsli"

GBUFFEROutputType main(VSOut input)
{
	clip(dither(input.pos.xy + GetTemporalAASampleRotation()) - input.dither);

	float3 uv_col = input.tex;
	float3 uv_nor = uv_col + impostorCaptureAngles;
	float3 uv_sur = uv_nor + impostorCaptureAngles;

	float4 color = impostorTex.Sample(sampler_linear_clamp, uv_col);
	ALPHATEST(color.a);

	float4 normal = impostorTex.Sample(sampler_linear_clamp, uv_nor);
	float4 surfaceparams = impostorTex.Sample(sampler_linear_clamp, uv_sur);

	float3 N = normal.rgb;

	float ao = surfaceparams.r;
	float roughness = surfaceparams.g;
	float metalness = surfaceparams.b;
	float reflectance = surfaceparams.a;

	Surface surface = CreateSurface(0, input.nor, 0, color, ao, roughness, metalness, reflectance);

	float2 velocity = ((input.pos2DPrev.xy / input.pos2DPrev.w - g_xFrame_TemporalAAJitterPrev) - (input.pos2D.xy / input.pos2D.w - g_xFrame_TemporalAAJitter)) * float2(0.5f, -0.5f);

	return CreateGbuffer(color, surface, velocity, 0, 0);
}