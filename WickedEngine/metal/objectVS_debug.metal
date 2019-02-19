#include "globals.h"
#include "objectInputLayoutHF.h"

vertex float4 objectVS_debug(device const float4 *inPos [[buffer(POSITION_NORMAL_SUBSETINDEX)]], constant GlobalCBuffer &cb, uint vid [[vertex_id]])
{
	float4 pos = float4(inPos[vid].xyz, 1) * cb.misc.g_xTransform;

	return pos;
}
