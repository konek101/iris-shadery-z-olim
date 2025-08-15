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
    vec3 src0 = texture2D(colortex0, uv).rgb;
    vec3 src3 = texture2D(colortex3, uv).rgb;
    vec3 base = (dot(src3, vec3(1.0)) > 1e-3) ? src3 : src0;

    float depth = texture2D(depthtex0, uv).r;
    // If depth is invalid/sky, skip RT/PT and output base
    if(depth >= 0.9999){
        gl_FragColor = vec4(base, 1.0);
        return;
    }

    // Proper view-space reconstruction with divide by w
    vec3 viewPos = reconstructViewPos(uv, depth);
    vec3 ddx = dFdx(viewPos);
    vec3 ddy = dFdy(viewPos);
    vec3 normal = normalize(cross(ddx, ddy));

    vec3 color = base;

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
