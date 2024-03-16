vec2 Reprojection(vec3 pos) {
    pos = pos * 2.0 - 1.0;

    vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
    viewPosPrev /= viewPosPrev.w;
    viewPosPrev = gbufferModelViewInverse * viewPosPrev;

    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    cameraOffset *= float(pos.z > 0.56);

    vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
    previousPosition = gbufferPreviousModelView * previousPosition;
    previousPosition = gbufferPreviousProjection * previousPosition;

    return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
}

vec3 ApplyMultiColoredBlocklight(vec3 blocklightCol, vec3 screenPos) {
    if (screenPos.z > 0.56) {
        screenPos.xy = Reprojection(screenPos);
    }
    vec3 coloredLight = texture2DLod(colortex9, screenPos.xy, 2).rgb;

    vec3 coloredLightNormalized;
    float coloredLightMix;

#if defined MCBL_LEGACY_COLOR
    coloredLightNormalized = normalize(coloredLight - 1);
    coloredLightNormalized *= GetLuminance(blocklightCol) / max(GetLuminance(coloredLightNormalized), 1e-6);
    coloredLightMix = min(dot(coloredLightNormalized, vec3(1.0)), 1.0);
#else
    coloredLightNormalized = normalize(coloredLight + 1e-6);
    coloredLightNormalized = mix(coloredLightNormalized * coloredLightNormalized, vec3(1.0), 0.125);
    coloredLightNormalized *= GetLuminance(blocklightCol) * 1.7;
    coloredLightMix = min(dot(coloredLightNormalized, vec3(1.0)), 1.0);
#endif

    return mix(blocklightCol, coloredLightNormalized, coloredLightMix);
}
