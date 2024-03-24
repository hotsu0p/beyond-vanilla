//Settings//
#include "/lib/settings.glsl"
//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float star;

varying vec3 upVec, sunVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor, darknessFactor;
uniform float far, near;
uniform float frameCounter;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float shadowFade, voidFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D noisetex;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

//Common Functions//
float GetLuminance(vec3 color) {
    return dot(color,vec3(0.299, 0.587, 0.114));
}

void RoundSunMoon(inout vec3 color, vec3 viewPos, vec3 sunColor, vec3 moonColor) {
    float VoL = dot(normalize(viewPos),sunVec);
    float isMoon = float(VoL < 0.0);
    float sun = pow(abs(VoL), 800.0 * isMoon + 950 ) * (.98 - sqrt(rainStrength));

    vec3 sunMoonCol = mix(moonColor * moonVisibility, sunColor * sunVisibility, float(VoL > 0.0));
    color += sun * sunMoonCol * 16.0;
}

// Function to draw star
void SunGlare(inout vec3 color, vec3 viewPos, vec3 lightCol) {
    float VoL = dot(normalize(viewPos), lightVec);
    float visfactor = 0.05 * (-0.8 * timeBrightness + 1.0) * (3.0 * rainStrength + 1.0);
    float invvisfactor = 1.0 - visfactor;

    float visibility = clamp(VoL * 0.5 + 0.5, 0.0, 1.0);
    visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
    visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
    visibility = mix(1.0, visibility, 0.03125 * eBS + 0.96875) * (1.0 - rainStrength * eBS * 0.875);
    visibility *= shadowFade * LIGHT_SHAFT_STRENGTH;
    //visibility *= voidFade;
    #if MC_VERSION >= 11800
    visibility *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
    #else
    visibility *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
    #endif

    #ifdef LIGHT_SHAFT
    if (isEyeInWater == 1) color += 0.25 * lightCol * visibility;
    #else
    color += 0.25 * lightCol * visibility * (1.0 + 0.25 * isEyeInWater);
    #endif
}

// Function to add birds flying in the sky
void DrawBirds(inout vec3 color, vec3 viewPos) {
    // Define bird properties such as size, color, and behavior
    float birdSize = 0.1; // Size of the bird
    vec3 birdColor = vec3(0.0, 0.0, 1.0); // Blue color for birds

    // Calculate bird positions and behavior
    // Here you would implement the logic to determine bird positions and movement
    // For simplicity, let's just add a single bird at a fixed position for now
    vec3 birdPosition = vec3(0.2, 0.5, 0.0); // Example bird position

    // Draw birds based on their positions
    float distanceToBird = length(viewPos - birdPosition);
    if (distanceToBird < birdSize) {
        color += birdColor;
    }
}

//Includes//
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/atmospherics/sky.glsl"
//Program//
void main() {
    #ifdef OVERWORLD
    vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    
    vec3 albedo = GetSkyColor(viewPos.xyz, false);
    
    #ifdef ROUND_SUN_MOON
    vec3 lightMA = mix(lightMorning, lightEvening, mefade);
    vec3 sunColor = mix(lightMA, sqrt(lightDay * lightMA * LIGHT_DI), timeBrightness);
    vec3 moonColor = sqrt(lightNight);

    RoundSunMoon(albedo, viewPos.xyz, sunColor, moonColor);
    #endif
    
    #ifdef STARS
    if (moonVisibility > 0.0) DrawStars(albedo.rgb, viewPos.xyz);
    #endif

    float dither = Bayer8(gl_FragCoord.xy);

    #ifdef AURORA
    albedo.rgb += DrawAurora(viewPos.xyz, dither, 24);
    #endif

    SunGlare(albedo, viewPos.xyz, lightCol);

    // Draw birds flying in the sky
    DrawBirds(albedo.rgb, viewPos.xyz);
    albedo.rgb *= 1.0 + nightVision;
    #ifdef CLASSIC_EXPOSURE
    albedo.rgb *= 4.0 - 3.0 * eBS;
    #endif

    #if ALPHA_BLEND == 0
    albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
    albedo.rgb = albedo.rgb + dither / vec3(64.0);
    #endif
    #endif
    
    #ifdef END
	
    vec3 albedo = vec3(1.0);
    #endif
    
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(albedo, 1.0 - star);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float star;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
    float ang = fract(timeAngle - 0.25);
    ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
    sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

    upVec = normalize(gbufferModelView[1].xyz);
    
    gl_Position = ftransform();

    star = float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);
}

#endif