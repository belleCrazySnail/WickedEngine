#include "postProcessHF.h"
#include "reconstructPositionHF.h"
#include "brdf.h"
#include "packHF.h"
#include "objectHF.h"


fragment float4 deferredPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float4 color = gd.texture_gbuffer0.read(uint2(PSIn.pos.xy));

	float4 g2 = gd.texture_gbuffer2.read(uint2(PSIn.pos.xy));
	float roughness = g2.x;
	float reflectance = g2.y;
	float metalness = g2.z;
	float3 albedo = ComputeAlbedo(color, metalness, reflectance);

	float  depth = gd.texture_lineardepth.read((uint2)PSIn.pos.xy) * gd.frame.g_xFrame_MainCamera_ZFarP;

	float4 diffuse = gd.texture_0.read(uint2(PSIn.pos.xy)); // light diffuse
	float4 specular = gd.texture_1.read(uint2(PSIn.pos.xy)); // light specular
	color.rgb = diffuse.rgb * albedo + specular.rgb;

	ApplyFog(depth, color, gd);

	return color;
}
