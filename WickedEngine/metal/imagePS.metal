#include "imageHF.h"

fragment float4 imagePS(VertextoPixel PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = xTexture.SampleLevel(gd.customsampler0, PSIn.tex.xy, gd.image.xMipLevel) * gd.image.xColor;

	return color;
}
