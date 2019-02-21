#include "imageHF.h"


static constant uint NUM_SAMPLES = 32;
static constant uint UNROLL_GRANULARITY = 8;

fragment float4 lightShaftPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float3 color = xTexture.sample(gd.customsampler0,PSIn.tex).rgb;

	float2 lightPos = float2(gd.postproc.xPPParams1[0] / GetInternalResolution(gd).x, gd.postproc.xPPParams1[1] / GetInternalResolution(gd).y);
	float2 deltaTexCoord =  PSIn.tex - lightPos;
	deltaTexCoord *= gd.postproc.xPPParams0[0] / NUM_SAMPLES;
	float illuminationDecay = 1.0f;
	
//    [loop] // loop big part (balance register pressure)
	for (uint i = 0; i < NUM_SAMPLES / UNROLL_GRANULARITY; i++)
	{
//        [unroll] // unroll small parts (balance register pressure)
		for (uint j = 0; j < UNROLL_GRANULARITY; ++j)
		{
			PSIn.tex.xy -= deltaTexCoord;
			float3 sam = xTexture.SampleLevel(gd.sampler_linear_clamp, PSIn.tex.xy, 0).rgb;
			sam *= illuminationDecay * gd.postproc.xPPParams0[1];
			color.rgb += sam;
			illuminationDecay *= gd.postproc.xPPParams0[2];
		}
	}

	color*= gd.postproc.xPPParams0[3];

	return float4(color, 1);
}
