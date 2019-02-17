#ifndef _MESH_INPUT_LAYOUT_HF_
#define _MESH_INPUT_LAYOUT_HF_

#import <simd/simd.h>

enum {
    MATI0 = 0,
    MATI1 = 1,
    MATI2 = 2,
    COLOR_DITHER = 3,
    MATIPREV0 = 4, 
    MATIPREV1 = 5,
    MATIPREV2 = 6,
    INSTANCEATLAS = 7,
};

enum {
    POSITION_NORMAL_SUBSETINDEX = 0,
    TEXCOORD0 = 1,
    ATLAS = 2,
    PREVPOS = 3,
    PER_INSTANCE = 4,
};

struct Input_Instance
{
    simd::float4 wi0 [[attribute(MATI0)]];
    simd::float4 wi1 [[attribute(MATI1)]];
    simd::float4 wi2 [[attribute(MATI2)]];
    simd::float4 color_dither [[attribute(COLOR_DITHER)]];
};
struct Input_InstancePrev
{
    simd::float4 wiPrev0 [[attribute(MATIPREV0)]];
    simd::float4 wiPrev1 [[attribute(MATIPREV1)]];
    simd::float4 wiPrev2 [[attribute(MATIPREV2)]];
};
struct Input_InstanceAtlas
{
    simd::float4 atlasMulAdd [[attribute(INSTANCEATLAS)]];
};

struct PerInstanceData
{
    Input_Instance instance;
    Input_InstancePrev instancePrev;
    Input_InstanceAtlas instanceAtlas;
};

struct Input_Object_POS
{
    device const float4 *pos [[buffer(POSITION_NORMAL_SUBSETINDEX)]];
    device const Input_Instance *instance [[buffer(PER_INSTANCE)]];
};
struct Input_Object_POS_TEX
{
    device const float4 *pos [[buffer(POSITION_NORMAL_SUBSETINDEX)]];
    device const float2 *tex [[buffer(TEXCOORD0)]];
    device const Input_Instance *instance [[buffer(PER_INSTANCE)]];
};
struct Input_Object_ALL
{
    device const float4 *pos [[buffer(POSITION_NORMAL_SUBSETINDEX)]];
    device const float2 *tex [[buffer(TEXCOORD0)]];
    device const float2 *atl [[buffer(ATLAS)]];
    device const float4 *pre [[buffer(PREVPOS)]];
    device const PerInstanceData *data [[buffer(PER_INSTANCE)]];
};

inline simd::float4x4 MakeWorldMatrixFromInstance(Input_Instance input)
{
    return simd::float4x4(
                    simd::float4(input.wi0.x, input.wi1.x, input.wi2.x, 0)
                    , simd::float4(input.wi0.y, input.wi1.y, input.wi2.y, 0)
                    , simd::float4(input.wi0.z, input.wi1.z, input.wi2.z, 0)
                    , simd::float4(input.wi0.w, input.wi1.w, input.wi2.w, 1)
                    );
}
inline simd::float4x4 MakeWorldMatrixFromInstance(Input_InstancePrev input)
{
    return simd::float4x4(
                    simd::float4(input.wiPrev0.x, input.wiPrev1.x, input.wiPrev2.x, 0)
                    , simd::float4(input.wiPrev0.y, input.wiPrev1.y, input.wiPrev2.y, 0)
                    , simd::float4(input.wiPrev0.z, input.wiPrev1.z, input.wiPrev2.z, 0)
                    , simd::float4(input.wiPrev0.w, input.wiPrev1.w, input.wiPrev2.w, 1)
                    );
}

struct VertexSurface
{
    simd::float4 position;
    simd::float3 normal;
    uint materialIndex;
    simd::float2 uv;
    simd::float2 atlas;
    simd::float4 prevPos;
};
inline VertexSurface MakeVertexSurfaceFromInput(Input_Object_POS input, uint vid)
{
    VertexSurface surface;
    
    surface.position = simd::float4(input.pos[vid].xyz, 1);
    
    uint normal_wind_matID = uint(input.pos[vid].w);
    surface.normal.x = (float)((normal_wind_matID >> 0) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.y = (float)((normal_wind_matID >> 8) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.z = (float)((normal_wind_matID >> 16) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.materialIndex = (normal_wind_matID >> 24) & 0x000000FF;
    
    return surface;
}
inline VertexSurface MakeVertexSurfaceFromInput(Input_Object_POS_TEX input, uint vid)
{
    VertexSurface surface;
    
    surface.position = simd::float4(input.pos[vid].xyz, 1);
    
    uint normal_wind_matID = uint(input.pos[vid].w);
    surface.normal.x = (float)((normal_wind_matID >> 0) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.y = (float)((normal_wind_matID >> 8) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.z = (float)((normal_wind_matID >> 16) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.materialIndex = (normal_wind_matID >> 24) & 0x000000FF;
    
    surface.uv = input.tex[vid];
    
    return surface;
}
inline VertexSurface MakeVertexSurfaceFromInput(Input_Object_ALL input, uint vid, uint iid)
{
    VertexSurface surface;
    
    surface.position = simd::float4(input.pos[vid].xyz, 1);
    
    uint normal_wind_matID = uint(input.pos[vid].w);
    surface.normal.x = (float)((normal_wind_matID >> 0) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.y = (float)((normal_wind_matID >> 8) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.z = (float)((normal_wind_matID >> 16) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.materialIndex = (normal_wind_matID >> 24) & 0x000000FF;
    
    surface.uv = input.tex[vid];
    
    surface.atlas = input.atl[vid] * input.data[iid].instanceAtlas.atlasMulAdd.xy + input.data[iid].instanceAtlas.atlasMulAdd.zw;
    
    surface.prevPos = simd::float4(input.pre[vid].xyz, 1);
    
    return surface;
}

#endif // _MESH_INPUT_LAYOUT_HF_
