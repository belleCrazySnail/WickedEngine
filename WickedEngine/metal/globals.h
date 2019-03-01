#ifndef _SHADER_GLOBALS_
#define _SHADER_GLOBALS_
#include "ShaderInterop.h"
#include "ShaderInterop_Renderer.h"
#include "ShaderInterop_Image.h"
#include "ShaderInterop_Font.h"

#ifdef TRANCEDRENDERING_CB
#include "ShaderInterop_TracedRendering.h"
#endif
#ifdef RAY_INTERSECT_DATA
#include "ShaderInterop_BVH.h"
#endif

struct GlobalData
{
DEPTH2D(texture_depth, float, TEXSLOT_DEPTH)
DEPTH2D(texture_lineardepth, float, TEXSLOT_LINEARDEPTH)
TEXTURE2D(texture_gbuffer0, float, TEXSLOT_GBUFFER0)
TEXTURE2D(texture_gbuffer1, float, TEXSLOT_GBUFFER1)
TEXTURE2D(texture_gbuffer2, float, TEXSLOT_GBUFFER2)
TEXTURECUBE(texture_globalenvmap, float, TEXSLOT_GLOBALENVMAP)
TEXTURE2D(texture_globallightmap, float, TEXSLOT_GLOBALLIGHTMAP)
TEXTURECUBEARRAY(texture_envmaparray, float, TEXSLOT_ENVMAPARRAY)
TEXTURE2D(texture_decalatlas, float, TEXSLOT_DECALATLAS)
DEPTH2DARRAY(texture_shadowarray_2d, float, TEXSLOT_SHADOWARRAY_2D)
DEPTHCUBEARRAY(texture_shadowarray_cube, float, TEXSLOT_SHADOWARRAY_CUBE)
DEPTH2DARRAY(texture_shadowarray_transparent, float, TEXSLOT_SHADOWARRAY_TRANSPARENT)
TEXTURE3D(texture_voxelradiance, float, TEXSLOT_VOXELRADIANCE)

#ifdef TEXSLOT0
TEXTURE2D(texture_0, float, TEXSLOT_ONDEMAND0)
#endif
#ifdef TEXSLOT1
TEXTURE2D(texture_1, float, TEXSLOT_ONDEMAND1)
#endif
#ifdef TEXSLOT2
TEXTURE2D(texture_2, float, TEXSLOT_ONDEMAND2)
#endif
#ifdef TEXSLOT3
TEXTURE2D(texture_3, float, TEXSLOT_ONDEMAND3)
#endif
#ifdef TEXSLOT4
TEXTURE2D(texture_4, float, TEXSLOT_ONDEMAND4)
#endif
#ifdef TEXSLOT5
TEXTURE2D(texture_5, float, TEXSLOT_ONDEMAND5)
#endif
#ifdef TEXSLOT6
TEXTURE2D(texture_6, float, TEXSLOT_ONDEMAND6)
#endif
#ifdef TEXSLOT7
TEXTURE2D(texture_7, float, TEXSLOT_ONDEMAND7)
#endif
#ifdef TEXSLOT8
TEXTURE2D(texture_8, float, TEXSLOT_ONDEMAND8)
#endif
#ifdef TEXSLOT9
TEXTURE2D(texture_9, float, TEXSLOT_ONDEMAND9)
#endif

#ifdef RAY_INTERSECT_DATA
    STRUCTUREDBUFFER(materialBuffer, TracedRenderingMaterial, TEXSLOT_ONDEMAND0);
    STRUCTUREDBUFFER(triangleBuffer, BVHMeshTriangle, TEXSLOT_ONDEMAND1);
    RAWBUFFER(clusterCounterBuffer, TEXSLOT_ONDEMAND2);
    STRUCTUREDBUFFER(clusterIndexBuffer, uint, TEXSLOT_ONDEMAND3);
    STRUCTUREDBUFFER(clusterOffsetBuffer, uint2, TEXSLOT_ONDEMAND4);
    STRUCTUREDBUFFER(clusterConeBuffer, ClusterCone, TEXSLOT_ONDEMAND5);
    STRUCTUREDBUFFER(bvhNodeBuffer, BVHNode, TEXSLOT_ONDEMAND6);
    STRUCTUREDBUFFER(bvhAABBBuffer, BVHAABB, TEXSLOT_ONDEMAND7);
    
    TEXTURE2D(materialTextureAtlas, float, TEXSLOT_ONDEMAND8);
#endif

STRUCTUREDBUFFER(EntityTiles, uint, SBSLOT_ENTITYTILES);
STRUCTUREDBUFFER(EntityArray, ShaderEntityType, SBSLOT_ENTITYARRAY);
STRUCTUREDBUFFER(MatrixArray, float4x4, SBSLOT_MATRIXARRAY);

    constant FrameCB &frame [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_RENDERER_FRAME)]];
    constant CameraCB &camera [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_RENDERER_CAMERA)]];
    constant MiscCB &misc [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_RENDERER_MISC)]];
    constant ImageCB &image [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_IMAGE_IMAGE)]];
    constant PostProcessCB &postproc [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_IMAGE_POSTPROCESS)]];
    constant FontCB &font [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_FONT)]];
    constant APICB &api [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_API)]];
    constant MaterialCB &material [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_RENDERER_MATERIAL)]];

#ifdef VOLUMELIGHT_CB
    constant VolumeLightCB &vol [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_RENDERER_VOLUMELIGHT)]];
#endif
#ifdef TRANCEDRENDERING_CB
    constant TracedRenderingCB &traced [[buffer(METAL_DESCRIPTOR_SET_OFFSET_CBV + CBSLOT_RENDERER_TRACED)]];
#endif
    
SAMPLERSTATE(			sampler_linear_clamp,	SSLOT_LINEAR_CLAMP	)
SAMPLERSTATE(			sampler_linear_wrap,	SSLOT_LINEAR_WRAP	)
SAMPLERSTATE(			sampler_linear_mirror,	SSLOT_LINEAR_MIRROR	)
SAMPLERSTATE(			sampler_point_clamp,	SSLOT_POINT_CLAMP	)
SAMPLERSTATE(			sampler_point_wrap,		SSLOT_POINT_WRAP	)
SAMPLERSTATE(			sampler_point_mirror,	SSLOT_POINT_MIRROR	)
SAMPLERSTATE(			sampler_aniso_clamp,	SSLOT_ANISO_CLAMP	)
SAMPLERSTATE(			sampler_aniso_wrap,		SSLOT_ANISO_WRAP	)
SAMPLERSTATE(			sampler_aniso_mirror,	SSLOT_ANISO_MIRROR	)
SAMPLERCOMPARISONSTATE(	sampler_cmp_depth,		SSLOT_CMP_DEPTH		)
SAMPLERSTATE(			sampler_objectshader,	SSLOT_OBJECTSHADER	)
SAMPLERSTATE(customsampler0, SSLOT_ONDEMAND0)
SAMPLERSTATE(customsampler1, SSLOT_ONDEMAND1)
};

static constant float		PI = 3.14159265358979323846;
static constant float	 SQRT2 = 1.41421356237309504880;

static constant float gaussWeight0 = 1.0f;
static constant float gaussWeight1 = 0.9f;
static constant float gaussWeight2 = 0.55f;
static constant float gaussWeight3 = 0.18f;
static constant float gaussWeight4 = 0.1f;
static constant float gaussNormalization = 1.0f / (gaussWeight0 + 2.0f * (gaussWeight1 + gaussWeight2 + gaussWeight3 + gaussWeight4));
static constant float gaussianWeightsNormalized[9] = {
	gaussWeight4 * gaussNormalization,
	gaussWeight3 * gaussNormalization,
	gaussWeight2 * gaussNormalization,
	gaussWeight1 * gaussNormalization,
	gaussWeight0 * gaussNormalization,
	gaussWeight1 * gaussNormalization,
	gaussWeight2 * gaussNormalization,
	gaussWeight3 * gaussNormalization,
	gaussWeight4 * gaussNormalization,
};
static constant int gaussianOffsets[9] = {
	-4, -3, -2, -1, 0, 1, 2, 3, 4
};

#define sqr(a)		((a)*(a))
inline bool is_saturated(float a) { return a == saturate(a); }
inline bool is_saturated(float2 a) { return any(bool2(a - saturate(a))); }
inline bool is_saturated(float3 a) { return any(bool3(a - saturate(a))); }
inline bool is_saturated(float4 a) { return any(bool4(a - saturate(a))); }

#ifdef DISABLE_ALPHATEST
#define ALPHATEST(x)
#else
#define ALPHATEST(x)	if((x) < (1.0f - gd.api.g_xAlphaRef)) discard_fragment();
#endif

#define DEGAMMA_SKY(x)	pow(abs(x),gd.frame.g_xFrame_StaticSkyGamma)
#define DEGAMMA(x)		pow(abs(x),gd.frame.g_xFrame_Gamma)
#define GAMMA(x)		pow(abs(x),1.0/gd.frame.g_xFrame_Gamma)

struct VertexToPixel
{
    float4 pos [[position]];
    float2 tex_original;
    float2 tex;
    float4 pos2D;
};
struct VertexToPixel1
{
    float4 pos [[position]];
    float2 tex;
};
struct VertexToPixel2
{
    float4 pos [[position]];
    float4 col;
};
struct VertexToPixel3
{
    float4 pos [[position]];
    float4 pos2D;
};
struct VertexToPixel4
{
    float4 pos [[position]];
    float2 uv;
    float3 pos3D;
    float3 normal;
};

inline float3 GetSunColor(constant GlobalData &gd) { return gd.frame.g_xFrame_SunColor; }
inline float3 GetSunDirection(constant GlobalData &gd) { return gd.frame.g_xFrame_SunDirection; }
inline float3 GetHorizonColor(constant GlobalData &gd) { return gd.frame.g_xFrame_Horizon.rgb; }
inline float3 GetZenithColor(constant GlobalData &gd) { return gd.frame.g_xFrame_Zenith.rgb; }
inline float3 GetAmbientColor(constant GlobalData &gd) { return gd.frame.g_xFrame_Ambient.rgb; }
inline float3 GetAmbient(float3 N, constant GlobalData &gd) { return mix(GetHorizonColor(gd), GetZenithColor(gd), saturate(N.y * 0.5f + 0.5f)) + GetAmbientColor(gd); }
inline float2 GetScreenResolution(constant GlobalData &gd) { return gd.frame.g_xFrame_ScreenWidthHeight; }
inline float GetScreenWidth(constant GlobalData &gd) { return gd.frame.g_xFrame_ScreenWidthHeight.x; }
inline float GetScreenHeight(constant GlobalData &gd) { return gd.frame.g_xFrame_ScreenWidthHeight.y; }
inline float2 GetInternalResolution(constant GlobalData &gd) { return gd.frame.g_xFrame_InternalResolution; }
inline float GetTime(constant GlobalData &gd) { return gd.frame.g_xFrame_Time; }
inline float2 GetTemporalAASampleRotation(constant GlobalData &gd) { return float2((gd.frame.g_xFrame_TemporalAASampleRotation >> 0) & 0x000000FF, (gd.frame.g_xFrame_TemporalAASampleRotation >> 8) & 0x000000FF); }
inline bool IsStaticSky(constant GlobalData &gd) { return gd.frame.g_xFrame_StaticSkyGamma > 0.0f; }

struct ComputeShaderInput
{
	uint3 groupID [[threadgroup_position_in_grid]];           // 3D index of the thread group in the dispatch.
    uint3 groupThreadID [[thread_position_in_threadgroup]];     // 3D index of local thread ID in a thread group.
	uint3 dispatchThreadID [[thread_position_in_grid]];  // 3D index of global thread ID in the dispatch.
	uint  groupIndex [[thread_index_in_threadgroup]];        // Flattened local index of the thread within a thread group.
};


// Helpers:

// returns a random float in range (0, 1). seed must be >0!
inline float rand(thread float &seed, float2 uv)
{
	float result = fract(sin(seed * dot(uv, float2(12.9898f, 78.233f))) * 43758.5453f);
	seed += 1.0f;
	return result;
}

// 2D array index to flattened 1D array index
inline uint flatten2D(uint2 coord, uint2 dim)
{
	return coord.x + coord.y * dim.x;
}
// flattened array index to 2D array index
inline uint2 unflatten2D(uint idx, uint2 dim)
{
	return uint2(idx % dim.x, idx / dim.x);
}

// 3D array index to flattened 1D array index
inline uint flatten3D(uint3 coord, uint3 dim)
{
	return (coord.z * dim.x * dim.y) + (coord.y * dim.x) + coord.x;
}
// flattened array index to 3D array index
inline uint3 unflatten3D(uint idx, uint3 dim)
{
	const uint z = idx / (dim.x * dim.y);
	idx -= (z * dim.x * dim.y);
	const uint y = idx / dim.x;
	const uint x = idx % dim.x;
	return  uint3(x, y, z);
}

// Creates a unit cube triangle strip from just vertex ID (14 vertices)
inline float3 CreateCube(uint vertexID)
{
	uint b = 1 << vertexID;
	return float3((0x287a & b) != 0, (0x02af & b) != 0, (0x31e3 & b) != 0);
}


// Convert texture coordinates on a cubemap face to cubemap sampling coordinates:
// uv			: UV texture coordinates on cubemap face in range [0, 1]
// faceIndex	: cubemap face index as in the backing texture2DArray in range [0, 5]
inline float3 UV_to_CubeMap(float2 uv, uint faceIndex)
{
	// get uv in [-1, 1] range:
	uv = uv * 2 - 1;

	// and UV.y should point upwards:
	uv.y *= -1;

	switch (faceIndex)
	{
	case 0:
		// +X
		return float3(1, uv.y, -uv.x);
	case 1:
		// -X
		return float3(-1, uv.yx);
	case 2:
		// +Y
		return float3(uv.x, 1, -uv.y);
	case 3:
		// -Y
		return float3(uv.x, -1, uv.y);
	case 4:
		// +Z
		return float3(uv, 1);
	case 5:
		// -Z
		return float3(-uv.x, uv.y, -1);
	default:
		// error
		return 0;
	}
}

inline float getLinearDepth(float c, constant GlobalData &gd)
{
    float z_b = c;
    float z_n = 2.0 * z_b - 1.0;
    //float lin = 2.0 * g_xFrame_MainCamera_ZNearP * g_xFrame_MainCamera_ZFarP / (g_xFrame_MainCamera_ZFarP + g_xFrame_MainCamera_ZNearP - z_n * (g_xFrame_MainCamera_ZFarP - g_xFrame_MainCamera_ZNearP));
    float lin = 2.0 * gd.frame.g_xFrame_MainCamera_ZFarP * gd.frame.g_xFrame_MainCamera_ZNearP / (gd.frame.g_xFrame_MainCamera_ZNearP + gd.frame.g_xFrame_MainCamera_ZFarP - z_n * (gd.frame.g_xFrame_MainCamera_ZNearP - gd.frame.g_xFrame_MainCamera_ZFarP));
    return lin;
}

inline float GetFog(float dist, constant GlobalData &gd)
{
    return saturate((dist - gd.frame.g_xFrame_Fog.x) / (gd.frame.g_xFrame_Fog.y - gd.frame.g_xFrame_Fog.x));
}

// Reinhard operator
inline float3 tonemap(float3 x)
{
    return x / (x + 1);
}
inline float3 inverseTonemap(float3 x)
{
    return x / (1 - x);
}

inline float2 encodeNormal (float3 n)
{
    return n.xy*0.5+0.5;
}
inline float3 decodeNormal (float2 enc)
{
    float3 n;
    n.xy = enc*2-1;
    n.z = sqrt(1-dot(n.xy, n.xy));
    return n;
}

// Samples a texture with Catmull-Rom filtering, using 9 texture fetches instead of 16. ( https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1#file-tex2dcatmullrom-hlsl )
// See http://vec3.ca/bicubic-filtering-in-fewer-taps/ for more details
inline float4 SampleTextureCatmullRom(texture2d<float> tex, float2 uv, float mipLevel, constant GlobalData &gd)
{
	float2 texSize;
    GETDIMENSION(tex, texSize);

	// We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
	// down the sample location to get the exact center of our "starting" texel. The starting texel will be at
	// location [1, 1] in the grid, where [0, 0] is the top left corner.
	float2 samplePos = uv * texSize;
	float2 texPos1 = floor(samplePos - 0.5f) + 0.5f;

	// Compute the fractional offset from our starting texel to our original sample location, which we'll
	// feed into the Catmull-Rom spline function to get our filter weights.
	float2 f = samplePos - texPos1;

	// Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
	// These equations are pre-expanded based on our knowledge of where the texels will be located,
	// which lets us avoid having to evaluate a piece-wise function.
	float2 w0 = f * (-0.5f + f * (1.0f - 0.5f * f));
	float2 w1 = 1.0f + f * f * (-2.5f + 1.5f * f);
	float2 w2 = f * (0.5f + f * (2.0f - 1.5f * f));
	float2 w3 = f * f * (-0.5f + 0.5f * f);

	// Work out weighting factors and sampling offsets that will let us use bilinear filtering to
	// simultaneously evaluate the middle 2 samples from the 4x4 grid.
	float2 w12 = w1 + w2;
	float2 offset12 = w2 / (w1 + w2);

	// Compute the final UV coordinates we'll use for sampling the texture
	float2 texPos0 = texPos1 - 1;
	float2 texPos3 = texPos1 + 2;
	float2 texPos12 = texPos1 + offset12;

	texPos0 /= texSize;
	texPos3 /= texSize;
	texPos12 /= texSize;

	float4 result = 0.0f;
	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos0.x, texPos0.y), mipLevel) * w0.x * w0.y;
	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos12.x, texPos0.y), mipLevel) * w12.x * w0.y;
	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos3.x, texPos0.y), mipLevel) * w3.x * w0.y;

	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos0.x, texPos12.y), mipLevel) * w0.x * w12.y;
	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos12.x, texPos12.y), mipLevel) * w12.x * w12.y;
	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos3.x, texPos12.y), mipLevel) * w3.x * w12.y;

	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos0.x, texPos3.y), mipLevel) * w0.x * w3.y;
	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos12.x, texPos3.y), mipLevel) * w12.x * w3.y;
	result += tex.SampleLevel(gd.sampler_linear_clamp, float2(texPos3.x, texPos3.y), mipLevel) * w3.x * w3.y;

	return result;
}

#endif // _SHADER_GLOBALS_
