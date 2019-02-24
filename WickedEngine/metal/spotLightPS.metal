#include "deferredLightHF.h"

fragment LightOutputType spotLightPS(VertexToPixel3 PSIn [[stage_in]], constant GlobalData &gd)
{
	DEFERREDLIGHT_MAKEPARAMS

	DEFERREDLIGHT_SPOT

	DEFERREDLIGHT_RETURN
}
