#include "globals.h"
#include "imageHF.h"

VertextoPixel imageVS(uint vI [[vertex_id]], constant GlobalData &gd)
{
	VertextoPixel Out;

	// This vertex shader generates a trianglestrip like this:
	//	1--2
	//	  /
	//	 /
	//	3--4
	float2 inTex = float2(vI % 2, vI % 4 / 2);

	Out.pos = gd.image.xCorners[vI];

	Out.tex_original = inTex;

	Out.tex = inTex * gd.image.xTexMulAdd.xy + gd.image.xTexMulAdd.zw;

	Out.pos2D = Out.pos;

	return Out;
}

