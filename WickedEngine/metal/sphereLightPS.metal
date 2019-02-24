#include "deferredLightHF.h"

fragment LightOutputType sphereLightPS(VertexToPixel3 PSIn [[stage_in]], constant GlobalData &gd)
{
	DEFERREDLIGHT_MAKEPARAMS

	DEFERREDLIGHT_SPHERE

	DEFERREDLIGHT_RETURN
}
