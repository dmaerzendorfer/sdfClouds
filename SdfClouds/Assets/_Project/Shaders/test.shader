Shader "Custom/SDFCloudURP"
{
    //disclaimer: this is from chatgpt, just wanted to see if it can create a working shader
    //ps: it cannot
    Properties
    {
        _SphereCenter ("Sphere Center (World)", Vector) = (0,0,2,0)
        _SphereRadius ("Sphere Radius", Float) = 0.5
        _Steps       ("March Steps", Range(16,256)) = 96
        _ShadowSteps ("Light Steps", Range(4,64)) = 16
        _StepSize    ("Base Step Size", Range(0.001,0.05)) = 0.01

        _NoiseScale  ("Noise Scale", Float) = 1.5
        _NoiseAmp    ("Noise Amplitude", Float) = 0.5
        _NoiseSpeed  ("Noise Scroll Speed", Float) = 0.4
        _ScrollDir   ("Noise Scroll Dir (xyz)", Vector) = (0.0, 0.3, 0.1, 0)

        _Density     ("Medium Density (sigma_t)", Float) = 1.5
        _Scatter     ("Scattering Albedo (sigma_s)", Range(0,1)) = 0.9
        _PhaseG      ("Phase g (Henyey-Greenstein)", Range(-0.99,0.99)) = 0.8
        _Brightness  ("Brightness", Float) = 1.0
        _SoftShadowK ("Soft Shadow K", Float) = 8.0

        _Tint        ("Tint", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags{ "RenderType" = "Transparent" "Queue" = "Transparent" "IgnoreProjector" = "True" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        Pass
        {
            Name "VolumetricRaymarch"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5

            // URP/Core includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            // ==== Uniforms ====
            float4 _SphereCenter; // xyz = world center
            float _SphereRadius;
            float _Steps, _ShadowSteps, _StepSize;
            float _NoiseScale, _NoiseAmp, _NoiseSpeed;
            float4 _ScrollDir; // xyz used
            float _Density, _Scatter, _PhaseG, _Brightness, _SoftShadowK;
            float4 _Tint;

            // // Main light (URP) – direction stored in _MainLightPosition.xyz for directional lights
            // float4 _MainLightPosition; // world dir (w=0) or position (w=1)
            // float4 _MainLightColor;    // rgb

            struct appdata
            {
                float3 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 posCS : SV_POSITION;
                float2 uv    : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.posCS = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // ===== Utility: Reconstruct world ray from screen UV =====
            float3 GetRayDirWS(float2 uv)
            {
                // uv in [0,1] -> NDC
                float2 ndc = uv * 2.0 - 1.0;
                float4 clip = float4(ndc, 0, 1);
                float4 view = mul(unity_CameraInvProjection, clip);
                view /= max(view.w, 1e-5);
                float3 dirVS = normalize(view.xyz);
                float3 dirWS = mul((float3x3)unity_CameraToWorld, dirVS);
                return normalize(dirWS);
            }

            // ===== Ray-sphere intersection (world space) =====
            bool IntersectSphere(float3 ro, float3 rd, float3 c, float r, out float t0, out float t1)
            {
                float3 oc = ro - c;
                float b = dot(oc, rd);
                float cterm = dot(oc, oc) - r*r;
                float disc = b*b - cterm;
                if (disc < 0) { t0 = t1 = -1; return false; }
                float s = sqrt(disc);
                t0 = -b - s;
                t1 = -b + s;
                return t1 > 0;
            }

            // ===== Hash & noise (cheap 3D value noise + fbm) =====
            float hash31(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float noise3(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);

                float n000 = hash31(i + float3(0,0,0));
                float n100 = hash31(i + float3(1,0,0));
                float n010 = hash31(i + float3(0,1,0));
                float n110 = hash31(i + float3(1,1,0));
                float n001 = hash31(i + float3(0,0,1));
                float n101 = hash31(i + float3(1,0,1));
                float n011 = hash31(i + float3(0,1,1));
                float n111 = hash31(i + float3(1,1,1));

                float3 u = f*f*(3.0 - 2.0*f);

                float nx00 = lerp(n000, n100, u.x);
                float nx10 = lerp(n010, n110, u.x);
                float nx01 = lerp(n001, n101, u.x);
                float nx11 = lerp(n011, n111, u.x);

                float nxy0 = lerp(nx00, nx10, u.y);
                float nxy1 = lerp(nx01, nx11, u.y);

                return lerp(nxy0, nxy1, u.z);
            }

            float fbm(float3 p)
            {
                float a = 0.5;
                float f = 0.0;
                for (int i=0; i<5; i++)
                {
                    f += a * noise3(p);
                    p *= 2.02;
                    a *= 0.5;
                }
                return f;
            }

            // Henyey–Greenstein phase function
            float HG(float cosTheta, float g)
            {
                float g2 = g*g;
                return (1.0 - g2) / (4.0 * 3.14159265 * pow(1.0 + g2 - 2.0*g*cosTheta, 1.5));
            }

            // Shadow/occlusion along light ray (single scattering approx)
            float LightTransmittance(float3 posWS, float3 lightDirWS, float maxDist)
            {
                float T = 1.0;
                float stepLen = maxDist / max(_ShadowSteps, 1.0);
                float3 p = posWS;
                [loop]
                for (int i=0; i<(int)_ShadowSteps; i++)
                {
                    p += lightDirWS * stepLen;
                    // inside sphere? if not, break (early exit helps a lot)
                    if (distance(p, _SphereCenter.xyz) > _SphereRadius) break;
                    // density sample
                    float3 npos = p * _NoiseScale + (_Time.y * _NoiseSpeed) * normalize(_ScrollDir.xyz);
                    float n = fbm(npos) * 2.0 - 1.0; // [-1,1]
                    // base spherical mask -> more dense near center
                    float mask = saturate(1.0 - length(p - _SphereCenter.xyz) / _SphereRadius);
                    float dens = saturate(mask + _NoiseAmp * n);
                    float extinction = _Density * dens;
                    T *= exp(-extinction * stepLen);
                    if (T < 0.005) break;
                }
                return T;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 ro = _WorldSpaceCameraPos;
                float3 rd = GetRayDirWS(i.uv);

                // Ray-sphere bounds
                float t0, t1;
                if (!IntersectSphere(ro, rd, _SphereCenter.xyz, _SphereRadius, t0, t1))
                    return float4(0,0,0,0);

                t0 = max(t0, 0.0);
                float t = t0;
                float endT = t1;

                // March
                 Light mainLight = GetMainLight();
                // float3 lightDir = mainLight.direction; //dir to light
                // float3 lightColor = mainLight.color;
                float3 lightDir = (_MainLightPosition.w == 0) ? normalize(_MainLightPosition.xyz) : normalize(_MainLightPosition.xyz - _SphereCenter.xyz);
                float3 viewDir = -rd; // from point toward camera
                float phase = HG(dot(lightDir, viewDir), _PhaseG);

                float3 radiance = 0;
                float T = 1.0; // transmittance to camera

                int steps = (int)_Steps;
                float stepLen = _StepSize;
                float maxMarch = endT - t0;
                int maxIters = min(steps, (int)ceil(maxMarch / stepLen));

                [loop]
                for (int s = 0; s < maxIters; s++)
                {
                    float3 pos = ro + rd * t;

                    // inside sphere density
                    float3 toC = pos - _SphereCenter.xyz;
                    float r01 = length(toC) / _SphereRadius; // 0 at center, 1 at surface
                    if (r01 > 1.0) break;

                    float shell = saturate(1.0 - r01);

                    // Noise displacement in world space
                    float3 npos = pos * _NoiseScale + (_Time.y * _NoiseSpeed) * normalize(_ScrollDir.xyz);
                    float n = fbm(npos) * 2.0 - 1.0; // [-1,1]

                    float density = saturate(shell + _NoiseAmp * n);
                    if (density > 1e-3)
                    {
                        // Light attenuation along light ray (cheap shadowing)
                        float lMax = 2.0 * _SphereRadius; // conservative
                        float Tl = LightTransmittance(pos, lightDir, lMax);

                        float sigma_t = _Density * density;
                        float sigma_s = _Scatter * sigma_t; // simple albedo model

                        float3 Li = _MainLightColor.rgb * Tl; // in-scattered light that reaches pos
                        float3 S = sigma_s * Li * phase;     // scattering source term

                        // integrate along view ray
                        radiance += T * S * stepLen;
                        T *= exp(-sigma_t * stepLen);
                        if (T < 0.01) break;
                    }

                    t += stepLen;
                    if (t > endT) break;
                }

                float alpha = 1.0 - T; // opacity from absorbed light
                float3 col = radiance * _Brightness * _Tint.rgb;

                // Optional: simple gamma to sRGB (Unity usually handles this if Color Space = Linear)
                // col = pow(col, 1.0/2.2);

                return float4(col, saturate(alpha));
            }
            ENDHLSL
        }
    }
}
