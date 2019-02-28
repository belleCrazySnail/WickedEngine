#ifndef _MESH_INPUT_LAYOUT_HF_
#define _MESH_INPUT_LAYOUT_HF_

#import <simd/simd.h>

struct Input_Instance
{
    simd::float4 wi0 [[attribute(0)]];
    simd::float4 wi1 [[attribute(1)]];
    simd::float4 wi2 [[attribute(2)]];
    simd::float4 color_dither [[attribute(3)]];
};
struct Input_InstancePrev
{
    simd::float4 wiPrev0 [[attribute(0)]];
    simd::float4 wiPrev1 [[attribute(1)]];
    simd::float4 wiPrev2 [[attribute(2)]];
};
struct Input_InstanceAll
{
    simd::float4 wi0 [[attribute(0)]];
    simd::float4 wi1 [[attribute(1)]];
    simd::float4 wi2 [[attribute(2)]];
    simd::float4 color_dither [[attribute(3)]];
    simd::float4 wiPrev0 [[attribute(4)]];
    simd::float4 wiPrev1 [[attribute(5)]];
    simd::float4 wiPrev2 [[attribute(6)]];
    simd::float4 atlasMulAdd [[attribute(7)]];
};

struct Input_Object_POS
{
    device const float4 *pos [[buffer(0)]];
    device const Input_Instance *instance [[buffer(1)]];
};
struct Input_Object_POS_TEX
{
    device const float4 *pos [[buffer(0)]];
    device const float2 *tex [[buffer(1)]];
    device const Input_Instance *instance [[buffer(2)]];
};
struct Input_Object_ALL
{
    device const float4 *pos [[buffer(0)]];
    device const float2 *tex [[buffer(1)]];
    device const float2 *atl [[buffer(2)]];
    device const float4 *pre [[buffer(3)]];
    device const Input_InstanceAll *instance [[buffer(4)]];
};

#define MakeWorldMatrixFromInstance(input) simd::float4x4( \
                    simd::float4(input.wi0.x, input.wi1.x, input.wi2.x, 0) \
                    , simd::float4(input.wi0.y, input.wi1.y, input.wi2.y, 0) \
                    , simd::float4(input.wi0.z, input.wi1.z, input.wi2.z, 0) \
                    , simd::float4(input.wi0.w, input.wi1.w, input.wi2.w, 1) \
                    );

#define MakeWorldMatrixFromPrevInstance(input) simd::float4x4( \
                    simd::float4(input.wiPrev0.x, input.wiPrev1.x, input.wiPrev2.x, 0) \
                    , simd::float4(input.wiPrev0.y, input.wiPrev1.y, input.wiPrev2.y, 0) \
                    , simd::float4(input.wiPrev0.z, input.wiPrev1.z, input.wiPrev2.z, 0) \
                    , simd::float4(input.wiPrev0.w, input.wiPrev1.w, input.wiPrev2.w, 1) \
                    );

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
    
    uint normal_wind_matID = as_type<uint>(input.pos[vid].w);
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
    
    uint normal_wind_matID = as_type<uint>(input.pos[vid].w);
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
    
    uint normal_wind_matID = as_type<uint>(input.pos[vid].w);
    surface.normal.x = (float)((normal_wind_matID >> 0) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.y = (float)((normal_wind_matID >> 8) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.normal.z = (float)((normal_wind_matID >> 16) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
    surface.materialIndex = (normal_wind_matID >> 24) & 0x000000FF;
    
    surface.uv = input.tex[vid];
    
    surface.atlas = input.atl[vid] * input.instance[iid].atlasMulAdd.xy + input.instance[iid].atlasMulAdd.zw;
    
    surface.prevPos = simd::float4(input.pre[vid].xyz, 1);
    
    return surface;
}

#endif // _MESH_INPUT_LAYOUT_HF_
