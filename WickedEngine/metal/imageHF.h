#ifndef _IMAGEHF_
#define _IMAGEHF_
#include "globals.h"
#include "ShaderInterop_Image.h"

#define xTexture		gd.texture_0
#define xMaskTex		gd.texture_1
#define xDistortionTex	gd.texture_2

struct VertextoPixel
{
	float4 pos [[position]];
	float2 tex_original;
	float2 tex;
	float4 pos2D;
};
struct VertexToPixelPostProcess
{
	float4 pos [[position]];
	float2 tex;
};

#endif // _IMAGEHF_

