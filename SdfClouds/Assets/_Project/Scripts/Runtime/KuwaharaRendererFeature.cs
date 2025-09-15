using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace _Project.Scripts.Runtime
{
    public class KuwaharaRendererFeature : ScriptableRendererFeature
    {
        [SerializeField] private KuwaharaSettings settings;
        [SerializeField] private Shader shader;
        private Material blurMaterial;
        private KuwaharaRenderPass kuwaharaRenderPass;
        
        
        public override void Create()
        {
            if (shader == null)
            {
                return;
            }

            
            blurMaterial = new Material(shader);
            kuwaharaRenderPass = new KuwaharaRenderPass(blurMaterial, settings);

            kuwaharaRenderPass.renderPassEvent = settings.renderPassEvent;
            
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (kuwaharaRenderPass == null)
                return;

            if (renderingData.cameraData.cameraType == CameraType.Game)
                renderer.EnqueuePass(kuwaharaRenderPass);
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