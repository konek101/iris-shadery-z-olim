#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 worldPos;

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

	// Normal map via TBN from derivatives
	vec3 baseN = normalize(normal);
	vec3 dpdx = dFdx(worldPos);
	vec3 dpdy = dFdy(worldPos);
	vec2 dtdx = dFdx(texcoord);
	vec2 dtdy = dFdy(texcoord);
	float det = dtdx.x * dtdy.y - dtdx.y * dtdy.x;
	vec3 T = normalize(( dpdx * dtdy.y - dpdy * dtdx.y) * (sign(det)));
	vec3 B = normalize(( dpdy * dtdx.x - dpdx * dtdy.x) * (sign(det)));
	mat3 TBN = mat3(T, B, baseN);
	vec3 mapN = texture(normals, texcoord).xyz * 2.0 - 1.0;
	vec3 tnorm = normalize(TBN * mapN);
	if (!all(greaterThan(textureSize(normals, 0), ivec2(0)))) {
		tnorm = baseN;
	}

	// LabPBR MRME
	vec4 mrme = texture(specular, texcoord);
	if (!all(greaterThan(textureSize(specular, 0), ivec2(0)))) {
		mrme = vec4(1.0, 1.0, 0.0, 0.0);
	}
	float ao = mrme.r;
	float rough = mrme.g;
	float metal = mrme.b;
	float emiss = mrme.a;

	lightmapData = vec4(lmcoord, 0.0, 1.0);
	encodedNormal = vec4(tnorm * 0.5 + 0.5, 1.0);
	materialData = vec4(rough, metal, ao, emiss);
}
