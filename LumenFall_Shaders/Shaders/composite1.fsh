#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform float far;
uniform vec3 fogColor;
uniform int isEyeInWater;

uniform mat4 gbufferProjectionInverse;

in vec2 texcoord;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

// Configurable fog densities (overridden by shaders.properties sliders)
#ifndef FOG_DENSITY
#define FOG_DENSITY 4.0
#endif
#ifndef UNDERWATER_FOG_DENSITY
#define UNDERWATER_FOG_DENSITY 8.0
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
		// Separate fog densities for above water and underwater
		float density = (isEyeInWater > 0) ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
		float fogFactor = 1.0 - exp(-density * dist / max(far, 1e-3));
	fogFactor = clamp(fogFactor, 0.0, 1.0);

	vec3 fogLinear = pow(fogColor, vec3(2.2));
	color.rgb = mix(color.rgb, fogLinear, fogFactor);
}