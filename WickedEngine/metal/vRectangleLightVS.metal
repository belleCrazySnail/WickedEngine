
#define VOLUMELIGHT_CB
#include "globals.h"
#include "quad.h"

vertex VertexToPixel2 vRectangleLightVS(uint vID [[vertex_id]], constant GlobalData &gd)
{
	VertexToPixel2 Out;

	float4 pos = QUAD[vID];
	Out.pos = mul(pos, gd.vol.lightWorld);
	Out.col = float4(gd.vol.lightColor.rgb * gd.vol.lightEnerdis.x, 1);

	return Out;
}
