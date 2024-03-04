//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec4 color;
uniform float time;
//Uniforms//
uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D texture;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;

//Program//
void main() {
    // Sample the texture and multiply it by the base color
    vec4 albedo = texture2D(texture, texCoord) * color;

    // Basic rainbow glint effect using a sine wave for color cycling
    float speed = time * 2.0; // Control the speed of the color cycling

    // Generate a rainbow color based on a sine wave with different offsets for RGB channels
    vec3 rainbowColor = vec3(
        sin(speed) * 0.5 + 0.5,        // Red channel cycles with time
        sin(speed + 2.0) * 0.5 + 0.5,  // Green channel, offset for color variation
        sin(speed + 4.0) * 0.5 + 0.5   // Blue channel, further offset
    );

    // Apply the rainbow glint by blending it slightly with the original color
    float mixRatio = 0.3; // Adjust the mix ratio for subtlety
    albedo.rgb = mix(albedo.rgb, rainbowColor, mixRatio);

    // Output the final color with the rainbow glint
    gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec4 color;

//Uniforms//
#ifdef TAA
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
#endif

//Includes//
#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	color = gl_Color;

	#ifdef WORLD_CURVATURE
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	if (gl_ProjectionMatrix[2][2] < -0.5) position.y -= WorldCurvature(position.xz);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
	gl_Position = ftransform();
	#endif
	
	#if defined TAA && !defined TAA_SELECTIVE
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif