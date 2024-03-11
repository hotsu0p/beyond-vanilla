

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D colortex0;

//Optifine Constants//
const bool colortex0MipmapEnabled = true;

//Common Variables//
float ph = 0.8 / min(360.0, viewHeight);
float pw = ph / aspectRatio;
vec2 view = vec2(1.0 / viewWidth, 1.0 / viewHeight);

float weight[6] = float[6](0.0556, 0.1667, 0.2777, 0.2777, 0.1667, 0.0556);

//Common Functions//
vec3 BloomTile(float lod, vec2 coord, vec2 offset) {
    vec3 bloom = vec3(0.0);
    float scale = exp2(lod);
    coord = (coord - offset) * scale;
    vec2 padding = vec2(0.5) + 2.0 * view * scale;

    if (abs(coord.x - 0.5) < padding.x && abs(coord.y - 0.5) < padding.y) {
        for (int i = -2; i <= 2; i++) {
            for (int j = -2; j <= 2; j++) {
                float wg = weight[i + 2] * weight[j + 2];
                vec2 pixelOffset = vec2(float(i) * pw, float(j) * ph);
                vec2 sampleCoord = coord + pixelOffset * scale;
                bloom += texture2D(colortex0, sampleCoord).rgb * wg;
            }
        }
    }

    return pow(bloom / 32.0, vec3(0.25));
}

#include "/lib/util/dither.glsl"

//Program//
void main() {
	vec2 bloomCoord = texCoord * viewHeight * 0.8 / min(360.0, viewHeight);
	vec3 blur =  BloomTile(1.0, bloomCoord, vec2(0.0      , 0.0   ));
	     blur += BloomTile(2.0, bloomCoord, vec2(0.50     , 0.0   ) + vec2( 4.0, 0.0) * view);
	     blur += BloomTile(3.0, bloomCoord, vec2(0.50     , 0.25  ) + vec2( 4.0, 4.0) * view);
	     blur += BloomTile(4.0, bloomCoord, vec2(0.625    , 0.25  ) + vec2( 8.0, 4.0) * view);
	     blur += BloomTile(5.0, bloomCoord, vec2(0.6875   , 0.25  ) + vec2(12.0, 4.0) * view);
	     blur += BloomTile(6.0, bloomCoord, vec2(0.625    , 0.3125) + vec2( 8.0, 8.0) * view);
	     blur += BloomTile(7.0, bloomCoord, vec2(0.640625 , 0.3125) + vec2(12.0, 8.0) * view);
		
		 blur = clamp(blur + (Bayer8(gl_FragCoord.xy) - 0.5) / 384.0, vec3(0.0), vec3(1.0));

    /* DRAWBUFFERS:1 */
	gl_FragData[0] = vec4(blur, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif