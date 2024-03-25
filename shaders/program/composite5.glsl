

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor, darknessFactor;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;

#ifdef DIRTY_LENS
uniform sampler2D depthtex2;
#endif

#ifdef LENS_FLARE
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
#endif

#ifdef UNDERGROUND_SKY
uniform vec3 cameraPosition;
#endif

#ifdef MULTICOLORED_BLOCKLIGHT
uniform sampler2D colortex9;
#endif

//Optifine Constants//
const bool colortex2Clear = false;

#ifdef AUTO_EXPOSURE
const bool colortex0MipmapEnabled = true;
#endif

#ifdef MULTICOLORED_BLOCKLIGHT
const bool colortex9MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void UnderwaterDistort(inout vec2 texCoord) {
	vec2 originalTexCoord = texCoord;

	texCoord += vec2(
		cos(texCoord.y * 32.0 + frameTimeCounter * 3.0) * .001,
		sin(texCoord.x * 32.0 + frameTimeCounter * 1.5) * .002 
	);

	float mask = float(
		texCoord.x > 0.0 && texCoord.x < 1.0 &&
	    texCoord.y > 0.0 && texCoord.y < 1.0
	);
	if (mask < 0.5) texCoord = originalTexCoord;
}

void RetroDither(inout vec3 color, float dither) {
	color.rgb = pow(color.rgb, vec3(0.25));
	float lenColor = length(color);
	vec3 normColor = color / lenColor;

	dither = mix(dither, 0.5, exp(-2.0 * lenColor)) - 0.25;
	color = normColor * floor(lenColor * 4.0 + dither * 1.7) / 4.0;

	color = max(pow(color.rgb, vec3(4.0)), vec3(0.0));
}

vec3 GetBloomTile(float lod, vec2 coord, vec2 offset) {
	float scale = exp2(lod);
	float resScale = 1.25 * min(360.0, viewHeight) / viewHeight;
	vec3 bloom = texture2D(colortex1, (coord / scale + offset) * resScale).rgb;
	bloom *= bloom; bloom *= bloom * 32.0;
	return bloom;
}

void Bloom(inout vec3 color, vec2 coord) {
	vec2 view = vec2(1.0 / viewWidth, 1.0 / viewHeight);
	vec3 blur1 = GetBloomTile(1.0, coord, vec2(0.0      , 0.0   ) + vec2( 0.5, 0.0) * view);
	vec3 blur2 = GetBloomTile(2.0, coord, vec2(0.50     , 0.0   ) + vec2( 4.5, 0.0) * view);
	vec3 blur3 = GetBloomTile(3.0, coord, vec2(0.50     , 0.25  ) + vec2( 4.5, 4.0) * view);
	vec3 blur4 = GetBloomTile(4.0, coord, vec2(0.625    , 0.25  ) + vec2( 8.5, 4.0) * view);
	vec3 blur5 = GetBloomTile(5.0, coord, vec2(0.6875   , 0.25  ) + vec2(12.5, 4.0) * view);
	vec3 blur6 = GetBloomTile(6.0, coord, vec2(0.625    , 0.3125) + vec2( 8.5, 8.0) * view);
	vec3 blur7 = GetBloomTile(7.0, coord, vec2(0.640625 , 0.3125) + vec2(12.5, 8.0) * view);
	
	#ifdef DIRTY_LENS
	float newAspectRatio = 1.777777777777778 / aspectRatio;
	vec2 scale = vec2(max(newAspectRatio, 1.0), max(1.0 / newAspectRatio, 1.0));
	float dirt = texture2D(depthtex2, (coord - 0.5) / scale + 0.5).r;
	dirt *= length(blur6 / (1.0 + blur6));
	blur3 *= dirt *  2.0 + 1.0;
	blur4 *= dirt *  4.0 + 1.0;
	blur5 *= dirt *  8.0 + 1.0;
	blur6 *= dirt * 16.0 + 1.0;
	blur7 *= dirt * 32.0 + 1.0;
	#endif

	#if BLOOM_RADIUS == 1
	vec3 blur = blur1;
	#elif BLOOM_RADIUS == 2
	vec3 blur = (blur1 * 1.23 + blur2) / 2.23;
	#elif BLOOM_RADIUS == 3
	vec3 blur = (blur1 * 1.71 + blur2 * 1.52 + blur3) / 4.23;
	#elif BLOOM_RADIUS == 4
	vec3 blur = (blur1 * 2.46 + blur2 * 2.25 + blur3 * 1.71 + blur4) / 7.42;
	#elif BLOOM_RADIUS == 5
	vec3 blur = (blur1 * 3.58 + blur2 * 3.35 + blur3 * 2.72 + blur4 * 1.87 + blur5) / 12.52;
	#elif BLOOM_RADIUS == 6
	vec3 blur = (blur1 * 5.25 + blur2 * 4.97 + blur3 * 4.20 + blur4 * 3.13 + blur5 * 2.00 + blur6) / 20.55;
	#elif BLOOM_RADIUS == 7
	vec3 blur = (blur1 * 7.76 + blur2 * 7.41 + blur3 * 6.43 + blur4 * 5.04 + blur5 * 3.51 + blur6 * 2.11 + blur7) / 33.26;
	#endif

	#if BLOOM_CONTRAST == 0
	color = mix(color, blur, 0.2 * BLOOM_STRENGTH);
	#else
	vec3 bloomContrast = vec3(exp2(BLOOM_CONTRAST * 0.25));
	color = pow(color, bloomContrast);
	blur = pow(blur, bloomContrast);
	vec3 bloomStrength = pow(vec3(0.2 * BLOOM_STRENGTH), bloomContrast);
	color = mix(color, blur, bloomStrength);
	color = pow(color, 1.0 / bloomContrast);
	#endif
	
}

void AutoExposure(inout vec3 color, inout float exposure, float tempExposure) {
	float exposureLod = log2(viewHeight * AUTO_EXPOSURE_RADIUS);
	
	exposure = length(texture2DLod(colortex0, vec2(0.5), exposureLod).rgb);
	exposure = max(exposure, 0.0001);
	
	color /= 2.0 * tempExposure + 0.125;
}

void ColorGrading(inout vec3 color) {
	vec3 cgColor = pow(color.r, CG_RC) * pow(vec3(CG_RR, CG_RG, CG_RB) / 255.0, vec3(2.2)) +
				   pow(color.g, CG_GC) * pow(vec3(CG_GR, CG_GG, CG_GB) / 255.0, vec3(2.2)) +
				   pow(color.b, CG_BC) * pow(vec3(CG_BR, CG_BG, CG_BB) / 255.0, vec3(2.2));
	vec3 cgMin = pow(vec3(CG_RM, CG_GM, CG_BM) / 255.0, vec3(2.2));
	color = (cgColor * (1.0 - cgMin) + cgMin) * vec3(CG_RI, CG_GI, CG_BI);
	
	vec3 cgTint = pow(vec3(CG_TR, CG_TG, CG_TB) / 255.0, vec3(2.2)) * GetLuminance(color) * CG_TI;
	color = mix(color, cgTint, CG_TM);
}

void Tonemap(inout vec3 color) {
	color = color * exp2(2.0 + EXPOSURE);
	color = color / pow(pow(color, vec3(TONEMAP_WHITE_CURVE)) + 1.0, vec3(1.0 / TONEMAP_WHITE_CURVE));
	color = pow(color, mix(vec3(TONEMAP_LOWER_CURVE), vec3(TONEMAP_UPPER_CURVE), sqrt(color)));
}

void ColorSaturation(inout vec3 color) {
	float grayVibrance = (color.r + color.g + color.b) / 3.0;
	float graySaturation = dot(color, vec3(0.299, 0.587, 0.114));

	float mn = min(color.r, min(color.g, color.b));
	float mx = max(color.r, max(color.g, color.b));
	float sat = (1.0 - (mx - mn)) * (1.0 - mx) * grayVibrance * 5.0;
	vec3 lightness = vec3((mn + mx) * 0.5);

	color = mix(color, mix(color, lightness, 1.0 - VIBRANCE), sat);
	color = mix(color, lightness, (1.0 - lightness) * (2.0 - VIBRANCE) / 2.0 * abs(VIBRANCE - 1.0));
	color = color * SATURATION - graySaturation * (SATURATION - 1.0);
}

#ifdef LENS_FLARE
vec2 GetLightPos() {
	vec4 tpos = gbufferProjection * vec4(sunPosition, 1.0);
	tpos.xyz /= tpos.w;
	return tpos.xy / tpos.z * 0.5;
}
#endif

//Includes//
#include "/lib/color/lightColor.glsl"

#ifdef LENS_FLARE
#include "/lib/post/lensFlare.glsl"
#endif

#ifdef RETRO_FILTER
#include "/lib/util/dither.glsl"
#endif

//Program//
void main() {
    vec2 newTexCoord = texCoord;

	#ifdef UNDERWATER_DISTORTION
	if (isEyeInWater == 1.0) UnderwaterDistort(newTexCoord);
	#endif
	
	vec3 color = texture2D(colortex0, newTexCoord).rgb;
	
	#ifdef AUTO_EXPOSURE
	float tempExposure = texture2D(colortex2, vec2(pw, ph)).r;
	#endif

	#ifdef LENS_FLARE
	float tempVisibleSun = texture2D(colortex2, vec2(3.0 * pw, ph)).r;
	#endif

	vec3 temporalColor = vec3(0.0);
	#ifdef TAA
	temporalColor = texture2D(colortex2, texCoord).gba;
	#endif
	
	#ifdef RETRO_FILTER
	float dither = Bayer8(gl_FragCoord.xy);
	RetroDither(color.rgb, dither);
	#endif
	
	#ifdef BLOOM
	Bloom(color, newTexCoord);
	#endif
	
	#ifdef AUTO_EXPOSURE
	float exposure = 1.0;
	AutoExposure(color, exposure, tempExposure);
	#endif
	
	#ifdef COLOR_GRADING
	ColorGrading(color);
	#endif
	
    #ifdef VIGNETTE
	float screenDist = length(texCoord - 0.5);
	screenDist *= screenDist * 0.3535 + 0.75;
    color *= 1.0 - screenDist * VIGNETTE_STRENGTH;
	#endif
	
	Tonemap(color);
	
	#ifdef LENS_FLARE
	vec2 lightPos = GetLightPos();
	float truePos = sign(sunVec.z);
	      
    float visibleSun = float(texture2D(depthtex0, lightPos + 0.5).r >= 1.0);
	visibleSun *= max(1.0 - isEyeInWater, eBS) * (1.0 - max(blindFactor, darknessFactor)) * (1.0 - rainStrength);

	#ifdef UNDERGROUND_SKY
	visibleSun *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif
	
	float multiplier = tempVisibleSun * LENS_FLARE_STRENGTH * (length(color) * 0.25 + 0.25);

	if (multiplier > 0.001) LensFlare(color, lightPos, truePos, multiplier);
	#endif
	
	float temporalData = 0.0;
	
	#ifdef AUTO_EXPOSURE
	if (texCoord.x < 2.0 * pw && texCoord.y < 2.0 * ph)
		temporalData = mix(tempExposure, sqrt(exposure), AUTO_EXPOSURE_SPEED);
	#endif

	#ifdef LENS_FLARE
	if (texCoord.x > 2.0 * pw && texCoord.x < 4.0 * pw && texCoord.y < 2.0 * ph)
		temporalData = mix(tempVisibleSun, visibleSun, 0.125);
	#endif
	
	color = pow(color, vec3(1.0 / 2.2));
	
	ColorSaturation(color);
	
	float filmGrain = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 512.0).b;
	color += (filmGrain - 0.5) / 256.0;

	#ifdef MULTICOLORED_BLOCKLIGHT
	vec3 coloredLight = texture2DLod(colortex9, texCoord.xy, 2).rgb;
	coloredLight *= 0.99;
	#endif
	
	/* DRAWBUFFERS:12 */
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(temporalData,temporalColor);
	
	#ifdef MULTICOLORED_BLOCKLIGHT
		/*DRAWBUFFERS:129*/
		gl_FragData[2] = vec4(coloredLight, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif