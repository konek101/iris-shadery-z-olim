#include "/lib/uniforms.glsl"

#ifdef VERTEX_SHADER
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;

void main(){
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D texture;
uniform sampler2D lightmap;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;

void main(){
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    vec3 lm = texture2D(lightmap, lmcoord).rgb;
    vec4 color = vec4(albedo.rgb * lm, albedo.a);
    if(color.a < 0.1) discard;
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
}
#endif
