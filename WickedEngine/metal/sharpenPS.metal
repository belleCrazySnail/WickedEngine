#include "postProcessHF.h"

fragment float4 sharpenPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 center = xTexture.read(uint2(PSIn.pos.xy + float2(0, 0)),		0);
	float4 top =	xTexture.read(uint2(PSIn.pos.xy + float2(0, -1)),	0);
	float4 left =	xTexture.read(uint2(PSIn.pos.xy + float2(-1, 0)),	0);
	float4 right =	xTexture.read(uint2(PSIn.pos.xy + float2(1, 0)),		0);
	float4 bottom = xTexture.read(uint2(PSIn.pos.xy + float2(0, 1)),		0);

	return saturate(center + (4 * center - top - bottom - left - right) * gd.postproc.xPPParams0[0]);
}
