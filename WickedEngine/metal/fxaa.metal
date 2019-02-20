#include "imageHF.h"

#define FXAA_PC 1
#define FXAA_METAL 1
#define FXAA_GREEN_AS_LUMA 1
//#define FXAA_QUALITY__PRESET 12
#define FXAA_QUALITY__PRESET 25
//#define FXAA_QUALITY__PRESET 39
#include "fxaa.h"

static constant float fxaaSubpix = 0.75;
static constant float fxaaEdgeThreshold = 0.166;
static constant float fxaaEdgeThresholdMin = 0.0833;

fragment float4 fxaa(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
    float2 fxaaFrame;
    fxaaFrame.x = xTexture.get_width();
    fxaaFrame.y = xTexture.get_height();

    FxaaTex tex = { gd.customsampler0, xTexture };

    return FxaaPixelShader(PSIn.tex, 0, tex, tex, tex, 1 / fxaaFrame, 0, 0, 0, fxaaSubpix, fxaaEdgeThreshold, fxaaEdgeThresholdMin, 0, 0, 0, 0);
}
