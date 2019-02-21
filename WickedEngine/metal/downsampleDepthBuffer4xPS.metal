#include "postProcessHF.h"

struct FragRet {
    float dep [[depth(any)]];
};

fragment FragRet downsampleDepthBuffer4xPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
    FragRet ret;
    float4 samples0 = xTexture.gather(gd.sampler_point_clamp, PSIn.tex, int2(-1,-1), component::x);
	float4 samples1 = xTexture.gather(gd.sampler_point_clamp, PSIn.tex, int2(-1,1), component::x);
	float4 samples2 = xTexture.gather(gd.sampler_point_clamp, PSIn.tex, int2(1,-1), component::x);
	float4 samples3 = xTexture.gather(gd.sampler_point_clamp, PSIn.tex, int2(1,1), component::x);
	
	float min0 = min(samples0.x, min(samples0.y, min(samples0.z, samples0.w)));
	float min1 = min(samples1.x, min(samples1.y, min(samples1.z, samples1.w)));
	float min2 = min(samples2.x, min(samples2.y, min(samples2.z, samples2.w)));
	float min3 = min(samples3.x, min(samples3.y, min(samples3.z, samples3.w)));

	ret.dep = min(min0, min(min1, min(min2, min3)));
    return ret;
}
