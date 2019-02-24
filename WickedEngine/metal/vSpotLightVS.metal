
#define VOLUMELIGHT_CB
#include "globals.h"
#include "cone.h"

vertex VertexToPixel2 vSpotLightVS(uint vID [[vertex_id]], constant GlobalData &gd)
{
	VertexToPixel2 Out;
		
	float4 pos = CONE[vID];
	pos = mul( pos,gd.vol.lightWorld );
	Out.pos = mul(pos,gd.camera.g_xCamera_VP);
	Out.col=mix(
		float4(gd.vol.lightColor.rgb,1),float4(0,0,0,0),
		distance(pos.xyz,float3( gd.vol.lightWorld[0][3],gd.vol.lightWorld[1][3],gd.vol.lightWorld[2][3] ))/(gd.vol.lightEnerdis.w)
		);

	return Out;
}
