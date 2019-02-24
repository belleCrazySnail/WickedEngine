#include "deferredLightHF.h"
#include "fullScreenTriangleHF.h"

vertex VertexToPixel3 dirLightVS(uint vid [[vertex_id]])
{
	VertexToPixel3 Out;

	FullScreenTriangle(vid, Out.pos);
		
	Out.pos2D = Out.pos;

	return Out;
}
