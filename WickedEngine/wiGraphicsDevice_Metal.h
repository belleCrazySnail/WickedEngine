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
            Texture2D backBuffer;
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
        HRESULT CreateTexture1D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture1D *pTexture1D) override;
		HRESULT CreateTexture2D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture2D *pTexture2D) override;
        HRESULT CreateTexture3D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture3D *pTexture3D) override;
        HRESULT CreateInputLayout(const VertexLayoutDesc *pInputElementDescs, UINT NumElements, const ShaderByteCode* shaderCode, VertexLayout *pInputLayout) override;
        HRESULT CreateVertexShader(const ShaderByteCode *pCode, VertexShader *pVertexShader) override;
        HRESULT CreatePixelShader(const ShaderByteCode *pCode, PixelShader *pPixelShader) override;
        HRESULT CreateGeometryShader(const ShaderByteCode *pCode, GeometryShader *pGeometryShader) override;
        HRESULT CreateHullShader(const ShaderByteCode *pCode, HullShader *pHullShader) override;
        HRESULT CreateDomainShader(const ShaderByteCode *pCode, DomainShader *pDomainShader) override;
        HRESULT CreateComputeShader(const ShaderByteCode *pCode, ComputeShader *pComputeShader) override;
        HRESULT CreateBlendState(const BlendStateDesc *pBlendStateDesc, BlendState *pBlendState) override;
        HRESULT CreateDepthStencilState(const DepthStencilStateDesc *pDepthStencilStateDesc, DepthStencilState *pDepthStencilState) override;
        HRESULT CreateRasterizerState(const RasterizerStateDesc *pRasterizerStateDesc, RasterizerState *pRasterizerState) override;
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
        void NextSubPass(GRAPHICSTHREAD threadID) override;
        void EndRenderPass(GRAPHICSTHREAD threadID) override;
        
		void PresentBegin() override;
		void PresentEnd() override;

		void CreateCommandLists() override;
		void ExecuteCommandLists() override;
		void FinishCommandList(GRAPHICSTHREAD thread) override;

		void WaitForGPU() override;

		void SetResolution(int width, int height) override;
        
        const Texture2D &GetBackBuffer() override;

		///////////////Thread-sensitive////////////////////////

		void BindScissorRects(UINT numRects, const Rect* rects, GRAPHICSTHREAD threadID) override;
		void BindViewports(UINT NumViewports, const ViewPort *pViewports, GRAPHICSTHREAD threadID) override;
		void BindRenderTargets(UINT NumViews, const Texture2D* const *ppRenderTargets, const Texture2D* depthStencilTexture, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void ClearRenderTarget(const Texture* pTexture, const FLOAT ColorRGBA[4], GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void ClearDepthStencil(const Texture2D* pTexture, UINT ClearFlags, FLOAT Depth, UINT8 Stencil, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void BindResource(SHADERSTAGE stage, const GPUResource* resource, UINT slot, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void BindResources(SHADERSTAGE stage, const GPUResource *const* resources, UINT slot, UINT count, GRAPHICSTHREAD threadID) override;
		void BindUAV(SHADERSTAGE stage, const GPUResource* resource, UINT slot, GRAPHICSTHREAD threadID, int arrayIndex = -1) override;
		void BindUAVs(SHADERSTAGE stage, const GPUResource *const* resources, UINT slot, UINT count, GRAPHICSTHREAD threadID) override;
		void UnbindResources(UINT slot, UINT num, GRAPHICSTHREAD threadID) override;
		void UnbindUAVs(UINT slot, UINT num, GRAPHICSTHREAD threadID) override;
		void BindSampler(SHADERSTAGE stage, const Sampler* sampler, UINT slot, GRAPHICSTHREAD threadID) override;
		void BindConstantBuffer(SHADERSTAGE stage, const GPUBuffer* buffer, UINT slot, GRAPHICSTHREAD threadID) override;
		void BindVertexBuffers(const GPUBuffer* const *vertexBuffers, UINT slot, UINT count, const UINT* strides, const UINT* offsets, GRAPHICSTHREAD threadID) override;
		void BindIndexBuffer(const GPUBuffer* indexBuffer, const INDEXBUFFER_FORMAT format, UINT offset, GRAPHICSTHREAD threadID) override;
		void BindStencilRef(UINT value, GRAPHICSTHREAD threadID) override;
		void BindBlendFactor(float r, float g, float b, float a, GRAPHICSTHREAD threadID) override;
		void BindGraphicsPSO(const GraphicsPSO* pso, GRAPHICSTHREAD threadID) override;
		void BindComputePSO(const ComputePSO* pso, GRAPHICSTHREAD threadID) override;
		void Draw(UINT vertexCount, UINT startVertexLocation, GRAPHICSTHREAD threadID) override;
		void DrawIndexed(UINT indexCount, UINT startIndexLocation, UINT baseVertexLocation, GRAPHICSTHREAD threadID) override;
		void DrawInstanced(UINT vertexCount, UINT instanceCount, UINT startVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID) override;
		void DrawIndexedInstanced(UINT indexCount, UINT instanceCount, UINT startIndexLocation, UINT baseVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID) override;
		void DrawInstancedIndirect(const GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID) override;
		void DrawIndexedInstancedIndirect(const GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID) override;
		void Dispatch(UINT threadGroupCountX, UINT threadGroupCountY, UINT threadGroupCountZ, GRAPHICSTHREAD threadID) override;
		void DispatchIndirect(const GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID) override;
		void CopyTexture2D(const Texture2D* pDst, const Texture2D* pSrc, GRAPHICSTHREAD threadID) override;
		void CopyTexture2D_Region(const Texture2D* pDst, UINT dstMip, UINT dstX, UINT dstY, const Texture2D* pSrc, UINT srcMip, GRAPHICSTHREAD threadID) override;
		void MSAAResolve(const Texture2D* pDst, const Texture2D* pSrc, GRAPHICSTHREAD threadID) override;
		void UpdateBuffer(const GPUBuffer* buffer, const void* data, GRAPHICSTHREAD threadID, int dataSize = -1) override;
		bool DownloadResource(const GPUResource* resourceToDownload, const GPUResource* resourceDest, void* dataDest, GRAPHICSTHREAD threadID) override;
		void QueryBegin(const GPUQuery *query, GRAPHICSTHREAD threadID) override;
		void QueryEnd(const GPUQuery *query, GRAPHICSTHREAD threadID) override;
		bool QueryRead(const GPUQuery *query, GPUQueryResult* result) override;
		void UAVBarrier(const GPUResource *const* uavs, UINT NumBarriers, GRAPHICSTHREAD threadID) override;
		void TransitionBarrier(const GPUResource *const* resources, UINT NumBarriers, RESOURCE_STATES stateBefore, RESOURCE_STATES stateAfter, GRAPHICSTHREAD threadID) override;

        GPUAllocation AllocateGPU(size_t dataSize, GRAPHICSTHREAD threadID) override;
        
		void EventBegin(const std::string& name, GRAPHICSTHREAD threadID) override;
		void EventEnd(GRAPHICSTHREAD threadID) override;
		void SetMarker(const std::string& name, GRAPHICSTHREAD threadID) override;

	};
}

#endif // _GRAPHICSDEVICE_METAL_H_
