#include "imageHF.h"

fragment float4 screenPS_bicubic(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	return SampleTextureCatmullRom(xTexture, PSIn.tex, 0, gd);
}
