
#define TRANCEDRENDERING_CB
#include "globals.h"
#include "objectInputLayoutHF.h"
#include "ShaderInterop_TracedRendering.h"

struct Input
{
	device const float4 *pos [[buffer(0)]];
	device const float2 *atl [[buffer(1)]];
	device const Input_InstancePrev *instance [[buffer(2)]];
};

vertex VertexToPixel4 renderlightmapVS(Input input, constant GlobalData &gd, uint vid [[vertex_id]], uint iid [[instance_id]])
{
	VertexToPixel4 output;

	float4x4 WORLD = MakeWorldMatrixFromPrevInstance(input.instance[iid]);

	output.pos = float4(input.atl[vid], 0, 1);
	output.pos.xy = output.pos.xy * 2 - 1;
	output.pos.y *= -1;
	output.pos.xy += gd.traced.xTracePixelOffset;

	output.uv = input.atl[vid];

	output.pos3D = mul(float4(input.pos[vid].xyz, 1), WORLD).xyz;

	uint normal_wind_matID = as_type<uint>(input.pos[vid].w);
	output.normal.x = (float)((normal_wind_matID >> 0) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
	output.normal.y = (float)((normal_wind_matID >> 8) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
	output.normal.z = (float)((normal_wind_matID >> 16) & 0x000000FF) / 255.0f * 2.0f - 1.0f;

	return output;
}
