// Water effects: SSR reflections/refractions/underwater distortion
// Fix: use SSR from rt.glsl with Fresnel; remove noisy caustics dots
#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/rt.glsl"
#include "/lib/util/lighting.glsl"

varying vec2 texcoord;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }

void main(){
    vec2 uv = texcoord;
    vec3 base = texture2D(colortex0, uv).rgb;

    #if WATER_ENABLE
        float t = frameTimeCounter;
        // Small waves to perturb normals for Fresnel and SSR
        vec2 wave = vec2(sin(uv.y*60.0 + t*1.6), cos(uv.x*60.0 - t*1.2)) * 0.0020;
        vec2 uvd = uv + wave * 0.5;
        vec3 refr = texture2D(colortex0, uvd).rgb;

        // Reconstruct view position and direction
        float depth = texture2D(depthtex0, uv).r;
        vec3 viewPos = reconstructViewPos(uv, depth);
        vec3 viewDir = normalize(-viewPos);
        // Approximate water normal from waves in screen-space
        vec3 n = normalize(vec3(-wave.x*80.0, 1.0, -wave.y*80.0));

        vec3 colorSSR = base;
        #if SSR_WATER_ENABLE && RT_ENABLE
            colorSSR = applySSR(base, viewPos, viewDir, n, uv);
        #endif
        float NoV = max(dot(n, -viewDir), 0.0);
        float fres = pow(1.0 - NoV, 5.0);
        base = mix(refr, colorSSR, clamp(fres*0.9, 0.0, 0.9));
        // Optional underwater overlay handled in terrain pass; avoid noisy dots here.
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(base, 1.0);
}
