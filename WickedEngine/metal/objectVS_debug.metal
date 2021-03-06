#include "globals.h"
#include "objectInputLayoutHF.h"

vertex float4 objectVS_debug(device const float4 *inPos [[buffer(0)]], constant GlobalData &gd, uint vid [[vertex_id]])
{
	float4 pos = mul(float4(inPos[vid].xyz, 1), gd.misc.g_xTransform);

	return pos;
}
