#include "globals.h"

fragment float4 objectPS_debug(float4 pos [[position]], constant GlobalCBuffer &cb)
{
	return cb.misc.g_xColor;
}
