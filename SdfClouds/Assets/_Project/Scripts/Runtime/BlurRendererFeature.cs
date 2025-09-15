using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace _Project.Scripts.Runtime
{
    public class BlurRendererFeature : ScriptableRendererFeature
    {
        [SerializeField] private BlurSettings settings;
        [SerializeField] private Shader blurShader;
        private Material blurMaterial;
        private BlurRenderPass blurRenderPass;
        
        public override void Create()
        {
            if (blurShader == null)
            {
                return;
            }

            
            blurMaterial = new Material(blurShader);
            blurRenderPass = new BlurRenderPass(blurMaterial, settings);

            blurRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (blurRenderPass == null)
                return;

            if (renderingData.cameraData.cameraType == CameraType.Game)
                renderer.EnqueuePass(blurRenderPass);
        }

        protected override void Dispose(bool disposing)
        {
            if (Application.isPlaying)
                Destroy(blurMaterial);
            else
                DestroyImmediate(blurMaterial);
        }
    }
}