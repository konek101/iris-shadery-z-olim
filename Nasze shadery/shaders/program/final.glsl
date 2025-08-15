#define FINAL

#include "/lib/common.glsl"
#include "/lib/util/rt.glsl"

varying vec2 texcoord;

// Engine-provided uniforms (declared here once for this stage)
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float frameTimeCounter;
uniform float frameTimeSmooth;

void main(){
    vec2 uv = texcoord;
    vec4 base = texture2D(colortex0, uv);

    float depth = texture2D(depthtex0, uv).r;
    vec3 ndc = vec3(uv*2.0-1.0, depth*2.0-1.0);
    vec3 viewPos = (gbufferProjectionInverse * vec4(ndc,1.0)).xyz;
    vec3 ddx = dFdx(viewPos);
    vec3 ddy = dFdy(viewPos);
    vec3 normal = normalize(cross(ddx, ddy));

    vec3 color = base.rgb;

    #if RT_MODE > 0
    vec3 V = normalize(-viewPos);
    color = applySSR(color, viewPos, V, normal, uv);
        #if RT_MODE == 2
            color += applyOneBounceGI(viewPos, normal, uv) * GI_STRENGTH;
        #endif
    #endif

    // basic post
    gl_FragColor = vec4(color, 1.0);
}
