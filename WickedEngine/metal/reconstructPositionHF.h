#ifndef RECONSTRUCTPOSITION_HF
#define RECONSTRUCTPOSITION_HF
#include "globals.h"

inline float3 getPositionEx(float2 texCoord, float z, float4x4 InvVP)
{
	float x = texCoord.x * 2.0f - 1.0f;
	float y = (1.0 - texCoord.y) * 2.0f - 1.0f;
	float4 position_s = float4(x, y, z, 1.0f);
	float4 position_v = position_s * InvVP;
	return position_v.xyz / position_v.w;
}
inline float3 getPosition(float2 texCoord, float z, constant GlobalData &gd)
{
	return getPositionEx(texCoord, z, gd.frame.g_xFrame_MainCamera_InvVP);
}

inline float4 getPositionScreenEx(float2 texCoord, float z, constant GlobalData &gd)
{
	float x = texCoord.x * 2.0f - 1.0f;
	float y = (1.0 - texCoord.y) * 2.0f - 1.0f;
	float4 position_s = float4(x, y, z, 1.0f);
	return position_s * gd.frame.g_xFrame_MainCamera_InvVP;
}

#endif
