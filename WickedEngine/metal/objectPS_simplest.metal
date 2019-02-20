#include "objectHF.h"

fragment float4 objectPS_simplest(PixelInputType_Simple PSIn [[stage_in]], constant GlobalData &gd)
{
	return gd.material.g_xMat_baseColor * float4(PSIn.instanceColor,1);
}

