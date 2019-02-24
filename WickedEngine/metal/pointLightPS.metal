#include "deferredLightHF.h"

fragment LightOutputType pointLightPS(VertexToPixel3 PSIn [[stage_in]], constant GlobalData &gd)
{ 
	DEFERREDLIGHT_MAKEPARAMS

	DEFERREDLIGHT_POINT

	DEFERREDLIGHT_RETURN
}
