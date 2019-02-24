#ifndef _LIGHTHF_
#define _LIGHTHF_
#include "globals.h"
#include "brdf.h"
#include "packHF.h"
#include "lightingHF.h"

#include "reconstructPositionHF.h"


struct LightOutputType
{
	float4 diffuse [[color(0)]];
	float4 specular [[color(1)]];
};

fragment LightOutputType MAINAPIENTRY( VertexToPixel3 PSIn [[stage_in]] , constant GlobalData &gd) {
	ShaderEntityType light = gd.EntityArray[(uint)gd.misc.g_xColor.x];
	float3 diffuse, specular;
	float2 ScreenCoord = PSIn.pos2D.xy / PSIn.pos2D.w * float2(0.5f, -0.5f) + 0.5f;
	float depth = gd.texture_depth.read(uint2(PSIn.pos.xy));
	float4 g0 = gd.texture_gbuffer0.read(uint2(PSIn.pos.xy));
	float4 baseColor = float4(g0.rgb, 1);
	float ao = g0.a;
	float4 g1 = gd.texture_gbuffer1.read(uint2(PSIn.pos.xy));
	float4 g2 = gd.texture_gbuffer2.read(uint2(PSIn.pos.xy));
	float3 N = decode(g1.xy);
	float2 velocity = g1.zw;
	float roughness = g2.x;
	float reflectance = g2.y;
	float metalness = g2.z;
	float2 ReprojectedScreenCoord = ScreenCoord + velocity;
	float3 P = getPosition(ScreenCoord, depth, gd);
	float3 V = normalize(gd.camera.g_xCamera_CamPos - P);
	Surface surface = CreateSurface(P, N, V, baseColor, roughness, reflectance, metalness);


#ifdef DEFERREDLIGHT_DIRECTIONAL
	LightingResult result = DirectionalLight(light, surface, gd);
	diffuse = result.diffuse;
	specular = result.specular;
#endif

#ifdef DEFERREDLIGHT_SPOT
	LightingResult result = SpotLight(light, surface, gd);
	diffuse = result.diffuse;
	specular = result.specular;
#endif

#ifdef DEFERREDLIGHT_POINT
	LightingResult result = PointLight(light, surface, gd);
	diffuse = result.diffuse;
	specular = result.specular;
#endif

#ifdef DEFERREDLIGHT_SPHERE
	LightingResult result = SphereLight(light, surface, gd);
	diffuse = result.diffuse;
	specular = result.specular;
#endif

#ifdef DEFERREDLIGHT_DISC
	LightingResult result = DiscLight(light, surface, gd);
	diffuse = result.diffuse;
	specular = result.specular;
#endif

#ifdef DEFERREDLIGHT_RECTANGLE
	LightingResult result = RectangleLight(light, surface, gd);
	diffuse = result.diffuse;
	specular = result.specular;
#endif

#ifdef DEFERREDLIGHT_TUBE
	LightingResult result = TubeLight(light, surface, gd);
	diffuse = result.diffuse;
	specular = result.specular;
#endif

#ifdef DEFERREDLIGHT_ENV
    diffuse = 0;
    float envMapMIP = roughness * gd.frame.g_xFrame_EnvProbeMipCount;
    specular = max(0, EnvironmentReflection_Global(surface, envMapMIP, gd));
    
    VoxelGI(surface, diffuse, specular, ao, gd);
    float3 ambient = GetAmbient(N, gd) * ao;
    diffuse += ambient;
    
    float4 ssr = xSSR.SampleLevel(gd.sampler_linear_clamp, ReprojectedScreenCoord, 0);
    specular = mix(specular, ssr.rgb, ssr.a);
    
    specular *= surface.F;
#endif

	LightOutputType Out;
	Out.diffuse = float4(diffuse, 1);
	Out.specular = float4(specular, 1);
	return Out;
}

#endif // _LIGHTHF_

