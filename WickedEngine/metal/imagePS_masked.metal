#include "imageHF.h"

fragment float4 imagePS_masked(VertextoPixel PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = xTexture.SampleLevel(gd.customsampler0, PSIn.tex.xy, gd.image.xMipLevel) * gd.image.xColor;
	
	color *= xMaskTex.SampleLevel(gd.customsampler0, PSIn.tex_original.xy, gd.image.xMipLevel);

	return color;
}
