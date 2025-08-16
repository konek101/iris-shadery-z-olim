// Composite pass for routing base color
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

void main(){
    vec2 uv = texcoord;
    vec3 base = texture2D(colortex0, uv).rgb;
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(base,1.0);
}
