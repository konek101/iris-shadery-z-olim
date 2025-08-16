#define FINAL

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

uniform float frameTimeCounter;
uniform float frameTimeSmooth;

// Include after uniforms so referenced globals are known
#include "/lib/util/rt.glsl"

// Simple ACES tonemapper as fallback when no composite tonemap runs
vec3 tonemapACES(vec3 x){
    const float a=2.51; const float b=0.03; const float c=2.43; const float d=0.59; const float e=0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main(){
    vec2 uv = texcoord;
    // Base scene color routed from composite into colortex3
    vec3 base = texture2D(colortex3, uv).rgb;

    float depth = texture2D(depthtex0, uv).r;

    vec3 color = base;

    // Apply RT/PT only when depth is valid (avoid sky/cutouts)
    if(depth < 0.9999){
        // Proper view-space reconstruction with divide by w
        vec3 viewPos = reconstructViewPos(uv, depth);
        vec3 ddx = dFdx(viewPos);
        vec3 ddy = dFdy(viewPos);
        vec3 normal = normalize(cross(ddx, ddy));

        #if RT_MODE > 0
            vec3 V = normalize(-viewPos);
            color = applySSR(color, viewPos, V, normal, uv);
            #if RT_MODE == 2
                color += applyOneBounceGI(viewPos, normal, uv) * GI_STRENGTH;
            #endif
        #endif
    }

    // Add bloom from colortex3 (if available), then tonemap once
    #if BLOOM
        vec3 bloom = texture2D(colortex3, uv).rgb * BLOOM_STRENGTH;
        color += bloom;
    #endif
    color = tonemapACES(color);
    gl_FragColor = vec4(color, 1.0);
}
