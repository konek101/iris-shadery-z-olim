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
    vec3 c0 = texture2D(colortex0, uv).rgb;
    vec3 c3 = texture2D(colortex3, uv).rgb;
    float l0 = dot(c0, vec3(0.2126,0.7152,0.0722));
    float l3 = dot(c3, vec3(0.2126,0.7152,0.0722));
    vec3 base = (l3 > l0 ? c3 : c0);
    if(max(l0, l3) < 1e-6) base = vec3(0.02); // last-resort to avoid pure black

    float depth = texture2D(depthtex0, uv).r;

    // Proper view-space reconstruction with divide by w
    vec3 viewPos = reconstructViewPos(uv, depth);
    vec3 ddx = dFdx(viewPos);
    vec3 ddy = dFdy(viewPos);
    vec3 normal = normalize(cross(ddx, ddy));

    vec3 color = base;

    // If depth is invalid (sky), skip RT/PT; else apply
    if(depth < 0.9999){
        #if RT_MODE > 0
        vec3 V = normalize(-viewPos);
        color = applySSR(color, viewPos, V, normal, uv);
            #if RT_MODE == 2
                color += applyOneBounceGI(viewPos, normal, uv) * GI_STRENGTH;
            #endif
        #endif
    }

    // Fallback tonemap to avoid overly dark linear color when composites are off
    color = tonemapACES(color);
    gl_FragColor = vec4(color, 1.0);
}
