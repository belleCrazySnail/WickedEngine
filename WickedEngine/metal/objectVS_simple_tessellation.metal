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


vertex HullInputType objectVS_simple_tessellation(Input_Object_ALL input, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	HullInputType Out;

	float4x4 WORLD = MakeWorldMatrixFromInstance(input.instance[iid]);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid, iid);

	surface.position = mul(surface.position, WORLD);
	surface.normal = normalize(mul(surface.normal, getUpper3x3(WORLD)));

	Out.pos = surface.position;
	Out.tex = surface.uv.xyxy;

	Out.nor = float4(surface.normal, 1);

	// todo: leave these but I'm lazy to create appropriate hull/domain shaders now...
	Out.posPrev = 0;
	Out.instanceColor = 0;
	Out.dither = 0;

	return Out;
}
