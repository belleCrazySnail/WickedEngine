#include "imageHF.h"

fragment float4 imagePS_distortion_masked_bicubic(VertexToPixel PSIn [[stage_in]], constant GlobalData &gd)
{
	float2 distortionCo = PSIn.pos2D.xy / PSIn.pos2D.w * float2(0.5f, -0.5f) + 0.5f;
	float2 distort = xDistortionTex.SampleLevel(gd.customsampler0, PSIn.tex.xy, 0).rg * 2 - 1;
	PSIn.tex.xy = distortionCo + distort;

	float4 color = SampleTextureCatmullRom(xTexture, PSIn.tex.xy, gd.image.xMipLevel, gd) * gd.image.xColor;

	color *= xMaskTex.SampleLevel(gd.customsampler0, PSIn.tex.xy, gd.image.xMipLevel);

	return color;
}
