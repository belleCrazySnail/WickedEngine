#ifndef _OBJECTSHADER_HF_
#define _OBJECTSHADER_HF_

#if defined(TILEDFORWARD) && !defined(TRANSPARENT)
#define DISABLE_ALPHATEST
#endif

#ifdef TRANSPARENT
#define DISABLE_TRANSPARENT_SHADOWMAP
#endif


#ifdef PLANARREFLECTION
#define DISABLE_ENVMAPS
#endif


#define LIGHTMAP_QUALITY_BICUBIC

#define TEXSLOT0
#define TEXSLOT1
#define TEXSLOT2
#define TEXSLOT3
#define TEXSLOT4
#define TEXSLOT5
#define TEXSLOT6
#define TEXSLOT7
#define TEXSLOT8
#define TEXSLOT9

#include "globals.h"
#include "objectInputLayoutHF.h"
#include "ditherHF.h"
#include "brdf.h"
#include "packHF.h"
#include "lightingHF.h"

// DEFINITIONS
//////////////////

// These are bound by wiRenderer (based on Material):
#define xBaseColorMap			gd.texture_0	// rgb: baseColor, a: opacity
#define xNormalMap				gd.texture_1	// rgb: normal, a: roughness
#define xSurfaceMap				gd.texture_2	// r: reflectance, g: metalness, b: emissive, a: subsurface scattering
#define xDisplacementMap		gd.texture_3	// r: heightmap

// These are bound by RenderPath (based on Render Path):
#define xReflection				gd.texture_6	// rgba: scene color from reflected camera angle
#define xRefraction				gd.texture_7	// rgba: scene color from primary camera angle
#define	xWaterRipples			gd.texture_8	// rgb: snorm8 water ripple normal map
#define	xSSAO					gd.texture_8	// r: screen space ambient occlusion
#define	xSSR					gd.texture_9	// rgb: screen space ray-traced reflections, a: reflection blend based on ray hit or miss


struct PixelInputType_Simple
{
	float4 pos [[position]];
	float  clip	[[clip_distance]];
	float2 tex;
	float  dither [[flat]];
	float3 instanceColor [[flat]];
};

struct PixelInputType
{
    simd::float4 pos [[position]];
    float  clip [[clip_distance]];
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

struct GBUFFEROutputType
{
	float4 g0 [[color(0)]];		// texture_gbuffer0
	float4 g1 [[color(1)]];		// texture_gbuffer1
	float4 g2 [[color(2)]];		// texture_gbuffer2
	float4 diffuse [[color(3)]];
	float4 specular [[color(4)]];
};
inline GBUFFEROutputType CreateGbuffer(float4 color, Surface surface, float2 velocity, float3 diffuse, float3 specular, float ao)
{
	GBUFFEROutputType Out;
	Out.g0 = float4(color.rgb, ao);																/*FORMAT_R8G8B8A8_UNORM*/
	Out.g1 = float4(encode(surface.N), velocity);												/*FORMAT_R16G16B16A16_FLOAT*/
	Out.g2 = float4(surface.roughness, surface.reflectance, surface.metalness, surface.sss);	/*FORMAT_R8G8B8A8_UNORM*/
	Out.diffuse = float4(diffuse, 1);															/*wiRenderer::RTFormat_deferred_lightbuffer*/
	Out.specular = float4(specular, 1);															/*wiRenderer::RTFormat_deferred_lightbuffer*/
	return Out;
}

struct GBUFFEROutputType_Thin
{
	float4 g0 [[color(0)]];		// texture_gbuffer0
	float4 g1 [[color(1)]];		// texture_gbuffer1
};
inline GBUFFEROutputType_Thin CreateGbuffer_Thin(float4 color, Surface surface, float2 velocity)
{
	GBUFFEROutputType_Thin Out;
	Out.g0 = color;																		/*FORMAT_R16G16B16A16_FLOAT*/
	Out.g1 = float4(encode(surface.N), velocity);										/*FORMAT_R16G16B16A16_FLOAT*/
	return Out;
}


// METHODS
////////////

inline float3x3 compute_tangent_frame(float3 N, float3 P, float2 UV, thread float3 &T, thread float3 &B)
{
    float3 dp1 = dfdx(P);
    float3 dp2 = dfdy(P);
    float2 duv1 = dfdx(UV);
    float2 duv2 = dfdy(UV);
    
    float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
    float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
    T = normalize(mul(float2(duv1.x, duv2.x), inverseM));
    B = normalize(mul(float2(duv1.y, duv2.y), inverseM));
    
    return float3x3(T, B, N);
}

inline void ApplyEmissive(Surface surface, thread float3 &specular)
{
	specular += surface.baseColor.rgb * surface.emissive;
}

inline void LightMapping(float2 ATLAS, thread float3 &diffuse, thread float3 &specular, thread float &ao, float ssao, constant GlobalData &gd)
{
	if (any(bool2(ATLAS)))
	{
#ifdef LIGHTMAP_QUALITY_BICUBIC
		float4 lightmap = SampleTextureCatmullRom(gd.texture_globallightmap, ATLAS, 0, gd);
#else
		float4 lightmap = gd.texture_globallightmap.SampleLevel(gd.sampler_linear_clamp, ATLAS, 0);
#endif // LIGHTMAP_QUALITY_BICUBIC
		diffuse += lightmap.rgb * ssao;
		ao *= saturate(1 - lightmap.a);
	}
}

inline void NormalMapping(float2 UV, float3 V, thread float3 &N, float3x3 TBN, thread float3 &bumpColor, thread float &roughness, constant GlobalData &gd)
{
	float4 normal_roughness = xNormalMap.sample(gd.sampler_objectshader, UV);
	bumpColor = 2.0f * normal_roughness.rgb - 1.0f;
	N = normalize(mix(N, mul(bumpColor, TBN), gd.material.g_xMat_normalMapStrength));
	bumpColor *= gd.material.g_xMat_normalMapStrength;
	roughness *= normal_roughness.a;
}

inline void SpecularAA(float3 N, thread float &roughness, constant GlobalData &gd)
{
//    [branch]
	if (gd.frame.g_xFrame_SpecularAA > 0)
	{
		float3 ddxN = dfdx(N);
		float3 ddyN = dfdy(N);
		float curve = pow(max(dot(ddxN, ddxN), dot(ddyN, ddyN)), 1 - gd.frame.g_xFrame_SpecularAA);
		roughness = max(roughness, curve);
	}
}

inline float3 PlanarReflection(float2 reflectionUV, Surface surface, constant GlobalData &gd)
{
	return xReflection.SampleLevel(gd.sampler_linear_clamp, reflectionUV + surface.N.xz*gd.material.g_xMat_normalMapStrength, 0).rgb;
}

#define NUM_PARALLAX_OCCLUSION_STEPS 32
inline void ParallaxOcclusionMapping(thread float2 &UV, float3 V, float3x3 TBN, constant GlobalData &gd)
{
	V = mul(TBN, V);
	float layerHeight = 1.0 / NUM_PARALLAX_OCCLUSION_STEPS;
	float curLayerHeight = 0;
	float2 dtex = gd.material.g_xMat_parallaxOcclusionMapping * V.xy / NUM_PARALLAX_OCCLUSION_STEPS;
	float2 currentTextureCoords = UV;
	float2 derivX = dfdx(UV);
	float2 derivY = dfdy(UV);
	float heightFromTexture = 1 - xDisplacementMap.SampleGrad(gd.sampler_linear_wrap, currentTextureCoords, gradient2d(derivX, derivY)).r;
	uint iter = 0;
//    [loop]
	while (heightFromTexture > curLayerHeight && iter < NUM_PARALLAX_OCCLUSION_STEPS)
	{
		curLayerHeight += layerHeight;
		currentTextureCoords -= dtex;
		heightFromTexture = 1 - xDisplacementMap.SampleGrad(gd.sampler_linear_wrap, currentTextureCoords, gradient2d(derivX, derivY)).r;
		iter++;
	}
	float2 prevTCoords = currentTextureCoords + dtex;
	float nextH = heightFromTexture - curLayerHeight;
	float prevH = 1 - xDisplacementMap.SampleGrad(gd.sampler_linear_wrap, prevTCoords, gradient2d(derivX, derivY)).r - curLayerHeight + layerHeight;
	float weight = nextH / (nextH - prevH);
	float2 finalTexCoords = prevTCoords * weight + currentTextureCoords * (1.0 - weight);
	UV = finalTexCoords;
}

inline void Refraction(float2 ScreenCoord, float2 normal2D, float3 bumpColor, thread Surface &surface, thread float4 &color, thread float3 &diffuse, constant GlobalData &gd)
{
	if (gd.material.g_xMat_refractionIndex > 0)
	{
		float mipLevels = xRefraction.get_num_mip_levels();
		float2 perturbatedRefrTexCoords = ScreenCoord.xy + (normal2D + bumpColor.rg) * gd.material.g_xMat_refractionIndex;
		float4 refractiveColor = xRefraction.SampleLevel(gd.sampler_linear_clamp, perturbatedRefrTexCoords, level((gd.frame.g_xFrame_AdvancedRefractions ? surface.roughness * mipLevels : 0)));
		surface.albedo.rgb = mix(refractiveColor.rgb, surface.albedo.rgb, color.a);
		diffuse = mix(1, diffuse, color.a);
		color.a = 1;
	}
}

inline void ForwardLighting(thread Surface &surface, thread float3 &diffuse, thread float3 &specular, thread float3 &reflection, constant GlobalData &gd)
{
#ifndef DISABLE_ENVMAPS
	const float envMapMIP = surface.roughness * gd.frame.g_xFrame_EnvProbeMipCount;
	reflection = max(float3(0.f), EnvironmentReflection_Global(surface, envMapMIP, gd));
#endif // DISABLE_ENVMAPS

//    [loop]
	for (uint iterator = 0; iterator < gd.frame.g_xFrame_LightArrayCount; iterator++)
	{
		ShaderEntityType light = gd.EntityArray[gd.frame.g_xFrame_LightArrayOffset + iterator];

		if (light.GetFlags() & ENTITY_FLAG_LIGHT_STATIC)
		{
			continue; // static lights will be skipped (they are used in lightmap baking)
		}

        LightingResult result = {};

		switch (light.GetType())
		{
		case ENTITY_TYPE_DIRECTIONALLIGHT:
		{
			result = DirectionalLight(light, surface, gd);
		}
		break;
		case ENTITY_TYPE_POINTLIGHT:
		{
			result = PointLight(light, surface, gd);
		}
		break;
		case ENTITY_TYPE_SPOTLIGHT:
		{
			result = SpotLight(light, surface, gd);
		}
		break;
		case ENTITY_TYPE_SPHERELIGHT:
		{
			result = SphereLight(light, surface, gd);
		}
		break;
		case ENTITY_TYPE_DISCLIGHT:
		{
			result = DiscLight(light, surface, gd);
		}
		break;
		case ENTITY_TYPE_RECTANGLELIGHT:
		{
			result = RectangleLight(light, surface, gd);
		}
		break;
		case ENTITY_TYPE_TUBELIGHT:
		{
			result = TubeLight(light, surface, gd);
		}
		break;
		}

		diffuse += max(0.0f, result.diffuse);
		specular += max(0.0f, result.specular);
	}
}

inline void TiledLighting(float2 pixel, thread Surface &surface, thread float3 &diffuse, thread float3 &specular, thread float3 &reflection, constant GlobalData &gd)
{
	const uint2 tileIndex = uint2(floor(pixel / TILED_CULLING_BLOCKSIZE));
	const uint flatTileIndex = flatten2D(tileIndex, gd.frame.g_xFrame_EntityCullingTileCount.xy) * SHADER_ENTITY_TILE_BUCKET_COUNT;

#ifndef DISABLE_DECALS
	// decals are enabled, loop through them first:
	float4 decalAccumulation = 0;
	const float3 P_dx = dfdx(surface.P);
	const float3 P_dy = dfdy(surface.P);
#endif // DISABLE_DECALS

#ifndef DISABLE_ENVMAPS
	// Apply environment maps:
	float4 envmapAccumulation = 0;
	const float envMapMIP = surface.roughness * gd.frame.g_xFrame_EnvProbeMipCount;
#endif // DISABLE_ENVMAPS

	// Loop through entity buckets in the tile (but only up to the last bucket that contains a light):
	const uint last_bucket = min((gd.frame.g_xFrame_LightArrayOffset + gd.frame.g_xFrame_LightArrayCount) / 32, max(0u, SHADER_ENTITY_TILE_BUCKET_COUNT - 1));
	for (uint bucket = 0; bucket <= last_bucket; ++bucket)
	{
		uint bucket_bits = gd.EntityTiles[flatTileIndex + bucket];
		
		//// This is the wave scalarizer from Improved Culling - Siggraph 2017 [Drobot]:
		// bucket_bits = WaveReadFirstLane(WaveAllBitOr(bucket_bits));

		while (bucket_bits != 0)
		{
			// Retrieve global entity index from local bucket, then remove bit from local bucket:
			const uint bucket_bit_index = clz(bucket_bits);
			const uint entity_index = bucket * 32 + bucket_bit_index;
			bucket_bits ^= 1 << bucket_bit_index;


#ifndef DISABLE_DECALS
			// Check if it is a decal, and process:
			if (entity_index >= gd.frame.g_xFrame_DecalArrayOffset &&
				entity_index < gd.frame.g_xFrame_DecalArrayOffset + gd.frame.g_xFrame_DecalArrayCount &&
				decalAccumulation.a < 1)
			{
				ShaderEntityType decal = gd.EntityArray[entity_index];

				const float4x4 decalProjection = gd.MatrixArray[decal.userdata];
				const float3 clipSpacePos = mul(float4(surface.P, 1), decalProjection).xyz;
				const float3 uvw = clipSpacePos.xyz*float3(0.5f, -0.5f, 0.5f) + 0.5f;
//                [branch]
				if (!is_saturated(uvw))
				{
					// mipmapping needs to be performed by hand:
					const float2 decalDX = (mul(P_dx, getUpper3x3(decalProjection))).xy * decal.texMulAdd.xy;
					const float2 decalDY = (mul(P_dy, getUpper3x3(decalProjection))).xy * decal.texMulAdd.xy;
					float4 decalColor = gd.texture_decalatlas.SampleGrad(gd.sampler_linear_clamp, uvw.xy*decal.texMulAdd.xy + decal.texMulAdd.zw, gradient2d(decalDX, decalDY));
					// blend out if close to cube Z:
					float edgeBlend = 1 - pow(saturate(abs(clipSpacePos.z)), 8);
					decalColor.a *= edgeBlend;
					decalColor *= decal.GetColor();
					// apply emissive:
					specular += max(0, decalColor.rgb * decal.GetEmissive() * edgeBlend);
					// perform manual blending of decals:
					//  NOTE: they are sorted top-to-bottom, but blending is performed bottom-to-top
					decalAccumulation.rgb = (1 - decalAccumulation.a) * (decalColor.a*decalColor.rgb) + decalAccumulation.rgb;
					decalAccumulation.a = decalColor.a + (1 - decalColor.a) * decalAccumulation.a;
				}

				continue;
			}
#endif // DISABLE_DECALS
			

#ifndef DISABLE_ENVMAPS
#ifndef DISABLE_LOCALENVPMAPS
			// Check if it is an envprobe and process:
			if (entity_index >= gd.frame.g_xFrame_EnvProbeArrayOffset &&
				entity_index < gd.frame.g_xFrame_EnvProbeArrayOffset + gd.frame.g_xFrame_EnvProbeArrayCount &&
				envmapAccumulation.a < 1)
			{
				ShaderEntityType probe = gd.EntityArray[entity_index];

				const float4x4 probeProjection = gd.MatrixArray[probe.userdata];
				const float3 clipSpacePos = mul(float4(surface.P, 1), probeProjection).xyz;
				const float3 uvw = clipSpacePos.xyz*float3(0.5f, -0.5f, 0.5f) + 0.5f;
//                [branch]
				if (!is_saturated(uvw))
				{
					const float4 envmapColor = EnvironmentReflection_Local(surface, probe, probeProjection, clipSpacePos, envMapMIP, gd);
					// perform manual blending of probes:
					//  NOTE: they are sorted top-to-bottom, but blending is performed bottom-to-top
					envmapAccumulation.rgb = (1 - envmapAccumulation.a) * (envmapColor.a * envmapColor.rgb) + envmapAccumulation.rgb;
					envmapAccumulation.a = envmapColor.a + (1 - envmapColor.a) * envmapAccumulation.a;
				}

				continue;
			}
#endif // DISABLE_LOCALENVPMAPS
#endif // DISABLE_ENVMAPS
			

			// Check if it is a light and process:
			if (entity_index >= gd.frame.g_xFrame_LightArrayOffset &&
				entity_index < gd.frame.g_xFrame_LightArrayOffset + gd.frame.g_xFrame_LightArrayCount)
			{
				ShaderEntityType light = gd.EntityArray[entity_index];

				if (light.GetFlags() & ENTITY_FLAG_LIGHT_STATIC)
				{
					continue; // static lights will be skipped (they are used in lightmap baking)
				}

                LightingResult result = {};

				switch (light.GetType())
				{
				case ENTITY_TYPE_DIRECTIONALLIGHT:
				{
					result = DirectionalLight(light, surface, gd);
				}
				break;
				case ENTITY_TYPE_POINTLIGHT:
				{
					result = PointLight(light, surface, gd);
				}
				break;
				case ENTITY_TYPE_SPOTLIGHT:
				{
					result = SpotLight(light, surface, gd);
				}
				break;
				case ENTITY_TYPE_SPHERELIGHT:
				{
					result = SphereLight(light, surface, gd);
				}
				break;
				case ENTITY_TYPE_DISCLIGHT:
				{
					result = DiscLight(light, surface, gd);
				}
				break;
				case ENTITY_TYPE_RECTANGLELIGHT:
				{
					result = RectangleLight(light, surface, gd);
				}
				break;
				case ENTITY_TYPE_TUBELIGHT:
				{
					result = TubeLight(light, surface, gd);
				}
				break;
				}

				diffuse += max(0.0f, result.diffuse);
				specular += max(0.0f, result.specular);

				continue;
			}

		}
	}

#ifndef DISABLE_DECALS
	surface.albedo.rgb = mix(surface.albedo.rgb, decalAccumulation.rgb, decalAccumulation.a);
#endif // DISABLE_DECALS

#ifndef DISABLE_ENVMAPS
	// Apply global envmap where there is no local envmap information:
	if (envmapAccumulation.a < 0.99f)
	{
		envmapAccumulation.rgb = mix(EnvironmentReflection_Global(surface, envMapMIP, gd), envmapAccumulation.rgb, envmapAccumulation.a);
	}
	reflection = max(0, envmapAccumulation.rgb);
#endif // DISABLE_ENVMAPS

}

inline void ApplyLighting(Surface surface, float3 diffuse, float3 specular, float ao, thread float4 &color, constant GlobalData &gd)
{
	color.rgb = (GetAmbient(surface.N, gd) * ao + diffuse) * surface.albedo + specular;
}

inline void ApplyFog(float dist, thread float4 &color, constant GlobalData &gd)
{
	color.rgb = mix(color.rgb, GetHorizonColor(gd), GetFog(dist, gd));
}


// OBJECT SHADER PROTOTYPE
///////////////////////////

#if defined(COMPILE_OBJECTSHADER_PS)

// Possible switches:
//	ALPHATESTONLY		-	assemble object shader for depth only rendering + alpha test
//	TEXTUREONLY			-	assemble object shader for rendering only with base textures, no lighting
//	DEFERRED			-	assemble object shader for deferred rendering
//	FORWARD				-	assemble object shader for forward rendering
//	TILEDFORWARD		-	assemble object shader for tiled forward rendering
//	TRANSPARENT			-	assemble object shader for forward or tile forward transparent rendering
//	ENVMAPRENDERING		-	modify object shader for envmap rendering
//	NORMALMAP			-	include normal mapping computation
//	PLANARREFLECTION	-	include planar reflection sampling
//	POM					-	include parallax occlusion mapping computation
//	WATER				-	include specialized water shader code
//	BLACKOUT			-	include specialized blackout shader code

#if defined(ALPHATESTONLY) || defined(TEXTUREONLY)
#define SIMPLE_INPUT
#endif // APLHATESTONLY

#ifdef SIMPLE_INPUT
#define PIXELINPUT PixelInputType_Simple
#else
#define PIXELINPUT PixelInputType
#endif // SIMPLE_INPUT


// entry point:
#if defined(ALPHATESTONLY)
fragment void MAINAPIENTRY(PIXELINPUT input [[stage_in]]
#elif defined(TEXTUREONLY)
fragment float4 MAINAPIENTRY(PIXELINPUT input [[stage_in]]
#elif defined(TRANSPARENT)
fragment float4 MAINAPIENTRY(PIXELINPUT input [[stage_in]]
#elif defined(ENVMAPRENDERING)
fragment float4 MAINAPIENTRY(PSIn_EnvmapRendering input [[stage_in]]
#elif defined(DEFERRED)
fragment GBUFFEROutputType MAINAPIENTRY(PIXELINPUT input [[stage_in]]
#elif defined(FORWARD)
fragment GBUFFEROutputType_Thin MAINAPIENTRY(PIXELINPUT input [[stage_in]]
#elif defined(TILEDFORWARD)
[[early_fragment_tests]]
fragment GBUFFEROutputType_Thin MAINAPIENTRY(PIXELINPUT input [[stage_in]]
#endif // ALPHATESTONLY
, constant GlobalData &gd)


// shader base:
{
	float2 pixel = input.pos.xy;

#if !(defined(TILEDFORWARD) && !defined(TRANSPARENT)) && !defined(ENVMAPRENDERING)
	// apply dithering:
	if (any(bool2(dither(pixel + GetTemporalAASampleRotation(gd)) - input.dither)))
        discard_fragment();
#endif



	float2 UV = input.tex * gd.material.g_xMat_texMulAdd.xy + gd.material.g_xMat_texMulAdd.zw;

	Surface surface;

#ifndef SIMPLE_INPUT
	surface.P = input.pos3D;
	surface.V = gd.camera.g_xCamera_CamPos - surface.P;
	float dist = length(surface.V);
	surface.V /= dist;
	surface.N = normalize(input.nor);

	float3 T, B;
	float3x3 TBN = compute_tangent_frame(surface.N, surface.P, UV, T, B);
#endif // SIMPLE_INPUT

#ifdef POM
	ParallaxOcclusionMapping(UV, surface.V, TBN, gd);
#endif // POM

	float4 color = gd.material.g_xMat_baseColor * float4(input.instanceColor, 1) * xBaseColorMap.sample(gd.sampler_objectshader, UV);
	color.rgb = DEGAMMA(color.rgb);
	ALPHATEST(color.a);

#ifndef SIMPLE_INPUT
	float3 diffuse = 0;
	float3 specular = 0;
	float3 reflection = 0;
	float3 bumpColor = 0;
	float opacity = color.a;
	float depth = input.pos.z;
	float ao = 1;
	float ssao = 1;
#ifndef ENVMAPRENDERING
	float lineardepth = input.pos2D.w;
	input.pos2D.xy /= input.pos2D.w;
	input.pos2DPrev.xy /= input.pos2DPrev.w;
	input.ReflectionMapSamplingPos.xy /= input.ReflectionMapSamplingPos.w;

	float2 refUV = input.ReflectionMapSamplingPos.xy * float2(0.5f, -0.5f) + 0.5f;
	float2 ScreenCoord = input.pos2D.xy * float2(0.5f, -0.5f) + 0.5f;
	float2 velocity = ((input.pos2DPrev.xy - gd.frame.g_xFrame_TemporalAAJitterPrev) - (input.pos2D.xy - gd.frame.g_xFrame_TemporalAAJitter)) * float2(0.5f, -0.5f);
	float2 ReprojectedScreenCoord = ScreenCoord + velocity;
#endif // ENVMAPRENDERING
#endif // SIMPLE_INPUT

	float roughness = gd.material.g_xMat_roughness;

#ifdef NORMALMAP
	NormalMapping(UV, surface.P, surface.N, TBN, bumpColor, roughness, gd);
#endif // NORMALMAP

	float4 surface_ref_met_emi_sss = xSurfaceMap.sample(gd.sampler_objectshader, UV);

	surface = CreateSurface(
		surface.P, surface.N, surface.V, color, roughness,
		gd.material.g_xMat_reflectance * surface_ref_met_emi_sss.r,
		gd.material.g_xMat_metalness * surface_ref_met_emi_sss.g,
		gd.material.g_xMat_emissive * surface_ref_met_emi_sss.b,
		gd.material.g_xMat_subsurfaceScattering * surface_ref_met_emi_sss.a
	);


#ifndef SIMPLE_INPUT


#ifdef WATER
	color.a = 1;

	//NORMALMAP
	float2 bumpColor0 = 0;
	float2 bumpColor1 = 0;
	float2 bumpColor2 = 0;
	bumpColor0 = 2.0f * xNormalMap.sample(gd.sampler_objectshader, UV - gd.material.g_xMat_texMulAdd.ww).rg - 1.0f;
	bumpColor1 = 2.0f * xNormalMap.sample(gd.sampler_objectshader, UV + gd.material.g_xMat_texMulAdd.zw).rg - 1.0f;
	bumpColor2 = xWaterRipples.sample(gd.sampler_objectshader, ScreenCoord).rg;
	bumpColor = float3(bumpColor0 + bumpColor1 + bumpColor2, 1)  * gd.material.g_xMat_refractionIndex;
	surface.N = normalize(mix(surface.N, mul(normalize(bumpColor), TBN), gd.material.g_xMat_normalMapStrength));
	bumpColor *= gd.material.g_xMat_normalMapStrength;

	//REFLECTION
	float4 reflectiveColor = xReflection.SampleLevel(gd.sampler_linear_mirror, refUV + bumpColor.rg, 0);


	//REFRACTION 
	float2 perturbatedRefrTexCoords = ScreenCoord.xy + bumpColor.rg;
	float refDepth = gd.texture_lineardepth.sample(gd.sampler_linear_mirror, ScreenCoord) * gd.frame.g_xFrame_MainCamera_ZFarP;
	float3 refractiveColor = xRefraction.SampleLevel(gd.sampler_linear_mirror, perturbatedRefrTexCoords, 0).rgb;
	float mod = saturate(0.05*(refDepth - lineardepth));
	refractiveColor = mix(refractiveColor, surface.baseColor.rgb, mod).rgb;

	//FRESNEL TERM
	float3 fresnelTerm = F_Fresnel(surface.f0, surface.NdotV);
	surface.albedo.rgb = mix(refractiveColor, reflectiveColor.rgb, fresnelTerm);
#endif // WATER


#ifndef ENVMAPRENDERING
#ifndef TRANSPARENT
	ssao = xSSAO.SampleLevel(gd.sampler_linear_clamp, ReprojectedScreenCoord, 0).r;
	ao *= ssao;
#endif // TRANSPARENT
#endif // ENVMAPRENDERING



	SpecularAA(surface.N, surface.roughness, gd);

	ApplyEmissive(surface, specular);

	LightMapping(input.atl, diffuse, specular, ao, ssao, gd);



#ifdef DEFERRED


#ifdef PLANARREFLECTION
	specular += PlanarReflection(refUV, surface, gd) * surface.F;
#endif



#else // not DEFERRED

#ifdef FORWARD
	ForwardLighting(surface, diffuse, specular, reflection, gd);
#endif // FORWARD

#ifdef TILEDFORWARD
	TiledLighting(pixel, surface, diffuse, specular, reflection, gd);
#endif // TILEDFORWARD


#ifndef WATER
#ifndef ENVMAPRENDERING

	VoxelGI(surface, diffuse, reflection, ao, gd);

#ifdef PLANARREFLECTION
	reflection = PlanarReflection(refUV, surface, gd);
#endif


#ifdef TRANSPARENT
	Refraction(ScreenCoord, input.nor2D, bumpColor, surface, color, diffuse, gd);
#else
	float4 ssr = xSSR.SampleLevel(gd.sampler_linear_clamp, ReprojectedScreenCoord, 0);
	reflection = mix(reflection, ssr.rgb, ssr.a);
#endif // TRANSPARENT


#endif // ENVMAPRENDERING
#endif // WATER

	specular += reflection * surface.F;

	ApplyLighting(surface, diffuse, specular, ao, color, gd);

#ifdef WATER
	// SOFT EDGE
	float fade = saturate(0.3 * abs(refDepth - lineardepth));
	color.a *= fade;
#endif // WATER

	ApplyFog(dist, color, gd);


#endif // DEFERRED


#ifdef TEXTUREONLY
	color.rgb += color.rgb * surface.emissive;
#endif // TEXTUREONLY


#ifdef BLACKOUT
	color = float4(0, 0, 0, 1);
#endif

#endif // SIMPLE_INPUT

	color = max(0, color);


	// end point:
#if defined(TRANSPARENT) || defined(TEXTUREONLY) || defined(ENVMAPRENDERING)
	return color;
#else
#if defined(DEFERRED)	
	return CreateGbuffer(color, surface, velocity, diffuse, specular, ao);
#elif defined(FORWARD) || defined(TILEDFORWARD)
	return CreateGbuffer_Thin(color, surface, velocity);
#endif // DEFERRED
#endif // TRANSPARENT

}


#endif // COMPILE_OBJECTSHADER_PS



#endif // _OBJECTSHADER_HF_

