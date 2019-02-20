#include "imageHF.h"
#include "fullScreenTriangleHF.h"

vertex VertexToPixelPostProcess screenVS(uint vI [[vertex_id]])
{
	VertexToPixelPostProcess Out;

	FullScreenTriangle(vI, Out.pos, Out.tex);

	return Out;
}
