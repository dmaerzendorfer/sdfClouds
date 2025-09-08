using UnityEngine;

namespace _Project.Scripts.Runtime
{
    [System.Serializable]
    public class BlurSettings
    {
        [Range(0, 0.4f)] public float horizontalBlur;
        [Range(0, 0.4f)] public float verticalBlur;
        
    }
}
