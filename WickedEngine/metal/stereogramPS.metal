#include "postProcessHF.h"

static constant float pWid = 100;
static constant float pHei = 100;

fragment float4 stereogramPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float maxStep = 32.;
	float d = 0.;

	float2 uv = PSIn.pos.xy;

	for (int count = 0; count < 100; count++) {
		if (uv.x < pWid)
			break;

		float d = 1.0 - saturate(gd.texture_lineardepth.SampleLevel(gd.sampler_linear_clamp, uv / gd.frame.g_xFrame_ScreenWidthHeight.xy, 0) * 100);

		uv.x -= pWid - (d * maxStep);
	}

	float x = fmod(uv.x, pWid) / pWid;
	float y = fmod(uv.y, pHei) / pHei;
	float3 rgb = xTexture.SampleLevel(gd.sampler_linear_wrap, float2(x, y), 0).yxz;

	float4 fragColor = float4(rgb, 1.0);


	return fragColor;
}
