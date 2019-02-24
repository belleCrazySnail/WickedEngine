#include "imageHF.h"

fragment float4 imagePS_bicubic(VertexToPixel PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = SampleTextureCatmullRom(xTexture, PSIn.tex.xy, gd.image.xMipLevel, gd) * gd.image.xColor;

	return color;
}
