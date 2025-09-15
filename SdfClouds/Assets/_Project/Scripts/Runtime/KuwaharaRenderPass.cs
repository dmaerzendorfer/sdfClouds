using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace _Project.Scripts.Runtime
{
    //based on:
    // https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/AnisotropicKuwahara.cs
    //but ported into urp and implemented as a scriptablerenderpass
    public class KuwaharaRenderPass : ScriptableRenderPass
    {
        private KuwaharaSettings defaultSettings;
        private Material material;

        private TextureDesc
            kuwaharaTextureDescriptor; //todo: change this to be renderTargetDescriptors. they are better for rendering stuff with gpu

        private TextureDesc eigenvectorTextureDescriptor; //textureDesc are better for general purpose textures
        private TextureDesc blurTextureDescriptor;


        private const string k_KuwaharaTextureName = "_KuwaharaTexture";
        private const string k_EigenvectorTextureName = "_EigenvectorTexture";
        private const string k_BlurTextureName = "_BlurTexture";

        private const string k_VerticalBlurPassName = "VerticalBlurRenderPass";
        private const string k_HorizontalBlurPassName = "HorizontalBlurRenderPass";
        private const string k_EigenvectorPassName = "EigenvectorRenderPass";
        private const string k_KuwaharaPassName = "KuwaharaRenderPass";

        private static readonly int kernelSizeId = Shader.PropertyToID("_KernelSize");
        private static readonly int nId = Shader.PropertyToID("_N");
        private static readonly int sharpnessId = Shader.PropertyToID("_Q");
        private static readonly int hardnessId = Shader.PropertyToID("_Hardness");
        private static readonly int alphaId = Shader.PropertyToID("_Alpha");
        private static readonly int zeroCrossingId = Shader.PropertyToID("_ZeroCrossing");
        private static readonly int zetaId = Shader.PropertyToID("_Zeta");
        private static readonly int tfmId = Shader.PropertyToID("_TFM");


        public KuwaharaRenderPass(Material material, KuwaharaSettings defaultSettings)
        {
            this.material = material;
            this.defaultSettings = defaultSettings;
        }

        private void UpdateKuwaharaSettings()
        {
            if (material == null) return;

            material.SetInt(kernelSizeId, defaultSettings.kernelSize);
            material.SetInt(nId, defaultSettings.n);
            material.SetFloat(sharpnessId, defaultSettings.sharpness);
            material.SetFloat(hardnessId, defaultSettings.hardness);
            material.SetFloat(alphaId, defaultSettings.alpha);
            material.SetFloat(zeroCrossingId, defaultSettings.zeroCrossing);
            material.SetFloat(zetaId,
                defaultSettings.useZeta ? defaultSettings.zeta : 2.0f / 2.0f / (defaultSettings.kernelSize / 2.0f));
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            //there is a good chance nowadays you actually do this differently
            //have seen stuff with a builder in the unity documentation.
            //builder would be cleaner it seems, but im just happy as long as it works and the sample from the documentation still uses this.
            //builder documentation: https://docs.unity3d.com/Manual/urp/render-graph-create-a-texture.html
            //sample without builder: https://docs.unity3d.com/6000.2/Documentation/Manual/urp/renderer-features/create-custom-renderer-feature.html
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            //ensure we dont blit from the back buffer, back buffer is where the next frame is prepared before it is blited to the screen
            if (resourceData.isActiveTargetBackBuffer)
                return;

            //to create a texture we need a dscriptor that has all the data for it, eG how big etc
            TextureHandle srcCamColor = resourceData.activeColorTexture;
            kuwaharaTextureDescriptor =
                srcCamColor.GetDescriptor(renderGraph); //basically make a texture same as the rendered cam
            kuwaharaTextureDescriptor.name = k_KuwaharaTextureName; //but rename it
            kuwaharaTextureDescriptor.depthBufferBits = 0; //depth precision
            var kuwaharaTh = renderGraph.CreateTexture(kuwaharaTextureDescriptor);
            //alternate way of creating a texture handle:
            //https://docs.unity3d.com/6000.1/Documentation/Manual/urp/render-graph-create-a-texture.html
            // or just: renderGraph.CreateTexture(srcCamColor); makes a texture handle just like srcCamColors settings

            eigenvectorTextureDescriptor = srcCamColor.GetDescriptor(renderGraph);
            eigenvectorTextureDescriptor.name = k_EigenvectorTextureName;
            eigenvectorTextureDescriptor.depthBufferBits = 0;
            var eigenvectorTh = renderGraph.CreateTexture(eigenvectorTextureDescriptor);

            blurTextureDescriptor = srcCamColor.GetDescriptor(renderGraph);
            blurTextureDescriptor.name = k_BlurTextureName;
            blurTextureDescriptor.depthBufferBits = 0;
            var blurTh = renderGraph.CreateTexture(blurTextureDescriptor);


            UpdateKuwaharaSettings();

            //check to avoid error from material preview in scene
            if (!srcCamColor.IsValid() || !kuwaharaTh.IsValid())
                return;

            //1. do the eigenvector calc and put in a texture
            RenderGraphUtils.BlitMaterialParameters paraEigenvector = new(srcCamColor, eigenvectorTh, material, 0);
            renderGraph.AddBlitPass(paraEigenvector, k_EigenvectorPassName);

            //2. do vertical and then horizontal blur
            RenderGraphUtils.BlitMaterialParameters paraVertical = new(eigenvectorTh, blurTh, material, 1);
            renderGraph.AddBlitPass(paraVertical, k_VerticalBlurPassName);

            RenderGraphUtils.BlitMaterialParameters paraHorizontal = new(blurTh, eigenvectorTh, material, 2);
            renderGraph.AddBlitPass(paraHorizontal, k_HorizontalBlurPassName);

            //todo: vergleich mit azerolas post process again. look into what textures i really need
            //can i ping pong? (meaning ping ponging between two render textures)
            //what source texture does the kuwahara part have? is it already blurred?
            //3. set tfm texture for kuwahara
            
            //probably need to split it into two passes and pass the texture between them...
            //https://docs.unity3d.com/6000.0/Documentation/Manual/urp/render-graph-pass-textures-between-passes.html
            
            RenderGraphUtils.BlitMaterialParameters para = new(eigenvectorTh, eigenvectorTh, material, 3);
            para.sourceTexturePropertyID = tfmId;
            renderGraph.AddBlitPass(para, "blitEigenvectors");

            
            //resolve textureHandle so we get the texture and can set it in the mat
            // using (var builder = renderGraph.AddRenderPass<KuwaharaPassData>(k_KuwaharaPassName, out var passData))
            // {
            //     passData.material = material;
            //     passData.inputTexture = kuwaharaTh;
            //     passData.propertyId = tfmId;
            //
            //     builder.UseColorBuffer(passData.inputTexture, 0);
            //     
            //     builder.SetRenderFunc((KuwaharaPassData passData, RenderGraphContext ctx) =>
            //     {
            //         var tex = renderGraph.GetTextureDesc(passData.inputTexture);
            //     });
            // }
            
            
            
            material.SetTexture(tfmId, kuwaharaTh);

            //4. do x passes of the kuwahara filter
            RenderGraphUtils.BlitMaterialParameters kuwahara;
            for (int i = 0; i < defaultSettings.passes; ++i)
            {
                //we ping pong between kuwharaTH and srcCamColor textures
                if (i % 2 == 0)
                    kuwahara = new(srcCamColor, kuwaharaTh, material, 3);
                else
                    kuwahara = new(kuwaharaTh, srcCamColor, material, 3);
                renderGraph.AddBlitPass(kuwahara, k_KuwaharaPassName);
            }

            //make sure the end result is always in the srcCamColor texture
            if (defaultSettings.passes % 2 != 0)
                Graphics.Blit(kuwaharaTh, srcCamColor);
        }
    }

    // public class KuwaharaPassData
    // {
    //     public Material material;
    //     public int propertyId;             // e.g. Shader.PropertyToID("_PrevTex")
    //     public TextureHandle inputTexture; // result from a previous pass
    // }
}