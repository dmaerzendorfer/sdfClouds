Shader "Custom/DisplayTextureShader"
{
    Properties
    {
        _DisplayTex ("display texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        LOD 200

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

        // The structure definition defines which variables it contains.
        // This example uses the Attributes structure as an input structure in
        // the vertex shader.
        struct Attributes
        {
            // The positionOS variable contains the vertex positions in object
            // space.
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            // The positions in this struct must have the SV_POSITION semantic.
            float4 positionHCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };
        ENDHLSL

        Pass
        {

            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_DisplayTex);
            SAMPLER(sampler_DisplayTex);
            CBUFFER_START(UnityPerMaterial)
            // The following line declares the _BaseMap_ST variable, so that you
            // can use the _BaseMap variable in the fragment shader. The _ST 
            // suffix is necessary for the tiling and offset function to work.
            float4 _DisplayTex_ST;
            CBUFFER_END

            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                // The TransformObjectToHClip function transforms vertex positions
                // from object space to homogenous space
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                OUT.uv = TRANSFORM_TEX(IN.uv, _DisplayTex);
                // Returning the output.
                return OUT;
            }

            // The fragment shader definition.            
            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_DisplayTex, sampler_DisplayTex, IN.uv);
                return color;
            }
            ENDHLSL
        }
    }
}