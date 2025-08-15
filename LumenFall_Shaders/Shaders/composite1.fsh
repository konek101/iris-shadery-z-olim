#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform float far;
uniform vec3 fogColor;
uniform int isEyeInWater;

uniform mat4 gbufferProjectionInverse;

in vec2 texcoord;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

// Configurable fog (overridden by shaders.properties sliders)
#ifndef FOG_DENSITY
#define FOG_DENSITY 0.5 // [0.0 0.2 0.5 1.0 2.0 4.0 6.0 10.0]
#endif
#ifndef UNDERWATER_FOG_DENSITY
#define UNDERWATER_FOG_DENSITY 6.0 // [0.0 2.0 4.0 6.0 8.0 12.0 16.0 20.0]
#endif
#ifndef FOG_START_FRAC
#define FOG_START_FRAC 0.5 // [0.0 0.2 0.5 0.7 0.9]
#endif
#ifndef UNDERWATER_FOG_START_FRAC
#define UNDERWATER_FOG_START_FRAC 0.0 // [0.0 0.2 0.5]
#endif

// Apply underwater-like fog when looking through translucent layers (e.g., water) from above
#ifndef THROUGH_TRANSPARENT_FOG
#define THROUGH_TRANSPARENT_FOG 1 // [0 1]
#endif
#ifndef THROUGH_TRANSPARENT_FOG_MULT
#define THROUGH_TRANSPARENT_FOG_MULT 0.6 // [0.3 0.5 0.6 0.8 1.0]
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;
	if(depth == 1.0){
		return;
	}

  vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

			float dist = length(viewPos);
			// Separate fog densities and start distance for above water and underwater
				bool under = (isEyeInWater > 0);
				float d0 = texture(depthtex0, texcoord).r;
				float d1 = texture(depthtex1, texcoord).r;
				bool throughTrans = (THROUGH_TRANSPARENT_FOG == 1) && (d1 < 0.999) && (d1 + 1e-4 < d0);
				bool useUnderwaterFog = under || throughTrans;
				float density = useUnderwaterFog ? (UNDERWATER_FOG_DENSITY * (under ? 1.0 : THROUGH_TRANSPARENT_FOG_MULT)) : FOG_DENSITY;
				float startFrac = useUnderwaterFog ? UNDERWATER_FOG_START_FRAC : FOG_START_FRAC;

			float distN = clamp(dist / max(far, 1e-3), 0.0, 1.0);
			float t = clamp((distN - startFrac) / max(1.0 - startFrac, 1e-3), 0.0, 1.0);
			float fogFactor = 1.0 - exp(-density * t);
	fogFactor = clamp(fogFactor, 0.0, 1.0);

	vec3 fogLinear = pow(fogColor, vec3(2.2));
	color.rgb = mix(color.rgb, fogLinear, fogFactor);
}