using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace _Project.Scripts.Runtime
{
    //based on:
    // https://docs.unity3d.com/6000.0/Documentation/Manual/urp/renderer-features/create-custom-renderer-feature.html
    public class BlurRenderPass : ScriptableRenderPass
    {
        private BlurSettings defaultSettings;
        private Material material;

        private TextureDesc blurTextureDescriptor;

        private const string k_BlurTextureName = "_BlurTexture";
        private const string k_VerticalPassName = "VerticalBlurRenderPass";
        private const string k_HorizontalPassName = "HorizontalBlurRenderPass";

        private static readonly int horizontalBlurId = Shader.PropertyToID("_HorizontalBlur");
        private static readonly int verticalBlurId = Shader.PropertyToID("_VerticalBlur");


        public BlurRenderPass(Material material, BlurSettings defaultSettings)
        {
            this.material = material;
            this.defaultSettings = defaultSettings;
        }

        private void UpdateBlurSettings()
        {
            if (material == null) return;
            //use the volume settings or the default settings if no volume is set.
            var volumeComponent = VolumeManager.instance.stack.GetComponent<CustomBlurVolumeComponent>();
            float horizontalBlur = volumeComponent.horizontalBlur.overrideState
                ? volumeComponent.horizontalBlur.value
                : defaultSettings.horizontalBlur;
            float verticalBlur = volumeComponent.verticalBlur.overrideState
                ? volumeComponent.verticalBlur.value
                : defaultSettings.verticalBlur;

            material.SetFloat(horizontalBlurId, horizontalBlur);
            material.SetFloat(verticalBlurId, verticalBlur);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

            TextureHandle srcCamColor = resourceData.activeColorTexture;
            blurTextureDescriptor = srcCamColor.GetDescriptor(renderGraph);
            blurTextureDescriptor.name = k_BlurTextureName;
            blurTextureDescriptor.depthBufferBits = 0;
            var dst = renderGraph.CreateTexture(blurTextureDescriptor);

            UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

            //ensure we dont blit from the back buffer, back buffer is where the next frame is prepared before it is blited to the screen
            if (resourceData.isActiveTargetBackBuffer)
                return;

            UpdateBlurSettings();

            //check to avoid error from material preview in scene
            if (!srcCamColor.IsValid() || !dst.IsValid())
                return;

            // The AddBlitPass method adds a vertical blur render graph pass that blits from the source texture (camera color in this case) to the destination texture using the first shader pass (the shader pass is defined in the last parameter).
            RenderGraphUtils.BlitMaterialParameters paraVertical = new(srcCamColor, dst, material, 0);
            renderGraph.AddBlitPass(paraVertical, k_VerticalPassName);

            // The AddBlitPass method adds a horizontal blur render graph pass that blits from the texture written by the vertical blur pass to the camera color texture. The method uses the second shader pass.
            RenderGraphUtils.BlitMaterialParameters paraHorizontal = new(dst, srcCamColor, material, 1);
            renderGraph.AddBlitPass(paraHorizontal, k_HorizontalPassName);
        }
    }
}