// Composite pass for accumulation / post
#include "/lib/uniforms.glsl"
#include "/lib/util/rt.glsl"

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

void main(){
    vec2 uv = texcoord;
    vec3 base = texture2D(colortex0, uv).rgb; // source from prior stage
    // Copy to colortex1 to provide a stable read source for later stages
    /* DRAWBUFFERS:1 */
    gl_FragData[1] = vec4(base,1.0);
}
