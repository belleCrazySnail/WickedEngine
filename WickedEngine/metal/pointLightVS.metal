#include "deferredLightHF.h"
#include "icosphere.h"

vertex VertexToPixel3 pointLightVS(uint vid [[vertex_id]], constant GlobalData &gd)
{
	VertexToPixel3 Out;
		
	float4 pos = ICOSPHERE[vid];
	Out.pos = Out.pos2D = mul(pos, gd.misc.g_xTransform);
	return Out;
}
