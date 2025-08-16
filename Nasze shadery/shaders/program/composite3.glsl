// Screen-space godrays (light shafts) accumulating along sun direction
#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;


vec3 projectAndDivide(mat4 m, vec3 p){
    vec4 h = m * vec4(p,1.0);
    return h.xyz / max(h.w, 1e-6);
}

// Compute sun position in screen UV using world sunPosition
bool getSunUV(out vec2 sunUV){
    vec3 sunWorld = cameraPosition + normalize(sunPosition) * 1000.0;
    vec4 sunVS = gbufferModelView * vec4(sunWorld, 1.0);
    vec3 ndc = projectAndDivide(gbufferProjection, sunVS.xyz);
    sunUV = ndc.xy * 0.5 + 0.5;
    return all(greaterThanEqual(sunUV, vec2(0.0))) && all(lessThanEqual(sunUV, vec2(1.0)));
}

void main(){
    vec2 uv = texcoord;
    vec2 sunUV; bool onScreen = getSunUV(sunUV);
    vec3 outCol = vec3(0.0);

    #if GODRAYS
        // Radial sampling from pixel towards sun
        vec2 dir = sunUV - uv;
        float dist = length(dir);
        if(dist > 1e-4){
            vec2 stepv = dir / float(RAYS_STEPS);
            vec2 p = uv;
            float decay = 0.95;
            float illum = GODRAYS_INTENSITY;
            for(int i=0;i<RAYS_STEPS;i++){
                p += stepv;
                // break if leaving screen
                if(p.x<=0.0 || p.y<=0.0 || p.x>=1.0 || p.y>=1.0) break;
                float depth = texture2D(depthtex0, p).r;
                // Sky mask from depth far and brightness
                float sky = smoothstep(0.98, 1.0, depth);
                vec3 src = texture2D(colortex0, p).rgb;
                float bright = dot(src, vec3(0.2126,0.7152,0.0722));
                float samp = sky * smoothstep(0.6, 1.2, bright);
                outCol += samp * illum;
                illum *= decay;
            }
            outCol /= float(RAYS_STEPS);
        }
    #endif

    // Lightweight view-ray volumetric scattering contribution
    #if FOG_ENABLE && CLOUDS_ENABLE
        vec3 Ldir = normalize(getDirectionalLightDir());
        // Sample a few points along the view ray in clip space
        float depthC = texture2D(depthtex0, uv).r;
        // only accumulate in air (not close geometry)
        if(depthC > 0.6){
            float accum = 0.0;
            float stepT = 1.0 / float(VOLUME_STEPS);
            for(int i=0;i<VOLUME_STEPS;i++){
                float t = (float(i)+0.5)*stepT;
                // reconstruct a far sample by lerping towards sky
                vec2 sUV = mix(uv, sunUV, t);
                float sky = smoothstep(0.9, 1.0, texture2D(depthtex0, sUV).r);
                if(sky < 0.5) continue;
                // approximate world position along ray: use camera forward assumption negligible for simplicity
                vec3 world = cameraPosition + normalize(sunPosition) * (t*200.0);
                float cd = cloudDensityAt(world);
                // Henyey–Greenstein-like phase function (approx)
                float cosTheta = dot(Ldir, normalize(vec3(0.0,0.0,-1.0)));
                float g = PHASE_G;
                float phase = (1.0 - g*g) / pow(1.0 + g*g - 2.0*g*cosTheta, 1.5);
                accum += cd * phase;
            }
            outCol += accum * 0.02 * GODRAYS_INTENSITY;
        }
    #endif

    /* DRAWBUFFERS:2 */
    gl_FragData[2] = vec4(outCol, 1.0);
}
