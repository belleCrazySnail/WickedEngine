// This can retrieve better velocity vectors so moving objects could be better anti aliased:
#define DILATE_VELOCITY_BEST_3X3

#include "postProcessHF.h"
#include "reconstructPositionHF.h"

// This hack can improve bright areas:
#define HDR_CORRECTION

fragment float4 temporalAAResolvePS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float2 velocity = GetVelocity(int2(PSIn.pos.xy), gd);
	float2 prevTC = PSIn.tex + velocity;

	float4 neighborhood[9];
	neighborhood[0] = xTexture.read(uint2(PSIn.pos.xy + float2(-1, -1)));
	neighborhood[1] = xTexture.read(uint2(PSIn.pos.xy + float2(0, -1)));
	neighborhood[2] = xTexture.read(uint2(PSIn.pos.xy + float2(1, -1)));
	neighborhood[3] = xTexture.read(uint2(PSIn.pos.xy + float2(-1, 0)));
	neighborhood[4] = xTexture.read(uint2(PSIn.pos.xy + float2(0, 0))); // center
	neighborhood[5] = xTexture.read(uint2(PSIn.pos.xy + float2(1, 0)));
	neighborhood[6] = xTexture.read(uint2(PSIn.pos.xy + float2(-1, 1)));
	neighborhood[7] = xTexture.read(uint2(PSIn.pos.xy + float2(0, 1)));
	neighborhood[8] = xTexture.read(uint2(PSIn.pos.xy + float2(1, 1)));
	float4 neighborhoodMin = neighborhood[0];
	float4 neighborhoodMax = neighborhood[0];
//    [unroll]
	for (uint i = 1; i < 9; ++i)
	{
		neighborhoodMin = min(neighborhoodMin, neighborhood[i]);
		neighborhoodMax = max(neighborhoodMax, neighborhood[i]);
	}

	// we cannot avoid the linear filter here because point sampling could sample irrelevant pixels but we try to correct it later:
	float4 history = xMaskTex.SampleLevel(gd.sampler_linear_clamp, prevTC, 0);

	// simple correction of image signal incoherency (eg. moving shadows or lighting changes):
	history = clamp(history, neighborhoodMin, neighborhoodMax);

	// our currently rendered frame sample:
	float4 current = neighborhood[4];

	// the linear filtering can cause blurry image, try to account for that:
	float subpixelCorrection = fract(max(abs(velocity.x)*gd.frame.g_xFrame_InternalResolution.x, abs(velocity.y)*gd.frame.g_xFrame_InternalResolution.y)) * 0.5f;

	// compute a nice blend factor:
	float blendfactor = saturate(mix(0.05f, 0.8f, subpixelCorrection));

	// if information can not be found on the screen, revert to aliased image:
	blendfactor = is_saturated(prevTC) ? blendfactor : 1.0f;

#ifdef HDR_CORRECTION
	history.rgb = tonemap(history.rgb);
	current.rgb = tonemap(current.rgb);
#endif

	// do the temporal super sampling by linearly accumulating previous samples with the current one:
	float4 resolved = float4(mix(history.rgb, current.rgb, blendfactor), 1);

#ifdef HDR_CORRECTION
	resolved.rgb = inverseTonemap(resolved.rgb);
#endif

	return resolved;
}
