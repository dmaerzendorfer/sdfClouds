
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#define E 2.71828f

float gaussian(int x, float spread)
{
    float sigmaSqu = spread*spread;
    return (1 /sqrt(TWO_PI *sigmaSqu))*pow(E,-(x*x)/(2*sigmaSqu));
}

void gaussianBlur_float(float spread, float gridSize, UnitySamplerState _sampler, float2 uv,out float4 result)
{
   // result = SAMPLE_TEXTURE2D(_BlitTex, _sampler, uv);
    result = 0;
}
