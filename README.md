# sdfClouds

A Unity URP playground for raymarched signed-distance-field (SDF) clouds and painterly post-processing.

## What's inside

- **Raymarched SDF clouds.** HLSL shaders (`Raymarch`, `CloudMarch`, `RaymarchedSdfClouds`, `UpdatedRayMarch`) and several Shader Graph versions (`Raymarchv1SG` to `Raymarchv4SG`, `RaymarchClouds`). Cloud spheres render, but the lighting is not right yet.
- **Blur post-process.** A custom URP `ScriptableRendererFeature` with a Gaussian blur, controlled by a volume component (`CustomBlurVolumeComponent`).
- **Kuwahara filter.** A renderer feature and pass that run an anisotropic Kuwahara filter, based on [Acerola's implementation](https://github.com/GarrettGunnell/Post-Processing), for a painterly look. A `FullScreenPainterlyShader` graph and a Hybrid Kuwahara package are also included.
- **Debug helper.** `ShowDepthRenderFeature` shows the depth texture.

## Getting started

1. Open the `SdfClouds/` folder in **Unity 6000.0.41f1** (URP).
2. Open `Assets/_Project/Scenes/DemoScene_Forest.unity` or `SampleScene.unity`.
3. Turn the blur and Kuwahara renderer features on or off on the URP renderer asset.

## Status

Experimental and unfinished. The Kuwahara render pass is still a work in progress.

## References

- [Real-time cloudscapes with volumetric raymarching](https://blog.maximeheckel.com/posts/real-time-cloudscapes-with-volumetric-raymarching/) by Maxime Heckel
- [Acerola, Post-Processing](https://github.com/GarrettGunnell/Post-Processing)

Third-party assets: NaughtyAttributes, Hybrid Kuwahara package, FreeDimensionForge Low Poly Environments Pack.
