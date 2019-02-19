#include "objectHF.h"

struct VSOut
{
	float4 pos [[position]];
	float3 nor;
	float2 tex;
	float3 instanceColor [[flat]];
};

vertex VSOut objectVS_voxelizer(Input_Object_POS_TEX input, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	VSOut Out;

	float4x4 WORLD = MakeWorldMatrixFromInstance(input.instance[iid]);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid);

	Out.pos = surface.position * WORLD;
	Out.nor = normalize(surface.normal * getUpper3x3(WORLD));
	Out.tex = surface.uv;
	Out.instanceColor = input.instance[iid].color_dither.rgb;

	return Out;
}
