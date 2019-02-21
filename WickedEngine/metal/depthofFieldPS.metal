#include "postProcessHF.h"
//#include "ViewProp.h"


fragment float4 depthofFieldPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = float4(0,0,0,0);

	color += xTexture.SampleLevel(gd.customsampler0, PSIn.tex,0);

	float targetDepth = gd.postproc.xPPParams0[2];

	float fragmentDepth = gd.texture_lineardepth.SampleLevel(gd.customsampler0, PSIn.tex, 0) * gd.frame.g_xFrame_MainCamera_ZFarP;
	float difference = abs(targetDepth - fragmentDepth);

	color = mix(color,xMaskTex.SampleLevel(gd.customsampler0,PSIn.tex,0),abs(clamp(difference*0.008f,-1,1)));

	return color;
}
