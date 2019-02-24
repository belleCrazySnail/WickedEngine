#include "imageHF.h"

fragment float4 imagePS_masked_bicubic(VertexToPixel PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = SampleTextureCatmullRom(xTexture, PSIn.tex.xy, gd.image.xMipLevel, gd) * gd.image.xColor;

	color *= xMaskTex.SampleLevel(gd.customsampler0, PSIn.tex_original.xy, gd.image.xMipLevel);

	return color;
}
