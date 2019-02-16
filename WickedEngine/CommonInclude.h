#ifndef WICKEDENGINE_COMMONINCLUDE_H
#define WICKEDENGINE_COMMONINCLUDE_H

// This is a helper include file pasted into all engine headers try to keep it minimal!
// Do not include engine features in this file!


#ifdef _WIN32
// Platform specific:
#define NOMINMAX
#include <SDKDDKVer.h>
#include <windows.h>

#ifdef WINSTORE_SUPPORT
#include <Windows.UI.Core.h>
#endif // WINSTORE_SUPPORT

#if __has_include("vulkan/vulkan.h")
#define WICKEDENGINE_BUILD_VULKAN
#endif // HAS VULKAN

#define ALIGN_16 void* operator new(size_t i){return _mm_malloc(i, 16);} void operator delete(void* p){_mm_free(p);}


// Platform agnostic:
#include <DirectXMath.h>
#include <DirectXPackedVector.h>
#include <DirectXCollision.h>

#elif __APPLE__

#include <stddef.h>
#include <stdint.h>
typedef char BYTE;
typedef unsigned char UINT8;
typedef unsigned int UINT;
typedef int INT;
typedef long LONG;
typedef uint64_t UINT64;
typedef size_t SIZE_T;
typedef float FLOAT;

#include <float.h>
typedef uint32_t HRESULT;
#define S_OK 0x00000000
#define E_FAIL 0x80004005

#define SUCCEEDED(hr) (((HRESULT)(hr)) == 0)
#define FAILED(hr) (((HRESULT)(hr)) != 0)

#define ARRAYSIZE(x) (sizeof(x)/sizeof(0[x]))
#define ZeroMemory(d, l) memset((d), 0, (l))

#define _getcwd getcwd
#define _chdir chdir
#define strcpy_s strcpy

#define ALIGN_16

#define _XM_NO_INTRINSICS_
#include "DX/DirectXMath.h"
#include "DX/DirectXPackedVector.h"
#include "DX/DirectXCollision.h"

#endif //_WIN32

#include <algorithm>

#define SAFE_RELEASE(a) if((a)!=nullptr){(a)->Release();(a)=nullptr;}
#define SAFE_DELETE(a) if((a)!=nullptr){delete (a);(a)=nullptr;}
#define SAFE_DELETE_ARRAY(a) if((a)!=nullptr){delete[](a);(a)=nullptr;}
#define GFX_STRUCT struct alignas(16)
#define GFX_CLASS class alignas(16)

template <typename T>
inline void SwapPtr(T*& a, T*& b)
{
	T* swap = a;
	a = b;
	b = swap;
}

template<typename T>
inline void RECREATE(T*& myObject)
{
	SAFE_DELETE(myObject);
	myObject = new T;
}

using namespace DirectX;
using namespace DirectX::PackedVector;
static const XMFLOAT4X4 IDENTITYMATRIX = XMFLOAT4X4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);


#endif //WICKEDENGINE_COMMONINCLUDE_H
