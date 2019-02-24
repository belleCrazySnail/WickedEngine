#include "imageHF.h"

fragment float4 imagePS_separatenormalmap(VertexToPixel PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = xTexture.SampleLevel(gd.customsampler0, PSIn.tex.xy, gd.image.xMipLevel);

	color = 2 * color - 1;

	color *= gd.image.xColor;

	return color;
}
