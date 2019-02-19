#include "objectHF.hlsli"



PixelInputType main(Input_Object_ALL input)
{
	PixelInputType Out;

	float4x4 WORLD = MakeWorldMatrixFromInstance(input.inst);
	float4x4 WORLDPREV = MakeWorldMatrixFromInstance(input.instPrev);
	VertexSurface surface = MakeVertexSurfaceFromInput(input);

	Out.instanceColor = input.inst.color_dither.rgb;
	Out.dither = input.inst.color_dither.a;

	surface.position = mul(surface.position, WORLD);
	surface.prevPos = mul(surface.prevPos, WORLDPREV);
	surface.normal = normalize(mul(surface.normal, (float3x3)WORLD));

	Out.clip = dot(surface.position, g_xClipPlane);

	Out.pos = Out.pos2D = mul(surface.position, g_xCamera_VP);
	Out.pos2DPrev = mul(surface.prevPos, g_xFrame_MainCamera_PrevVP);
	Out.pos3D = surface.position.xyz;
	Out.tex = surface.uv;
	Out.nor = surface.normal;
	Out.nor2D = mul(Out.nor.xyz, (float3x3)g_xCamera_View).xy;
	Out.atl = surface.atlas;

	Out.ReflectionMapSamplingPos = mul(surface.position, g_xFrame_MainCamera_ReflVP);

	return Out;
}