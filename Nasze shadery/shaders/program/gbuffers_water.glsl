#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/util/lighting.glsl"

#ifdef VERTEX_SHADER
varying vec2 texcoord;
varying vec3 fragPos;           // world-space position
varying vec3 encodedNormal;     // world-space normal
varying vec2 screenUV;          // for scene sampling/masks
void main(){
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec4 posVS = gbufferModelView * gl_Vertex;
    fragPos = (gbufferModelViewInverse * posVS).xyz;
    vec3 nVS = normalize(mat3(gbufferModelView) * gl_Normal.xyz);
    encodedNormal = normalize(mat3(gbufferModelViewInverse) * nVS);
    // derive screen uv from clip
    vec4 clip = gbufferProjection * (gbufferModelView * gl_Vertex);
    vec3 ndc = clip.xyz / max(clip.w, 1e-6);
    screenUV = ndc.xy * 0.5 + 0.5;
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D texture;   // water albedo
#if CAUSTICS_TEX_ENABLE
uniform sampler2D causticstex; // optional caustics texture
#endif
varying vec2 texcoord;
varying vec3 fragPos;
varying vec3 encodedNormal;
varying vec2 screenUV;

// Build a 2D basis from light direction for planar projection
void lightBasis(vec3 L, out vec3 U, out vec3 V){
    vec3 up = abs(L.y) > 0.9 ? vec3(0.0,0.0,1.0) : vec3(0.0,1.0,0.0);
    U = normalize(cross(up, L));
    V = normalize(cross(L, U));
}

vec2 panner(vec2 uv, float speed, float invScale){
    return uv * invScale + vec2(1.0, 0.0) * frameTimeCounter * speed;
}

vec3 sampleCaustics(vec2 uvBase){
    float invScale = 1.0 / CAUSTICS_SCALE;
    vec2 uv1 = panner(uvBase, 0.75 * CAUSTICS_SPEED, invScale);
    vec2 uv2 = panner(uvBase, 1.00 * CAUSTICS_SPEED, -invScale);
    vec3 c1, c2;
    #if CAUSTICS_TEX_ENABLE
        c1 = texture2D(causticstex, uv1).rgb;
        c2 = texture2D(causticstex, uv2).rgb;
    #else
        // Procedural fallback: use sine bands
        c1 = vec3(0.5+0.5*sin(uv1.x*10.0)+0.5*sin(uv1.y*11.3));
        c2 = vec3(0.5+0.5*sin(uv2.x*9.1)+0.5*sin(uv2.y*12.7));
    #endif
    vec3 c = min(c1, c2);
    // Chromatic aberration
    float s = CAUSTICS_SPLIT;
    #if CAUSTICS_TEX_ENABLE
        vec3 cR = texture2D(causticstex, uv1 + vec2( s,  s)).rgb;
        vec3 cG = texture2D(causticstex, uv1 + vec2( s, -s)).rgb;
        vec3 cB = texture2D(causticstex, uv1 + vec2(-s, -s)).rgb;
        c = min(c, vec3(cR.r, cG.g, cB.b));
    #else
        // Procedural: small RGB phase shift using sines
        vec3 cR = vec3(0.5+0.5*sin((uv1.x+s)*10.0)+0.5*sin((uv1.y+s)*11.3));
        vec3 cG = vec3(0.5+0.5*sin((uv1.x+s)*9.1 )+0.5*sin((uv1.y-s)*12.7));
        vec3 cB = vec3(0.5+0.5*sin((uv1.x-s)*8.3 )+0.5*sin((uv1.y-s)*10.9));
        c = min(c, vec3(cR.r, cG.g, cB.b));
    #endif
    return c;
}

void main(){
    vec4 base = texture2D(texture, texcoord);
    if(base.a < 0.1) discard;

    // Lighting direction (world-space)
    vec3 L = normalize(getDirectionalLightDir());
    vec3 U, V; lightBasis(L, U, V);
    vec2 uv = vec2(dot(fragPos, U), dot(fragPos, V));

    // Caustics
    vec3 cau = sampleCaustics(uv);
    // Luminance mask from scene
    vec3 scene = texture2D(colortex0, screenUV).rgb;
    float lum = dot(scene, vec3(0.2126, 0.7152, 0.0722));
    float mask = mix(1.0, lum, CAUSTICS_LUM_MASK);
    vec3 caustics = cau * CAUSTICS_STRENGTH * mask;

    // Simple water shading: Fresnel + tint + add caustics
    vec3 N = normalize(encodedNormal);
    vec3 Vdir = normalize(cameraPosition - fragPos);
    float fres = pow(1.0 - max(dot(N, Vdir), 0.0), 5.0);
    vec3 tint = vec3(0.05, 0.2, 0.25);
    vec3 color = mix(base.rgb * (1.0 + caustics), vec3(1.0), fres*0.04);
    color = mix(color, tint, 0.15);

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, base.a);
}
#endif
