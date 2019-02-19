#include "wiGPUBVH.h"
#include "wiSceneSystem.h"
#include "wiRenderer.h"
#include "ShaderInterop_BVH.h"
#include "wiProfiler.h"
#include "wiResourceManager.h"
#include "wiGPUSortLib.h"

#include <string>
#include <vector>
#include <set>

using namespace std;
using namespace wiGraphicsTypes;
using namespace wiSceneSystem;
using namespace wiECS;

enum CSTYPES_BVH
{
	CSTYPE_BVH_RESET,
	CSTYPE_BVH_CLASSIFICATION,
	CSTYPE_BVH_KICKJOBS,
	CSTYPE_BVH_CLUSTERPROCESSOR,
	CSTYPE_BVH_HIERARCHY,
	CSTYPE_BVH_PROPAGATEAABB,
	CSTYPE_BVH_COUNT
};
static ComputeShader* computeShaders[CSTYPE_BVH_COUNT] = {};
static ComputePSO* CPSO[CSTYPE_BVH_COUNT] = {};

static GPUBuffer* constantBuffer = nullptr;

wiGPUBVH::wiGPUBVH()
{

}
wiGPUBVH::~wiGPUBVH()
{
}

//#define BVH_VALIDATE // slow but great for debug!
void wiGPUBVH::Build(const Scene& scene, GRAPHICSTHREAD threadID)
{
	GraphicsDevice* device = wiRenderer::GetDevice();

	if (constantBuffer == nullptr)
	{
		GPUBufferDesc bd;
		bd.Usage = USAGE_DYNAMIC;
		bd.CPUAccessFlags = CPU_ACCESS_WRITE;
		bd.BindFlags = BIND_CONSTANT_BUFFER;
		bd.ByteWidth = sizeof(BVHCB);

		constantBuffer = new GPUBuffer;
		device->CreateBuffer(&bd, nullptr, constantBuffer);
		device->SetName(constantBuffer, "BVHGeneratorCB");
	}

	// Pre-gather scene properties:
	uint totalTriangles = 0;
	for (size_t i = 0; i < scene.objects.GetCount(); ++i)
	{
		const ObjectComponent& object = scene.objects[i];

		if (object.meshID != INVALID_ENTITY)
		{
			const MeshComponent& mesh = *scene.meshes.GetComponent(object.meshID);

			totalTriangles += (uint)mesh.indices.size() / 3;
		}
	}

	if (totalTriangles > maxTriangleCount)
	{
		maxTriangleCount = totalTriangles;
		maxClusterCount = maxTriangleCount; // todo: cluster / triangle capacity

		GPUBufferDesc desc;
		HRESULT hr;

		bvhNodeBuffer.reset(new GPUBuffer);
		bvhAABBBuffer.reset(new GPUBuffer);
		bvhFlagBuffer.reset(new GPUBuffer);
		triangleBuffer.reset(new GPUBuffer);
		clusterCounterBuffer.reset(new GPUBuffer);
		clusterIndexBuffer.reset(new GPUBuffer);
		clusterMortonBuffer.reset(new GPUBuffer);
		clusterSortedMortonBuffer.reset(new GPUBuffer);
		clusterOffsetBuffer.reset(new GPUBuffer);
		clusterAABBBuffer.reset(new GPUBuffer);
		clusterConeBuffer.reset(new GPUBuffer);

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(BVHNode);
		desc.ByteWidth = desc.StructureByteStride * maxClusterCount * 2;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, bvhNodeBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(bvhNodeBuffer.get(), "BVHNodeBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(BVHAABB);
		desc.ByteWidth = desc.StructureByteStride * maxClusterCount * 2;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, bvhAABBBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(bvhAABBBuffer.get(), "BVHAABBBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(uint);
		desc.ByteWidth = desc.StructureByteStride * (maxClusterCount - 1); // only for internal nodes
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, bvhFlagBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(bvhFlagBuffer.get(), "BVHFlagBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(BVHMeshTriangle);
		desc.ByteWidth = desc.StructureByteStride * maxTriangleCount;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, triangleBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(triangleBuffer.get(), "BVHTriangleBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(uint);
		desc.ByteWidth = desc.StructureByteStride;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, clusterCounterBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(clusterCounterBuffer.get(), "BVHClusterCounterBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(uint);
		desc.ByteWidth = desc.StructureByteStride * maxClusterCount;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, clusterIndexBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(clusterIndexBuffer.get(), "BVHClusterIndexBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(uint);
		desc.ByteWidth = desc.StructureByteStride * maxClusterCount;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, clusterMortonBuffer.get());
		hr = device->CreateBuffer(&desc, nullptr, clusterSortedMortonBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(clusterMortonBuffer.get(), "BVHClusterMortonBuffer");
		device->SetName(clusterSortedMortonBuffer.get(), "BVHSortedClusterMortonBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(uint2);
		desc.ByteWidth = desc.StructureByteStride * maxClusterCount;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, clusterOffsetBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(clusterOffsetBuffer.get(), "BVHClusterOffsetBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(BVHAABB);
		desc.ByteWidth = desc.StructureByteStride * maxClusterCount;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, clusterAABBBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(clusterAABBBuffer.get(), "BVHClusterAABBBuffer");

		desc.BindFlags = BIND_SHADER_RESOURCE | BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(ClusterCone);
		desc.ByteWidth = desc.StructureByteStride * maxClusterCount;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_BUFFER_STRUCTURED;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, clusterConeBuffer.get());
		assert(SUCCEEDED(hr));
		device->SetName(clusterConeBuffer.get(), "BVHClusterConeBuffer");
	}

	static GPUBuffer* indirectBuffer = nullptr; // GPU job kicks
	if (indirectBuffer == nullptr)
	{
		GPUBufferDesc desc;
		HRESULT hr;

		SAFE_DELETE(indirectBuffer);
		indirectBuffer = new GPUBuffer;

		desc.BindFlags = BIND_UNORDERED_ACCESS;
		desc.StructureByteStride = sizeof(IndirectDispatchArgs) * 2;
		desc.ByteWidth = desc.StructureByteStride;
		desc.CPUAccessFlags = 0;
		desc.Format = FORMAT_UNKNOWN;
		desc.MiscFlags = RESOURCE_MISC_DRAWINDIRECT_ARGS | RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
		desc.Usage = USAGE_DEFAULT;
		hr = device->CreateBuffer(&desc, nullptr, indirectBuffer);
		assert(SUCCEEDED(hr));
	}


	wiProfiler::BeginRange("BVH Rebuild", wiProfiler::DOMAIN_GPU, threadID);

	device->EventBegin("BVH - Reset", threadID);
	{
		device->BindComputePSO(CPSO[CSTYPE_BVH_RESET], threadID);

		GPUResource* uavs[] = {
			clusterCounterBuffer.get(),
			bvhNodeBuffer.get(),
			bvhAABBBuffer.get(),
		};
		device->BindUAVs(CS, uavs, 0, ARRAYSIZE(uavs), threadID);

		device->Dispatch(1, 1, 1, threadID);
	}
	device->EventEnd(threadID);


	uint32_t triangleCount = 0;
	uint32_t materialCount = 0;

	device->EventBegin("BVH - Classification", threadID);
	{
		device->BindComputePSO(CPSO[CSTYPE_BVH_CLASSIFICATION], threadID);
		GPUResource* uavs[] = {
			triangleBuffer.get(),
			clusterCounterBuffer.get(),
			clusterIndexBuffer.get(),
			clusterMortonBuffer.get(),
			clusterOffsetBuffer.get(),
			clusterAABBBuffer.get(),
		};
		device->BindUAVs(CS, uavs, 0, ARRAYSIZE(uavs), threadID);

		for (size_t i = 0; i < scene.objects.GetCount(); ++i)
		{
			const ObjectComponent& object = scene.objects[i];

			if (object.meshID != INVALID_ENTITY)
			{
				const MeshComponent& mesh = *scene.meshes.GetComponent(object.meshID);

				BVHCB cb;
				cb.xTraceBVHWorld = object.transform_index >= 0 ? scene.transforms[object.transform_index].world : IDENTITYMATRIX;
				cb.xTraceBVHMaterialOffset = materialCount;
				cb.xTraceBVHMeshTriangleOffset = triangleCount;
				cb.xTraceBVHMeshTriangleCount = (uint)mesh.indices.size() / 3;
				cb.xTraceBVHMeshVertexPOSStride = sizeof(MeshComponent::Vertex_POS);

				device->UpdateBuffer(constantBuffer, &cb, threadID);

				triangleCount += cb.xTraceBVHMeshTriangleCount;

				device->BindConstantBuffer(CS, constantBuffer, CB_GETBINDSLOT(BVHCB), threadID);

				GPUResource* res[] = {
					mesh.indexBuffer.get(),
					mesh.vertexBuffer_POS.get(),
					mesh.vertexBuffer_TEX.get(),
				};
				device->BindResources(CS, res, TEXSLOT_ONDEMAND0, ARRAYSIZE(res), threadID);

				device->Dispatch((UINT)ceilf((float)cb.xTraceBVHMeshTriangleCount / (float)BVH_CLASSIFICATION_GROUPSIZE), 1, 1, threadID);

				for (auto& subset : mesh.subsets)
				{
					materialCount++;
				}
			}
		}

		device->UAVBarrier(uavs, ARRAYSIZE(uavs), threadID);
		device->UnbindUAVs(0, ARRAYSIZE(uavs), threadID);
	}
	device->EventEnd(threadID);


	device->EventBegin("BVH - Sort Cluster Mortons", threadID);
	wiGPUSortLib::Sort(maxClusterCount, clusterMortonBuffer.get(), clusterCounterBuffer.get(), 0, clusterIndexBuffer.get(), threadID);
	device->EventEnd(threadID);

	device->EventBegin("BVH - Kick Jobs", threadID);
	{
		device->BindComputePSO(CPSO[CSTYPE_BVH_KICKJOBS], threadID);
		GPUResource* uavs[] = {
			indirectBuffer,
		};
		device->BindUAVs(CS, uavs, 0, ARRAYSIZE(uavs), threadID);

		GPUResource* res[] = {
			clusterCounterBuffer.get(),
		};
		device->BindResources(CS, res, TEXSLOT_ONDEMAND0, ARRAYSIZE(res), threadID);

		device->Dispatch(1, 1, 1, threadID);

		device->UAVBarrier(uavs, ARRAYSIZE(uavs), threadID);
		device->UnbindUAVs(0, ARRAYSIZE(uavs), threadID);
	}
	device->EventEnd(threadID);

	device->EventBegin("BVH - Cluster Processor", threadID);
	{
		device->BindComputePSO(CPSO[CSTYPE_BVH_CLUSTERPROCESSOR], threadID);
		GPUResource* uavs[] = {
			clusterSortedMortonBuffer.get(),
			clusterConeBuffer.get(),
		};
		device->BindUAVs(CS, uavs, 0, ARRAYSIZE(uavs), threadID);

		GPUResource* res[] = {
			clusterCounterBuffer.get(),
			clusterIndexBuffer.get(),
			clusterMortonBuffer.get(),
			clusterOffsetBuffer.get(),
			clusterAABBBuffer.get(),
			triangleBuffer.get(),
		};
		device->BindResources(CS, res, TEXSLOT_ONDEMAND0, ARRAYSIZE(res), threadID);

		device->DispatchIndirect(indirectBuffer, ARGUMENTBUFFER_OFFSET_CLUSTERPROCESSOR, threadID);


		device->UAVBarrier(uavs, ARRAYSIZE(uavs), threadID);
		device->UnbindUAVs(0, ARRAYSIZE(uavs), threadID);
	}
	device->EventEnd(threadID);

	device->EventBegin("BVH - Build Hierarchy", threadID);
	{
		device->BindComputePSO(CPSO[CSTYPE_BVH_HIERARCHY], threadID);
		GPUResource* uavs[] = {
			bvhNodeBuffer.get(),
			bvhFlagBuffer.get(),
		};
		device->BindUAVs(CS, uavs, 0, ARRAYSIZE(uavs), threadID);

		GPUResource* res[] = {
			clusterCounterBuffer.get(),
			clusterSortedMortonBuffer.get(),
		};
		device->BindResources(CS, res, TEXSLOT_ONDEMAND0, ARRAYSIZE(res), threadID);

		device->DispatchIndirect(indirectBuffer, ARGUMENTBUFFER_OFFSET_HIERARCHY, threadID);


		device->UAVBarrier(uavs, ARRAYSIZE(uavs), threadID);
		device->UnbindUAVs(0, ARRAYSIZE(uavs), threadID);
	}
	device->EventEnd(threadID);

	device->EventBegin("BVH - Propagate AABB", threadID);
	{
		device->BindComputePSO(CPSO[CSTYPE_BVH_PROPAGATEAABB], threadID);
		GPUResource* uavs[] = {
			bvhAABBBuffer.get(),
			bvhFlagBuffer.get(),
		};
		device->BindUAVs(CS, uavs, 0, ARRAYSIZE(uavs), threadID);

		GPUResource* res[] = {
			clusterCounterBuffer.get(),
			clusterIndexBuffer.get(),
			clusterAABBBuffer.get(),
			bvhNodeBuffer.get(),
		};
		device->BindResources(CS, res, TEXSLOT_ONDEMAND0, ARRAYSIZE(res), threadID);

		device->DispatchIndirect(indirectBuffer, ARGUMENTBUFFER_OFFSET_CLUSTERPROCESSOR, threadID);


		device->UAVBarrier(uavs, ARRAYSIZE(uavs), threadID);
		device->UnbindUAVs(0, ARRAYSIZE(uavs), threadID);
	}
	device->EventEnd(threadID);

#ifdef BVH_VALIDATE

	GPUBufferDesc readback_desc;
	bool download_success;

	// Download cluster count:
	readback_desc = clusterCounterBuffer->GetDesc();
	readback_desc.Usage = USAGE_STAGING;
	readback_desc.CPUAccessFlags = CPU_ACCESS_READ;
	readback_desc.BindFlags = 0;
	readback_desc.MiscFlags = 0;
	GPUBuffer readback_clusterCounterBuffer;
	device->CreateBuffer(&readback_desc, nullptr, &readback_clusterCounterBuffer);
	uint clusterCount;
	download_success = device->DownloadResource(clusterCounterBuffer.get(), &readback_clusterCounterBuffer, &clusterCount, threadID);
	assert(download_success);

	if (clusterCount > 0)
	{
		const uint leafNodeOffset = clusterCount - 1;

		// Validate node buffer:
		readback_desc = bvhNodeBuffer->GetDesc();
		readback_desc.Usage = USAGE_STAGING;
		readback_desc.CPUAccessFlags = CPU_ACCESS_READ;
		readback_desc.BindFlags = 0;
		readback_desc.MiscFlags = 0;
		GPUBuffer readback_nodeBuffer;
		device->CreateBuffer(&readback_desc, nullptr, &readback_nodeBuffer);
		vector<BVHNode> nodes(readback_desc.ByteWidth / sizeof(BVHNode));
		download_success = device->DownloadResource(bvhNodeBuffer.get(), &readback_nodeBuffer, nodes.data(), threadID);
		assert(download_success);
		set<uint> visitedLeafs;
		vector<uint> stack;
		stack.push_back(0);
		while (!stack.empty())
		{
			uint nodeIndex = stack.back();
			stack.pop_back();

			if (nodeIndex >= leafNodeOffset)
			{
				// leaf node
				assert(visitedLeafs.count(nodeIndex) == 0); // leaf node was already visited, this must not happen!
				visitedLeafs.insert(nodeIndex);
			}
			else
			{
				// internal node
				BVHNode& node = nodes[nodeIndex];
				stack.push_back(node.LeftChildIndex);
				stack.push_back(node.RightChildIndex);
			}
		}
		for (uint i = 0; i < clusterCount; ++i)
		{
			uint nodeIndex = leafNodeOffset + i;
			BVHNode& leaf = nodes[nodeIndex];
			assert(leaf.LeftChildIndex == 0 && leaf.RightChildIndex == 0); // a leaf must have no children
			assert(visitedLeafs.count(nodeIndex) > 0); // every leaf node must have been visited in the traversal above
		}

		// Validate flag buffer:
		readback_desc = bvhFlagBuffer->GetDesc();
		readback_desc.Usage = USAGE_STAGING;
		readback_desc.CPUAccessFlags = CPU_ACCESS_READ;
		readback_desc.BindFlags = 0;
		readback_desc.MiscFlags = 0;
		GPUBuffer readback_flagBuffer;
		device->CreateBuffer(&readback_desc, nullptr, &readback_flagBuffer);
		vector<uint> flags(readback_desc.ByteWidth / sizeof(uint));
		download_success = device->DownloadResource(bvhFlagBuffer.get(), &readback_flagBuffer, flags.data(), threadID);
		assert(download_success);
		for (auto& x : flags)
		{
			if (x > 2)
			{
				assert(0); // flagbuffer anomaly detected: node can't have more than two children (AABB propagation step)!
				break;
			}
		}
	}

#endif // BVH_VALIDATE


	wiProfiler::EndRange(threadID); // BVH rebuild
}
void wiGPUBVH::Bind(SHADERSTAGE stage, GRAPHICSTHREAD threadID)
{
	GraphicsDevice* device = wiRenderer::GetDevice();

	GPUResource* res[] = {
		triangleBuffer.get(),
		clusterCounterBuffer.get(),
		clusterIndexBuffer.get(),
		clusterOffsetBuffer.get(),
		clusterConeBuffer.get(),
		bvhNodeBuffer.get(),
		bvhAABBBuffer.get(),
	};
	device->BindResources(stage, res, TEXSLOT_ONDEMAND1, ARRAYSIZE(res), threadID);
}


void wiGPUBVH::LoadShaders()
{
	GraphicsDevice* device = wiRenderer::GetDevice();

	computeShaders[CSTYPE_BVH_RESET] = static_cast<ComputeShader*>(wiResourceManager::GetShaderManager().add("bvh_resetCS", wiResourceManager::COMPUTESHADER));
	computeShaders[CSTYPE_BVH_CLASSIFICATION] = static_cast<ComputeShader*>(wiResourceManager::GetShaderManager().add("bvh_classificationCS", wiResourceManager::COMPUTESHADER));
	computeShaders[CSTYPE_BVH_KICKJOBS] = static_cast<ComputeShader*>(wiResourceManager::GetShaderManager().add("bvh_kickjobsCS", wiResourceManager::COMPUTESHADER));
	computeShaders[CSTYPE_BVH_CLUSTERPROCESSOR] = static_cast<ComputeShader*>(wiResourceManager::GetShaderManager().add("bvh_clusterprocessorCS", wiResourceManager::COMPUTESHADER));
	computeShaders[CSTYPE_BVH_HIERARCHY] = static_cast<ComputeShader*>(wiResourceManager::GetShaderManager().add("bvh_hierarchyCS", wiResourceManager::COMPUTESHADER));
	computeShaders[CSTYPE_BVH_PROPAGATEAABB] = static_cast<ComputeShader*>(wiResourceManager::GetShaderManager().add("bvh_propagateaabbCS", wiResourceManager::COMPUTESHADER));


	for (int i = 0; i < CSTYPE_BVH_COUNT; ++i)
	{
		ComputePSODesc desc;
		desc.cs = computeShaders[i];
		RECREATE(CPSO[i]);
		device->CreateComputePSO(&desc, CPSO[i]);
	}
}
