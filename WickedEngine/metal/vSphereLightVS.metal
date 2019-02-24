
#define VOLUMELIGHT_CB
#include "globals.h"
#include "uvsphere.h"

vertex VertexToPixel2 vSphereLightVS(uint vID [[vertex_id]], constant GlobalData &gd)
{
	VertexToPixel2 Out;

	float4 pos = UVSPHERE[vID];
	Out.pos = mul(pos, gd.vol.lightWorld);
	Out.col = float4(gd.vol.lightColor.rgb * gd.vol.lightEnerdis.x, 1);

	return Out;
}
