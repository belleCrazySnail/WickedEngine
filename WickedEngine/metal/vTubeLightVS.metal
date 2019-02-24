
#define VOLUMELIGHT_CB
#include "globals.h"
#include "cylinder.h"

vertex VertexToPixel2 vTubeLightVS(uint vID [[vertex_id]], constant GlobalData &gd)
{
	VertexToPixel2 Out;

	float4 pos = CYLINDER[vID];
	Out.pos = mul(pos, gd.vol.lightWorld);
	Out.col = float4(gd.vol.lightColor.rgb * gd.vol.lightEnerdis.x, 1);

	return Out;
}
