// Directional sunlight + optional PCF shadows in terrain pass
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

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
float sampleShadow(vec3 wpos){
    vec4 lc = shadowProjection * (shadowModelView * vec4(wpos, 1.0));
    vec3 ndc = lc.xyz / max(lc.w, 1e-6);
    vec2 suv = ndc.xy * 0.5 + 0.5;
    if(suv.x<=0.0||suv.y<=0.0||suv.x>=1.0||suv.y>=1.0) return 1.0;
    float rcv = ndc.z;
    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    float cnt=0.0;
    for(int y=0;y<2;++y){
        for(int x=0;x<2;++x){
            vec2 o = (vec2(x,y)-0.5) * texel * 1.5;
            float d = texture2D(shadowtex0, suv+o).r*2.0-1.0;
            cnt += (rcv <= d+0.0015) ? 1.0 : 0.0;
        }
    }
    return cnt*0.25;
}

void main(){
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if(albedo.a < 0.1) discard;
    vec3 lm = texture2D(lightmap, lmcoord).rgb;

    vec3 N = normalize(encodedNormal);
    vec3 L = normalize(sunPosition);

    float NdotL = 0.0;
    float shadow = 1.0;
    #if SUNLIGHT_ENABLE
        NdotL = max(dot(N, L), 0.0);
        shadow = sampleShadow(fragPos);
    #endif

    // Ambient base, scaled by lightmap
    vec3 ambient = albedo.rgb * (float(AMBIENT_MULT) / 200.0) * lm;
    // Sunlight diffuse with shadowing
    vec3 sunColor = vec3(1.0, 0.97, 0.92);
    vec3 sunLit = albedo.rgb * sunColor * NdotL * shadow;

    vec3 outCol = ambient + sunLit;
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(outCol, albedo.a);
}
#endif
