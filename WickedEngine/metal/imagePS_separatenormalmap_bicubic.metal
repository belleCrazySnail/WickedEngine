#include "imageHF.h"

fragment float4 imagePS_separatenormalmap_bicubic(VertextoPixel PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = SampleTextureCatmullRom(xTexture, PSIn.tex.xy, gd.image.xMipLevel, gd);

	color = 2 * color - 1;

	color *= gd.image.xColor;

	return color;
}
