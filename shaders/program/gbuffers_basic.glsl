

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

#ifdef DYNAMIC_HANDLIGHT
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#endif

#ifdef MULTICOLORED_BLOCKLIGHT
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;

uniform sampler2D colortex9;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef MULTICOLORED_BLOCKLIGHT
#include "/lib/lighting/coloredBlocklight.glsl"
#endif
 uniform vec3 cameraDirection;
//Program//
void main() {
    vec4 albedo = color;

	if (albedo.a > 0.001) {
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#ifdef TAA
		vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
		vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);
		
		#ifdef DYNAMIC_HANDLIGHT
		float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
		float handlight = clamp((heldLightValue - 2.0 * length(viewPos)) / 15.0, 0.0, 0.9333);
		lightmap.x = max(lightmap.x, handlight);
		#endif

		#ifdef TOON_LIGHTMAP
		lightmap = floor(lmCoord * 14.999 * (0.75 + 0.25 * color.a)) / 14.0;
		lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));
		albedo.a = albedo.a * 0.5 + 0.5;

		#ifdef WHITE_WORLD
		if (albedo.a > 0.9) albedo.rgb = vec3(0.35);
		#endif

		float NoL = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float NoU = clamp(dot(normal, upVec), -1.0, 1.0);
		float NoE = clamp(dot(normal, eastVec), -1.0, 1.0);
		float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			  vanillaDiffuse*= vanillaDiffuse;

		#ifdef MULTICOLORED_BLOCKLIGHT
		blocklightCol = ApplyMultiColoredBlocklight(blocklightCol, screenPos);
		#endif
		
  
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, 1.0, NoL, vanillaDiffuse,
				    1.0, 0.0, 0.0, 0.0);

		#if ALPHA_BLEND == 0
		albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
		#endif
	#ifdef HIGHLIGHT
    float worldPosCBSA = worldPos.x + worldPos.y + worldPos.z;
    float cameraPosCBSA = cameraPosition.x + cameraPosition.y + cameraPosition.z;
    float finalPosCBSA = worldPosCBSA + cameraPosCBSA;
    if (dot(worldPos - cameraPosition, cameraDirection) < 1.0) {

        float timeOffset = frameTimeCounter * 0.5; 
        float hue = fract(finalPosCBSA + timeOffset) * 6.5; 
        vec3 rainbowColor;
        if (hue < 1.0) {
            rainbowColor = vec3(1.0, hue, 0.0); // Red to yellow
        } else if (hue < 2.0) {
            rainbowColor = vec3(1.0 - (hue - 1.0), 1.0, 0.0); // Yellow to green
        } else if (hue < 3.0) {
            rainbowColor = vec3(0.0, 1.0, hue - 2.0); // Green to cyan
        } else if (hue < 4.0) {
            rainbowColor = vec3(0.0, 1.0 - (hue - 3.0), 1.0); // Cyan to blue
        } else if (hue < 5.0) {
            rainbowColor = vec3(hue - 4.0, 0.0, 1.0); // Blue to magenta
        } else {
            rainbowColor = vec3(1.0, 0.0, 1.0 - (hue - 4.5)); // Magenta to red
        }
        albedo.rgb = rainbowColor;
    }
#endif
	}

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#ifdef MULTICOLORED_BLOCKLIGHT
	    /* DRAWBUFFERS:08 */
		gl_FragData[1] = vec4(0.0,0.0,0.0,1.0);

		#ifdef ADVANCED_MATERIALS
		/* DRAWBUFFERS:08367 */
		gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
		gl_FragData[3] = vec4(0.0, 0.0, float(gl_FragCoord.z < 1.0), 1.0);
		gl_FragData[4] = vec4(0.0, 0.0, 0.0, 1.0);
		#endif
	#else
		#ifdef ADVANCED_MATERIALS
		/* DRAWBUFFERS:0367 */
		gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
		gl_FragData[2] = vec4(0.0, 0.0, float(gl_FragCoord.z < 1.0), 1.0);
		gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
		#endif
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

#ifdef TAA
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	normal = normalize(gl_NormalMatrix * gl_Normal);
    
	color = gl_Color;

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

    #ifdef WORLD_CURVATURE
	vec4 position = gbufferModelViewInverse * gbufferProjectionInverse * ftransform();
	position.y -= WorldCurvature(position.xz);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
	gl_Position = ftransform();
    #endif
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif