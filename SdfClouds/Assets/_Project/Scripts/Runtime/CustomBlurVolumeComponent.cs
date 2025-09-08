using System;
using UnityEngine.Rendering;

namespace _Project.Scripts.Runtime
{
    [Serializable]
    public class CustomBlurVolumeComponent : VolumeComponent
    {
        public ClampedFloatParameter horizontalBlur =
            new ClampedFloatParameter(0.05f, 0, 0.5f);
        
        public ClampedFloatParameter verticalBlur =
            new ClampedFloatParameter(0.05f, 0, 0.5f);
    }
}