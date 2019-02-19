#include "objectHF.h"

vertex float4 objectVS_positionstream(Input_Object_POS input, constant GlobalCBuffer &cb, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	float4x4 WORLD = MakeWorldMatrixFromInstance(input.instance[iid]);
	VertexSurface surface = MakeVertexSurfaceFromInput(input, vid);

	surface.position = surface.position * WORLD;

	return surface.position * cb.camera.g_xCamera_VP;
}
