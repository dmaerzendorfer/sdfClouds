Shader "Hidden/Hybrid_Kuwahara_Shader"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _KernelSize("KernelSize (N)", Int) = 3
        _Sharpness("Sharpness", Int) = 8
        _Overlap("Overlap", Float) = 0
        _Scaling("Scaling", Float) = 0
   
    }
        SubShader
        {
            // No culling or depth
            Cull Off ZWrite Off ZTest Always

            Pass
            {
                CGPROGRAM
                #pragma vertex vert_img
                #pragma fragment frag

                /*  struct region
                 {
                     float3 mean;
                     float variance;
                 };*/

                 #include "UnityCG.cginc"
                 #define PI 3.14159265358979323846f

                 float4 m[4];
                 float3 s[4];


                 sampler2D _MainTex;
                 float2 _MainTex_TexelSize;
                 int _KernelSize;
                 float _Overlap, _Sharpness, _Scaling;

                 float gaussian(int x)
                 {
                     float sigmaSqu = 1;
                     return (1 / sqrt(2 * PI * sigmaSqu)) * exp(-(x * x) / (2 * sigmaSqu));
                 }


                 fixed4 frag(v2f_img i) : SV_Target
                 {

                    int radius = _KernelSize * 0.5f;
                    float overlap = ((float) radius * 0.5f) * (float)_Overlap;
                    float halfOverlap = overlap / 2;
                    //float halfOverlap = 0;
                    float maxV = length(float2(radius,radius));

                    //SOBEL OPERATOR

                    float2 d = _MainTex_TexelSize.xy;

                    float3 Sx = (
                        1.0f * tex2D(_MainTex, i.uv + float2(-d.x, -d.y)).rgb +
                        2.0f * tex2D(_MainTex, i.uv + float2(-d.x, 0.0)).rgb +
                        1.0f * tex2D(_MainTex, i.uv + float2(-d.x, d.y)).rgb +
                        -1.0f * tex2D(_MainTex, i.uv + float2(d.x, -d.y)).rgb +
                        -2.0f * tex2D(_MainTex, i.uv + float2(d.x, 0.0)).rgb +
                        -1.0f * tex2D(_MainTex, i.uv + float2(d.x, d.y)).rgb
                        ) / 4;

                    float3 Sy = (
                        1.0f * tex2D(_MainTex, i.uv + float2(-d.x, -d.y)).rgb +
                        2.0f * tex2D(_MainTex, i.uv + float2(0.0, -d.y)).rgb +
                        1.0f * tex2D(_MainTex, i.uv + float2(d.x, -d.y)).rgb +
                        -1.0f * tex2D(_MainTex, i.uv + float2(-d.x, d.y)).rgb +
                        -2.0f * tex2D(_MainTex, i.uv + float2(0.0, d.y)).rgb +
                        -1.0f * tex2D(_MainTex, i.uv + float2(d.x, d.y)).rgb
                        ) / 4;

                    float greyscale = float3(0.2126, 0.7152, 0.0722);
                    float gradientX = dot(Sx, greyscale);
                    float gradientY = dot(Sy, greyscale);

                   
                    float lineArt = max(gradientX, gradientY);
                    lineArt = abs(lineArt);
;

                    int2 offs[4] = { {-radius + overlap, -radius + overlap}, {-radius + overlap, 0}, {0, -radius + overlap}, {0,0} };

                    float angle = atan(gradientY / gradientX);

                    float sinPhi = sin(angle);
                    float cosPhi = cos(angle);

                    for (int x = 0; x < radius; ++x)
                    {
                        for (int y = 0; y < radius; ++y)
                        {
                            for (int k = 0; k < 4; ++k)
                            {
                                float2 v = float2(x, y);
                                v += offs[k] - float2(halfOverlap, halfOverlap);
                                fixed2 offset = v * _MainTex_TexelSize.xy;
                                //fixed2 offset = (v + offs[k]) * _MainTex_TexelSize.xy;
                                //v = v + offs[k];
                                //fixed2 offset = v * _MainTex_TexelSize.xy;
                                offset = float2(offset.x * cosPhi - offset.y * sinPhi, offset.x * sinPhi + offset.y * cosPhi);
                                fixed3 tex = tex2D(_MainTex, i.uv + offset);
                                //float w = 1-(length(v)/(float)radius);
                                float w = gaussian(length(v)/5);
                                //float w = 1;
                                m[k] += float4(tex * w, w);
                                s[k] += tex * tex * w;


                            }
                        }
                    }

                    float4 result = 0;
                    for (int k = 0; k < 4; ++k)
                    {
                        m[k].rgb /= m[k].w;
                        s[k] = abs((s[k] / m[k].w) - (m[k].rgb * m[k].rgb));
                        float sigma2 = s[k].r + s[k].g + s[k].b;
                        float w = 1.0f / (1.0f + pow(10000.0f * sigma2 * _Sharpness, 0.5 * _Sharpness));
                        result += float4(m[k].rgb * w, w);
                    }

                    result.rgb = result.rgb / result.w;
                    float3 final = lerp(result.rgb, lerp(lineArt, lineArt * result.rgb, 0.85f) * 0.5f + result.rgb, _Scaling);
                    return fixed4(final, 1.0);
                    //return lineArt;

                 }
                 ENDCG
             }
        }
}