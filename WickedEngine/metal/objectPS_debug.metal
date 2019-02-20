#include "globals.h"

fragment float4 objectPS_debug(float4 pos [[position]], constant GlobalData &gd)
{
	return gd.misc.g_xColor;
}
