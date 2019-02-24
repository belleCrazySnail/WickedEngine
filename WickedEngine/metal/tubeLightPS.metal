#include "deferredLightHF.h"

fragment LightOutputType tubeLightPS(VertexToPixel3 PSIn [[stage_in]], constant GlobalData &gd)
{
	DEFERREDLIGHT_MAKEPARAMS

	DEFERREDLIGHT_TUBE

	DEFERREDLIGHT_RETURN
}
