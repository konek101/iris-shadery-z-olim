// Directional sunlight + optional PCF shadows in terrain pass
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/util/lighting.glsl"

#ifdef VERTEX_SHADER
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 fragPos;           // world-space
varying vec3 encodedNormal;     // world-space normal

void main(){
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vertexColor = gl_Color;

    // Base transforms
    vec4 posVS = gbufferModelView * gl_Vertex;
    vec3 wpos  = (gbufferModelViewInverse * posVS).xyz;

    // Leaf-only waving using block ID from block.properties (10009)
    int blockId = mc_Entity.x;
    if(blockId == 10009){
        float t = frameTimeCounter;
        // Gentle wind sway based on world position
        float sway = sin(t*1.7 + wpos.x*0.25 + wpos.z*0.21)*0.08;
        float lift = sin(t*2.3 + wpos.x*0.11)*0.02;
        vec2 windDir = normalize(vec2(0.6, 0.8));
        wpos += vec3(windDir * sway, lift);
    }

    // Write varyings from waved position
    fragPos = wpos;

    // Transform normal to world
    vec3 nVS = normalize(mat3(gbufferModelView) * gl_Normal.xyz);
    encodedNormal = normalize(mat3(gbufferModelViewInverse) * nVS);

    // Final position
    gl_Position = gbufferProjection * (gbufferModelView * vec4(wpos, 1.0));
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D texture;
uniform sampler2D lightmap;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vertexColor;
varying vec3 fragPos;
varying vec3 encodedNormal;

// Simple 2x2 PCF shadow
// Adjustable bias to reduce acne and detach artifacts
float sampleShadow(vec3 wpos){
    #if SHADOW_PCSS_ENABLE
    return computeShadowPCSS(wpos, SHADOW_BIAS);
    #else
    return computeShadowPCF(wpos, SHADOW_BIAS);
    #endif
}

void main(){
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if(albedo.a < 0.1) discard;
    vec3 lm = texture2D(lightmap, lmcoord).rgb;

    vec3 N = normalize(encodedNormal);
    vec3 L = normalize(getDirectionalLightDir());

    float NdotL = 0.0;
    float shadow = 1.0;
    #if SUNLIGHT_ENABLE
        NdotL = max(dot(N, L), 0.0);
        shadow = sampleShadow(fragPos);
    #endif

    // Ambient base, scaled by lightmap, soft blend
    vec3 ambient = albedo.rgb * (float(AMBIENT_MULT) / 200.0) * lm;
    // Time-of-day light color and intensity
    vec3 sunColor; float sunInt;
    getLightColorIntensity(sunColor, sunInt);
    float cloudTrans = cloudShadowAt(fragPos);
    vec3 sunLit = albedo.rgb * sunColor * (NdotL * sunInt) * shadow * cloudTrans;

    // Weather: darken slightly in rain and boost spec highlights (simple approximation)
    float rain = clamp(rainStrength, 0.0, 1.0);
    vec3 weatherTint = mix(vec3(1.0), vec3(0.92,0.94,0.98), rain*0.6);
    vec3 outCol = (ambient + sunLit) * weatherTint;
    // Underwater caustics on surfaces when camera underwater
    if(isEyeInWater == 1){
        float c = causticsAt(fragPos) * CAUSTICS_STRENGTH;
        outCol += c * 0.6 * kelvinToRGB(5200.0);
    }
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(outCol, albedo.a);
}
#endif
