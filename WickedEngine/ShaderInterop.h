#ifndef _WICKEDENGINE_SHADERINTEROP_H_
#define _WICKEDENGINE_SHADERINTEROP_H_

#include "ShaderInterop_Vulkan.h"
#include "ShaderInterop_Metal.h"
#include "ConstantBufferMapping.h"
#include "SamplerMapping.h"
#include "ResourceMapping.h"

// Shader - side types:
#ifdef __METAL_VERSION__
//metal is based on c++ and has __cplusplus defined, so need to come before __cplusplus

#import <metal_stdlib>
using namespace metal;

#define getUpper3x3(m) (simd::float3x3((m)[0].xyz, (m)[1].xyz, (m)[2].xyz))
#define mul(a, b) ((b) * (a))

#define CBUFFER(name, slot) struct name

#define RAWBUFFER(name,slot) device const uchar *name [[buffer(slot)]]
#define RWRAWBUFFER(name,slot) device uchar *name [[buffer(slot)]]

#define TYPEDBUFFER(name, type, slot) device const type *name [[buffer(slot)]]
#define RWTYPEDBUFFER(name, type, slot) device type *name [[buffer(slot)]]

#define STRUCTUREDBUFFER(name, type, slot) device const type *name [[buffer(slot)]]
#define RWSTRUCTUREDBUFFER(name, type, slot) device type *name [[buffer(slot)]]
#define ROVSTRUCTUREDBUFFER(name, type, slot)


#define TEXTURE1D(name, type, slot) texture1d<type> name [[texture(slot)]];
#define TEXTURE1DARRAY(name, type, slot) texture1d_array<type> name [[texture(slot)]];
#define RWTEXTURE1D(name, type, slot) texture1d<type, access::read_write> name [[texture(slot)]];

#define TEXTURE2D(name, type, slot) texture2d<type> name [[texture(slot)]];
#define TEXTURE2DMS(name, type, slot) texture2d_ms<type> name [[texture(slot)]];
#define TEXTURE2DARRAY(name, type, slot) texture2d_array<type> name [[texture(slot)]];
#define RWTEXTURE2D(name, type, slot) texture2d<type, access::read_write> name [[texture(slot)]];
#define RWTEXTURE2DARRAY(name, type, slot) texture2d_array<type, access::read_write> name [[texture(slot)]];
#define ROVTEXTURE2D(name, type, slot) texture2d<type> name [[texture(slot), raster_order_group()]];

#define TEXTURECUBE(name, type, slot) texturecube<type> name [[texture(slot)]];
#define TEXTURECUBEARRAY(name, type, slot) texturecube_array<type> name [[texture(slot)]];

#define TEXTURE3D(name, type, slot) texture3d<type> name [[texture(slot)]];
#define RWTEXTURE3D(name, type, slot) texture3d<type, access::read_write> name [[texture(slot)]];
#define ROVTEXTURE3D(name, type, slot) texture3d<type> name [[texture(slot), raster_order_group()]];

#define DEPTH2D(name, type, slot) depth2d<type> name [[texture(slot)]];
#define DEPTH2DARRAY(name, type, slot) depth2d_array<type> name [[texture(slot)]];
#define DEPTHCUBE(name, type, slot) depthcube<type> name [[texture(slot)]];
#define DEPTHCUBEARRAY(name, type, slot) depthcube_array<type> name [[texture(slot)]];

#define SAMPLERSTATE(name, slot) sampler name [[sampler(slot)]];
#define SAMPLERCOMPARISONSTATE(name, slot) sampler name [[sampler(slot)]];

#define SampleLevel sample
#define SampleCmpLevelZero sample_compare
#define SampleGrad sample

#define GETDIMENSION(t, d) (d).x = (t).get_width(); (d).y = (t).get_height()

#elif __cplusplus // not invoking shader compiler, but included in engine source

// Application-side types:

typedef XMMATRIX matrix;
typedef XMFLOAT4X4 float4x4;
typedef XMFLOAT2 float2;
typedef XMFLOAT3 float3;
typedef XMFLOAT4 float4;
typedef uint32_t uint;
typedef XMUINT2 uint2;
typedef XMUINT3 uint3;
typedef XMUINT4 uint4;
typedef XMINT2 int2;
typedef XMINT3 int3;
typedef XMINT4 int4;

#define CB_GETBINDSLOT(name) __CBUFFERBINDSLOT__##name##__
#define CBUFFER(name, slot) static const int CB_GETBINDSLOT(name) = slot; struct alignas(16) name

#elif SHADERCOMPILER_SPIRV // invoking Vulkan shader compiler (HLSL -> SPIRV)

#if defined(SPIRV_SHADERTYPE_VS)
#define VULKAN_DESCRIPTOR_SET_ID 0
#elif defined(SPIRV_SHADERTYPE_HS)
#define VULKAN_DESCRIPTOR_SET_ID 1
#elif defined(SPIRV_SHADERTYPE_DS)
#define VULKAN_DESCRIPTOR_SET_ID 2
#elif defined(SPIRV_SHADERTYPE_GS)
#define VULKAN_DESCRIPTOR_SET_ID 3
#elif defined(SPIRV_SHADERTYPE_PS)
#define VULKAN_DESCRIPTOR_SET_ID 4
#elif defined(SPIRV_SHADERTYPE_CS) // cs is different in that it only has single descriptor table, so we will index the first
#define VULKAN_DESCRIPTOR_SET_ID 0
#else
#error You must specify a shader type when compiling spirv to resolve descriptor sets! (eg. #define SPIRV_SHADERTYPE_VS)
#endif

#define globallycoherent /*nothing*/

#define CBUFFER(name, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_CBV + slot, VULKAN_DESCRIPTOR_SET_ID)]] cbuffer name

#define RAWBUFFER(name,slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_UNTYPEDBUFFER + slot, VULKAN_DESCRIPTOR_SET_ID)]] ByteAddressBuffer name
#define RWRAWBUFFER(name,slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_UNTYPEDBUFFER + slot, VULKAN_DESCRIPTOR_SET_ID)]] RWByteAddressBuffer name

#define TYPEDBUFFER(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TYPEDBUFFER + slot, VULKAN_DESCRIPTOR_SET_ID)]] Buffer< type > name
#define RWTYPEDBUFFER(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_TYPEDBUFFER + slot, VULKAN_DESCRIPTOR_SET_ID)]] RWBuffer< type > name

#define STRUCTUREDBUFFER(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_UNTYPEDBUFFER + slot, VULKAN_DESCRIPTOR_SET_ID)]] StructuredBuffer< type > name
#define RWSTRUCTUREDBUFFER(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_UNTYPEDBUFFER + slot, VULKAN_DESCRIPTOR_SET_ID)]] RWStructuredBuffer< type > name
#define ROVSTRUCTUREDBUFFER(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_UNTYPEDBUFFER + slot, VULKAN_DESCRIPTOR_SET_ID)]] RasterizerOrderedStructuredBuffer< type > name


#define TEXTURE1D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] Texture1D< type > name;
#define TEXTURE1DARRAY(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] Texture1DArray< type > name;
#define RWTEXTURE1D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] RWTexture1D< type > name;

#define TEXTURE2D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] Texture2D< type > name;
#define TEXTURE2DMS(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] Texture2DMS< type > name;
#define TEXTURE2DARRAY(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] Texture2DArray< type > name;
#define RWTEXTURE2D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] RWTexture2D< type > name;
#define RWTEXTURE2DARRAY(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] RWTexture2DArray< type > name;
#define ROVTEXTURE2D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] RasterizerOrderedTexture2D< type > name;

#define TEXTURECUBE(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] TextureCube< type > name;
#define TEXTURECUBEARRAY(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] TextureCubeArray< type > name;

#define TEXTURE3D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] Texture3D< type > name;
#define RWTEXTURE3D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] RWTexture3D< type > name;
#define ROVTEXTURE3D(name, type, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE + slot, VULKAN_DESCRIPTOR_SET_ID)]] RasterizerOrderedTexture3D< type > name;


#define SAMPLERSTATE(name, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SAMPLER + slot, VULKAN_DESCRIPTOR_SET_ID)]] SamplerState name;
#define SAMPLERCOMPARISONSTATE(name, slot) [[vk::binding(VULKAN_DESCRIPTOR_SET_OFFSET_SAMPLER + slot, VULKAN_DESCRIPTOR_SET_ID)]] SamplerComparisonState name;

// Don't have access to wave-intrinsics in Vulkan yet:
#define WaveReadLaneFirst(a) (a)
#define WaveActiveBitOr(a) (a)


#else // invoking DirectX shader compiler

#define CBUFFER(name, slot) cbuffer name : register(b ## slot)

#define RAWBUFFER(name,slot) ByteAddressBuffer name : register(t ## slot)
#define RWRAWBUFFER(name,slot) RWByteAddressBuffer name : register(u ## slot)

#define TYPEDBUFFER(name, type, slot) Buffer< type > name : register(t ## slot)
#define RWTYPEDBUFFER(name, type, slot) RWBuffer< type > name : register(u ## slot)

#define STRUCTUREDBUFFER(name, type, slot) StructuredBuffer< type > name : register(t ## slot)
#define RWSTRUCTUREDBUFFER(name, type, slot) RWStructuredBuffer< type > name : register(u ## slot)
#define ROVSTRUCTUREDBUFFER(name, type, slot) RasterizerOrderedStructuredBuffer< type > name : register(u ## slot)


#define TEXTURE1D(name, type, slot) Texture1D< type > name : register(t ## slot);
#define TEXTURE1DARRAY(name, type, slot) Texture1DArray< type > name : register(t ## slot);
#define RWTEXTURE1D(name, type, slot) RWTexture1D< type > name : register(u ## slot);

#define TEXTURE2D(name, type, slot) Texture2D< type > name : register(t ## slot);
#define TEXTURE2DMS(name, type, slot) Texture2DMS< type > name : register(t ## slot);
#define TEXTURE2DARRAY(name, type, slot) Texture2DArray< type > name : register(t ## slot);
#define RWTEXTURE2D(name, type, slot) RWTexture2D< type > name : register(u ## slot);
#define RWTEXTURE2DARRAY(name, type, slot) RWTexture2DArray< type > name : register(u ## slot);
#define ROVTEXTURE2D(name, type, slot) RasterizerOrderedTexture2D< type > name : register(u ## slot);

#define TEXTURECUBE(name, type, slot) TextureCube< type > name : register(t ## slot);
#define TEXTURECUBEARRAY(name, type, slot) TextureCubeArray< type > name : register(t ## slot);

#define TEXTURE3D(name, type, slot) Texture3D< type > name : register(t ## slot);
#define RWTEXTURE3D(name, type, slot) RWTexture3D< type > name : register(u ## slot);
#define ROVTEXTURE3D(name, type, slot) RasterizerOrderedTexture3D< type > name : register(u ## slot);


#define SAMPLERSTATE(name, slot) SamplerState name : register(s ## slot);
#define SAMPLERCOMPARISONSTATE(name, slot) SamplerComparisonState name : register(s ## slot);

#ifndef SHADER_MODEL_6
// Don't have access to wave-intrinsics in pre-SM6:
#define WaveReadLaneFirst(a) (a)
#define WaveActiveBitOr(a) (a)
#endif // SHADER_MODEL_6

#endif

#endif
