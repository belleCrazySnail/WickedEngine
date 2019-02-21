#include "postProcessHF.h"
#include "reconstructPositionHF.h"

struct FragRet {
    float dep [[depth(any)]];
};

fragment FragRet reprojectDepthBufferPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
    FragRet ret;
	float prevDepth = gd.texture_0.sample(gd.sampler_point_clamp, PSIn.tex).r;

	float3 P = getPositionEx(PSIn.tex, prevDepth, gd.frame.g_xFrame_MainCamera_PrevInvVP);

	float4 reprojectedP = float4(P,1) * gd.camera.g_xCamera_VP;

	ret.dep = reprojectedP.z / reprojectedP.w;
    return ret;
}
