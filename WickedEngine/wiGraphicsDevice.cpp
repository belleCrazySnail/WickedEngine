#include "wiGraphicsDevice.h"

using namespace wiGraphicsTypes;

bool GraphicsDevice::CheckCapability(GRAPHICSDEVICE_CAPABILITY capability) const
{
	switch (capability)
	{
	case wiGraphicsTypes::GraphicsDevice::GRAPHICSDEVICE_CAPABILITY_TESSELLATION:
		return TESSELLATION;
		break;
	case wiGraphicsTypes::GraphicsDevice::GRAPHICSDEVICE_CAPABILITY_MULTITHREADED_RENDERING:
		return MULTITHREADED_RENDERING;
		break;
	case wiGraphicsTypes::GraphicsDevice::GRAPHICSDEVICE_CAPABILITY_CONSERVATIVE_RASTERIZATION:
		return CONSERVATIVE_RASTERIZATION;
		break;
	case wiGraphicsTypes::GraphicsDevice::GRAPHICSDEVICE_CAPABILITY_RASTERIZER_ORDERED_VIEWS:
		return RASTERIZER_ORDERED_VIEWS;
		break;
	case wiGraphicsTypes::GraphicsDevice::GRAPHICSDEVICE_CAPABILITY_UNORDEREDACCESSTEXTURE_LOAD_FORMAT_EXT:
		return UNORDEREDACCESSTEXTURE_LOAD_EXT;
		break;
	default:
		break;
	}
	return false;
}

uint32_t GraphicsDevice::GetFormatStride(FORMAT value) const
{
	switch (value)
	{
	case FORMAT_R32G32B32A32_FLOAT:
		return 16;
	case FORMAT_R32G32_FLOAT:
	case FORMAT_R32G32_UINT:
	case FORMAT_R32G32_SINT:
	case FORMAT_R16G16B16A16_FLOAT:
		return 8;
	case FORMAT_R11G11B10_FLOAT:
	case FORMAT_R16G16_FLOAT:
	case FORMAT_R16G16_UINT:
	case FORMAT_R16G16_SINT:
	case FORMAT_R32_FLOAT:
	case FORMAT_R32_UINT:
	case FORMAT_R8G8B8A8_UINT:
	case FORMAT_R8G8B8A8_SINT:
	case FORMAT_R8G8B8A8_UNORM:
	case FORMAT_R8G8B8A8_SNORM:
	case FORMAT_R10G10B10A2_UNORM:
		return 4;
	case FORMAT_R16_FLOAT:
	case FORMAT_R16_UINT:
	case FORMAT_R16_SINT:
	case FORMAT_R16_UNORM:
	case FORMAT_R16_SNORM:
		return 2;
	case FORMAT_R8_TYPELESS:
	case FORMAT_R8_UNORM:
	case FORMAT_R8_SNORM:
	case FORMAT_R8_UINT:
	case FORMAT_R8_SINT:
	case FORMAT_A8_UNORM:
		return 1;
	default:
		assert(0);
		break;
	}

	// Probably didn't catch all...

	return 16;
}

bool GraphicsDevice::IsFormatUnorm(FORMAT value) const
{
	switch (value)
	{
	case FORMAT_B8G8R8A8_UNORM:
	case FORMAT_R8G8B8A8_UNORM:
	case FORMAT_R10G10B10A2_UNORM:
	case FORMAT_R16_UNORM:
	case FORMAT_R8_UNORM:
	case FORMAT_A8_UNORM:
		return true;
	}

	// Probably didn't catch all...

	return false;
}

Texture2D GraphicsDevice::GetBackBuffer()
{
    return Texture2D();
}

HRESULT GraphicsDevice::CreateTexture1D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture1D *pTexture1D)
{
    if (pTexture1D == nullptr)
    {
        pTexture1D = new Texture1D;
    }
    pTexture1D->Register(this);
    
    pTexture1D->desc = *pDesc;
    
    return E_FAIL;
}
HRESULT GraphicsDevice::CreateTexture3D(const TextureDesc* pDesc, const SubresourceData *pInitialData, Texture3D *pTexture3D)
{
    pTexture3D->Register(this);
    
    pTexture3D->desc = *pDesc;
    
    return E_FAIL;
}
HRESULT GraphicsDevice::CreateInputLayout(const VertexLayoutDesc *pInputElementDescs, UINT NumElements, const ShaderByteCode* shaderCode, VertexLayout *pInputLayout)
{
    pInputLayout->Register(this);
    
    pInputLayout->desc.reserve((size_t)NumElements);
    for (UINT i = 0; i < NumElements; ++i)
    {
        pInputLayout->desc.push_back(pInputElementDescs[i]);
    }
    
    return S_OK;
}
HRESULT GraphicsDevice::CreateVertexShader(const std::string &shaderName, const void *pShaderBytecode, SIZE_T BytecodeLength, VertexShader *pVertexShader)
{
    pVertexShader->Register(this);
    
    pVertexShader->code.ShaderName = shaderName;
    pVertexShader->code.data = new BYTE[BytecodeLength];
    memcpy(pVertexShader->code.data, pShaderBytecode, BytecodeLength);
    pVertexShader->code.size = BytecodeLength;
    
    return (pVertexShader->code.data != nullptr && pVertexShader->code.size > 0 ? S_OK : E_FAIL);
}
HRESULT GraphicsDevice::CreatePixelShader(const std::string &shaderName, const void *pShaderBytecode, SIZE_T BytecodeLength, PixelShader *pPixelShader)
{
    pPixelShader->Register(this);
    
    pPixelShader->code.ShaderName = shaderName;
    pPixelShader->code.data = new BYTE[BytecodeLength];
    memcpy(pPixelShader->code.data, pShaderBytecode, BytecodeLength);
    pPixelShader->code.size = BytecodeLength;
    
    return (pPixelShader->code.data != nullptr && pPixelShader->code.size > 0 ? S_OK : E_FAIL);
}
HRESULT GraphicsDevice::CreateGeometryShader(const std::string &shaderName, const void *pShaderBytecode, SIZE_T BytecodeLength, GeometryShader *pGeometryShader)
{
    pGeometryShader->Register(this);
    
    pGeometryShader->code.ShaderName = shaderName;
    pGeometryShader->code.data = new BYTE[BytecodeLength];
    memcpy(pGeometryShader->code.data, pShaderBytecode, BytecodeLength);
    pGeometryShader->code.size = BytecodeLength;
    
    return (pGeometryShader->code.data != nullptr && pGeometryShader->code.size > 0 ? S_OK : E_FAIL);
}
HRESULT GraphicsDevice::CreateHullShader(const std::string &shaderName, const void *pShaderBytecode, SIZE_T BytecodeLength, HullShader *pHullShader)
{
    pHullShader->Register(this);
    
    pHullShader->code.ShaderName = shaderName;
    pHullShader->code.data = new BYTE[BytecodeLength];
    memcpy(pHullShader->code.data, pShaderBytecode, BytecodeLength);
    pHullShader->code.size = BytecodeLength;
    
    return (pHullShader->code.data != nullptr && pHullShader->code.size > 0 ? S_OK : E_FAIL);
}
HRESULT GraphicsDevice::CreateDomainShader(const std::string &shaderName, const void *pShaderBytecode, SIZE_T BytecodeLength, DomainShader *pDomainShader)
{
    pDomainShader->Register(this);
    
    pDomainShader->code.ShaderName = shaderName;
    pDomainShader->code.data = new BYTE[BytecodeLength];
    memcpy(pDomainShader->code.data, pShaderBytecode, BytecodeLength);
    pDomainShader->code.size = BytecodeLength;
    
    return (pDomainShader->code.data != nullptr && pDomainShader->code.size > 0 ? S_OK : E_FAIL);
}
HRESULT GraphicsDevice::CreateComputeShader(const std::string &shaderName, const void *pShaderBytecode, SIZE_T BytecodeLength, ComputeShader *pComputeShader)
{
    pComputeShader->Register(this);
    
    pComputeShader->code.ShaderName = shaderName;
    pComputeShader->code.data = new BYTE[BytecodeLength];
    memcpy(pComputeShader->code.data, pShaderBytecode, BytecodeLength);
    pComputeShader->code.size = BytecodeLength;
    
    return (pComputeShader->code.data != nullptr && pComputeShader->code.size > 0 ? S_OK : E_FAIL);
}
HRESULT GraphicsDevice::CreateBlendState(const BlendStateDesc *pBlendStateDesc, BlendState *pBlendState)
{
    pBlendState->Register(this);
    
    pBlendState->desc = *pBlendStateDesc;
    return S_OK;
}
HRESULT GraphicsDevice::CreateDepthStencilState(const DepthStencilStateDesc *pDepthStencilStateDesc, DepthStencilState *pDepthStencilState)
{
    pDepthStencilState->Register(this);
    
    pDepthStencilState->desc = *pDepthStencilStateDesc;
    return S_OK;
}
HRESULT GraphicsDevice::CreateRasterizerState(const RasterizerStateDesc *pRasterizerStateDesc, RasterizerState *pRasterizerState)
{
    pRasterizerState->Register(this);
    
    pRasterizerState->desc = *pRasterizerStateDesc;
    return S_OK;
}
