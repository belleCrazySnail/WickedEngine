#ifndef _GRAPHICSDEVICE_METAL_H_
#define _GRAPHICSDEVICE_METAL_H_

#include "CommonInclude.h"
#include "wiGraphicsDevice.h"
#include "wiWindowRegistration.h"

#include "wiGraphicsDevice_SharedInternals.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include <vector>
#include <unordered_map>

namespace wiGraphicsTypes
{
	struct FrameResources;
	struct DescriptorTableFrameAllocator;

	class GraphicsDevice_Metal : public GraphicsDevice
	{
		friend struct DescriptorTableFrameAllocator;
	private:

        id <MTLDevice> _device;
        id <MTLCommandQueue> _queue;
        id <MTLCommandBuffer> _commandBuffer;
        id <MTLLibrary> _library;
		dispatch_semaphore_t _inFlightSemaphore;
        MTKView *_view;
        id <MTLComputeCommandEncoder> _computeEnc;
 
		struct FrameResources
		{
            struct DrawInfo
            {
                id <MTLRenderCommandEncoder> commandLists;
                MTLPrimitiveType primType;
                id <MTLBuffer> indexBuffer;
                MTLIndexType indexType;
                NSUInteger indexOffset;
            };
            DrawInfo drawInfo[GRAPHICSTHREAD_COUNT];
            
			struct ResourceFrameAllocator
			{
                GPUBuffer                buffer;
				uint8_t*				dataBegin;
				uint8_t*				dataCur;
				uint8_t*				dataEnd;

				ResourceFrameAllocator(id <MTLDevice> device, size_t size);
				~ResourceFrameAllocator();

				uint8_t* allocate(size_t dataSize, size_t alignment);
				void clear();
				uint64_t calculateOffset(uint8_t* address);
			};
			ResourceFrameAllocator* resourceBuffer[GRAPHICSTHREAD_COUNT];
		};
		FrameResources frames[BACKBUFFER_COUNT];
		FrameResources& GetFrameResources() { return frames[GetFrameCount() % BACKBUFFER_COUNT]; }
		id <MTLRenderCommandEncoder> GetDirectCommandList(GRAPHICSTHREAD threadID);

	public:
		GraphicsDevice_Metal(wiWindowRegistration::window_type window, bool fullscreen = false, bool debuglayer = false);
		virtual ~GraphicsDevice_Metal();

		HRESULT CreateBuffer(const GPUBufferDesc *pDesc, const SubresourceData* pInitialData, GPUBuffer *pBuffer) override;
		HRESULT CreateTexture2D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture2D *pTexture2D) override;
		HRESULT CreateSamplerState(const SamplerDesc *pSamplerDesc, Sampler *pSamplerState) override;
		HRESULT CreateQuery(const GPUQueryDesc *pDesc, GPUQuery *pQuery) override;
		HRESULT CreateGraphicsPSO(const GraphicsPSODesc* pDesc, GraphicsPSO* pso) override;
		HRESULT CreateComputePSO(const ComputePSODesc* pDesc, ComputePSO* pso) override;
        HRESULT CreateRenderPass(const RenderPassDesc *pDesc, RenderPass *pRenderPass) override;

		void DestroyResource(GPUResource* pResource) override;
		void DestroyBuffer(GPUBuffer *pBuffer) override;
		void DestroyTexture1D(Texture1D *pTexture1D) override;
		void DestroyTexture2D(Texture2D *pTexture2D) override;
		void DestroyTexture3D(Texture3D *pTexture3D) override;
		void DestroyInputLayout(VertexLayout *pInputLayout) override;
		void DestroyVertexShader(VertexShader *pVertexShader) override;
		void DestroyPixelShader(PixelShader *pPixelShader) override;
		void DestroyGeometryShader(GeometryShader *pGeometryShader) override;
		void DestroyHullShader(HullShader *pHullShader) override;
		void DestroyDomainShader(DomainShader *pDomainShader) override;
		void DestroyComputeShader(ComputeShader *pComputeShader) override;
		void DestroyBlendState(BlendState *pBlendState) override;
		void DestroyDepthStencilState(DepthStencilState *pDepthStencilState) override;
		void DestroyRasterizerState(RasterizerState *pRasterizerState) override;
		void DestroySamplerState(Sampler *pSamplerState) override;
		void DestroyQuery(GPUQuery *pQuery) override;
		void DestroyGraphicsPSO(GraphicsPSO* pso) override;
		void DestroyComputePSO(ComputePSO* pso) override;

		void SetName(GPUResource* pResource, const std::string& name) override;

        void BeginRenderPass(RenderPass *pRenderPass, GRAPHICSTHREAD threadID) override;
        void EndRenderPass(GRAPHICSTHREAD threadID) override;
		void PresentBegin() override;
		void PresentEnd() override;

		void CreateCommandLists() override;
		void ExecuteCommandLists() override;
		void FinishCommandList(GRAPHICSTHREAD thread) override;

		void WaitForGPU() override;

		void SetResolution(int width, int height) override;

		///////////////Thread-sensitive////////////////////////

		void BindScissorRects(UINT numRects, const Rect* rects, GRAPHICSTHREAD threadID) override;
		void BindViewports(UINT NumViewports, const ViewPort *pViewports, GRAPHICSTHREAD threadID) override;
		void BindRenderTargets(UINT NumViews, Texture2D* const *ppRenderTargets, Texture2D* depthStencilTexture, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void ClearRenderTarget(Texture* pTexture, const FLOAT ColorRGBA[4], GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void ClearDepthStencil(Texture2D* pTexture, UINT ClearFlags, FLOAT Depth, UINT8 Stencil, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void BindResource(SHADERSTAGE stage, GPUResource* resource, int slot, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void BindResources(SHADERSTAGE stage, GPUResource *const* resources, int slot, int count, GRAPHICSTHREAD threadID) override;
		void BindUAV(SHADERSTAGE stage, GPUResource* resource, int slot, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void BindUAVs(SHADERSTAGE stage, GPUResource *const* resources, int slot, int count, GRAPHICSTHREAD threadID) override;
		void UnbindResources(int slot, int num, GRAPHICSTHREAD threadID) override;
		void UnbindUAVs(int slot, int num, GRAPHICSTHREAD threadID) override;
		void BindSampler(SHADERSTAGE stage, Sampler* sampler, int slot, GRAPHICSTHREAD threadID) override;
		void BindConstantBuffer(SHADERSTAGE stage, GPUBuffer* buffer, int slot, GRAPHICSTHREAD threadID) override;
		void BindVertexBuffers(GPUBuffer* const *vertexBuffers, int slot, int count, const UINT* strides, const UINT* offsets, GRAPHICSTHREAD threadID) override;
		void BindIndexBuffer(GPUBuffer* indexBuffer, const INDEXBUFFER_FORMAT format, UINT offset, GRAPHICSTHREAD threadID) override;
		void BindStencilRef(UINT value, GRAPHICSTHREAD threadID) override;
		void BindBlendFactor(XMFLOAT4 value, GRAPHICSTHREAD threadID) override;
		void BindGraphicsPSO(GraphicsPSO* pso, GRAPHICSTHREAD threadID) override;
		void BindComputePSO(ComputePSO* pso, GRAPHICSTHREAD threadID) override;
		void Draw(int vertexCount, UINT startVertexLocation, GRAPHICSTHREAD threadID) override;
		void DrawIndexed(int indexCount, UINT startIndexLocation, UINT baseVertexLocation, GRAPHICSTHREAD threadID) override;
		void DrawInstanced(int vertexCount, int instanceCount, UINT startVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID) override;
		void DrawIndexedInstanced(int indexCount, int instanceCount, UINT startIndexLocation, UINT baseVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID) override;
		void DrawInstancedIndirect(GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID) override;
		void DrawIndexedInstancedIndirect(GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID) override;
		void Dispatch(UINT threadGroupCountX, UINT threadGroupCountY, UINT threadGroupCountZ, GRAPHICSTHREAD threadID) override;
		void DispatchIndirect(GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID) override;
		void CopyTexture2D(Texture2D* pDst, Texture2D* pSrc, GRAPHICSTHREAD threadID) override;
		void CopyTexture2D_Region(Texture2D* pDst, UINT dstMip, UINT dstX, UINT dstY, Texture2D* pSrc, UINT srcMip, GRAPHICSTHREAD threadID) override;
		void MSAAResolve(Texture2D* pDst, Texture2D* pSrc, GRAPHICSTHREAD threadID) override;
		void UpdateBuffer(GPUBuffer* buffer, const void* data, GRAPHICSTHREAD threadID, int dataSize = -1) override;
		bool DownloadResource(GPUResource* resourceToDownload, GPUResource* resourceDest, void* dataDest, GRAPHICSTHREAD threadID) override;
		void QueryBegin(GPUQuery *query, GRAPHICSTHREAD threadID) override;
		void QueryEnd(GPUQuery *query, GRAPHICSTHREAD threadID) override;
		bool QueryRead(GPUQuery *query, GRAPHICSTHREAD threadID) override;
		void UAVBarrier(GPUResource *const* uavs, UINT NumBarriers, GRAPHICSTHREAD threadID) override;
		void TransitionBarrier(GPUResource *const* resources, UINT NumBarriers, RESOURCE_STATES stateBefore, RESOURCE_STATES stateAfter, GRAPHICSTHREAD threadID) override;

        GPUAllocation AllocateGPU(size_t dataSize, GRAPHICSTHREAD threadID) override;
        
		void EventBegin(const std::string& name, GRAPHICSTHREAD threadID) override;
		void EventEnd(GRAPHICSTHREAD threadID) override;
		void SetMarker(const std::string& name, GRAPHICSTHREAD threadID) override;

	};
}

#endif // _GRAPHICSDEVICE_METAL_H_
