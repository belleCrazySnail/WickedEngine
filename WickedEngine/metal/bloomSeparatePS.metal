#include "postProcessHF.h"

// This will cut out bright parts (>1) and also downsample 4x

fragment float4 bloomSeparatePS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float2 dim;
    GETDIMENSION(xTexture, dim);
	dim = 1.0 / dim;

	float3 color = 0;

	color += xTexture.SampleLevel(gd.sampler_linear_clamp, PSIn.tex + float2(-1, -1) * dim, 0).rgb;
	color += xTexture.SampleLevel(gd.sampler_linear_clamp, PSIn.tex + float2(1, -1) * dim, 0).rgb;
	color += xTexture.SampleLevel(gd.sampler_linear_clamp, PSIn.tex + float2(-1, 1) * dim, 0).rgb;
	color += xTexture.SampleLevel(gd.sampler_linear_clamp, PSIn.tex + float2(1, 1) * dim, 0).rgb;

	color /= 4.0f;

	color = max(0, color - gd.postproc.xPPParams0.x);

	return float4(color, 1);
}
