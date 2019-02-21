#define DILATE_VELOCITY_AVG_FAR

#include "postProcessHF.h"
#include "reconstructPositionHF.h"


fragment float4 motionBlurPS(VertexToPixelPostProcess PSIn [[stage_in]], constant GlobalData &gd)
{
	float3 color = 0;
	float numSampling = 1.0f;

	float2 vel = GetVelocity(int2(PSIn.pos.xy), gd);
	vel *= 0.025f;

//    [unroll]
	for(float i=-7.5f;i<=7.5f;i+=1.0f){
		color.rgb += xTexture.SampleLevel(gd.sampler_linear_clamp,saturate(PSIn.tex+vel*i*0.5f),0).rgb;
		numSampling++;
	}

	return float4(color / numSampling, 1);
}
