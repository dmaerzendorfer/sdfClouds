//Based on code from DMEville https://www.youtube.com/watch?v=0G8CVQZhMXw

//Uses 3D texture and lighting 
void raymarch_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                    float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler,
                    float3 offset, float numLightSteps, float lightStepSize, float3 lightDir,
                    float lightAbsorb, float darknessThreshold, float transmittance, out float3 result)
{
    float density = 0;
    float transmission = 0;
    float lightAccumulation = 0;
    float finalLight = 0;


    for (int i = 0; i < numSteps; i++)
    {
        rayOrigin += (rayDirection * stepSize);

        //The blue dot position
        float3 samplePos = rayOrigin + offset;
        float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, samplePos).r;
        density += sampledDensity * densityScale;

        //light loop
        float3 lightRayOrigin = samplePos;

        for (int j = 0; j < numLightSteps; j++)
        {
            //The red dot position
            lightRayOrigin += -lightDir * lightStepSize;
            float lightDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, lightRayOrigin).r;
            //The accumulated density from samplePos to the light - the higher this value the less light reaches samplePos
            lightAccumulation += lightDensity;
        }

        //The amount of light received along the ray from param rayOrigin in the direction rayDirection
        float lightTransmission = exp(-lightAccumulation);
        //shadow tends to the darkness threshold as lightAccumulation rises
        float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
        //The final light value is accumulated based on the current density, transmittance value and the calculated shadow value 
        finalLight += density * transmittance * shadow;
        //Initially a param its value is updated at each step by lightAbsorb, this sets the light lost by scattering
        transmittance *= exp(-density * lightAbsorb);
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);
}

void raymarchv1_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                      float densityScale, float4 Sphere, out float result)
{
    float density = 0;

    for (int i = 0; i < numSteps; i++)
    {
        rayOrigin += (rayDirection * stepSize);

        //Calculate density
        float sphereDist = distance(rayOrigin, Sphere.xyz);

        if (sphereDist < Sphere.w)
        {
            density += 0.1;
        }
    }

    result = density * densityScale;
}

void raymarchv2_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                      float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler,
                      float3 offset, out float result)
{
    float density = 0;
    float transmission = 0;

    for (int i = 0; i < numSteps; i++)
    {
        rayOrigin += (rayDirection * stepSize);

        //Calculate density
        float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, rayOrigin + offset).r;
        density += sampledDensity;
    }

    result = density * densityScale;
}

void raymarchv3_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                      float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler,
                      float3 offset, float numLightSteps, float lightStepSize, float3 lightPosition,
                      out float result)
{
    float density = 0;
    float lightAccumulation = 0;
    //offset -= SHADERGRAPH_OBJECT_POSITION;

    for (int i = 0; i < numSteps; i++)
    {
        rayOrigin += (rayDirection * stepSize);
        float3 samplePos = rayOrigin + offset;
        //Calculate density
        float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, samplePos).r;
        density += sampledDensity;

        float3 lightRayOrigin = samplePos;
        float3 lightDir = samplePos - lightPosition;

        for (int j = 0; j < numLightSteps; j++)
        {
            lightRayOrigin += lightDir * lightStepSize;
            float lightDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, lightRayOrigin).r;
            lightAccumulation += lightDensity;
        }
    }

    result = density * densityScale;
}

float sdSphere(float3 p, float r)
{
    return length(p) - r;
}

float hash(float n)
{
    return frac(sin(n) * 43758.5453);
}

///
/// Noise function
///
float noise(in float3 x)
{
    float3 p = floor(x);
    float3 f = frac(x);
    
    f = f * f * (3.0 - 2.0 * f);
    
    float n = p.x + p.y * 57.0 + 113.0 * p.z;
    
    float res = lerp(lerp(lerp(hash(n +   0.0), hash(n +   1.0), f.x),
                        lerp(hash(n +  57.0), hash(n +  58.0), f.x), f.y),
                    lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
                        lerp(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
    return res;
}

///
/// Fractal Brownian motion.
///
/// Refer to:
/// EN: https://thebookofshaders.com/13/
/// JP: https://thebookofshaders.com/13/?lan=jp
///
float fbm(float3 p)
{
    float f;
    f  = 0.5000 * noise(p); p = p * 2.02;
    f += 0.2500 * noise(p); p = p * 2.03;
    f += 0.1250 * noise(p);
    return f;
}

float scene(float3 p)
{
    //sdf of sphere of radius .5 sdf
    float d = -sdSphere(p, .25);
    // d= clamp(-d,0,1);
    //sdf of torus
    //float d = sdTorus(p,float2(.1f,.5f));

    //float d = sdBox(p,.5);

    float f = fbm(p*0.3);

    return clamp((d + f), 0, 1);
}

void raymarchv4_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                      float densityScale,
                      float3 offset, float numLightSteps, float lightStepSize, float3 lightDir,
                      float lightAbsorb, float darknessThreshold, float transmittance, out float3 result)
{
    float density = 0;
    float transmission = 0;
    float lightAccumulation = 0;
    float finalLight = 0;


    for (int i = 0; i < numSteps; i++)
    {
        rayOrigin += (rayDirection * stepSize);

        //The blue dot position
        float3 samplePos = rayOrigin + offset;
        float sampledDensity = scene(samplePos);
        density += sampledDensity * densityScale;

        //light loop
        float3 lightRayOrigin = samplePos;

        for (int j = 0; j < numLightSteps; j++)
        {
            //The red dot position
            lightRayOrigin += -lightDir * lightStepSize;
            float lightDensity = scene(samplePos);
            //The accumulated density from samplePos to the light - the higher this value the less light reaches samplePos
            lightAccumulation += lightDensity;
        }

        //The amount of light received along the ray from param rayOrigin in the direction rayDirection
        float lightTransmission = exp(-lightAccumulation);
        //shadow tends to the darkness threshold as lightAccumulation rises
        float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
        //The final light value is accumulated based on the current density, transmittance value and the calculated shadow value 
        finalLight += density * transmittance * shadow;
        //Initially a param its value is updated at each step by lightAbsorb, this sets the light lost by scattering
        transmittance *= exp(-density * lightAbsorb);
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);
}
