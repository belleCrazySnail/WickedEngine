#include "imageHF.h"

fragment float4 screenPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	return xTexture.SampleLevel(gd.sampler_linear_clamp, PSIn.tex, 0);
}
