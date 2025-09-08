using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace _Project.Scripts.Runtime
{
    public class BlurRendererFeature : ScriptableRendererFeature
    {
        [SerializeField] private BlurSettings settings;
        [SerializeField] private Shader shader;
        private Material material;
        private BlurRenderPass blurRenderPass;

        public override void Create()
        {
            if (shader == null)
            {
                return;
            }

            material = new Material(shader);
            blurRenderPass = new BlurRenderPass(material, settings);

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
                Destroy(material);
            else
                DestroyImmediate(material);
        }
    }
}