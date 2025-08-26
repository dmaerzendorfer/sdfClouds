Shader "Unlit/CloudMarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            #define MAX_STEPS 100
            #define MAX_DIST 100
            #define SURF_DIST 1e-3
            #define MARCH_SIZE 0.08

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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.ro=0;
                o.hitPos=0;
                // o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)); //worldspace
                // o.hitPos = v.vertex; //mul(unity_ObjectToWorld, v.vertex); //object space
                return o;
            }

            float sdSphere(float3 p, float r)
            {
                return length(p) - r;
            }

            float scene(float p)
            {
                float distance = sdSphere(p, 0.5);
                return distance;
            }

            /*
                float getDist(float3 p)
                {
                    //sdf of sphere of radius .5 sdf
                    float d = length(p) - .5;
    
                    //sdf of torus
                    //float d = length(float2(length(p.xz) - .5, p.y)) - .1;
                    return d;
                }
    
                float raymarch(float3 ro, float3 rd)
                {
                    float dO = 0; //distance origin
                    float dS; //distance surface
    
                    for (int i = 0; i < MAX_STEPS; i++)
                    {
                        float3 p = ro + dO * rd; //raymarching position
                        dS = getDist(p);
                        dO += dS;
                        if (dS < SURF_DIST || dO > MAX_DIST) break;
                    }
                    return dO;
                }
    
                float3 getNormal(float3 p)
                {
                    //using gradient approximation
                    float2 e = float2(1e-2, 0);
                    float3 n = getDist(p) - float3(
                        getDist(p - e.xyy),
                        getDist(p - e.yxy),
                        getDist(p - e.yyx)
                    );
                    return normalize(n);
                }
                */

            float raymarch(float3 ro, float3 rd)
            {
                float dO = 0; //distance origin
                float dS; //distance surface

                for (int i = 0; i < MAX_STEPS; i++)
                {
                    float3 p = ro + dO * rd; //raymarching position
                    dS = scene(p);
                    dO += dS;
                    if (dS < SURF_DIST || dO > MAX_DIST) break;
                }
                return dO;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv -.5;
                float3 ro = float3(0,0,-3);
                float3 rd = normalize(float3(uv.x,uv.y,1));
                fixed4 col = 0;
                col.rgb=rd;
                // float d = raymarch(ro, rd);
                // if(d<MAX_DIST)
                // {
                //     col.r=1;
                // }

                
                return col;
                // float2 uv = i.uv - 0.5; //center the uv
                // float3 ro = i.ro; //cam origin
                // ro = float3(0,0,-3);
                // float3 rd = normalize(i.hitPos - ro);
                // rd = normalize(float3(uv.xy,1));
                // float d = 0.0; //depth aka distance marched
                //
                // d = raymarch(ro, rd);
                // fixed4 col = 0;
                // // if (d >= MAX_DIST)
                // //     discard;
                // //else
                // if(d<MAX_DIST)
                // {
                //     float3 p = ro + rd * d;
                //     // float3 n = getNormal(p);
                //     col.r=1;
                // }
                // return col;


                //do the raymarch
                // float3 p = ro + d * rd;
                // float4 col = 0; //output colour
                //
                // for (int i = 0; i < MAX_STEPS; i++)
                // {
                //     float density = -scene(p); //the opposite distance from the scene
                //     if (density > 0.0)
                //     {
                //         //we are in the scene
                //         float4 x = float4(lerp((float3)1, (float3)0, density), density);
                //         x.rgb *= x.a;
                //         col += x * (1 - col.a);
                //     }
                //     d += MARCH_SIZE;
                //     p = ro + d * rd;
                // }
                // return col;
            }
            ENDCG
        }
    }
}