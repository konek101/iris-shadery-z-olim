#version 330 compatibility

uniform sampler2D lightmap;
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
	color = texture(gtexture, texcoord) * glcolor; // biome tint
	if (color.a < alphaTestRef) {
		discard;
	}

	// Terrain: keep texture alpha for cutout, opaque elsewhere

	// Decode normal map (if provided): tangent-space normal in RGB
	vec3 tnorm = texture(normals, texcoord).xyz * 2.0 - 1.0; // assume prebuilt tangent basis via ddx/ddy later
	// Fallback to flat normal if no normal texture (sampler will be white if not bound)
	if (length(tnorm) < 0.001) tnorm = normalize(normal);

	// Material maps: support LabPBR (default) layout on specular texture
	// LabPBR convention (common): R=AO, G=Roughness, B=Metalness, A=Emissive mask
	vec4 mrme = texture(specular, texcoord);
	float ao = mrme.r;
	float rough = mrme.g;
	float metal = mrme.b;
	float emiss = mrme.a;

	lightmapData = vec4(lmcoord, 0.0, 1.0);
	encodedNormal = vec4(tnorm * 0.5 + 0.5, 1.0);
	materialData = vec4(rough, metal, ao, emiss);
}