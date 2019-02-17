#ifndef _SHADERINTEROP_METAL_H_
#define _SHADERINTEROP_METAL_H_

#include "wiGraphicsDevice_SharedInternals.h"

// METAL Descriptor layout offsets:
#define METAL_DESCRIPTOR_SET_OFFSET_CBV				5

#define METAL_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE		METAL_DESCRIPTOR_SET_OFFSET_CBV + GPU_RESOURCE_HEAP_CBV_COUNT
#define METAL_DESCRIPTOR_SET_OFFSET_SRV_TYPEDBUFFER	METAL_DESCRIPTOR_SET_OFFSET_SRV_TEXTURE + GPU_RESOURCE_HEAP_SRV_COUNT
#define METAL_DESCRIPTOR_SET_OFFSET_SRV_UNTYPEDBUFFER	METAL_DESCRIPTOR_SET_OFFSET_SRV_TYPEDBUFFER + GPU_RESOURCE_HEAP_SRV_COUNT

#define METAL_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE		METAL_DESCRIPTOR_SET_OFFSET_SRV_UNTYPEDBUFFER + GPU_RESOURCE_HEAP_SRV_COUNT
#define METAL_DESCRIPTOR_SET_OFFSET_UAV_TYPEDBUFFER	METAL_DESCRIPTOR_SET_OFFSET_UAV_TEXTURE + GPU_RESOURCE_HEAP_UAV_COUNT
#define METAL_DESCRIPTOR_SET_OFFSET_UAV_UNTYPEDBUFFER	METAL_DESCRIPTOR_SET_OFFSET_UAV_TYPEDBUFFER + GPU_RESOURCE_HEAP_UAV_COUNT

#define METAL_DESCRIPTOR_SET_OFFSET_SAMPLER			METAL_DESCRIPTOR_SET_OFFSET_UAV_UNTYPEDBUFFER + GPU_RESOURCE_HEAP_UAV_COUNT


#endif // _SHADERINTEROP_METAL_H_

