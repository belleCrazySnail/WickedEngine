#include "wiGraphicsDevice_Metal.h"
#include "wiGraphicsDevice_SharedInternals.h"
//#include "wiHelper.h"
//#include "ShaderInterop_Metal.h"
#include "wiBackLog.h"

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
            case ACCESS_TYPE_PRESERVE:
                return MTLLoadActionLoad;
            case ACCESS_TYPE_CLEAR:
                return MTLLoadActionClear;
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
            case ACCESS_TYPE_PRESERVE:
                return MTLStoreActionStore;
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
        case FORMAT_R32G32B32A32_TYPELESS:
            return MTLPixelFormatRGBA32Uint;
            break;
        case FORMAT_R32G32B32A32_FLOAT:
            return MTLPixelFormatRGBA32Float;
            break;
        case FORMAT_R32G32B32A32_UINT:
            return MTLPixelFormatRGBA32Uint;
            break;
        case FORMAT_R32G32B32A32_SINT:
            return MTLPixelFormatRGBA32Sint;
            break;
        //these rgb 3 channel format didn't have a corresponding format in metal
        case FORMAT_R32G32B32_TYPELESS:
        case FORMAT_R32G32B32_FLOAT:
        case FORMAT_R32G32B32_UINT:
        case FORMAT_R32G32B32_SINT:
            return MTLPixelFormatInvalid;
            break;
        case FORMAT_R16G16B16A16_TYPELESS:
            return MTLPixelFormatRGBA16Uint;
            break;
        case FORMAT_R16G16B16A16_FLOAT:
            return MTLPixelFormatRGBA16Float;
            break;
        case FORMAT_R16G16B16A16_UNORM:
            return MTLPixelFormatRGBA16Unorm;
            break;
        case FORMAT_R16G16B16A16_UINT:
            return MTLPixelFormatRGBA16Uint;
            break;
        case FORMAT_R16G16B16A16_SNORM:
            return MTLPixelFormatRGBA16Snorm;
            break;
        case FORMAT_R16G16B16A16_SINT:
            return MTLPixelFormatRGBA16Sint;
            break;
        case FORMAT_R32G32_TYPELESS:
            return MTLPixelFormatRG32Uint;
            break;
        case FORMAT_R32G32_FLOAT:
            return MTLPixelFormatRG32Float;
            break;
        case FORMAT_R32G32_UINT:
            return MTLPixelFormatRG32Uint;
            break;
        case FORMAT_R32G32_SINT:
            return MTLPixelFormatRG32Sint;
            break;
        //strange dx format
        case FORMAT_R32G8X24_TYPELESS:
        case FORMAT_D32_FLOAT_S8X24_UINT:
        case FORMAT_R32_FLOAT_X8X24_TYPELESS:
        case FORMAT_X32_TYPELESS_G8X24_UINT:
            return MTLPixelFormatInvalid;
            break;
        case FORMAT_R10G10B10A2_TYPELESS:
            return MTLPixelFormatRGB10A2Uint;
            break;
        case FORMAT_R10G10B10A2_UNORM:
            return MTLPixelFormatRGB10A2Unorm;
            break;
        case FORMAT_R10G10B10A2_UINT:
            return MTLPixelFormatRGB10A2Uint;
            break;
        case FORMAT_R11G11B10_FLOAT:
            return MTLPixelFormatRG11B10Float;
            break;
        case FORMAT_R8G8B8A8_TYPELESS:
            return MTLPixelFormatRGBA8Uint;
            break;
        case FORMAT_R8G8B8A8_UNORM:
            return MTLPixelFormatRGBA8Unorm;
            break;
        case FORMAT_R8G8B8A8_UNORM_SRGB:
            return MTLPixelFormatRGBA8Unorm_sRGB;
            break;
        case FORMAT_R8G8B8A8_UINT:
            return MTLPixelFormatRGBA8Uint;
            break;
        case FORMAT_R8G8B8A8_SNORM:
            return MTLPixelFormatRGBA8Snorm;
            break;
        case FORMAT_R8G8B8A8_SINT:
            return MTLPixelFormatRGBA8Sint;
            break;
        case FORMAT_R16G16_TYPELESS:
            return MTLPixelFormatRG16Uint;
            break;
        case FORMAT_R16G16_FLOAT:
            return MTLPixelFormatRG16Float;
            break;
        case FORMAT_R16G16_UNORM:
            return MTLPixelFormatRG16Unorm;
            break;
        case FORMAT_R16G16_UINT:
            return MTLPixelFormatRG16Uint;
            break;
        case FORMAT_R16G16_SNORM:
            return MTLPixelFormatRG16Snorm;
            break;
        case FORMAT_R16G16_SINT:
            return MTLPixelFormatRG16Sint;
            break;
        case FORMAT_R32_TYPELESS:
            return MTLPixelFormatR32Uint;
            break;
        case FORMAT_D32_FLOAT:
            return MTLPixelFormatDepth32Float;
            break;
        case FORMAT_R32_FLOAT:
            return MTLPixelFormatR32Float;
            break;
        case FORMAT_R32_UINT:
            return MTLPixelFormatR32Uint;
            break;
        case FORMAT_R32_SINT:
            return MTLPixelFormatR32Sint;
            break;
        case FORMAT_R24G8_TYPELESS:
        case FORMAT_D24_UNORM_S8_UINT:
        case FORMAT_R24_UNORM_X8_TYPELESS:
        case FORMAT_X24_TYPELESS_G8_UINT:
            return MTLPixelFormatDepth24Unorm_Stencil8;
            break;
        case FORMAT_R8G8_TYPELESS:
            return MTLPixelFormatRG8Uint;
            break;
        case FORMAT_R8G8_UNORM:
            return MTLPixelFormatRG8Unorm;
            break;
        case FORMAT_R8G8_UINT:
            return MTLPixelFormatRG8Uint;
            break;
        case FORMAT_R8G8_SNORM:
            return MTLPixelFormatRG8Snorm;
            break;
        case FORMAT_R8G8_SINT:
            return MTLPixelFormatRG8Sint;
            break;
        case FORMAT_R16_TYPELESS:
            return MTLPixelFormatR16Uint;
            break;
        case FORMAT_R16_FLOAT:
            return MTLPixelFormatR16Float;
            break;
        case FORMAT_D16_UNORM:
            return MTLPixelFormatDepth16Unorm;
            break;
        case FORMAT_R16_UNORM:
            return MTLPixelFormatR16Unorm;
            break;
        case FORMAT_R16_UINT:
            return MTLPixelFormatR16Uint;
            break;
        case FORMAT_R16_SNORM:
            return MTLPixelFormatR16Snorm;
            break;
        case FORMAT_R16_SINT:
            return MTLPixelFormatR16Sint;
            break;
        case FORMAT_R8_TYPELESS:
            return MTLPixelFormatR8Uint;
            break;
        case FORMAT_R8_UNORM:
            return MTLPixelFormatR8Unorm;
            break;
        case FORMAT_R8_UINT:
            return MTLPixelFormatR8Uint;
            break;
        case FORMAT_R8_SNORM:
            return MTLPixelFormatR8Snorm;
            break;
        case FORMAT_R8_SINT:
            return MTLPixelFormatR8Sint;
            break;
        case FORMAT_A8_UNORM:
            return MTLPixelFormatA8Unorm;
            break;
        case FORMAT_R1_UNORM:
            return MTLPixelFormatInvalid;
            break;
        case FORMAT_R9G9B9E5_SHAREDEXP:
            return MTLPixelFormatRGB9E5Float;
            break;
        case FORMAT_R8G8_B8G8_UNORM:
            return MTLPixelFormatBGRG422;
            break;
        case FORMAT_G8R8_G8B8_UNORM:
            return MTLPixelFormatGBGR422;
            break;
        case FORMAT_BC1_TYPELESS:
        case FORMAT_BC1_UNORM:
            return MTLPixelFormatBC1_RGBA;
            break;
        case FORMAT_BC1_UNORM_SRGB:
            return MTLPixelFormatBC1_RGBA_sRGB;
            break;
        case FORMAT_BC2_TYPELESS:
        case FORMAT_BC2_UNORM:
            return MTLPixelFormatBC2_RGBA;
            break;
        case FORMAT_BC2_UNORM_SRGB:
            return MTLPixelFormatBC2_RGBA_sRGB;
            break;
        case FORMAT_BC3_TYPELESS:
        case FORMAT_BC3_UNORM:
            return MTLPixelFormatBC3_RGBA;
            break;
        case FORMAT_BC3_UNORM_SRGB:
            return MTLPixelFormatBC3_RGBA_sRGB;
            break;
        case FORMAT_BC4_TYPELESS:
        case FORMAT_BC4_UNORM:
            return MTLPixelFormatBC4_RUnorm;
            break;
        case FORMAT_BC4_SNORM:
            return MTLPixelFormatBC4_RSnorm;
            break;
        case FORMAT_BC5_TYPELESS:
        case FORMAT_BC5_UNORM:
            return MTLPixelFormatBC5_RGUnorm;
            break;
        case FORMAT_BC5_SNORM:
            return MTLPixelFormatBC5_RGSnorm;
            break;
        case FORMAT_B5G6R5_UNORM:
#if TARGET_OS_OSX
            return MTLPixelFormatInvalid;
#else
            return MTLPixelFormatB5G6R5Unorm;
#endif
            break;
        case FORMAT_B5G5R5A1_UNORM:
#if TARGET_OS_OSX
            return MTLPixelFormatInvalid;
#else
            return MTLPixelFormatA1BGR5Unorm;
#endif
            break;
        case FORMAT_B8G8R8A8_UNORM:
        case FORMAT_B8G8R8X8_UNORM:
            return MTLPixelFormatBGRA8Unorm;
            break;
        case FORMAT_R10G10B10_XR_BIAS_A2_UNORM:
            return MTLPixelFormatBGR10A2Unorm;
            break;
        case FORMAT_B8G8R8A8_TYPELESS:
            return MTLPixelFormatBGRA8Unorm;
            break;
        case FORMAT_B8G8R8A8_UNORM_SRGB:
            return MTLPixelFormatBGRA8Unorm_sRGB;
            break;
        case FORMAT_B8G8R8X8_TYPELESS:
            return MTLPixelFormatBGRA8Unorm;
            break;
        case FORMAT_B8G8R8X8_UNORM_SRGB:
            return MTLPixelFormatBGRA8Unorm_sRGB;
            break;
        case FORMAT_BC6H_TYPELESS:
        case FORMAT_BC6H_UF16:
            return MTLPixelFormatBC6H_RGBUfloat;
            break;
        case FORMAT_BC6H_SF16:
            return MTLPixelFormatBC6H_RGBFloat;
            break;
        case FORMAT_BC7_TYPELESS:
        case FORMAT_BC7_UNORM:
            return MTLPixelFormatBC7_RGBAUnorm;
            break;
        case FORMAT_BC7_UNORM_SRGB:
            return MTLPixelFormatBC7_RGBAUnorm_sRGB;
            break;
        case FORMAT_AYUV:
        case FORMAT_Y410:
        case FORMAT_Y416:
        case FORMAT_NV12:
        case FORMAT_P010:
        case FORMAT_P016:
        case FORMAT_420_OPAQUE:
        case FORMAT_YUY2:
        case FORMAT_Y210:
        case FORMAT_Y216:
        case FORMAT_NV11:
        case FORMAT_AI44:
        case FORMAT_IA44:
        case FORMAT_P8:
        case FORMAT_A8P8:
            return MTLPixelFormatInvalid;
            break;
        case FORMAT_B4G4R4A4_UNORM:
#if TARGET_OS_OSX
            return MTLPixelFormatInvalid;
#else
            return MTLPixelFormatABGR4Unorm;
#endif
            break;
        case FORMAT_FORCE_UINT:
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
            case FORMAT_R32G32B32A32_FLOAT:
                return MTLVertexFormatFloat4;
                break;
            case FORMAT_R32G32B32A32_UINT:
                return MTLVertexFormatUInt4;
                break;
            case FORMAT_R32G32B32A32_SINT:
                return MTLVertexFormatInt4;
                break;
            case FORMAT_R32G32B32_FLOAT:
                return MTLVertexFormatFloat3;
                break;
            case FORMAT_R32G32B32_UINT:
                return MTLVertexFormatUInt3;
                break;
            case FORMAT_R32G32B32_SINT:
                return MTLVertexFormatInt3;
                break;
            case FORMAT_R16G16B16A16_FLOAT:
                return MTLVertexFormatHalf4;
                break;
            case FORMAT_R16G16B16A16_UNORM:
                return MTLVertexFormatUShort4Normalized;
                break;
            case FORMAT_R16G16B16A16_UINT:
                return MTLVertexFormatUShort4;
                break;
            case FORMAT_R16G16B16A16_SNORM:
                return MTLVertexFormatShort4Normalized;
                break;
            case FORMAT_R16G16B16A16_SINT:
                return MTLVertexFormatShort4;
                break;
            case FORMAT_R32G32_FLOAT:
                return MTLVertexFormatFloat2;
                break;
            case FORMAT_R32G32_UINT:
                return MTLVertexFormatUInt2;
                break;
            case FORMAT_R32G32_SINT:
                return MTLVertexFormatInt2;
                break;
            case FORMAT_R10G10B10A2_UINT:
                return MTLVertexFormatUInt1010102Normalized;
                break;
            case FORMAT_R8G8B8A8_UNORM:
                return MTLVertexFormatUChar4Normalized;
                break;
            case FORMAT_R8G8B8A8_UINT:
                return MTLVertexFormatUChar4;
                break;
            case FORMAT_R8G8B8A8_SNORM:
                return MTLVertexFormatChar4Normalized;
                break;
            case FORMAT_R8G8B8A8_SINT:
                return MTLVertexFormatChar4;
                break;
            case FORMAT_R16G16_FLOAT:
                return MTLVertexFormatHalf2;
                break;
            case FORMAT_R16G16_UNORM:
                return MTLVertexFormatUShort2Normalized;
                break;
            case FORMAT_R16G16_UINT:
                return MTLVertexFormatUShort2;
                break;
            case FORMAT_R16G16_SNORM:
                return MTLVertexFormatShort2Normalized;
                break;
            case FORMAT_R16G16_SINT:
                return MTLVertexFormatShort2;
                break;
            case FORMAT_R32_FLOAT:
                return MTLVertexFormatFloat;
                break;
            case FORMAT_R32_UINT:
                return MTLVertexFormatUInt;
                break;
            case FORMAT_R32_SINT:
                return MTLVertexFormatInt;
                break;
            case FORMAT_R8G8_UNORM:
                return MTLVertexFormatUChar2Normalized;
                break;
            case FORMAT_R8G8_UINT:
                return MTLVertexFormatUChar2;
                break;
            case FORMAT_R8G8_SNORM:
                return MTLVertexFormatChar2Normalized;
                break;
            case FORMAT_R8G8_SINT:
                return MTLVertexFormatChar2;
                break;
            case FORMAT_R16_FLOAT:
                return MTLVertexFormatHalf;
                break;
            case FORMAT_R16_UNORM:
                return MTLVertexFormatUShortNormalized;
                break;
            case FORMAT_R16_UINT:
                return MTLVertexFormatUShort;
                break;
            case FORMAT_R16_SNORM:
                return MTLVertexFormatShortNormalized;
                break;
            case FORMAT_R16_SINT:
                return MTLVertexFormatShort;
                break;
            case FORMAT_R8_UNORM:
                return MTLVertexFormatUCharNormalized;
                break;
            case FORMAT_R8_UINT:
                return MTLVertexFormatUChar;
                break;
            case FORMAT_R8_SNORM:
                return MTLVertexFormatCharNormalized;
                break;
            case FORMAT_R8_SINT:
                return MTLVertexFormatChar;
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
        case COMPARISON_LESS:
            return MTLCompareFunctionLess;
            break;
        case COMPARISON_EQUAL:
            return MTLCompareFunctionEqual;
            break;
        case COMPARISON_LESS_EQUAL:
            return MTLCompareFunctionLessEqual;
            break;
        case COMPARISON_GREATER:
            return MTLCompareFunctionGreater;
            break;
        case COMPARISON_NOT_EQUAL:
            return MTLCompareFunctionNotEqual;
            break;
        case COMPARISON_GREATER_EQUAL:
            return MTLCompareFunctionGreaterEqual;
            break;
        case COMPARISON_ALWAYS:
            return MTLCompareFunctionAlways;
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
        case BLEND_ONE:
            return MTLBlendFactorOne;
            break;
        case BLEND_SRC_COLOR:
            return MTLBlendFactorSourceColor;
            break;
        case BLEND_INV_SRC_COLOR:
            return MTLBlendFactorOneMinusSourceColor;
            break;
        case BLEND_SRC_ALPHA:
            return MTLBlendFactorSourceAlpha;
            break;
        case BLEND_INV_SRC_ALPHA:
            return MTLBlendFactorOneMinusSourceAlpha;
            break;
        case BLEND_DEST_ALPHA:
            return MTLBlendFactorDestinationAlpha;
            break;
        case BLEND_INV_DEST_ALPHA:
            return MTLBlendFactorOneMinusDestinationAlpha;
            break;
        case BLEND_DEST_COLOR:
            return MTLBlendFactorDestinationColor;
            break;
        case BLEND_INV_DEST_COLOR:
            return MTLBlendFactorOneMinusDestinationColor;
            break;
        case BLEND_SRC_ALPHA_SAT:
            return MTLBlendFactorSourceAlphaSaturated;
            break;
        case BLEND_BLEND_FACTOR:
            return MTLBlendFactorBlendColor;
            break;
        case BLEND_INV_BLEND_FACTOR:
            return MTLBlendFactorOneMinusBlendColor;
            break;
        case BLEND_SRC1_COLOR:
            return MTLBlendFactorSource1Color;
            break;
        case BLEND_INV_SRC1_COLOR:
            return MTLBlendFactorOneMinusSource1Color;
            break;
        case BLEND_SRC1_ALPHA:
            return MTLBlendFactorSource1Alpha;
            break;
        case BLEND_INV_SRC1_ALPHA:
            return MTLBlendFactorOneMinusSource1Alpha;
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
        case BLEND_OP_SUBTRACT:
            return MTLBlendOperationSubtract;
            break;
        case BLEND_OP_REV_SUBTRACT:
            return MTLBlendOperationReverseSubtract;
            break;
        case BLEND_OP_MIN:
            return MTLBlendOperationMin;
            break;
        case BLEND_OP_MAX:
            return MTLBlendOperationMax;
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
            return MTLSamplerAddressModeRepeat;
			break;
        case TEXTURE_ADDRESS_MIRROR:
            return MTLSamplerAddressModeMirrorRepeat;
            break;
        case TEXTURE_ADDRESS_CLAMP:
            return MTLSamplerAddressModeClampToEdge;
            break;
        case TEXTURE_ADDRESS_BORDER:
            return MTLSamplerAddressModeClampToBorderColor;
            break;
        case TEXTURE_ADDRESS_MIRROR_ONCE:
            return MTLSamplerAddressModeMirrorClampToEdge;
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
        _inFlightSemaphore = dispatch_semaphore_create(BACKBUFFER_COUNT);
        _view = BRIDGE_RES1(MTKView, window);

        wiBackLog::post("Created GraphicsDevice_Metal");
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
    
    const Texture2D &GraphicsDevice_Metal::GetBackBuffer()
    {
        return GetFrameResources().backBuffer;
    }

	HRESULT GraphicsDevice_Metal::CreateBuffer(const GPUBufferDesc *pDesc, const SubresourceData* pInitialData, GPUBuffer *pBuffer)
	{
        pBuffer->type = GPUResource::BUFFER;
		pBuffer->Register(this);
		pBuffer->desc = *pDesc;
        MTLResourceOptions option = MTLResourceStorageModeShared;
        id <MTLBuffer> buffer = nil;
        if (pInitialData != nullptr)
            buffer = [_device newBufferWithBytes:pInitialData->pSysMem length:pDesc->ByteWidth options:option];
        else
            buffer = [_device newBufferWithLength:pDesc->ByteWidth options:option];
        pBuffer->resource = RETAIN_RES(buffer);
		return S_OK;
	}

    HRESULT GraphicsDevice_Metal::CreateTexture1D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture1D *pTexture1D)
    {
        pTexture1D->type = GPUResource::TEXTURE_1D;
        pTexture1D->Register(this);
        
        return S_OK;
    }
    
	HRESULT GraphicsDevice_Metal::CreateTexture2D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture2D *pTexture2D)
	{
        pTexture2D->type = GPUResource::TEXTURE_2D;
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
        texDesc.storageMode = MTLStorageModePrivate;
        id <MTLTexture> mtlTex = [_device newTextureWithDescriptor:texDesc];
        pTexture2D->resource = RETAIN_RES(mtlTex);

		// Issue data copy on request:
		if (pInitialData != nullptr)
		{
            MTLOrigin tex_origin = { 0, 0, 0 };
            MTLSize tex_size = {texDesc.width, texDesc.height, 1};
//            MTLRegion region = {
//                tex_origin,                   // MTLOrigin
//                tex_size  // MTLSize
//            };
//            [mtlTex replaceRegion:region mipmapLevel:0 withBytes:pInitialData->pSysMem bytesPerRow:pInitialData->SysMemPitch];
            id <MTLBlitCommandEncoder> blitEnc = [_commandBuffer blitCommandEncoder];
            id <MTLBuffer> tempBuffer = [_device newBufferWithBytes:pInitialData->pSysMem length:pInitialData->SysMemPitch * texDesc.height options:MTLResourceStorageModeManaged];
            [blitEnc copyFromBuffer:tempBuffer sourceOffset:0 sourceBytesPerRow:pInitialData->SysMemPitch sourceBytesPerImage:pInitialData->SysMemPitch * texDesc.height sourceSize:tex_size toTexture:mtlTex destinationSlice:0 destinationLevel:0 destinationOrigin:tex_origin];
//            [blitEnc generateMipmapsForTexture:mtlTex];
            [blitEnc endEncoding];
		}

		return S_OK;
	}
    
    HRESULT GraphicsDevice_Metal::CreateTexture3D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture3D *pTexture3D)
    {
        pTexture3D->type = GPUResource::TEXTURE_3D;
        pTexture3D->Register(this);

        return S_OK;
    }
    
    HRESULT GraphicsDevice_Metal::CreateInputLayout(const VertexLayoutDesc *pInputElementDescs, UINT NumElements, const ShaderByteCode* shaderCode, VertexLayout *pInputLayout)
    {
        pInputLayout->Register(this);
        MTLVertexDescriptor *vertexDesc = [[MTLVertexDescriptor alloc] init];
        uint32_t offset = 0;
        uint32_t lastBuffer = 0;
        int attrib_index = 0;
        std::vector<uint32_t> vertex_stride;
        for (UINT i = 0; i < NumElements; ++i)
        {
            const VertexLayoutDesc &x = pInputElementDescs[i];
            if (x.InputSlot != lastBuffer) {
                attrib_index = 0;
                vertex_stride.push_back(offset);
                lastBuffer = x.InputSlot;
                offset = 0;
            }
            vertexDesc.attributes[attrib_index].bufferIndex = x.InputSlot;
            vertexDesc.attributes[attrib_index].format = _ConvertVertexFormat(x.Format);
            UINT off = x.AlignedByteOffset;
            if (off == VertexLayoutDesc::APPEND_ALIGNED_ELEMENT)
            {
                // need to manually resolve this from the format spec.
                off = offset;
            }
            vertexDesc.attributes[attrib_index].offset = off;
            offset += GetFormatStride(x.Format);
            ++attrib_index;
        }
        vertex_stride.push_back(offset);
        for (UINT i = 0; i < NumElements; ++i)
        {
            const VertexLayoutDesc &x = pInputElementDescs[i];
            UINT slot = x.InputSlot;
            vertexDesc.layouts[slot].stride = vertex_stride[slot];
            MTLVertexStepFunction func = _ConvertInputClassification(x.InputSlotClass);
            vertexDesc.layouts[slot].stepFunction = func;
            //dx12 specifies step rate must be 0 for an element that contains per-vertex data, but metal validator say it must be 1
            //so just don't set it for metal, which have a default value of 1 for step rate
            if (func == MTLVertexStepFunctionPerInstance) vertexDesc.layouts[slot].stepRate = x.InstanceDataStepRate;
        }
        pInputLayout->resource = RETAIN_RES(vertexDesc);

        return S_OK;
    }
    
    HRESULT GraphicsDevice_Metal::CreateVertexShader(const ShaderByteCode *pCode, VertexShader *pVertexShader)
    {
        pVertexShader->Register(this);
        
        pVertexShader->code.ShaderName = pCode->ShaderName;
        id <MTLFunction> func = [_library newFunctionWithName:[NSString stringWithUTF8String:pCode->ShaderName.c_str()]];
        pVertexShader->resource = RETAIN_RES(func);
        
        return func == nil ? S_OK : E_FAIL;
    }
    HRESULT GraphicsDevice_Metal::CreatePixelShader(const ShaderByteCode *pCode, PixelShader *pPixelShader)
    {
        pPixelShader->Register(this);
        
        pPixelShader->code.ShaderName = pCode->ShaderName;
        id <MTLFunction> func = [_library newFunctionWithName:[NSString stringWithUTF8String:pCode->ShaderName.c_str()]];
        pPixelShader->resource = RETAIN_RES(func);
        
        return func == nil ? S_OK : E_FAIL;
    }
    HRESULT GraphicsDevice_Metal::CreateGeometryShader(const ShaderByteCode *pCode, GeometryShader *pGeometryShader)
    {
        
        return E_FAIL;
    }
    HRESULT GraphicsDevice_Metal::CreateHullShader(const ShaderByteCode *pCode, HullShader *pHullShader)
    {
        
        return E_FAIL;
    }
    HRESULT GraphicsDevice_Metal::CreateDomainShader(const ShaderByteCode *pCode, DomainShader *pDomainShader)
    {
        
        return E_FAIL;
    }
    HRESULT GraphicsDevice_Metal::CreateComputeShader(const ShaderByteCode *pCode, ComputeShader *pComputeShader)
    {
        pComputeShader->Register(this);
        
        pComputeShader->code.ShaderName = pCode->ShaderName;
        id <MTLFunction> func = [_library newFunctionWithName:[NSString stringWithUTF8String:pCode->ShaderName.c_str()]];
        pComputeShader->resource = RETAIN_RES(func);
        
        return func == nil ? S_OK : E_FAIL;
    }
    HRESULT GraphicsDevice_Metal::CreateBlendState(const BlendStateDesc *pBlendStateDesc, BlendState *pBlendState)
    {
        pBlendState->Register(this);
        
        pBlendState->desc = *pBlendStateDesc;
        return S_OK;
    }
    HRESULT GraphicsDevice_Metal::CreateDepthStencilState(const DepthStencilStateDesc *pDepthStencilStateDesc, DepthStencilState *pDepthStencilState)
    {
        pDepthStencilState->Register(this);
        
        pDepthStencilState->desc = *pDepthStencilStateDesc;
        return S_OK;
    }
    HRESULT GraphicsDevice_Metal::CreateRasterizerState(const RasterizerStateDesc *pRasterizerStateDesc, RasterizerState *pRasterizerState)
    {
        pRasterizerState->Register(this);
        
        pRasterizerState->desc = *pRasterizerStateDesc;
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
        samplerDesc.borderColor = MTLSamplerBorderColorTransparentBlack;
		samplerDesc.normalizedCoordinates = TRUE;
        id <MTLSamplerState> sam_state = [_device newSamplerStateWithDescriptor:samplerDesc];
        pSamplerState->resource = RETAIN_RES(sam_state);

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
            pipelineDesc.vertexFunction = BRIDGE_RES(MTLFunction, pDesc->vs->resource);
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
            pipelineDesc.fragmentFunction = BRIDGE_RES(MTLFunction, pDesc->ps->resource);
        }
        
        //it's possible for pDesc->il to be null, as in a vertex shader that only uses uint vid [[vertex_id]] as input
        if (pDesc->il != nullptr) pipelineDesc.vertexDescriptor = BRIDGE_RES1(MTLVertexDescriptor, pDesc->il->resource);
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
        pso->pipeline = RETAIN_RES(mtl_pipeline);

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
            renderPassDesc.colorAttachments[i].loadAction = _ConvertLoadAction(pDesc->RenderTargets[i].BeginningAccess);
            renderPassDesc.colorAttachments[i].storeAction = _ConvertStoreAction(pDesc->RenderTargets[i].EndingAccess);
            if (renderPassDesc.colorAttachments[i].loadAction == MTLLoadActionClear) {
                const FLOAT *temp = pDesc->RenderTargets[i].Clear.Color;
                renderPassDesc.colorAttachments[i].clearColor = MTLClearColorMake(temp[0], temp[1], temp[2], temp[3]);
            }
        }
        renderPassDesc.depthAttachment.loadAction = _ConvertLoadAction(static_cast<ACCESS_TYPE>(pDesc->DepthStencil.BeginningAccess & 0x0f));
        renderPassDesc.depthAttachment.storeAction = _ConvertStoreAction(static_cast<ACCESS_TYPE>(pDesc->DepthStencil.EndingAccess & 0x0f));
        if (renderPassDesc.depthAttachment.loadAction == MTLLoadActionClear)
            renderPassDesc.depthAttachment.clearDepth = pDesc->DepthStencil.Clear.DepthStencil.Depth;
        renderPassDesc.stencilAttachment.loadAction = _ConvertLoadAction(static_cast<ACCESS_TYPE>(pDesc->DepthStencil.BeginningAccess & 0xf0));
        renderPassDesc.stencilAttachment.storeAction = _ConvertStoreAction(static_cast<ACCESS_TYPE>(pDesc->DepthStencil.EndingAccess & 0xf0));
        if (renderPassDesc.stencilAttachment.loadAction == MTLLoadActionClear)
            renderPassDesc.stencilAttachment.clearStencil = pDesc->DepthStencil.Clear.DepthStencil.Stencil;
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
    void GraphicsDevice_Metal::DestroyRenderPass(RenderPass* pRenderPass)
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

    void GraphicsDevice_Metal::NextSubPass(GRAPHICSTHREAD threadID)
    {
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
	void GraphicsDevice_Metal::BindRenderTargets(UINT NumViews, const Texture2D* const *ppRenderTargets, const Texture2D* depthStencilTexture, GRAPHICSTHREAD threadID, int arrayIndex)
	{
		assert(NumViews <= 8);

	}
	void GraphicsDevice_Metal::ClearRenderTarget(const Texture* pTexture, const FLOAT ColorRGBA[4], GRAPHICSTHREAD threadID, int arrayIndex)
	{
	}
	void GraphicsDevice_Metal::ClearDepthStencil(const Texture2D* pTexture, UINT ClearFlags, FLOAT Depth, UINT8 Stencil, GRAPHICSTHREAD threadID, int arrayIndex)
	{
	}
	void GraphicsDevice_Metal::BindResource(SHADERSTAGE stage, const GPUResource* resource, UINT slot, GRAPHICSTHREAD threadID, int arrayIndex)
	{
		assert(slot < GPU_RESOURCE_HEAP_SRV_COUNT);

        if (resource != nullptr && resource->resource != WI_NULL_HANDLE)
        {
            const Texture* tex = dynamic_cast<const Texture*>(resource);
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
                const GPUBuffer* buffer = dynamic_cast<const GPUBuffer*>(resource);
                if (buffer != nullptr && buffer->resource != WI_NULL_HANDLE)
                    BindConstantBuffer(stage, buffer, slot, threadID);
            }
        }
	}
	void GraphicsDevice_Metal::BindResources(SHADERSTAGE stage, const GPUResource *const* resources, UINT slot, UINT count, GRAPHICSTHREAD threadID)
	{
		if (resources != nullptr)
		{
			for (UINT i = 0; i < count; ++i)
			{
				BindResource(stage, resources[i], slot + i, threadID, -1);
			}
		}
	}
	void GraphicsDevice_Metal::BindUAV(SHADERSTAGE stage, const GPUResource* resource, UINT slot, GRAPHICSTHREAD threadID, int arrayIndex)
	{
		assert(slot < GPU_RESOURCE_HEAP_UAV_COUNT);

	}
	void GraphicsDevice_Metal::BindUAVs(SHADERSTAGE stage, const GPUResource *const* resources, UINT slot, UINT count, GRAPHICSTHREAD threadID)
	{
		if (resources != nullptr)
		{
			for (UINT i = 0; i < count; ++i)
			{
				BindUAV(stage, resources[i], slot + i, threadID, -1);
			}
		}
	}
	void GraphicsDevice_Metal::UnbindResources(UINT slot, UINT num, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::UnbindUAVs(UINT slot, UINT num, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::BindSampler(SHADERSTAGE stage, const Sampler* sampler, UINT slot, GRAPHICSTHREAD threadID)
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
	void GraphicsDevice_Metal::BindConstantBuffer(SHADERSTAGE stage, const GPUBuffer* buffer, UINT slot, GRAPHICSTHREAD threadID)
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
	void GraphicsDevice_Metal::BindVertexBuffers(const GPUBuffer* const *vertexBuffers, UINT slot, UINT count, const UINT* strides, const UINT* offsets, GRAPHICSTHREAD threadID)
	{
		NSUInteger voffsets[8] = {};
		id <MTLBuffer> vbuffers[8] = {};
		assert(count <= 8);
        bool valid = offsets == nullptr ? false : true;
		for (UINT i = 0; i < count; ++i)
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
	void GraphicsDevice_Metal::BindIndexBuffer(const GPUBuffer* _indexBuffer, const INDEXBUFFER_FORMAT format, UINT offset, GRAPHICSTHREAD threadID)
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
	void GraphicsDevice_Metal::BindBlendFactor(float r, float g, float b, float a, GRAPHICSTHREAD threadID)
	{
        [GetDirectCommandList(threadID) setBlendColorRed:r green:g blue:b alpha:a];
	}
	void GraphicsDevice_Metal::BindGraphicsPSO(const GraphicsPSO* pso, GRAPHICSTHREAD threadID)
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
	void GraphicsDevice_Metal::BindComputePSO(const ComputePSO* pso, GRAPHICSTHREAD threadID)
	{
        [_computeEnc setComputePipelineState:BRIDGE_RES(MTLComputePipelineState, pso->pipeline)];
	}
	void GraphicsDevice_Metal::Draw(UINT vertexCount, UINT startVertexLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawPrimitives:info.primType vertexStart:startVertexLocation vertexCount:vertexCount];
	}
	void GraphicsDevice_Metal::DrawIndexed(UINT indexCount, UINT startIndexLocation, UINT baseVertexLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawIndexedPrimitives:info.primType indexCount:indexCount indexType:info.indexType indexBuffer:info.indexBuffer indexBufferOffset:info.indexOffset instanceCount:1 baseVertex:baseVertexLocation baseInstance:0];
	}
	void GraphicsDevice_Metal::DrawInstanced(UINT vertexCount, UINT instanceCount, UINT startVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawPrimitives:info.primType vertexStart:startVertexLocation vertexCount:vertexCount instanceCount:instanceCount baseInstance:startInstanceLocation];
	}
	void GraphicsDevice_Metal::DrawIndexedInstanced(UINT indexCount, UINT instanceCount, UINT startIndexLocation, UINT baseVertexLocation, UINT startInstanceLocation, GRAPHICSTHREAD threadID)
	{
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawIndexedPrimitives:info.primType indexCount:indexCount indexType:info.indexType indexBuffer:info.indexBuffer indexBufferOffset:info.indexOffset instanceCount:instanceCount baseVertex:baseVertexLocation baseInstance:startInstanceLocation];
	}
	void GraphicsDevice_Metal::DrawInstancedIndirect(const GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID)
	{
        if (args == nullptr) return;
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawPrimitives:info.primType indirectBuffer:BRIDGE_RES(MTLBuffer, args->resource) indirectBufferOffset:args_offset];
	}
	void GraphicsDevice_Metal::DrawIndexedInstancedIndirect(const GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID)
	{
        if (args == nullptr) return;
        FrameResources::DrawInfo &info = GetFrameResources().drawInfo[threadID];
        [info.commandLists drawIndexedPrimitives:info.primType indexType:info.indexType indexBuffer:info.indexBuffer indexBufferOffset:info.indexOffset indirectBuffer:BRIDGE_RES(MTLBuffer, args->resource) indirectBufferOffset:args_offset];
	}
	void GraphicsDevice_Metal::Dispatch(UINT threadGroupCountX, UINT threadGroupCountY, UINT threadGroupCountZ, GRAPHICSTHREAD threadID)
	{
        [_computeEnc dispatchThreadgroups:MTLSizeMake(threadGroupCountX, threadGroupCountY, threadGroupCountZ) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
	}
	void GraphicsDevice_Metal::DispatchIndirect(const GPUBuffer* args, UINT args_offset, GRAPHICSTHREAD threadID)
	{
        if (args == nullptr) return;
        [_computeEnc dispatchThreadgroupsWithIndirectBuffer:BRIDGE_RES(MTLBuffer, args->resource) indirectBufferOffset:args_offset threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
	}
	void GraphicsDevice_Metal::CopyTexture2D(const Texture2D* pDst, const Texture2D* pSrc, GRAPHICSTHREAD threadID)
	{
        id <MTLBlitCommandEncoder> blitEnc = [_commandBuffer blitCommandEncoder];
        [blitEnc copyFromTexture:BRIDGE_RES(MTLTexture, pSrc->resource) sourceSlice:0 sourceLevel:0 sourceOrigin:{0,0,0} sourceSize:MTLSizeMake(pSrc->desc.Width, pSrc->desc.Height, 1) toTexture:BRIDGE_RES(MTLTexture, pDst->resource) destinationSlice:0 destinationLevel:0 destinationOrigin:{0,0,0}];
        [blitEnc endEncoding];
	}
	void GraphicsDevice_Metal::CopyTexture2D_Region(const Texture2D* pDst, UINT dstMip, UINT dstX, UINT dstY, const Texture2D* pSrc, UINT srcMip, GRAPHICSTHREAD threadID)
	{
        id <MTLBlitCommandEncoder> blitEnc = [_commandBuffer blitCommandEncoder];
        [blitEnc copyFromTexture:BRIDGE_RES(MTLTexture, pSrc->resource) sourceSlice:0 sourceLevel:srcMip sourceOrigin:{0,0,0} sourceSize:MTLSizeMake(pSrc->desc.Width, pSrc->desc.Height, 1) toTexture:BRIDGE_RES(MTLTexture, pDst->resource) destinationSlice:0 destinationLevel:dstMip destinationOrigin:{dstX,dstY,0}];
        [blitEnc endEncoding];
	}
	void GraphicsDevice_Metal::MSAAResolve(const Texture2D* pDst, const Texture2D* pSrc, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::UpdateBuffer(const GPUBuffer* buffer, const void* data, GRAPHICSTHREAD threadID, int dataSize)
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
	bool GraphicsDevice_Metal::DownloadResource(const GPUResource* resourceToDownload, const GPUResource* resourceDest, void* dataDest, GRAPHICSTHREAD threadID)
	{
		return false;
	}

	void GraphicsDevice_Metal::QueryBegin(const GPUQuery *query, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::QueryEnd(const GPUQuery *query, GRAPHICSTHREAD threadID)
	{
	}
	bool GraphicsDevice_Metal::QueryRead(const GPUQuery *query, GPUQueryResult* result)
	{
		return true;
	}

	void GraphicsDevice_Metal::UAVBarrier(const GPUResource *const* uavs, UINT NumBarriers, GRAPHICSTHREAD threadID)
	{
	}
	void GraphicsDevice_Metal::TransitionBarrier(const GPUResource *const* resources, UINT NumBarriers, RESOURCE_STATES stateBefore, RESOURCE_STATES stateAfter, GRAPHICSTHREAD threadID)
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
