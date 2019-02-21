#include "postProcessHF.h"


fragment float4 linDepthPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	return getLinearDepth(xTexture.SampleLevel(gd.sampler_point_clamp,PSIn.tex,0).r, gd) * gd.frame.g_xFrame_MainCamera_ZFarP_Recip; // store in range 0-1 for reduced precision
}
