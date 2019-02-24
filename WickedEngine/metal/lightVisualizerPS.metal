#include "globals.h"

fragment float4 lightVisualizerPS(VertexToPixel2 PSIn [[stage_in]])
{
	return max(PSIn.col,0);
}
