// Nasze shadery - common settings (UI scanned by Iris/OptiFine)

// Visual/Lighting baseline (kept minimal; extend as needed)
#define AMBIENT_MULT 100 //[50 60 70 80 90 100 120 140 160 180 200]

// RT/PT controls (master toggle + mode)
#define RT_ENABLE 0 //[0 1]
#define RT_MODE 0 //[0 1 2] // 0=Off, 1=RT Reflections (SSR), 2=PT Lite (1-bounce SSGI)
#define RT_QUALITY 2 //[0 1 2 3 4]
#define PT_SPP 2 //[0 1 2 3 4 6 8 12 16]
#define PT_BOUNCES 1 //[1 2 3]
#define GI_STRENGTH 0.35 //[0.0 0.2 0.35 0.5 0.8 1.0]

// Post
#define BLOOM 1 //[0 1]
#define BLOOM_STRENGTH 0.12 //[0.05 0.08 0.10 0.12 0.16 0.20 0.25]
#define FXAA_DEFINE -1 //[-1 1]

// Sunlight & Godrays
#define SUNLIGHT_ENABLE 1 //[0 1]
#define GODRAYS 1 //[0 1]
#define GODRAYS_INTENSITY 0.6 //[0.0 0.2 0.4 0.6 0.8 1.0]

// Ambient Occlusion & Water
#define AO_ENABLE 1 //[0 1]
#define AO_STRENGTH 0.7 //[0.0 0.3 0.5 0.7 0.9 1.0]
#define WATER_ENABLE 0 //[0 1]

// Volumetric Clouds & Atmosphere
#define CLOUDS_ENABLE 1 //[0 1]
#define CLOUD_COVERAGE 0.6 //[0.0 0.2 0.4 0.6 0.8 1.0]
#define CLOUD_DENSITY 0.8 //[0.2 0.4 0.6 0.8 1.0]
#define CLOUD_HEIGHT 180.0 //[80.0 120.0 160.0 180.0 220.0]
#define CLOUD_SPEED 0.01 //[0.003 0.006 0.01 0.02]
#define CLOUD_DETAIL 1 //[0 1]
#define PHASE_G 0.82 //[0.0 0.5 0.7 0.82 0.9]

// Shadow softness
#define SHADOW_SOFTNESS 1.0 //[0.5 1.0 1.5 2.0]

// Shadow quality
#define SHADOW_PCSS_ENABLE 1 //[0 1]
#define PCSS_SAMPLES 2 //[1 2 3]

// Volumetric Fog
#define FOG_ENABLE 1 //[0 1]
#define FOG_DENSITY 0.02 //[0.0 0.01 0.02 0.03 0.05]
#define FOG_HEIGHT_FALLOFF 0.0025 //[0.0 0.0015 0.0025 0.004]

// Volumetrics quality
#define VOLUME_STEPS 16 //[8 12 16 24]
#define RAYS_STEPS 64 //[32 48 64 96]

// Water & Caustics
#define CAUSTICS_ENABLE 1 //[0 1]
#define CAUSTICS_TEX_ENABLE 0 //[0 1]
#define CAUSTICS_STRENGTH 0.25 //[0.0 0.15 0.25 0.4]
#define CAUSTICS_SPEED 0.35 //[0.1 0.25 0.35 0.5 0.7]
#define CAUSTICS_SCALE 6.0 //[2.0 4.0 6.0 8.0 12.0]
#define CAUSTICS_SPLIT 0.0015 //[0.0 0.001 0.0015 0.002]
#define CAUSTICS_LUM_MASK 0.5 //[0.0 0.25 0.5 0.75 1.0]

// RP stub for menu (not functionally used yet)
#define RP_MODE 1 //[0 1 2 3]
