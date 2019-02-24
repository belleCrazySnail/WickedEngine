#include "globals.h"
#include "cone.h"


vertex VertexToPixel3 spotLightVS(uint vid [[vertex_id]], constant GlobalData &gd)
{
	VertexToPixel3 Out;
		
	float4 pos = CONE[vid];
	Out.pos = Out.pos2D = mul( pos, gd.misc.g_xTransform );
	return Out;
}
