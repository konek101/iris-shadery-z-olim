#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

layout(location = 0) out vec4 color;

// Iris/OptiFine-configurable macros with sane defaults
#ifndef BLOOM_ENABLED
#define BLOOM_ENABLED 1 // [0 1]
#endif
#ifndef BLOOM_STRENGTH
#define BLOOM_STRENGTH 0.18 // [0.0 0.1 0.18 0.3 0.5 0.8 1.0]
#endif
#ifndef BLOOM_THRESHOLD
#define BLOOM_THRESHOLD 0.8 // [0.0 0.5 0.8 1.0 1.5 2.0]
#endif
#ifndef BLOOM_RADIUS
#define BLOOM_RADIUS 1.75 // [0.5 1.0 1.5 1.75 2.5 3.5 5.0]
#endif
#ifndef EXPOSURE
#define EXPOSURE 1.0 // [0.1 0.5 1.0 1.2 1.5 2.0 2.5]
#endif
#ifndef CONTRAST
#define CONTRAST 1.05 // [0.5 0.8 1.0 1.05 1.2 1.5 1.8]
#endif
#ifndef SATURATION
#define SATURATION 1.05 // [0.5 0.8 1.0 1.05 1.2 1.5 1.8]
#endif
#ifndef VIGNETTE_STRENGTH
#define VIGNETTE_STRENGTH 0.12 // [0.0 0.05 0.1 0.12 0.2 0.3 0.5 0.8]
#endif
#ifndef TONEMAP_ACES
#define TONEMAP_ACES 1 // [0 1]
#endif

// Helpers
vec3 toGamma(vec3 c) { return pow(max(c, 0.0), vec3(1.0/2.2)); }

// Simple bright pass
vec3 brightPass(vec3 c) {
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float w = clamp((luma - BLOOM_THRESHOLD) / max(1e-4, 1.0 - BLOOM_THRESHOLD), 0.0, 1.0);
	return c * w;
}

// 9-tap separable-ish blur in a single pass (cheap, screen-space)
vec3 bloomBlur(vec2 uv, vec2 texelSize) {
	vec2 r = BLOOM_RADIUS * texelSize;
	vec3 acc = vec3(0.0);
	float wSum = 0.0;
	// weights roughly Gaussian
	float w[5];
	w[0]=0.227027; w[1]=0.1945946; w[2]=0.1216216; w[3]=0.054054; w[4]=0.016216;
	for(int i=-4;i<=4;i++){
		float wi = w[abs(i)];
		vec2 off = vec2(float(i)) * r;
	vec3 s = texture(colortex0, uv + off).rgb; // source is already linear
	acc += brightPass(s) * wi;
		wSum += wi;
	}
	return acc / max(wSum, 1e-4);
}

// ACES tonemap approximation
vec3 tonemapACES(vec3 x){
	// Narkowicz 2015, optimized ACES approximation
	const float a=2.51; const float b=0.03; const float c=2.43; const float d=0.59; const float e=0.14;
	return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
	vec2 texelSize = vec2(1.0) / textureSize(colortex0, 0);

	// Source from previous pass is already linear
	vec3 col = texture(colortex0, texcoord).rgb;

	// Bloom (optional)
	#if BLOOM_ENABLED
		vec3 bloom = bloomBlur(texcoord, texelSize);
		col += bloom * BLOOM_STRENGTH;
	#endif

	// Exposure
	col *= EXPOSURE;

	// Tonemapping
	#if TONEMAP_ACES
		col = tonemapACES(col);
	#else
		col = col / (1.0 + col); // simple Reinhard
	#endif

	// Color tweaks in linear-ish space
	// Contrast (pivot at 0.5 after gamma to reduce lifted blacks)
	col = clamp(col, 0.0, 1.0);
	float pivot = 0.5;
	col = (col - pivot) * CONTRAST + pivot;

	// Saturation using luminance mix
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lum), col, SATURATION);

	// Vignette in screen space (applied after tone)
	vec2 p = texcoord * 2.0 - 1.0;
	float d = dot(p, p); // r^2
	float vig = 1.0 - VIGNETTE_STRENGTH * smoothstep(0.4, 1.0, d);
	col *= vig;

	// Gamma encode and output
	color = vec4(toGamma(clamp(col, 0.0, 1.0)), 1.0);
}