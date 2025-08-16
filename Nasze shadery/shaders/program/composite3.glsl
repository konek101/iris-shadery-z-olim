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
            vec2 stepv = dir / 64.0;
            vec2 p = uv;
            float decay = 0.95;
            float illum = GODRAYS_INTENSITY;
            for(int i=0;i<64;i++){
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
            outCol /= 64.0;
        }
    #endif

    /* DRAWBUFFERS:2 */
    gl_FragData[2] = vec4(outCol, 1.0);
}
