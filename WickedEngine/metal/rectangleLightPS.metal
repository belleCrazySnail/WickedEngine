#include "deferredLightHF.h"

fragment LightOutputType rectangleLightPS(VertexToPixel3 PSIn [[stage_in]], constant GlobalData &gd)
{
	DEFERREDLIGHT_MAKEPARAMS

	DEFERREDLIGHT_RECTANGLE

	DEFERREDLIGHT_RETURN
}
