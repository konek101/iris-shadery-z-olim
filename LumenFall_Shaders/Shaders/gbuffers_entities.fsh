#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,1,2,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 materialData; // R=roughness, G=metalness, B=AO, A=emissive

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) discard;

	// Force entities opaque to avoid half-transparency issues
	color.a = 1.0;

	// Normal map
	vec3 tnorm = texture(normals, texcoord).xyz * 2.0 - 1.0;
	if (length(tnorm) < 0.001) tnorm = normalize(normal);

	// LabPBR MRME
	vec4 mrme = texture(specular, texcoord);
	float ao = mrme.r;
	float rough = mrme.g;
	float metal = mrme.b;
	float emiss = mrme.a;

	lightmapData = vec4(lmcoord, 0.0, 1.0);
	encodedNormal = vec4(tnorm * 0.5 + 0.5, 1.0);
	materialData = vec4(rough, metal, ao, emiss);
}
