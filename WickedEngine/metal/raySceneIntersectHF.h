#ifndef _RAY_SCENE_INTERSECT_HF_
#define _RAY_SCENE_INTERSECT_HF_

#define TRANCEDRENDERING_CB
#define RAY_INTERSECT_DATA
#define TEXSLOT0

#include "globals.h"
#include "tracedRenderingHF.h"

#ifndef RAYTRACE_STACKSIZE
#define RAYTRACE_STACKSIZE 32
#endif // RAYTRACE_STACKSIZE

inline RayHit TraceScene(Ray ray, constant GlobalData &gd)
{
	RayHit bestHit = CreateRayHit();

	// Using BVH acceleration structure:

	// Emulated stack for tree traversal:
	uint stack[RAYTRACE_STACKSIZE];
	uint stackpos = 0;

	uint clusterCount = gd.clusterCounterBuffer[0];
	uint leafNodeOffset = clusterCount - 1;

	// push root node
	stack[stackpos] = 0;
	stackpos++;

	uint exit_condition = 0;
	do {
#ifdef RAYTRACE_EXIT
		if (exit_condition > RAYTRACE_EXIT)
			break;
		exit_condition++;
#endif // RAYTRACE_EXIT

		// pop untraversed node
		stackpos--;
		const uint nodeIndex = stack[stackpos];

		BVHNode node = gd.bvhNodeBuffer[nodeIndex];
		BVHAABB box = gd.bvhAABBBuffer[nodeIndex];

		if (IntersectBox(ray, box))
		{
			//if (node.LeftChildIndex == 0 && node.RightChildIndex == 0)
			if (nodeIndex >= clusterCount - 1)
			{
				// Leaf node
				uint nodeToClusterID = nodeIndex - leafNodeOffset;
				uint clusterIndex = gd.clusterIndexBuffer[nodeToClusterID];
				bool cullCluster = false;

				//// Compute per cluster visibility:
				//const ClusterCone cone = clusterConeBuffer[clusterIndex];
				//if (cone.valid)
				//{
				//	const float3 testVec = normalize(ray.origin - cone.position);
				//	if (dot(testVec, cone.direction) > cone.angleCos)
				//	{
				//		cullCluster = true;
				//	}
				//}

				if (!cullCluster)
				{
					uint2 cluster = gd.clusterOffsetBuffer[clusterIndex];
					uint triangleOffset = cluster.x;
					uint triangleCount = cluster.y;

					for (uint tri = 0; tri < triangleCount; ++tri)
					{
						uint primitiveID = triangleOffset + tri;
						IntersectTriangle(ray, bestHit, gd.triangleBuffer[primitiveID], primitiveID);
					}
				}
			}
			else
			{
				// Internal node
				if (stackpos < RAYTRACE_STACKSIZE - 1)
				{
					// push left child
					stack[stackpos] = node.LeftChildIndex;
					stackpos++;
					// push right child
					stack[stackpos] = node.RightChildIndex;
					stackpos++;
				}
				else
				{
					// stack overflow, terminate
					break;
				}
			}

		}

	} while (stackpos > 0);


	return bestHit;
}

inline bool TraceSceneANY(Ray ray, float maxDistance, constant GlobalData &gd)
{
	bool shadow = false;

	// Using BVH acceleration structure:

	// Emulated stack for tree traversal:
	uint stack[RAYTRACE_STACKSIZE];
	uint stackpos = 0;

	uint clusterCount = gd.clusterCounterBuffer[0];
	uint leafNodeOffset = clusterCount - 1;

	// push root node
	stack[stackpos] = 0;
	stackpos++;

	uint exit_condition = 0;
	do {
#ifdef RAYTRACE_EXIT
		if (exit_condition > RAYTRACE_EXIT)
			break;
		exit_condition++;
#endif // RAYTRACE_EXIT

		// pop untraversed node
		stackpos--;
		uint nodeIndex = stack[stackpos];

		BVHNode node = gd.bvhNodeBuffer[nodeIndex];
		BVHAABB box = gd.bvhAABBBuffer[nodeIndex];

		if (IntersectBox(ray, box))
		{
			//if (node.LeftChildIndex == 0 && node.RightChildIndex == 0)
			if (nodeIndex >= clusterCount - 1)
			{
				// Leaf node
				uint nodeToClusterID = nodeIndex - leafNodeOffset;
				uint clusterIndex = gd.clusterIndexBuffer[nodeToClusterID];
				bool cullCluster = false;

				//// Compute per cluster visibility:
				//const ClusterCone cone = clusterConeBuffer[clusterIndex];
				//if (cone.valid)
				//{
				//	const float3 testVec = normalize(ray.origin - cone.position);
				//	if (dot(testVec, cone.direction) > cone.angleCos)
				//	{
				//		cullCluster = true;
				//	}
				//}

				if (!cullCluster)
				{
					uint2 cluster = gd.clusterOffsetBuffer[clusterIndex];
					uint triangleOffset = cluster.x;
					uint triangleCount = cluster.y;

					for (uint tri = 0; tri < triangleCount; ++tri)
					{
						const uint primitiveID = triangleOffset + tri;
						if (IntersectTriangleANY(ray, maxDistance, gd.triangleBuffer[primitiveID]))
						{
							shadow = true;
							break;
						}
					}
				}
			}
			else
			{
				// Internal node
				if (stackpos < RAYTRACE_STACKSIZE - 1)
				{
					// push left child
					stack[stackpos] = node.LeftChildIndex;
					stackpos++;
					// push right child
					stack[stackpos] = node.RightChildIndex;
					stackpos++;
				}
				else
				{
					// stack overflow, terminate
					break;
				}
			}

		}

	} while (!shadow && stackpos > 0);

	return shadow;
}

// This will modify ray to continue the trace
//	Also fill the final params of rayHit, such as normal, uv, materialIndex
//	seed should be > 0
//	pixel should be normalized uv coordinates of the ray start position (used to randomize)
inline float3 Shade(thread Ray &ray, thread RayHit &hit, thread float &seed, float2 pixel, constant GlobalData &gd)
{
	if (hit.distance < INFINITE_RAYHIT)
	{
		BVHMeshTriangle tri = gd.triangleBuffer[hit.primitiveID];

		float u = hit.bary.x;
		float v = hit.bary.y;
		float w = 1 - u - v;

		hit.N = normalize(tri.n0 * w + tri.n1 * u + tri.n2 * v);
		hit.UV = tri.t0 * w + tri.t1 * u + tri.t2 * v;
		hit.materialIndex = tri.materialIndex;

		TracedRenderingMaterial mat = gd.materialBuffer[hit.materialIndex];

		hit.UV = fract(hit.UV); // emulate wrap
		float4 baseColorMap = gd.materialTextureAtlas.SampleLevel(gd.sampler_linear_clamp, hit.UV * mat.baseColorAtlasMulAdd.xy + mat.baseColorAtlasMulAdd.zw, 0);
		float4 surfaceMap = gd.materialTextureAtlas.SampleLevel(gd.sampler_linear_clamp, hit.UV * mat.surfaceMapAtlasMulAdd.xy + mat.surfaceMapAtlasMulAdd.zw, 0);
		float4 normalMap = gd.materialTextureAtlas.SampleLevel(gd.sampler_linear_clamp, hit.UV * mat.normalMapAtlasMulAdd.xy + mat.normalMapAtlasMulAdd.zw, 0);

		float4 baseColor = DEGAMMA(mat.baseColor * baseColorMap);
		float reflectance = mat.reflectance * surfaceMap.r;
		float metalness = mat.metalness * surfaceMap.g;
		float3 emissive = baseColor.rgb * mat.emissive * surfaceMap.b;
		float roughness = mat.roughness * normalMap.a;
		roughness = sqrt(roughness); // convert linear roughness to cone aperture
		float sss = mat.subsurfaceScattering;


		// Calculate chances of reflection types:
		float refractChance = 1 - baseColor.a;

		// Roulette-select the ray's path
		float roulette = rand(seed, pixel);
		if (roulette < refractChance)
		{
			// Refraction
			float3 R = refract(ray.direction, hit.N, 1 - mat.refractionIndex);
			ray.direction = mix(R, SampleHemisphere(R, seed, pixel), roughness);
			ray.energy *= mix(baseColor.rgb, 1, refractChance);

			// The ray penetrates the surface, so push DOWN along normal to avoid self-intersection:
			ray.origin = trace_bias_position(hit.position, -hit.N);
		}
		else
		{
			// Calculate chances of reflection types:
			float3 albedo = ComputeAlbedo(baseColor, reflectance, metalness);
			float3 f0 = ComputeF0(baseColor, reflectance, metalness);
			float3 F = F_Fresnel(f0, saturate(dot(-ray.direction, hit.N)));
			float specChance = dot(F, 0.33);
			float diffChance = dot(albedo, 0.33);
			float inv = 1.0 / (specChance + diffChance);
			specChance *= inv;
			diffChance *= inv;

			roulette = rand(seed, pixel);
			if (roulette < specChance)
			{
				// Specular reflection
				float3 R = reflect(ray.direction, hit.N);
				ray.direction = mix(R, SampleHemisphere(R, seed, pixel), roughness);
				ray.energy *= F / specChance;
			}
			else
			{
				// Diffuse reflection
				ray.direction = SampleHemisphere(hit.N, seed, pixel);
				ray.energy *= albedo / diffChance;
			}

			// Ray reflects from surface, so push UP along normal to avoid self-intersection:
			ray.origin = trace_bias_position(hit.position, hit.N);
		}

		ray.primitiveID = hit.primitiveID;
		ray.bary = hit.bary;
		ray.Update();

		return emissive;
	}
	else
	{
		// Erase the ray's energy - the sky doesn't reflect anything
		ray.energy = 0.0f;

		float3 envColor;
//        [branch]
		if (IsStaticSky(gd))
		{
			// We have envmap information in a texture:
			envColor = DEGAMMA_SKY(gd.texture_globalenvmap.SampleLevel(gd.sampler_linear_clamp, ray.direction, level(0)).rgb);
		}
		else
		{
			envColor = GetDynamicSkyColor(ray.direction, gd);
		}
		return envColor;
	}
}

#endif // _RAY_SCENE_INTERSECT_HF_
