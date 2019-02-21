#include "postProcessHF.h"

fragment float4 toneMapPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float2 distortion = xDistortionTex.SampleLevel(gd.sampler_linear_clamp, PSIn.tex,0).rg;

	float4 hdr = xTexture.SampleLevel(gd.sampler_linear_clamp, PSIn.tex + distortion, 0);
	float exposure = gd.postproc.xPPParams0.x;
	hdr.rgb *= exposure;

	float average_luminance = xMaskTex.read(uint2(0, 0)).r;
	float luminance = dot(hdr.rgb, float3(0.2126, 0.7152, 0.0722));
	luminance /= average_luminance; // adaption
	hdr.rgb *= luminance;

	float4 ldr = saturate(float4(tonemap(hdr.rgb), hdr.a));

	ldr.rgb = GAMMA(ldr.rgb);

	return ldr;
}
