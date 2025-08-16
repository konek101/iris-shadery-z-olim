#define FINAL

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/lighting.glsl"

varying vec2 texcoord;

// Include after uniforms so referenced globals are known
#include "/lib/util/rt.glsl"

// Simple ACES tonemapper as fallback when no composite tonemap runs
vec3 tonemapACES(vec3 x){
    const float a=2.51; const float b=0.03; const float c=2.43; const float d=0.59; const float e=0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

vec3 reconstructViewPos_Local(vec2 uv, float depth){
    vec3 ndc = vec3(uv*2.0-1.0, depth*2.0-1.0);
    vec4 v = gbufferProjectionInverse * vec4(ndc,1.0);
    return v.xyz / max(v.w, 1e-6);
}

void main(){
    vec2 uv = texcoord;
    // Safe passthrough with optional RT features below
    vec3 base = texture2D(colortex0, uv).rgb;
    vec3 ao   = texture2D(colortex1, uv).rgb;
    vec3 rays = texture2D(colortex2, uv).rgb;
    vec3 bloom= texture2D(colortex3, uv).rgb;
    vec3 color = base;

    // Volumetric fog (height + distance)
    #if FOG_ENABLE
        float depth = texture2D(depthtex0, uv).r;
        vec3 viewPos = reconstructViewPos_Local(uv, depth);
        vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos,1.0)).xyz;
        float dist = length(viewPos);
        float h = max(0.0, worldPos.y);
        float sigma = FOG_DENSITY * (1.0 + h * FOG_HEIGHT_FALLOFF);
        float fog = 1.0 - exp(-sigma * dist);
        fog = clamp(fog, 0.0, 1.0);
        // Fog color: slightly warm daylight from Kelvin
        vec3 fogColor = kelvinToRGB(5500.0) * 0.8;
        color = mix(color, fogColor, fog);
        // Godrays strengthened only where fog exists
        rays *= fog;
    #endif
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
