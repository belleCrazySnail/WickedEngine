#include "objectHF.h"


struct HullInputType
{
	float4 pos [[position]];
	float3 posPrev;
	float4 tex;
	float4 nor;
	float3 instanceColor [[flat]];
	float dither [[flat]];
};


vertex HullInputType objectVS_common_tessellation(Input_Object_ALL input, constant GlobalData &gd, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	HullInputType Out;

	
	float4x4 WORLD = MakeWorldMatrixFromInstance(input.instance[iid]);
	float4x4 WORLDPREV = MakeWorldMatrixFromPrevInstance(input.instance[iid]);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid, iid);
		

	surface.position = mul(surface.position, WORLD);
	surface.prevPos = mul(surface.prevPos, WORLDPREV);
	surface.normal = normalize(mul(surface.normal, getUpper3x3(WORLD)));


	Out.pos = surface.position;
	Out.posPrev = surface.prevPos.xyz;
	Out.tex = float4(surface.uv, surface.atlas);
	Out.nor = float4(surface.normal, 1);

	Out.instanceColor = input.instance[iid].color_dither.rgb;
	Out.dither = input.instance[iid].color_dither.a;

	return Out;
}
