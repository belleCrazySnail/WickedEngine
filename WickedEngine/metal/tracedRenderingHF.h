#ifndef _TRACEDRENDERING_HF_
#define _TRACEDRENDERING_HF_
#include "lightingHF.h"

#define NOSUN
#include "skyHF.h"

constant float INFINITE_RAYHIT = 1000000;
constant float EPSILON = 0.0001f;

// returns a position that is sligtly above the surface position to avoid self intersection
//	P	: surface postion
//	N	: surface normal
inline float3 trace_bias_position(float3 P, float3 N)
{
	return P + N * EPSILON; // this is the original version
	//return P + sign(N) * abs(P * 0.0000002); // this is from https://ndotl.wordpress.com/2018/08/29/baking-artifact-free-lightmaps/ 
}


//struct Sphere
//{
//	float3 position;
//	float radius;
//	float3 albedo;
//	float3 specular;
//	float emission;
//};

struct Ray
{
	float3 origin;
	float3 direction;
	float3 direction_inverse;
	float3 energy;
	uint primitiveID;
	float2 bary;

	inline void Update()
	{
		direction_inverse = 1.0 / direction;
	}
};

inline TracedRenderingStoredRay CreateStoredRay(Ray ray, uint pixelID)
{
	TracedRenderingStoredRay storedray;

	storedray.pixelID = pixelID;
	storedray.origin = ray.origin;
	storedray.direction_energy.x = pack_float_to_snorm2x16(ray.direction.xy);
    storedray.direction_energy.y = pack_float_to_snorm2x16(float2(ray.direction.z, ray.energy.x));
    storedray.direction_energy.z = pack_float_to_snorm2x16(ray.direction.yz);
	storedray.primitiveID = ray.primitiveID;
	storedray.bary = ray.bary;

	return storedray;
}
inline void LoadRay(TracedRenderingStoredRay storedray, thread Ray &ray, thread uint &pixelID)
{
	pixelID = storedray.pixelID;

	ray.origin = storedray.origin;
    ray.direction.xy = unpack_snorm2x16_to_float(storedray.direction_energy.x);
    float2 val = unpack_snorm2x16_to_float(storedray.direction_energy.y);
    ray.direction.z = val.x;
    ray.energy.x = val.y;
    ray.energy.yz = unpack_snorm2x16_to_float(storedray.direction_energy.z);
	ray.primitiveID = storedray.primitiveID;
	ray.bary = storedray.bary;
	ray.Update();
}

inline Ray CreateRay(float3 origin, float3 direction)
{
	Ray ray;
	ray.origin = origin;
	ray.direction = direction;
	ray.energy = float3(1, 1, 1);
	ray.primitiveID = 0xFFFFFFFF;
	ray.bary = 0;
	ray.Update();
	return ray;
}

inline Ray CreateCameraRay(float2 uv, constant GlobalData &gd)
{
	float4 unprojected = mul(float4(uv, 0.0f, 1.0f), gd.frame.g_xFrame_MainCamera_InvVP);
	unprojected.xyz /= unprojected.w;

	const float3 origin = gd.frame.g_xFrame_MainCamera_CamPos;
	const float3 direction = normalize(unprojected.xyz - origin);

	return CreateRay(origin, direction);
}

struct RayHit
{
	float distance;
	float3 position;
	uint primitiveID;
	float2 bary;

	// these will only be filled when bestHit is determined to avoid recomputing them for every intersection:
	float3 N;
	float2 UV;
	uint materialIndex;
};

inline RayHit CreateRayHit()
{
	RayHit hit;
	hit.distance = INFINITE_RAYHIT;
	hit.position = float3(0.0f, 0.0f, 0.0f);
	hit.primitiveID = 0xFFFFFFFF;
	hit.bary = 0;

	hit.N = 0;
	hit.UV = 0;
	hit.materialIndex = 0;

	return hit;
}

//inline void IntersectGroundPlane(Ray ray, inout RayHit bestHit)
//{
//	// Calculate distance along the ray where the ground plane is intersected
//	float t = -ray.origin.y / ray.direction.y;
//	if (t > 0 && t < bestHit.distance)
//	{
//		bestHit.distance = t;
//		bestHit.position = ray.origin + t * ray.direction;
//		bestHit.normal = float3(0.0f, 1.0f, 0.0f);
//	}
//}
//
//inline void IntersectSphere(Ray ray, inout RayHit bestHit, Sphere sphere)
//{
//	// Calculate distance along the ray where the sphere is intersected
//	float3 d = ray.origin - sphere.position;
//	float p1 = -dot(ray.direction, d);
//	float p2sqr = p1 * p1 - dot(d, d) + sphere.radius * sphere.radius;
//	if (p2sqr < 0)
//		return;
//	float p2 = sqrt(p2sqr);
//	float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;
//	if (t > 0 && t < bestHit.distance)
//	{
//		bestHit.distance = t;
//		bestHit.position = ray.origin + t * ray.direction;
//		bestHit.normal = normalize(bestHit.position - sphere.position);
//	}
//}



inline void IntersectTriangle(Ray ray, thread RayHit &bestHit, BVHMeshTriangle tri, uint primitiveID)
{
	float3 v0v1 = tri.v1 - tri.v0;
	float3 v0v2 = tri.v2 - tri.v0;
	float3 pvec = cross(ray.direction, v0v2);
	float det = dot(v0v1, pvec);
#ifdef RAY_BACKFACE_CULLING 
	// if the determinant is negative the triangle is backfacing
	// if the determinant is close to 0, the ray misses the triangle
	if (det < EPSILON)
		return;
#else 
	// ray and triangle are parallel if det is close to 0
	if (abs(det) < EPSILON)
		return;
#endif 
	float invDet = 1 / det;

	float3 tvec = ray.origin - tri.v0;
	float u = dot(tvec, pvec) * invDet;
	if (u < 0 || u > 1)
		return;

	float3 qvec = cross(tvec, v0v1);
	float v = dot(ray.direction, qvec) * invDet;
	if (v < 0 || u + v > 1)
		return;

	float t = dot(v0v2, qvec) * invDet;

	if (t > 0 && t < bestHit.distance)
	{
		bestHit.distance = t;
		bestHit.position = ray.origin + t * ray.direction;
		bestHit.primitiveID = primitiveID;
		bestHit.bary = float2(u, v);

		//float w = 1 - u - v;
		//bestHit.normal = normalize(tri.n0 * w + tri.n1 * u + tri.n2 * v);
		//bestHit.texCoords = tri.t0 * w + tri.t1 * u + tri.t2 * v;
		//
		//bestHit.materialIndex = tri.materialIndex;
	}
}

inline bool IntersectTriangleANY(Ray ray, float maxDistance, BVHMeshTriangle tri)
{
	float3 v0v1 = tri.v1 - tri.v0;
	float3 v0v2 = tri.v2 - tri.v0;
	float3 pvec = cross(ray.direction, v0v2);
	float det = dot(v0v1, pvec);
#ifdef RAY_BACKFACE_CULLING 
	// if the determinant is negative the triangle is backfacing
	// if the determinant is close to 0, the ray misses the triangle
	if (det < EPSILON)
		return false;
#else 
	// ray and triangle are parallel if det is close to 0
	if (abs(det) < EPSILON)
		return false;
#endif 
	float invDet = 1 / det;

	float3 tvec = ray.origin - tri.v0;
	float u = dot(tvec, pvec) * invDet;
	if (u < 0 || u > 1)
		return false;

	float3 qvec = cross(tvec, v0v1);
	float v = dot(ray.direction, qvec) * invDet;
	if (v < 0 || u + v > 1)
		return false;

	float t = dot(v0v2, qvec) * invDet;

	if (t > 0 && t < maxDistance)
	{
		return true;
	}

	return false;
}


inline bool IntersectBox(Ray ray, BVHAABB box)
{
	if (ray.origin.x >= box.min.x && ray.origin.x <= box.max.x &&
		ray.origin.y >= box.min.y && ray.origin.y <= box.max.y &&
		ray.origin.z >= box.min.z && ray.origin.z <= box.max.z)
		return true;

	float t[6];
	t[0] = (box.min.x - ray.origin.x) * ray.direction_inverse.x;
	t[1] = (box.max.x - ray.origin.x) * ray.direction_inverse.x;
	t[2] = (box.min.y - ray.origin.y) * ray.direction_inverse.y;
	t[3] = (box.max.y - ray.origin.y) * ray.direction_inverse.y;
	t[4] = (box.min.z - ray.origin.z) * ray.direction_inverse.z;
	t[5] = (box.max.z - ray.origin.z) * ray.direction_inverse.z;
	const float tmin  = max(max(min(t[0], t[1]), min(t[2], t[3])), min(t[4], t[5])); // close intersection point's distance on ray
	const float tmax  = min(min(max(t[0], t[1]), max(t[2], t[3])), max(t[4], t[5])); // far intersection point's distance on ray

	return (tmax < 0 || tmin > tmax) ? false : true;
}

inline float3x3 GetTangentSpace(float3 normal)
{
	// Choose a helper vector for the cross product
	float3 helper = abs(normal.x) > 0.99f ? float3(0, 0, 1) : float3(1, 0, 0);

	// Generate vectors
	float3 tangent = normalize(cross(normal, helper));
	float3 binormal = normalize(cross(normal, tangent));
	return float3x3(tangent, binormal, normal);
}

inline float3 SampleHemisphere(float3 normal, thread float &seed, float2 pixel)
{
	// Sample the hemisphere, where alpha determines the kind of the sampling
	float cosTheta = rand(seed, pixel);
	float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
	float phi = 2 * PI * rand(seed, pixel);
	float3 tangentSpaceDir = float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);

	// Transform direction to world space
	return mul(tangentSpaceDir, GetTangentSpace(normal));
}

#endif // _TRACEDRENDERING_HF_
