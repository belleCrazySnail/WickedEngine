//#include "objectHF.hlsli"
#include "objectInputLayoutHF.h"
#include "ShaderInterop_Renderer.h"

struct PixelInputType
{
    simd::float4 pos [[position]];
    float  clip;
    simd::float2 tex;
    float  dither [[flat]];
    simd::float3 instanceColor [[flat]];
    simd::float3 nor;
    simd::float4 pos2D;
    simd::float3 pos3D;
    simd::float4 pos2DPrev;
    simd::float4 ReflectionMapSamplingPos;
    simd::float2 nor2D;
    simd::float2 atl;
};


vertex PixelInputType objectVS_common(Input_Object_ALL input, GlobalData cb, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	PixelInputType Out;

	simd::float4x4 WORLD = MakeWorldMatrixFromInstance(input.data[iid].instance);
	simd::float4x4 WORLDPREV = MakeWorldMatrixFromInstance(input.data[iid].instancePrev);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid, iid);

	Out.instanceColor = input.data[iid].instance.color_dither.rgb;
	Out.dither = input.data[iid].instance.color_dither.a;

	surface.position = surface.position * WORLD;
	surface.prevPos = surface.prevPos * WORLDPREV;
	surface.normal = normalize(surface.normal * getUpper3x3(WORLD));

	Out.clip = dot(surface.position, cb.api.g_xClipPlane);

	Out.pos = Out.pos2D = surface.position * cb.camera.g_xCamera_VP;
	Out.pos2DPrev = surface.prevPos * cb.frame.g_xFrame_MainCamera_PrevVP;
	Out.pos3D = surface.position.xyz;
	Out.tex = surface.uv;
	Out.nor = surface.normal;
	Out.nor2D = (Out.nor.xyz * getUpper3x3(cb.camera.g_xCamera_View)).xy;
	Out.atl = surface.atlas;

	Out.ReflectionMapSamplingPos = surface.position * cb.frame.g_xFrame_MainCamera_ReflVP;

	return Out;
}
