#define FINAL

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

uniform float frameTimeCounter;
uniform float frameTimeSmooth;

// Include after uniforms so referenced globals are known
#include "/lib/util/rt.glsl"

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
