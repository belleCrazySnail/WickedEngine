#include "wiGraphicsDevice_Metal.h"
#include "wiGraphicsDevice_SharedInternals.h"
//#include "wiHelper.h"
#include "ShaderInterop_Vulkan.h"
//#include "wiBackLog.h"

#include <sstream>
#include <vector>
#include <cstring>
#include <iostream>
#include <set>


namespace wiGraphicsTypes
{
    // Engine -> Native converters

    inline MTLColorWriteMask _ParseColorWriteMask(UINT value)
    {
        MTLColorWriteMask mask = MTLColorWriteMaskNone;
        
        if (value == COLOR_WRITE_ENABLE_ALL)
        {
            return MTLColorWriteMaskAll;
        }
        else
        {
            if (value & COLOR_WRITE_ENABLE_RED)
                mask |= MTLColorWriteMaskRed;
            if (value & COLOR_WRITE_ENABLE_GREEN)
                mask |= MTLColorWriteMaskGreen;
            if (value & COLOR_WRITE_ENABLE_BLUE)
                mask |= MTLColorWriteMaskBlue;
            if (value & COLOR_WRITE_ENABLE_ALPHA)
                mask |= MTLColorWriteMaskAlpha;
        }
        
        return mask;
    }
    
    inline MTLLoadAction _ConvertLoadAction(ACCESS_TYPE value)
    {
        switch (value) {
            case ACCESS_TYPE_DISCARD:
                return MTLLoadActionDontCare;
                break;
                
            default:
                break;
        }
        return MTLLoadActionDontCare;
    }
    
    inline MTLStoreAction _ConvertStoreAction(ACCESS_TYPE value)
    {
        switch (value) {
            case ACCESS_TYPE_DISCARD:
                return MTLStoreActionDontCare;
                break;
                
            default:
                break;
        }
        return MTLStoreActionDontCare;
    }
    
	inline MTLPixelFormat _ConvertPixelFormat(FORMAT value)
	{
		// _TYPELESS is converted to _UINT or _FLOAT or _UNORM in that order depending on availability!
		// X channel is converted to regular missing channel (eg. FORMAT_B8G8R8X8_UNORM -> VK_FORMAT_B8G8R8A8_UNORM)
		switch (value)
		{
		case FORMAT_UNKNOWN:
			return MTLPixelFormatInvalid;
			break;
        default:
            break;
		}
		return MTLPixelFormatInvalid;
	}
    inline MTLVertexFormat _ConvertVertexFormat(FORMAT value)
    {
        // _TYPELESS is converted to _UINT or _FLOAT or _UNORM in that order depending on availability!
        // X channel is converted to regular missing channel (eg. FORMAT_B8G8R8X8_UNORM -> VK_FORMAT_B8G8R8A8_UNORM)
        switch (value)
        {
            case FORMAT_UNKNOWN:
                return MTLVertexFormatInvalid;
                break;
            default:
                break;
        }
        return MTLVertexFormatInvalid;
    }
	inline MTLCompareFunction _ConvertComparisonFunc(COMPARISON_FUNC value)
	{
		switch (value)
		{
		case COMPARISON_NEVER:
			return MTLCompareFunctionNever;
			break;
		default:
			break;
		}
		return MTLCompareFunctionNever;
	}
	inline MTLBlendFactor _ConvertBlend(BLEND value)
	{
		switch (value)
		{
		case BLEND_ZERO:
			return MTLBlendFactorZero;
			break;
		default:
			break;
		}
		return MTLBlendFactorZero;
	}
	inline MTLBlendOperation _ConvertBlendOp(BLEND_OP value)
	{
		switch (value)
		{
		case BLEND_OP_ADD:
			return MTLBlendOperationAdd;
			break;
		default:
			break;
		}
		return MTLBlendOperationAdd;
	}
    inline MTLVertexStepFunction _ConvertInputClassification(INPUT_CLASSIFICATION value)
    {
        switch (value)
        {
            case INPUT_PER_VERTEX_DATA:
                return MTLVertexStepFunctionPerVertex;
                break;
            case INPUT_PER_INSTANCE_DATA:
                return MTLVertexStepFunctionPerInstance;
                break;
            default:
                break;
        }
        return MTLVertexStepFunctionPerVertex;
    }
	inline MTLSamplerAddressMode _ConvertTextureAddressMode(TEXTURE_ADDRESS_MODE value)
	{
		switch (value)
		{
		case TEXTURE_ADDRESS_WRAP:
			return MTLSamplerAddressModeClampToEdge;
			break;
		default:
			break;
		}
		return MTLSamplerAddressModeClampToEdge;
	}
    
#define BRIDGE_RES(type, res) (__bridge id <type>)((void *)(res))
#define BRIDGE_RES1(type, res) (__bridge type *)((void *)(res))
#define TRANSFER_RES(type, res) (__bridge_transfer id <type>)((void *)(res))
#define TRANSFER_RES1(type, res) (__bridge_transfer type *)((void *)(res))
#define RETAIN_RES(res) (wiCPUHandle)((__bridge_retained void *)(res))
    
    // Memory tools:
    
    inline size_t Align(size_t uLocation, size_t uAlign)
    {
        if ((0 == uAlign) || (uAlign & (uAlign - 1)))
        {
            assert(0);
        }
        
        return ((uLocation + (uAlign - 1)) & ~(uAlign - 1));
    }

    GraphicsDevice_Metal::FrameResources::ResourceFrameAllocator::ResourceFrameAllocator(id <MTLDevice> device, size_t size)
    {
        id <MTLBuffer> buf = [device newBufferWithLength:size options:MTLResourceStorageModeManaged];
        void* pData = [buf contents];
        //
        // No CPU reads will be done from the resource.
        //
        dataCur = dataBegin = reinterpret_cast<uint8_t*>(pData);
        dataEnd = dataBegin + size;
        
        // Because the "buffer" is created by hand in this, fill the desc to indicate how it can be used:
        buffer.resource = RETAIN_RES(buf);
        buffer.desc.ByteWidth = (UINT)((size_t)dataEnd - (size_t)dataBegin);
        buffer.desc.Usage = USAGE_DYNAMIC;
        buffer.desc.BindFlags = BIND_VERTEX_BUFFER | BIND_INDEX_BUFFER | BIND_SHADER_RESOURCE;
        buffer.desc.MiscFlags = RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
    }
    GraphicsDevice_Metal::FrameResources::ResourceFrameAllocator::~ResourceFrameAllocator()
    {
        if (buffer.resource != WI_NULL_HANDLE)
        {
            id <MTLBuffer> buf = TRANSFER_RES(MTLBuffer, buffer.resource);
            buf = nil;
            buffer.resource = WI_NULL_HANDLE;
        }
    }
    uint8_t* GraphicsDevice_Metal::FrameResources::ResourceFrameAllocator::allocate(size_t dataSize, size_t alignment)
    {
        dataCur = reinterpret_cast<uint8_t*>(Align(reinterpret_cast<size_t>(dataCur), alignment));
        
        if (dataCur + dataSize > dataEnd)
        {
            return nullptr; // failed allocation
        }
        
        uint8_t* retVal = dataCur;
        
        dataCur += dataSize;
        
        return retVal;
    }
    void GraphicsDevice_Metal::FrameResources::ResourceFrameAllocator::clear()
    {
        dataCur = dataBegin;
    }
    uint64_t GraphicsDevice_Metal::FrameResources::ResourceFrameAllocator::calculateOffset(uint8_t* address)
    {
        assert(address >= dataBegin && address < dataEnd);
        return static_cast<uint64_t>(address - dataBegin);
    }
    
    // We allow up to three command buffers to be in flight on GPU before we wait
    static const NSUInteger kMaxBuffersInFlight = 3;

    id <MTLRenderCommandEncoder> GraphicsDevice_Metal::GetDirectCommandList(GRAPHICSTHREAD threadID) {
        return GetFrameResources().drawInfo[threadID].commandLists;
    }
    
	GraphicsDevice_Metal::GraphicsDevice_Metal(wiWindowRegistration::window_type window, bool fullscreen, bool debuglayer)
	{
		BACKBUFFER_FORMAT = FORMAT::FORMAT_B8G8R8A8_UNORM;

		FULLSCREEN = fullscreen;

//        RECT rect = RECT();
//        GetClientRect(window, &rect);
//        SCREENWIDTH = rect.right - rect.left;
//        SCREENHEIGHT = rect.bottom - rect.top;

        _device = MTLCreateSystemDefaultDevice();
        NSLog(@"Selected Device: %@", _device.name);
        _queue = [_device newCommandQueue];
        _library = [_device newDefaultLibrary];
        _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
        _view = BRIDGE_RES1(MTKView, window);

//		wiBackLog::post("Created GraphicsDevice_Metal");
	}
	GraphicsDevice_Metal::~GraphicsDevice_Metal()
	{
		WaitForGPU();

	}

	void GraphicsDevice_Metal::SetResolution(int width, int height)
	{
		if (width != SCREENWIDTH || height != SCREENHEIGHT)
		{
			SCREENWIDTH = width;
			SCREENHEIGHT = height;
			//swapChain->ResizeBuffers(2, width, height, _ConvertFormat(GetBackBufferFormat()), 0);
			RESOLUTIONCHANGED = true;
		}
	}

	HRESULT GraphicsDevice_Metal::CreateBuffer(const GPUBufferDesc *pDesc, const SubresourceData* pInitialData, GPUBuffer *pBuffer)
	{
		pBuffer->Register(this);
		pBuffer->desc = *pDesc;
#if TARGET_OS_IOS
        // Statically sized
        static const size_t alignment = 16;
#else
        static const size_t alignment = 256;
#endif
        UINT64 alignedSize = Align(pDesc->ByteWidth, alignment);
        MTLResourceOptions option = MTLResourceStorageModeShared;
        id <MTLBuffer> buffer = nil;
        if (pInitialData != nullptr)
            buffer = [_device newBufferWithBytes:pInitialData->pSysMem length:alignedSize options:option];
        else
            buffer = [_device newBufferWithLength:alignedSize options:option];
        pBuffer->resource = (wiCPUHandle)buffer;
		return S_OK;
	}
    
	HRESULT GraphicsDevice_Metal::CreateTexture2D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture2D *pTexture2D)
	{
		pTexture2D->Register(this);

		pTexture2D->desc = *pDesc;

		if (pTexture2D->desc.MipLevels == 0)
		{
            pTexture2D->desc.MipLevels = static_cast<UINT>(log2(std::max(pTexture2D->desc.Width, pTexture2D->desc.Height)));
		}

        MTLTextureDescriptor* texDesc = [[MTLTextureDescriptor alloc] init];
        texDesc.width = pTexture2D->desc.Width;
        texDesc.height = pTexture2D->desc.Height;
        texDesc.pixelFormat = _ConvertPixelFormat(pTexture2D->desc.Format);
        texDesc.mipmapLevelCount = pDesc->MipLevels;
		if (pTexture2D->desc.BindFlags & BIND_SHADER_RESOURCE)
		{
			texDesc.usage |= MTLTextureUsageShaderRead;
		}
		if (pTexture2D->desc.BindFlags & BIND_RENDER_TARGET)
		{
			texDesc.usage |= MTLTextureUsageRenderTarget;
		}
        id <MTLTexture> mtlTex = [_device newTextureWithDescriptor:texDesc];
        pTexture2D->resource = (wiCPUHandle)mtlTex;

		// Issue data copy on request:
		if (pInitialData != nullptr)
		{
            MTLRegion region = {
                { 0, 0, 0 },                   // MTLOrigin
                {texDesc.width, texDesc.height, 1} // MTLSize
            };
            [mtlTex replaceRegion:region mipmapLevel:0 withBytes:pInitialData->pSysMem bytesPerRow:pInitialData->SysMemPitch];
            id <MTLBlitCommandEncoder> blitEnc = [_commandBuffer blitCommandEncoder];
            [blitEnc generateMipmapsForTexture:mtlTex];
            [blitEnc endEncoding];
		}

		return S_OK;
	}
    
	HRESULT GraphicsDevice_Metal::CreateSamplerState(const SamplerDesc *pSamplerDesc, Sampler *pSamplerState)
	{
		pSamplerState->Register(this);

		pSamplerState->desc = *pSamplerDesc;

        MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
        switch (pSamplerDesc->Filter)
        {
            case FILTER_MIN_MAG_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_MIN_MAG_POINT_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_MIN_POINT_MAG_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_MIN_LINEAR_MAG_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_MIN_MAG_LINEAR_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_MIN_MAG_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_ANISOTROPIC:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_COMPARISON_MIN_MAG_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_COMPARISON_MIN_MAG_POINT_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_COMPARISON_MIN_POINT_MAG_LINEAR_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_COMPARISON_MIN_POINT_MAG_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_COMPARISON_MIN_LINEAR_MAG_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_COMPARISON_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_COMPARISON_MIN_MAG_LINEAR_MIP_POINT:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
            case FILTER_COMPARISON_MIN_MAG_MIP_LINEAR:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_COMPARISON_ANISOTROPIC:
                samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
                samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
                break;
            case FILTER_MINIMUM_MIN_MAG_MIP_POINT:
            case FILTER_MINIMUM_MIN_MAG_POINT_MIP_LINEAR:
            case FILTER_MINIMUM_MIN_POINT_MAG_LINEAR_MIP_POINT:
            case FILTER_MINIMUM_MIN_POINT_MAG_MIP_LINEAR:
            case FILTER_MINIMUM_MIN_LINEAR_MAG_MIP_POINT:
            case FILTER_MINIMUM_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
            case FILTER_MINIMUM_MIN_MAG_LINEAR_MIP_POINT:
            case FILTER_MINIMUM_MIN_MAG_MIP_LINEAR:
            case FILTER_MINIMUM_ANISOTROPIC:
            case FILTER_MAXIMUM_MIN_MAG_MIP_POINT:
            case FILTER_MAXIMUM_MIN_MAG_POINT_MIP_LINEAR:
            case FILTER_MAXIMUM_MIN_POINT_MAG_LINEAR_MIP_POINT:
            case FILTER_MAXIMUM_MIN_POINT_MAG_MIP_LINEAR:
            case FILTER_MAXIMUM_MIN_LINEAR_MAG_MIP_POINT:
            case FILTER_MAXIMUM_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
            case FILTER_MAXIMUM_MIN_MAG_LINEAR_MIP_POINT:
            case FILTER_MAXIMUM_MIN_MAG_MIP_LINEAR:
            case FILTER_MAXIMUM_ANISOTROPIC:
            default:
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
                break;
        }
		samplerDesc.rAddressMode = _ConvertTextureAddressMode(pSamplerDesc->AddressU);
		samplerDesc.sAddressMode = _ConvertTextureAddressMode(pSamplerDesc->AddressV);
		samplerDesc.tAddressMode = _ConvertTextureAddressMode(pSamplerDesc->AddressW);
		samplerDesc.maxAnisotropy = static_cast<float>(pSamplerDesc->MaxAnisotropy);
		samplerDesc.compareFunction = _ConvertComparisonFunc(pSamplerDesc->ComparisonFunc);
		samplerDesc.lodMinClamp = pSamplerDesc->MinLOD;
		samplerDesc.lodMaxClamp = pSamplerDesc->MaxLOD;
        //samplerDesc.borderColor = MTLSamplerBorderColorTransparentBlack;
		samplerDesc.normalizedCoordinates = FALSE;
        id <MTLSamplerState> sam_state = [_device newSamplerStateWithDescriptor:samplerDesc];
        pSamplerState->resource = (wiCPUHandle)sam_state;

		return S_OK;
	}
	HRESULT GraphicsDevice_Metal::CreateQuery(const GPUQueryDesc *pDesc, GPUQuery *pQuery)
	{
		pQuery->Register(this);

		return E_FAIL;
	}
	HRESULT GraphicsDevice_Metal::CreateGraphicsPSO(const GraphicsPSODesc* pDesc, GraphicsPSO* pso)
	{
		pso->Register(this);

		pso->desc = *pDesc;

        MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
        if (pDesc->vs != nullptr)
        {
            pipelineDesc.vertexFunction = [_library newFunctionWithName:[NSString stringWithUTF8String:pDesc->vs->code.ShaderName.c_str()]];
        }
        if (pDesc->hs != nullptr)
        {
        }
        if (pDesc->ds != nullptr)
        {
        }
        if (pDesc->gs != nullptr)
        {
        }
        if (pDesc->ps != nullptr)
        {
            pipelineDesc.fragmentFunction = [_library newFunctionWithName:[NSString stringWithUTF8String:pDesc->ps->code.ShaderName.c_str()]];
        }
        
		// Input layout:
		if (pDesc->il != nullptr)
		{
			MTLVertexDescriptor *vertexDesc = [[MTLVertexDescriptor alloc] init];
            for (auto& x : pDesc->il->desc)
			{
                UINT slot = x.InputSlot;
                vertexDesc.layouts[slot].stride = x.AlignedByteOffset;
                vertexDesc.layouts[slot].stepRate = x.InstanceDataStepRate;
                vertexDesc.layouts[slot].stepFunction = _ConvertInputClassification(x.InputSlotClass);
			}
            for (auto &x : pDesc->il->desc)
            {
                UINT index = x.SemanticIndex;
                vertexDesc.attributes[index].format = _ConvertVertexFormat(x.Format);
                vertexDesc.attributes[index].offset = x.AlignedByteOffset;
                vertexDesc.attributes[index].bufferIndex = x.InputSlot;
            }
            pipelineDesc.vertexDescriptor = vertexDesc;
		}
        //Render target:
        BlendStateDesc pBlendStateDesc = pDesc->bs != nullptr ? pDesc->bs->GetDesc() : BlendStateDesc();
        for (UINT i = 0; i < pDesc->numRTs; ++i)
        {
            pipelineDesc.colorAttachments[i].pixelFormat = _ConvertPixelFormat(pDesc->RTFormats[i]);
            pipelineDesc.colorAttachments[i].blendingEnabled = pBlendStateDesc.RenderTarget[i].BlendEnable;
            pipelineDesc.colorAttachments[i].sourceRGBBlendFactor = _ConvertBlend(pBlendStateDesc.RenderTarget[i].SrcBlend);
            pipelineDesc.colorAttachments[i].destinationRGBBlendFactor = _ConvertBlend(pBlendStateDesc.RenderTarget[i].DestBlend);
            pipelineDesc.colorAttachments[i].rgbBlendOperation = _ConvertBlendOp(pBlendStateDesc.RenderTarget[i].BlendOp);
            pipelineDesc.colorAttachments[i].sourceAlphaBlendFactor = _ConvertBlend(pBlendStateDesc.RenderTarget[i].SrcBlendAlpha);
            pipelineDesc.colorAttachments[i].destinationAlphaBlendFactor = _ConvertBlend(pBlendStateDesc.RenderTarget[i].DestBlendAlpha);
            pipelineDesc.colorAttachments[i].alphaBlendOperation = _ConvertBlendOp(pBlendStateDesc.RenderTarget[i].BlendOpAlpha);
            pipelineDesc.colorAttachments[i].writeMask = _ParseColorWriteMask(pBlendStateDesc.RenderTarget[i].RenderTargetWriteMask);
        }

		// Primitive type:
		switch (pDesc->pt)
		{
		case POINTLIST:
			pipelineDesc.inputPrimitiveTopology = MTLPrimitiveTopologyClassPoint;
			break;
		case LINELIST:
			pipelineDesc.inputPrimitiveTopology = MTLPrimitiveTopologyClassLine;
			break;
		case TRIANGLESTRIP:
			pipelineDesc.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
			break;
		case TRIANGLELIST:
			pipelineDesc.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
			break;
		case PATCHLIST:
			pipelineDesc.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
			break;
		default:
            pipelineDesc.inputPrimitiveTopology = MTLPrimitiveTopologyClassUnspecified;
			break;
		}
        NSError* error = nil;
        id <MTLRenderPipelineState> mtl_pipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
        pso->pipeline = (wiCPUHandle)mtl_pipeline;

		return S_OK;
	}
	HRESULT GraphicsDevice_Metal::CreateComputePSO(const ComputePSODesc* pDesc, ComputePSO* pso)
	{
		pso->Register(this);

		pso->desc = *pDesc;
        
        MTLComputePipelineDescriptor *computeDesc = [[MTLComputePipelineDescriptor alloc] init];
		if (pDesc->cs != nullptr)
		{
            computeDesc.computeFunction = [_library newFunctionWithName:[NSString stringWithUTF8String:pDesc->cs->code.ShaderName.c_str()]];
		}
        computeDesc.threadGroupSizeIsMultipleOfThreadExecutionWidth = TRUE;
        NSError* error = nil;
        id <MTLComputePipelineState> compute_pipeline = [_device newComputePipelineStateWithDescriptor:computeDesc options:0 reflection:nil error:&error];
        pso->pipeline = RETAIN_RES(compute_pipeline);

		return S_OK;
	}

    HRESULT GraphicsDevice_Metal::CreateRenderPass(const RenderPassDesc *pDesc, RenderPass *pRenderPass)
    {
        pRenderPass->Register(this);
        
        pRenderPass->desc = *pDesc;

        MTLRenderPassDescriptor *renderPassDesc = [[MTLRenderPassDescriptor alloc] init];
        for (UINT i = 0; i < pDesc->NumRenderTargets; ++i)
        {
            renderPassDesc.colorAttachments[i].loadAction = _ConvertLoadAction(pDesc->RenderTargets[i].BeginningAccess.Type);
            renderPassDesc.colorAttachments[i].storeAction = _ConvertStoreAction(pDesc->RenderTargets[i].EndingAccess);
            if (renderPassDesc.colorAttachments[i].loadAction == MTLLoadActionClear) {
                const FLOAT *temp = pDesc->RenderTargets[i].BeginningAccess.Clear.Color;
                renderPassDesc.colorAttachments[i].clearColor = MTLClearColorMake(temp[0], temp[1], temp[2], temp[3]);
            }
        }
        renderPassDesc.depthAttachment.loadAction = _ConvertLoadAction(pDesc->Depth.BeginningAccess.Type);
        renderPassDesc.depthAttachment.storeAction = _ConvertStoreAction(pDesc->Depth.EndingAccess);
        if (renderPassDesc.depthAttachment.loadAction == MTLLoadActionClear)
            renderPassDesc.depthAttachment.clearDepth = pDesc->Depth.BeginningAccess.Clear.DepthStencil.Depth;
        renderPassDesc.stencilAttachment.loadAction = _ConvertLoadAction(pDesc->Stencil.BeginningAccess.Type);
        renderPassDesc.stencilAttachment.storeAction = _ConvertStoreAction(pDesc->Stencil.EndingAccess);
        if (renderPassDesc.stencilAttachment.loadAction == MTLLoadActionClear)
            renderPassDesc.stencilAttachment.clearStencil = pDesc->Stencil.BeginningAccess.Clear.DepthStencil.Stencil;
        pRenderPass->resource = RETAIN_RES(renderPassDesc);
        
        return S_OK;
    }
    
	void GraphicsDevice_Metal::DestroyResource(GPUResource* pResource)
	{
        id resource = (__bridge_transfer id)((void *)(pResource->resource));
        resource = nil;
	}
	void GraphicsDevice_Metal::DestroyBuffer(GPUBuffer *pBuffer)
	{
        id <MTLBuffer> buffer = TRANSFER_RES(MTLBuffer, pBuffer->resource);
        buffer = nil;
	}
	void GraphicsDevice_Metal::DestroyTexture1D(Texture1D *pTexture1D)
	{
        DestroyResource(pTexture1D);
	}
	void GraphicsDevice_Metal::DestroyTexture2D(Texture2D *pTexture2D)
	{
        DestroyResource(pTexture2D);
	}
	void GraphicsDevice_Metal::DestroyTexture3D(Texture3D *pTexture3D)
	{
        DestroyResource(pTexture3D);
	}
	void GraphicsDevice_Metal::DestroyInputLayout(VertexLayout *pInputLayout)
	{

	}
	void GraphicsDevice_Metal::DestroyVertexShader(VertexShader *pVertexShader)
	{

	}
	void GraphicsDevice_Metal::DestroyPixelShader(PixelShader *pPixelShader)
	{

	}
	void GraphicsDevice_Metal::DestroyGeometryShader(GeometryShader *pGeometryShader)
	{

	}
	void GraphicsDevice_Metal::DestroyHullShader(HullShader *pHullShader)
	{

	}
	void GraphicsDevice_Metal::DestroyDomainShader(DomainShader *pDomainShader)
	{

	}
	void GraphicsDevice_Metal::DestroyComputeShader(ComputeShader *pComputeShader)
	{

	}
	void GraphicsDevice_Metal::DestroyBlendState(BlendState *pBlendState)
	{

	}
	void GraphicsDevice_Metal::DestroyDepthStencilState(DepthStencilState *pDepthStencilState)
	{

	}
	void GraphicsDevice_Metal::DestroyRasterizerState(RasterizerState *pRasterizerState)
	{

	}
	void GraphicsDevice_Metal::DestroySamplerState(Sampler *pSamplerState)
	{
	}
	void GraphicsDevice_Metal::DestroyQuery(GPUQuery *pQuery)
	{

	}
	void GraphicsDevice_Metal::DestroyGraphicsPSO(GraphicsPSO* pso)
	{
	}
	void GraphicsDevice_Metal::DestroyComputePSO(ComputePSO* pso)
	{
	}

	void GraphicsDevice_Metal::SetName(GPUResource* pResource, const std::string& name)
	{

	}

    void GraphicsDevice_Metal::BeginRenderPass(RenderPass *pRenderPass, GRAPHICSTHREAD threadID)
    {
        MTLRenderPassDescriptor *renderPassDesc = BRIDGE_RES1(MTLRenderPassDescriptor, pRenderPass->resource);
        GetFrameResources().drawInfo[threadID].commandLists = [_commandBuffer renderCommandEncoderWithDescriptor:renderPassDesc];
    }

    void GraphicsDevice_Metal::EndRenderPass(GRAPHICSTHREAD threadID)
    {
        [GetDirectCommandList(threadID) endEncoding];
    }
    
	void GraphicsDevice_Metal::PresentBegin()
	{
        // Wait to ensure only AAPLMaxBuffersInFlight are getting processed by any stage in the Metal
        //   pipeline (App, Metal, Drivers, GPU, etc)
        dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

        _commandBuffer = [_queue commandBuffer];
        
        // Add completion hander which signal _inFlightSemaphore when Metal and the GPU has fully
        //   finished processing the commands we're encoding this frame.  This indicates when the
        //   dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
        //   and the GPU.
        __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
        [_commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
         {
             dispatch_semaphore_signal(block_sema);
         }];

	}
	void GraphicsDevice_Metal::PresentEnd()
	{
        // Schedule a present once the framebuffer is complete using the current drawable
        if(_view.currentDrawable)
        {
            [_commandBuffer presentDrawable:_view.currentDrawable];
        }
        
        // Finalize rendering here & push the command buffer to the GPU
        [_commandBuffer commit];

		// This acts as a barrier, following this we will be using the next frame's resources when calling GetFrameResources()!
		FRAMECOUNT++;

		RESOLUTIONCHANGED = false;
	}

	void GraphicsDevice_Metal::CreateCommandLists()
	{

	}
	void GraphicsDevice_Metal::ExecuteCommandLists()
	{
	}
	void GraphicsDevice_Metal::FinishCommandList(GRAPHICSTHREAD threadID)
	{
	}

	void GraphicsDevice_Metal::WaitForGPU()
	{
	}

	void GraphicsDevice_Metal::BindScissorRects(UINT numRects, const Rect* rects, GRAPHICSTHREAD threadID) {
		assert(rects != nullptr);
		assert(numRects <= 8);
		MTLScissorRect scissors[8];
		for(UINT i = 0; i < numRects; ++i) {
			scissors[i].width = abs(rects[i].right - rects[i].left);
			scissors[i].height = abs(rects[i].top - rects[i].bottom);
            scissors[i].x = std::max(0l, rects[i].left);
            scissors[i].y = std::max(0l, rects[i].top);
		}
        [GetDirectCommandList(threadID) setScissorRects:scissors count:numRects];
	}
	void GraphicsDevice_Metal::BindViewports(UINT NumViewports, const ViewPort *pViewports, GRAPHICSTHREAD threadID)
	{
		assert(NumViewports <= 6);
		MTLViewport viewports[6];
		for (UINT i = 0; i < NumViewports; ++i)
		{
			viewports[i].originX = pViewports[i].TopLeftX;
			viewports[i].originY = pViewports[i].TopLeftY;
			viewports[i].width = pViewports[i].Width;
			viewports[i].height = pViewports[i].Height;
			viewports[i].znear = pViewports[i].MinDepth;
			viewports[i].zfar = pViewports[i].MaxDepth;
		}
        [GetDirectCommandList(threadID) setViewports:viewports count:NumViewports];
	}
	void GraphicsDevice_Metal::BindRenderTargets(UINT NumViews, Texture2D* const *ppRenderTargets, Texture2D* depthStencilTexture, GRAPHICSTHREAD threadID, int arrayIndex)
	{
		assert(NumViews <= 8);

	}
	void GraphicsDevice_Metal::ClearRenderTarget(Texture* pTexture, const FLOAT ColorRGBA[4], GRAPHICSTHREAD threadID, int arrayIndex)
	{
	}
	void GraphicsDevice_Metal::ClearDepthStencil(Texture2D* pTexture, UINT ClearFlags, FLOAT Depth, UINT8 Stencil, GRAPHICSTHREAD threadID, int arrayIndex)
	{
	}
	void GraphicsDevice_Metal::BindResource(SHADERSTAGE stage, GPUResource* resource, int slot, GRAPHICSTHREAD threadID, int arrayIndex)
	{
		assert(slot < GPU_RESOURCE_HEAP_SRV_COUNT);

        if (resource != nullptr && resource->resource != WI_NULL_HANDLE)
        {
            Texture* tex = dynamic_cast<Texture*>(resource);
            if (tex != nullptr && tex->resource != WI_NULL_HANDLE)
            {
                id <MTLTexture> mtl_tex = BRIDGE_RES(MTLTexture, tex->resource);
                switch (stage) {
                    case VS:
                        [GetDirectCommandList(threadID) setVertexTexture:mtl_tex atIndex:slot];
                        break;
                    case PS:
                        [GetDirectCommandList(threadID) setFragmentTexture:mtl_tex atIndex:slot];
                    case CS:
                        [_computeEnc setTexture:mtl_tex atIndex:slot];
                    default:
                        break;
                }
            }
            else {
                GPUBuffer* buffer = dynamic_cast<GPUBuffer*>(resource);
                if (buffer != nullptr && buffer->resource != WI_NULL_HANDLE)
                    BindConstantBuffer(stage, buffer, slot, threadID);
            }
        }
	}
	void GraphicsDevice_Metal::BindResources(SHADERSTAGE stage, GPUResource *const* resources, int slot, int count, GRAPHICSTHREAD threadID)
	{
		if (resources != nullptr)
		{
			for (int i = 0; i < count; ++i)
			{
				BindResource(stage, resources[i], slot + i, threadID, -1);
			}
		}
	}
	void GraphicsDevice_Metal::BindUAV(SHADERSTAGE stage, GPUResource* resource, int slot, GRAPHICSTHREAD threadID, int arrayIndex)
	{
		assert(slot < GPU_RESOURCE_HEAP_UAV_COUNT);

	}
	void GraphicsDevice_Metal::BindUAVs(SHADERSTAGE stage, GPUResource *const* resources, int slot, int count, GRAPHICSTHREAD threadID)
	{
		if (resources != nullptr)
		{
			for (int i = 0; i < count; ++i)
			{
				BindUAV(stage, resources[i], slot + i, threadID, -1);
			}
		}
	}
	void GraphicsDevice_Metal::UnbindResources(int slot, int num, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::UnbindUAVs(int slot, int num, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::BindSampler(SHADERSTAGE stage, Sampler* sampler, int slot, GRAPHICSTHREAD threadID)
	{
		assert(slot < GPU_SAMPLER_HEAP_COUNT);

		if (sampler != nullptr && sampler->resource != WI_NULL_HANDLE)
		{
            id <MTLSamplerState> sam = BRIDGE_RES(MTLSamplerState, sampler->resource);
            switch (stage) {
                case VS:
                    [GetDirectCommandList(threadID) setVertexSamplerState:sam atIndex:slot];
                    break;
                case PS:
                    [GetDirectCommandList(threadID) setFragmentSamplerState:sam atIndex:slot];
                case CS:
                    [_computeEnc setSamplerState:sam atIndex:slot];
                default:
                    break;
            }
		}
	}
	void GraphicsDevice_Metal::BindConstantBuffer(SHADERSTAGE stage, GPUBuffer* buffer, int slot, GRAPHICSTHREAD threadID)
	{
		assert(slot < GPU_RESOURCE_HEAP_CBV_COUNT);

		if (buffer != nullptr && buffer->resource != WI_NULL_HANDLE)
		{
            id <MTLBuffer> buf = BRIDGE_RES(MTLBuffer, buffer->resource);
            switch (stage) {
                case VS:
                    [GetDirectCommandList(threadID) setVertexBuffer:buf offset:0 atIndex:slot];
                    break;
                case PS:
                    [GetDirectCommandList(threadID) setFragmentBuffer:buf offset:0 atIndex:slot];
                case CS:
                    [_computeEnc setBuffer:buf offset:0 atIndex:slot];
                default:
                    break;
            }
		}
	}
	void GraphicsDevice_Metal::BindVertexBuffers(GPUBuffer* const *vertexBuffers, int slot, int count, const UINT* strides, const UINT* offsets, GRAPHICSTHREAD threadID)
	{
		NSUInteger voffsets[8] = {};
		id <MTLBuffer> vbuffers[8] = {};
		assert(count <= 8);
        bool valid = offsets == nullptr ? false : true;
		for (int i = 0; i < count; ++i)
		{
			if (vertexBuffers[i] != nullptr)
			{
				vbuffers[i] = BRIDGE_RES(MTLBuffer, vertexBuffers[i]->resource);
			}
            else valid = false;
            voffsets[i] = offsets[i];
		}

		if (valid)
		{
            [GetDirectCommandList(threadID) setVertexBuffers:vbuffers offsets:voffsets withRange:NSMakeRange(slot, count)];
		}
	}
	void GraphicsDevice_Metal::BindIndexBuffer(GPUBuffer* _indexBuffer, const INDEXBUFFER_FORMAT format, UINT offset, GRAPHICSTHREAD threadID)
	{
		if (_indexBuffer != nullptr)
		{
            FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
            info.indexBuffer = BRIDGE_RES(MTLBuffer, _indexBuffer->resource);
            info.indexType = format == INDEXFORMAT_16BIT ? MTLIndexTypeUInt16 : MTLIndexTypeUInt32;
            info.indexOffset = offset;
		}
	}
	void GraphicsDevice_Metal::BindStencilRef(UINT value, GRAPHICSTHREAD threadID)
	{
        [GetDirectCommandList(threadID) setStencilReferenceValue:value];
	}
	void GraphicsDevice_Metal::BindBlendFactor(XMFLOAT4 value, GRAPHICSTHREAD threadID)
	{
        [GetDirectCommandList(threadID) setBlendColorRed:value.x green:value.y blue:value.z alpha:value.w];
	}
	void GraphicsDevice_Metal::BindGraphicsPSO(GraphicsPSO* pso, GRAPHICSTHREAD threadID)
	{
        switch (pso->desc.pt) {
            case TRIANGLELIST:
                GetFrameResources().drawInfo[threadID].primType = MTLPrimitiveTypeTriangle;
                break;
            case TRIANGLESTRIP:
                GetFrameResources().drawInfo[threadID].primType = MTLPrimitiveTypeTriangleStrip;
            case POINTLIST:
                GetFrameResources().drawInfo[threadID].primType = MTLPrimitiveTypePoint;
            case LINELIST:
                GetFrameResources().drawInfo[threadID].primType = MTLPrimitiveTypeLine;
            case PATCHLIST:
                GetFrameResources().drawInfo[threadID].primType = MTLPrimitiveTypeTriangle;
            default:
                GetFrameResources().drawInfo[threadID].primType = MTLPrimitiveTypeTriangleStrip;
                break;
        }
        [GetDirectCommandList(threadID) setRenderPipelineState:BRIDGE_RES(MTLRenderPipelineState, pso->pipeline)];
	}
	void GraphicsDevice_Metal::BindComputePSO(ComputePSO* pso, GRAPHICSTHREAD threadID)
	{
        [_computeEnc setComputePipelineState:BRIDGE_RES(MTLComputePipelineState, pso->pipeline)];
	}
	void GraphicsDevice_Metal::Draw(int vertexCount, UINT startVertexLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawPrimitives:info.primType vertexStart:startVertexLocation vertexCount:vertexCount];
	}
	void GraphicsDevice_Metal::DrawIndexed(int indexCount, UINT startIndexLocation, UINT baseVertexLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawIndexedPrimitives:info.primType indexCount:indexCount indexType:info.indexType indexBuffer:info.indexBuffer indexBufferOffset:info.indexOffset instanceCount:1 baseVertex:baseVertexLocation baseInstance:0];
	}
	void GraphicsDevice_Metal::DrawInstanced(int vertexCount, int instanceCount, UINT startVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawPrimitives:info.primType vertexStart:startVertexLocation vertexCount:vertexCount instanceCount:instanceCount baseInstance:startInstanceLocation];
	}
	void GraphicsDevice_Metal::DrawIndexedInstanced(int indexCount, int instanceCount, UINT startIndexLocation, UINT baseVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawIndexedPrimitives:info.primType indexCount:indexCount indexType:info.indexType indexBuffer:info.indexBuffer indexBufferOffset:info.indexOffset instanceCount:instanceCount baseVertex:baseVertexLocation baseInstance:startInstanceLocation];
	}
	void GraphicsDevice_Metal::DrawInstancedIndirect(GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID)
	{
        if (args == nullptr) return;
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawPrimitives:info.primType indirectBuffer:BRIDGE_RES(MTLBuffer, args->resource) indirectBufferOffset:args_offset];
	}
	void GraphicsDevice_Metal::DrawIndexedInstancedIndirect(GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID)
	{
        if (args == nullptr) return;
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawIndexedPrimitives:info.primType indexType:info.indexType indexBuffer:info.indexBuffer indexBufferOffset:info.indexOffset indirectBuffer:BRIDGE_RES(MTLBuffer, args->resource) indirectBufferOffset:args_offset];
	}
	void GraphicsDevice_Metal::Dispatch(UINT threadGroupCountX, UINT threadGroupCountY, UINT threadGroupCountZ, GRAPHICSTHREAD threadID)
	{
        [_computeEnc dispatchThreadgroups:MTLSizeMake(threadGroupCountX, threadGroupCountY, threadGroupCountZ) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
	}
	void GraphicsDevice_Metal::DispatchIndirect(GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID)
	{
        if (args == nullptr) return;
        [_computeEnc dispatchThreadgroupsWithIndirectBuffer:BRIDGE_RES(MTLBuffer, args->resource) indirectBufferOffset:args_offset threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
	}
	void GraphicsDevice_Metal::CopyTexture2D(Texture2D* pDst, Texture2D* pSrc, GRAPHICSTHREAD threadID)
	{
        id <MTLBlitCommandEncoder> blitEnc = [_commandBuffer blitCommandEncoder];
        [blitEnc copyFromTexture:BRIDGE_RES(MTLTexture, pSrc->resource) sourceSlice:0 sourceLevel:0 sourceOrigin:{0,0,0} sourceSize:MTLSizeMake(pSrc->desc.Width, pSrc->desc.Height, 1) toTexture:BRIDGE_RES(MTLTexture, pDst->resource) destinationSlice:0 destinationLevel:0 destinationOrigin:{0,0,0}];
        [blitEnc endEncoding];
	}
	void GraphicsDevice_Metal::CopyTexture2D_Region(Texture2D* pDst, UINT dstMip, UINT dstX, UINT dstY, Texture2D* pSrc, UINT srcMip, GRAPHICSTHREAD threadID)
	{
        id <MTLBlitCommandEncoder> blitEnc = [_commandBuffer blitCommandEncoder];
        [blitEnc copyFromTexture:BRIDGE_RES(MTLTexture, pSrc->resource) sourceSlice:0 sourceLevel:srcMip sourceOrigin:{0,0,0} sourceSize:MTLSizeMake(pSrc->desc.Width, pSrc->desc.Height, 1) toTexture:BRIDGE_RES(MTLTexture, pDst->resource) destinationSlice:0 destinationLevel:dstMip destinationOrigin:{dstX,dstY,0}];
        [blitEnc endEncoding];
	}
	void GraphicsDevice_Metal::MSAAResolve(Texture2D* pDst, Texture2D* pSrc, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::UpdateBuffer(GPUBuffer* buffer, const void* data, GRAPHICSTHREAD threadID, int dataSize)
	{
		assert(buffer->desc.Usage != USAGE_IMMUTABLE && "Cannot update IMMUTABLE GPUBuffer!");
		assert((int)buffer->desc.ByteWidth >= dataSize || dataSize < 0 && "Data size is too big!");
        if (dataSize == 0) return;

        UINT trueSize = (dataSize == -1) ? buffer->desc.ByteWidth : dataSize;

        id <MTLBlitCommandEncoder> blitEnc = [_commandBuffer blitCommandEncoder];
        id <MTLBuffer> tempBuffer = [_device newBufferWithBytes:data length:trueSize options:MTLResourceStorageModeManaged];
        [blitEnc copyFromBuffer:tempBuffer sourceOffset:0 toBuffer:BRIDGE_RES(MTLBuffer, buffer->resource) destinationOffset:0 size:trueSize];
        [blitEnc endEncoding];
        
        id <MTLBuffer> buf = BRIDGE_RES(MTLBuffer, buffer->resource);
        void *handle = [buf contents];
        memcpy(handle, data, trueSize);
        
	}
	bool GraphicsDevice_Metal::DownloadResource(GPUResource* resourceToDownload, GPUResource* resourceDest, void* dataDest, GRAPHICSTHREAD threadID)
	{
		return false;
	}

	void GraphicsDevice_Metal::QueryBegin(GPUQuery *query, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::QueryEnd(GPUQuery *query, GRAPHICSTHREAD threadID)
	{
	}
	bool GraphicsDevice_Metal::QueryRead(GPUQuery *query, GRAPHICSTHREAD threadID)
	{
		return true;
	}

	void GraphicsDevice_Metal::UAVBarrier(GPUResource *const* uavs, UINT NumBarriers, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::TransitionBarrier(GPUResource *const* resources, UINT NumBarriers, RESOURCE_STATES stateBefore, RESOURCE_STATES stateAfter, GRAPHICSTHREAD threadID)
	{

	}
    
    GraphicsDevice::GPUAllocation GraphicsDevice_Metal::AllocateGPU(size_t dataSize, GRAPHICSTHREAD threadID)
    {
        // This case allocates a CPU write access and GPU read access memory from the temporary buffer
        // The application can write into this, but better to not read from it
        
        FrameResources::ResourceFrameAllocator& allocator = *GetFrameResources().resourceBuffer[threadID];
        GPUAllocation result;
        
        if (dataSize == 0)
        {
            return result;
        }
        
        uint8_t* dest = allocator.allocate(dataSize, 256);
        
        assert(dest != nullptr); // todo: this needs to be handled as well
        
        result.buffer = &allocator.buffer;
        result.offset = (UINT)allocator.calculateOffset(dest);
        result.data = (void*)dest;
        return result;
    }

	void GraphicsDevice_Metal::EventBegin(const std::string& name, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::EventEnd(GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::SetMarker(const std::string& name, GRAPHICSTHREAD threadID)
	{

	}

}
