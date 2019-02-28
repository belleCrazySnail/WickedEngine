#include "objectHF.h"


vertex PixelInputType objectVS_common(Input_Object_ALL input, constant GlobalData &gd, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	PixelInputType Out;

	simd::float4x4 WORLD = MakeWorldMatrixFromInstance(input.instance[iid]);
	simd::float4x4 WORLDPREV = MakeWorldMatrixFromPrevInstance(input.instance[iid]);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid, iid);

	Out.instanceColor = input.instance[iid].color_dither.rgb;
	Out.dither = input.instance[iid].color_dither.a;

	surface.position = mul(surface.position, WORLD);
	surface.prevPos = mul(surface.prevPos, WORLDPREV);
	surface.normal = normalize(mul(surface.normal, getUpper3x3(WORLD)));

	Out.clip = dot(surface.position, gd.api.g_xClipPlane);

	Out.pos = Out.pos2D = mul(surface.position, gd.camera.g_xCamera_VP);
	Out.pos2DPrev = mul(surface.prevPos, gd.frame.g_xFrame_MainCamera_PrevVP);
	Out.pos3D = surface.position.xyz;
	Out.tex = surface.uv;
	Out.nor = surface.normal;
	Out.nor2D = (mul(Out.nor.xyz, getUpper3x3(gd.camera.g_xCamera_View))).xy;
	Out.atl = surface.atlas;

	Out.ReflectionMapSamplingPos = mul(surface.position, gd.frame.g_xFrame_MainCamera_ReflVP);

	return Out;
}
