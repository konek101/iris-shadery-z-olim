// Nasze shadery - common settings (UI scanned by Iris/OptiFine)

// Visual/Lighting baseline (kept minimal; extend as needed)
#define AMBIENT_MULT 100 //[50 60 70 80 90 100 120 140 160 180 200]

// RT/PT controls
#define RT_MODE 0 //[0 1 2] // 0=Off, 1=RT Reflections (SSR), 2=PT Lite (1-bounce SSGI)
#define RT_QUALITY 2 //[0 1 2 3 4]
#define PT_SPP 2 //[0 1 2 3 4 6 8 12 16]
#define PT_BOUNCES 1 //[1 2 3]
#define GI_STRENGTH 0.35 //[0.0 0.2 0.35 0.5 0.8 1.0]

// Post
#define BLOOM 1 //[0 1]
#define BLOOM_STRENGTH 0.12 //[0.05 0.08 0.10 0.12 0.16 0.20 0.25]
#define FXAA_DEFINE -1 //[-1 1]

// RP stub for menu (not functionally used yet)
#define RP_MODE 1 //[0 1 2 3]
