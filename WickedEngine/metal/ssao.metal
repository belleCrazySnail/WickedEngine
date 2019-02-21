#include "postProcessHF.h"
#include "reconstructPositionHF.h"


// Hemisphere point generation from:
//	http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html

inline float radicalInverse_VdC(uint bits) {
	bits = (bits << 16u) | (bits >> 16u);
	bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
	bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
	bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
	bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
	return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}
inline float2 hammersley2d(uint i, uint N) {
	return float2(float(i) / float(N), radicalInverse_VdC(i));
}

inline float3 hemisphereSample_uniform(float u, float v) {
	float phi = v * 2.0 * PI;
	float cosTheta = 1.0 - u;
	float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
	return float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

inline float3 hemisphereSample_cos(float u, float v) {
	float phi = v * 2.0 * PI;
	float cosTheta = sqrt(1.0 - u);
	float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
	return float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

inline float3x3 GetTangentSpace(float3 normal)
{
	// Choose a helper vector for the cross product
	float3 helper = abs(normal.x) > 0.99f ? float3(0, 0, 1) : float3(1, 0, 0);

	// Generate vectors
	float3 tangent = normalize(cross(normal, helper));
	float3 binormal = normalize(cross(normal, tangent));
	return float3x3(tangent, binormal, normal);
}

fragment float4 ssao(VertexToPixelPostProcess input [[stage_in]], constant GlobalData &gd)
{
	const float range = gd.postproc.xPPParams0.x;
	const uint sampleCount = gd.postproc.xPPParams0.y;

	float3 noise = xMaskTex.read(uint2(64 * input.tex.xy * 400) % 64, 0).xyz * 2.0 - 1.0;
	float3 normal = decode(gd.texture_gbuffer1.SampleLevel(gd.sampler_linear_clamp, input.tex, 0).xy);
	float3 P = getPosition(input.tex, gd.texture_depth.SampleLevel(gd.sampler_point_clamp, input.tex, 0), gd);

	float3 tangent = normalize(noise - normal * dot(noise, normal));
	float3 bitangent = cross(normal, tangent);
	float3x3 tangentSpace = float3x3(tangent, bitangent, normal);

	float center_depth = gd.texture_lineardepth.SampleLevel(gd.sampler_point_clamp, input.tex, 0);
	center_depth -= 0.0006f; // self-occlusion bias

	float ao = 0;
	for (uint i = 0; i < sampleCount; ++i)
	{
		float2 hamm = hammersley2d(i, sampleCount);
		float3 hemisphere = hemisphereSample_uniform(hamm.x, hamm.y);
		float3 cone = mul(hemisphere, tangentSpace);
		float3 sam = P + cone * range;

		float4 vProjectedCoord = mul(float4(sam, 1.0f), gd.camera.g_xCamera_VP);
		vProjectedCoord.xy /= vProjectedCoord.w;
		vProjectedCoord.xy = vProjectedCoord.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);

		float ray_depth = gd.texture_lineardepth.SampleLevel(gd.sampler_point_clamp, vProjectedCoord.xy, 0);

		float depth_fix = 1 - saturate(abs(center_depth - ray_depth) * 200); // too much depth difference cancels the effect

		ao += (ray_depth < center_depth ? 1 : 0) * depth_fix;
	}
	ao /= (float)sampleCount;

	return saturate(1 - float4(ao));
}
