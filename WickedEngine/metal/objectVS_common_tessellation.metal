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

	
	float4x4 WORLD = MakeWorldMatrixFromInstance(input.data[iid].instance);
	float4x4 WORLDPREV = MakeWorldMatrixFromInstance(input.data[iid].instancePrev);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid, iid);
		

	surface.position = surface.position * WORLD;
	surface.prevPos = surface.prevPos * WORLDPREV;
	surface.normal = normalize(surface.normal * getUpper3x3(WORLD));


	Out.pos = surface.position;
	Out.posPrev = surface.prevPos.xyz;
	Out.tex = float4(surface.uv, surface.atlas);
	Out.nor = float4(surface.normal, 1);

	Out.instanceColor = input.data[iid].instance.color_dither.rgb;
	Out.dither = input.data[iid].instance.color_dither.a;

	return Out;
}
