#include "imageHF.h"
#include "fullScreenTriangleHF.h"

VertexToPixelPostProcess main(uint vI [[vertex_id]])
{
	VertexToPixelPostProcess Out;

	FullScreenTriangle(vI, Out.pos, Out.tex);

	return Out;
}
