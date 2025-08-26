Shader "Lit/UpdatedRaymarch"
{
    //shader made with the help of: https://blog.maximeheckel.com/posts/real-time-cloudscapes-with-volumetric-raymarching/
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_NoiseTex ("NoiseTexture", 2D) = "white" {}
        _fbmAmplitude("fbm Amplitude", Float) = 0.5
        _fbmOctaves("fbm octaves", Float) = 6
        _fbmE("fbm e aka scaling of the noise",Float)=3
        _noiseScrollingDir("noise scrolling dir, (last component is ignored)", Vector) = (1.0,-0.2,-1.0,0)
        _noiseScrollingSpeed("noise scrolling speed", Float) = 0.5
        _cloudColor("color of the cloud", Color) = (0.6,0.6,0.75,1)
        _shadowWeight("shadow weight", Float) = 0.8
        _stepSize("march step size", Float) = 0.08
        _phaseParams("henyey greenstein phase params", Vector) = (0.8, -0.3,0.5,0.5)
        _lightAbsorptionTowardSun ("light absorption toward sun", Float) = .2
        _lightAbsorptionThroughCloud ("light absorption through cloud", Float) = .2
        _maxSteps ("max steps for raymarch", Float) = 100
        _lightSteps("how many steps towards the sun for lighting", Float)=3
        _darknessThreshold("darkness threshold", Float) = 0.1

    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue"="Transparent" "IgnoreProjector"="True"
        }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off // optional, helps see both sides of volume
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define MAX_DIST 100
            #define SURF_DIST 1e-3

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            // TEXTURE2D(_NoiseTex);
            // SAMPLER(sampler_NoiseTex);
            // float4 _NoiseTex_ST;


            float _fbmAmplitude;
            float _fbmOctaves;
            float _fbmE;
            float3 _noiseScrollingDir;
            float _noiseScrollingSpeed;
            float4 _cloudColor;
            float _shadowWeight;
            float _alphaDiscard;
            float _stepSize;
            float _maxSteps;

            // Light settings
            float _lightSteps;
            float _lightAbsorptionTowardSun;
            float _lightAbsorptionThroughCloud;
            float _darknessThreshold;

            //for the henyey greenstein phase stuff
            float4 _phaseParams; //x is g in the formula, yzw are extra weights


            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)); //worldspace
                //o.hitPos = mul(unity_ObjectToWorld, v.vertex); //object space
                o.hitPos = v.vertex; //world space
                return o;
            }

            float sdSphere(float3 p, float r)
            {
                return length(p) - r;
            }

            float sdTorus(float3 p, float2 t)
            {
                float2 q = float2(length(p.xz) - t.x, p.y);
                return length(q) - t.y;
            }

            float sdBox(float3 p, float3 b)
            {
                float3 q = abs(p) - b;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }

            //noise by: https://www.shadertoy.com/view/WdXGRj
            float hash(float n)
            {
                return frac(sin(n) * 43758.5453);
            }

            float noise(in float3 x)
            {
                //todo: replace with a noise texture (perlin noise?) check shell texturing as ref
                float3 p = floor(x);
                float3 f = frac(x);

                f = f * f * (3.0 - 2.0 * f);

                float n = p.x + p.y * 57.0 + 113.0 * p.z;

                float res = lerp(lerp(lerp(hash(n + 0.0), hash(n + 1.0), f.x),
                                      lerp(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
                                 lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
                                      lerp(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
                return res;
            }


            float fbm(float3 p, int octaves)
            {
                p += _Time.y * _noiseScrollingSpeed * normalize(_noiseScrollingDir.xyz);
                float value = 0.0;
                float amplitude = _fbmAmplitude;
                float e = _fbmE;
                for (int i = 0; i < octaves; ++ i)
                {
                    value += amplitude * noise(p);
                    p = p * e;
                    amplitude *= 0.5;
                    e *= 0.95;
                }
                return value;
            }

            float scene(float3 p)
            {
                //sdf of sphere of radius .5 sdf
                //float d = sdSphere(p, .5);

                //sdf of torus
                float d = sdTorus(p, float2(.1f, .5f));

                //float d = sdBox(p,.5);

                float f = fbm(p, _fbmOctaves);

                return d + f;
            }

            float raymarch(float3 ro, float3 rd)
            {
                float dO = 0; //distance origin
                float dS; //distance surface

                for (int i = 0; i < _maxSteps; i++)
                {
                    float3 p = ro + dO * rd; //raymarching position
                    dS = scene(p);
                    dO += dS;
                    if (dS < SURF_DIST || dO > MAX_DIST) break;
                }
                return dO;
            }

            float4 densityRaymarch(float3 ro, float3 rd)
            {
                float3 depth = 0;
                float3 p = ro + depth * rd;
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction; //dir to light
                float3 lightColor = mainLight.color;

                float4 res = 0;
                //todo: optimize to step normaly until we find a volumetric obj
                for (int i = 0; i < _maxSteps; i++)
                {
                    float density = -scene(p); //inverse sdf

                    //only draw density if its greater zero aka we are in the cloud
                    if (density > 0.0)
                    {
                        //do lighting calc
                        //use directional derivative for fast diffuse lighting

                        // float diffuse = clamp((scene(p)-scene(p+0.3*-_WorldSpaceLightPos0))/0.3,0.0,1.0);
                        // float3 lin = float3(0.60,0.60,0.75) * 1.1 + 0.8 * float3(1.0,0.6,0.3) * diffuse;
                        // float4 color = float4(lerp(float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0), density), density );
                        // color.rgb *= lin;
                        //
                        // color.rgb *= color.a;
                        // res += color * (1.0 - res.a);

                        //todo: fix lighting!

                        //calc directional derivative for fast diffuse lighting
                        //aka check density a small step towards light source in order to see if gets denser or not
                        //aka lighter or not
                        float diffuse = clamp(scene(p) - scene(p + 0.3 * -lightDir) / _stepSize, 0.0, 1.0);
                        float3 lin = _cloudColor * 1.1 + _shadowWeight * lightColor * diffuse;
                        //weigh the cloud color at 110%


                        float4 color = float4(lerp((float3)1, (float3)0, density), density);
                        color.rgb *= color.a;
                        color.rgb *= lin;
                        res += color * (1 - res.a);
                    }

                    depth += _stepSize;

                    p = ro + depth * rd;
                }
                return res;
            }

            float3 getNormal(float3 p)
            {
                //using gradient approximation
                float2 e = float2(1e-2, 0);
                float3 n = scene(p) - float3(
                    scene(p - e.xyy),
                    scene(p - e.yxy),
                    scene(p - e.yyx)
                );
                return normalize(n);
            }

            // Henyey-Greenstein
            float hg(float a, float g)
            {
                float g2 = g * g;
                return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
            }

            float phase(float a)
            {
                float blend = .5;
                float hgBlend = hg(a, _phaseParams.x) * (1 - blend) + hg(a, -_phaseParams.y) * blend;
                return _phaseParams.z + hgBlend * _phaseParams.w;
            }

            float lightmarch(float3 p)
            {
                Light mainLight = GetMainLight();

                float totalDensity = 0;
                for (int i = 0; i < _lightSteps; i++)
                {
                    p += mainLight.direction * _stepSize;
                    totalDensity += max(0, scene(p) * _stepSize);
                }

                float transmittance = exp(-totalDensity * _lightAbsorptionTowardSun);
                return _darknessThreshold + transmittance * (1 - _darknessThreshold);
            }


            half4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv - 0.5;
                float3 ro = i.ro; //cam origin
                float3 rd = normalize(i.hitPos - ro);

                //march through volume
                float transmittance = 1;
                float3 lightEnergy = 0;
                float distance_travelled = 0;
                float3 p = 0;

                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction; //dir to light
                float3 lightColor = mainLight.color;

                // Phase function makes clouds brighter around sun
                float cosAngle = dot(rd, lightDir.xyz); 
                float phaseVal = phase(cosAngle);

                for(int i =0; i<_maxSteps; i++)
                // while (distance_travelled < MAX_DIST)
                {
                    p = ro + rd * distance_travelled;
                    float density = -scene(p);

                    //we are in the cloud
                    if (density > 0)
                    {
                        //march towards light
                        float lightTransmittance = lightmarch(p);
                        lightEnergy += density * _stepSize * transmittance * lightTransmittance * phaseVal;
                        transmittance *= exp(-density * _stepSize * _lightAbsorptionThroughCloud);

                        //exit early if T is close to zero as further samples wont affect the result much
                        if (transmittance < 0.01 || distance_travelled>MAX_DIST)
                        {
                            break;
                        }
                    }
                    distance_travelled += _stepSize;
                }

                float3 lighting = lightEnergy * lightColor;
                float3 col = _cloudColor * transmittance + lighting;
                return float4(col, 0);
            }
            ENDHLSL
        }
    }
}