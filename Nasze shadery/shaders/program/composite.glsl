// Composite pass for routing base color
// Fix: ensure helpers available consistently across composite stages
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/util/lighting.glsl"

varying vec2 texcoord;

void main(){
    vec2 uv = texcoord;
    vec3 base = texture2D(colortex0, uv).rgb;
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(base,1.0);
}
