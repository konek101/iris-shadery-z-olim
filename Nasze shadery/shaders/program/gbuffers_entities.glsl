#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/util/lighting.glsl"

#ifdef VERTEX_SHADER
varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 fragPos;           // world-space
varying vec3 encodedNormal;     // world-space normal
void main(){
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
    vec4 posVS = gbufferModelView * gl_Vertex;
    fragPos = (gbufferModelViewInverse * posVS).xyz;
    vec3 nVS = normalize(mat3(gbufferModelView) * gl_Normal.xyz);
    encodedNormal = normalize(mat3(gbufferModelViewInverse) * nVS);
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D texture;
uniform sampler2D lightmap;
varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 fragPos;
varying vec3 encodedNormal;

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

    vec3 N = normalize(encodedNormal);
    vec3 L = normalize(getDirectionalLightDir());
    vec3 V = normalize(cameraPosition - fragPos);
    float NdotL = 0.0;
    float shadow = 1.0;
    #if SUNLIGHT_ENABLE
        NdotL = max(dot(N,L), 0.0);
        shadow = sampleShadow(fragPos);
    #endif

    // Lightmap fallback
    vec3 lm = vec3(1.0);
    #ifdef lightmap
        lm = texture2D(lightmap, (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy).rgb;
    #endif

    vec3 ambient = albedo.rgb * (float(AMBIENT_MULT)/200.0) * lm;
    vec3 sunColor; float sunInt; getLightColorIntensity(sunColor, sunInt);
    float cloudTrans = cloudShadowAt(fragPos);
    vec3 diffuse = albedo.rgb * sunColor * (NdotL * sunInt) * shadow * cloudTrans;
    // Blinn-Phong specular
    vec3 H = normalize(L+V);
    float NdotH = max(dot(N,H), 0.0);
    vec3 spec = sunColor * pow(NdotH, 64.0) * 0.15 * shadow * sunInt;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(ambient + diffuse + spec, albedo.a);
}
#endif
