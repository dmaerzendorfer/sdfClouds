using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace _Project.Scripts.Runtime
{
    [System.Serializable]
    public class KuwaharaSettings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRendering;
        
        [Header("Kuwahara settings")]
        [Range(2, 20)]
        public int kernelSize = 2;

        [Range(1, 10)]
        public int n = 8;
        
        [Range(1.0f, 18.0f)]
        public float sharpness = 8;
        [Range(1.0f, 100.0f)]
        public float hardness = 8;
        [Range(0.01f, 2.0f)]
        public float alpha = 1.0f;
        [Range(0.01f, 2.0f)]
        public float zeroCrossing = 0.58f;

        public bool useZeta = false;
        [Range(0.01f, 3.0f)]
        public float zeta = 1.0f;

        [Range(1, 4)]
        public int passes = 1;
    }
}