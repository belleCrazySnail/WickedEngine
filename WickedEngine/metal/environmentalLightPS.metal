#include "deferredLightHF.h"

#define	xSSR gd.texture_9

fragment LightOutputType environmentalLightPS(VertexToPixel3 PSIn [[stage_in]], constant GlobalData &gd)
{
	DEFERREDLIGHT_MAKEPARAMS

	diffuse = 0;
	float envMapMIP = roughness * gd.frame.g_xFrame_EnvProbeMipCount;
	specular = max(0, EnvironmentReflection_Global(surface, envMapMIP, gd));

	VoxelGI(surface, diffuse, specular, ao, gd);
	float3 ambient = GetAmbient(N, gd) * ao;
	diffuse += ambient;

	float4 ssr = xSSR.SampleLevel(gd.sampler_linear_clamp, ReprojectedScreenCoord, 0);
	specular = mix(specular, ssr.rgb, ssr.a);

	specular *= surface.F;

	DEFERREDLIGHT_RETURN
}
