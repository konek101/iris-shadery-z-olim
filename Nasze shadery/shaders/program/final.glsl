#define FINAL

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

// Include after uniforms so referenced globals are known
#include "/lib/util/rt.glsl"

// Simple ACES tonemapper as fallback when no composite tonemap runs
vec3 tonemapACES(vec3 x){
    const float a=2.51; const float b=0.03; const float c=2.43; const float d=0.59; const float e=0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main(){
    vec2 uv = texcoord;
    // Safe passthrough with optional RT features below
    vec3 base = texture2D(colortex0, uv).rgb;
    vec3 ao   = texture2D(colortex1, uv).rgb;
    vec3 rays = texture2D(colortex2, uv).rgb;
    vec3 bloom= texture2D(colortex3, uv).rgb;
    vec3 color = base;
    // AO darkening of diffuse
    #if AO_ENABLE
        color *= mix(1.0, AO_STRENGTH, 1.0 - ao.r);
    #endif

    #if RT_ENABLE
        // RT/GI can be re-enabled here later once baseline is stable
        // (Currently kept off for safety; SSR/GI guards exist in rt.glsl)
    #endif
    // Additive bloom and godrays
    #if BLOOM
        color += bloom;
    #endif
    #if GODRAYS
        color += rays;
    #endif

    gl_FragColor = vec4(color, 1.0);
}
