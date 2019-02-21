#include "imageHF.h"

fragment float4 blurPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	const float2 direction = gd.postproc.xPPParams0.xy;
	const float mip = gd.postproc.xPPParams0.z;

	float4 color = 0;
	for (uint i = 0; i < 9; ++i)
	{
		color += xTexture.SampleLevel(gd.customsampler0, PSIn.tex + direction * gaussianOffsets[i], mip) * gaussianWeightsNormalized[i];
	}
	return color;
}
