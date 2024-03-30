#ifdef SHADOW
uniform sampler2DShadow shadowtex0;

#ifdef SHADOW_COLOR
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

const vec2 shadowOffsets[9] = vec2[](
    vec2(0.0, 0.0), vec2(0.0, 1.0), vec2(0.7, 0.7),
    vec2(1.0, 0.0), vec2(0.7, -0.7), vec2(0.0, -1.0),
    vec2(-0.7, -0.7), vec2(-1.0, 0.0), vec2(-0.7, 0.7)
);

const float biasDistribution[10] = float[](
    0.0, 0.057, 0.118, 0.184, 0.255, 0.333, 0.423, 0.529, 0.667, 1.0
);

vec3 DistortShadow(vec3 worldPos, float distortFactor) {
    worldPos.xy /= distortFactor;
    worldPos.z *= 0.2;
    return worldPos * 0.5 + 0.5;
}

float GetCurvedBias(int i, float dither) {
    return mix(biasDistribution[i], biasDistribution[i + 1], dither);
}

// Replaced InterleavedGradientNoise() with a hash function
float Hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 SampleShadow(vec3 shadowPos, float subsurface, int samples) {
    float shadow = 0.0;
    vec3 shadowCol = vec3(0.0);

    for (int i = 0; i < samples; i++) {
        vec2 offset = shadowOffsets[i] * (1.0 / shadowMapResolution);
        shadow += shadow2D(shadowtex0, vec3(shadowPos.st + offset, shadowPos.z)).x;

        #ifdef SHADOW_COLOR
        if (shadow < 0.999) {
            vec3 shadowColSample = texture2D(shadowcolor0, shadowPos.st + offset).rgb *
                                   shadow2D(shadowtex1, vec3(shadowPos.st + offset, shadowPos.z)).x;
            #ifdef WATER_CAUSTICS
            shadowColSample *= 4.0;
            #endif
            shadowCol += shadowColSample;
        }
        #endif
    }

    shadow /= float(samples);
    #ifdef SHADOW_COLOR
    shadowCol /= float(samples);
    #endif

    shadow *= mix(shadow, 1.0, subsurface);
    shadowCol *= shadowCol;

    return clamp(shadowCol * (1.0 - shadow) + shadow, vec3(0.0), vec3(16.0));
}

vec3 GetShadow(vec3 worldPos, float NoL, float subsurface, float skylight) {
    worldPos = (floor((worldPos + cameraPosition) * SHADOW_PIXEL + 0.01) + 0.5) /
               SHADOW_PIXEL - cameraPosition;

    vec3 shadowPos = ToShadow(worldPos);

    float distb = sqrt(dot(shadowPos.xy, shadowPos.xy));
    float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
    shadowPos = DistortShadow(shadowPos, distortFactor);

    bool doShadow = shadowPos.x > 0.0 && shadowPos.x < 1.0 &&
                    shadowPos.y > 0.0 && shadowPos.y < 1.0;

    #ifdef OVERWORLD
    doShadow = doShadow && skylight > 0.001;
    #endif

    float skylightShadow = smoothstep(0.866, 1.0, skylight);
    if (!doShadow) return vec3(skylightShadow);

    float biasFactor = sqrt(1.0 - NoL * NoL) / NoL;
    float distortBias = distortFactor * shadowDistance / 256.0;
    distortBias *= 8.0 * distortBias;
    float distanceBias = sqrt(dot(worldPos.xyz, worldPos.xyz)) * 0.005;

    float bias = (distortBias * biasFactor + distanceBias + 0.05) / shadowMapResolution;
    float offset = 1.0 / shadowMapResolution;

    if (subsurface > 0.0) {
        bias = 0.0002;
        offset = 0.0007;
    }
    float biasStep = 0.001 * subsurface * (1.0 - NoL);

    #if SHADOW_PIXEL > 0
    bias += 0.0025 / SHADOW_PIXEL;
    #endif

    shadowPos.z -= bias;

    #ifdef SHADOW_FILTER
    vec3 shadow = SampleShadow(shadowPos, subsurface, 9);
    #else
    vec3 shadow = SampleShadow(shadowPos, subsurface, 1);
    #endif

    return shadow;
}

vec3 GetSubsurfaceShadow(vec3 worldPos, float subsurface, float skylight) {
    float gradNoise = Hash(gl_FragCoord.xy); // Use hash function instead of InterleavedGradientNoise()

    vec3 shadowPos = ToShadow(worldPos);

    float distb = sqrt(dot(shadowPos.xy, shadowPos.xy));
    float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
    shadowPos = DistortShadow(shadowPos, distortFactor);

    vec3 subsurfaceShadow = vec3(0.0);

    for (int i = 0; i < 12; i++) {
        gradNoise = fract(gradNoise + 1.618);
        float rot = gradNoise * 6.283;
        float dist = (i + gradNoise) / 12.0;

        vec2 offset2D = vec2(cos(rot), sin(rot)) * dist;
        float offsetZ = -(dist * dist + 0.025);

        vec3 offsetScale = vec3(0.002 / distortFactor, 0.002 / distortFactor, 0.001);

        vec3 lowOffset = vec3(0.0, 0.0, -0.00025 * (1.0 + gradNoise) * distortFactor);
        vec3 highOffset = vec3(offset2D, offsetZ) * offsetScale;

        vec3 offset = highOffset * (subsurface * 0.75 + 0.25);

        vec3 samplePos = shadowPos + offset;
        float shadow = SampleShadow(samplePos, 0.0, 1).x; // Use SampleShadow() for subsurface shadow

        subsurfaceShadow += shadow;
    }
    subsurfaceShadow /= 12.0;
    subsurfaceShadow *= subsurfaceShadow;

    return subsurfaceShadow;
}
#else
vec3 GetShadow(vec3 worldPos, float NoL, float subsurface, float skylight) {
    #ifdef OVERWORLD
    float shadow = smoothstep(0.866, 1.0, skylight);
    return vec3(shadow * shadow);
    #else
    return vec3(1.0);
    #endif
}

vec3 GetSubsurfaceShadow(vec3 worldPos, float subsurface, float skylight) {
    return vec3(0.0);
}
#endif