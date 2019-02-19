#include "objectHF.h"

vertex PixelInputType_Simple objectVS_simple(Input_Object_POS_TEX input, constant GlobalCBuffer &cb, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	PixelInputType_Simple Out;

	float4x4 WORLD = MakeWorldMatrixFromInstance(input.instance[iid]);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid);

	Out.instanceColor = input.instance[iid].color_dither.rgb;
	Out.dither = input.instance[iid].color_dither.a;

	surface.position = surface.position * WORLD;

	Out.clip = dot(surface.position, cb.api.g_xClipPlane);

	Out.pos = surface.position * cb.camera.g_xCamera_VP;
	Out.tex = surface.uv;

	return Out;
}
