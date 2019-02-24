#include "deferredLightHF.h"

fragment LightOutputType dirLightPS( VertexToPixel3 PSIn [[stage_in]] , constant GlobalData &gd)
{
	DEFERREDLIGHT_MAKEPARAMS

	DEFERREDLIGHT_DIRECTIONAL

	DEFERREDLIGHT_RETURN
}
