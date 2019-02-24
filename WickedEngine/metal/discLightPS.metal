#include "deferredLightHF.h"

fragment LightOutputType discLightPS(VertexToPixel3 PSIn [[stage_in]], constant GlobalData &gd)
{
	DEFERREDLIGHT_MAKEPARAMS

	DEFERREDLIGHT_DISC

	DEFERREDLIGHT_RETURN
}
