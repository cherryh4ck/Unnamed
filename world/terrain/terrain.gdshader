shader_type spatial;

// Piso del mundo: pasto de base y encima tierra (caminos), adoquines, suelo
// de bosque, musgo y piedra, segun los mapas de mezcla que arma
// world/build_world.gd. Cada textura se repite cada tile_size unidades y se
// mezcla con una segunda muestra mas grande para que no se note la repeticion.

uniform sampler2D splat_a : hint_default_black, filter_linear;   // r tierra, g adoquin, b bosque, a musgo
uniform sampler2D splat_b : hint_default_black, filter_linear;   // r piedra, g variacion de tono
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocky_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocky_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float world_size = 20000.0;
uniform float tile_size = 420.0;
uniform vec3 grass_tint : source_color = vec3(0.78, 0.84, 0.62);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Dos muestras a distinta escala: rompe la repeticion a la distancia de camara.
vec3 sample_albedo(sampler2D tex, vec2 uv) {
	return mix(texture(tex, uv).rgb, texture(tex, uv * 0.27 + vec2(0.31, 0.17)).rgb, 0.35);
}

// Mezcla con algo de "altura" (el brillo de la textura) para que los bordes
// entre suelos no sean un fundido liso.
float blend_weight(float w, vec3 albedo) {
	float h = dot(albedo, vec3(0.33));
	return clamp((w - (1.0 - h) * 0.35) * 1.6, 0.0, 1.0);
}

void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	vec2 suv = world_pos.xz / world_size + 0.5;
	vec4 a = texture(splat_a, suv);
	vec4 b = texture(splat_b, suv);

	vec3 col = sample_albedo(grass_albedo, uv) * grass_tint;
	vec3 nrm = texture(grass_normal, uv).rgb;

	vec3 c = sample_albedo(forest_albedo, uv * 0.8);
	float w = blend_weight(a.b, c);
	col = mix(col, c, w);
	nrm = mix(nrm, texture(forest_normal, uv * 0.8).rgb, w);

	c = sample_albedo(moss_albedo, uv);
	w = blend_weight(a.a, c);
	col = mix(col, c * vec3(0.8, 0.85, 0.78), w);
	nrm = mix(nrm, texture(moss_normal, uv).rgb, w);

	c = sample_albedo(rocky_albedo, uv * 0.7);
	w = blend_weight(b.r, c);
	col = mix(col, c, w);
	nrm = mix(nrm, texture(rocky_normal, uv * 0.7).rgb, w);

	c = sample_albedo(dirt_albedo, uv * 1.2);
	w = blend_weight(a.r, c);
	col = mix(col, c * vec3(0.85, 0.8, 0.74), w);
	nrm = mix(nrm, texture(dirt_normal, uv * 1.2).rgb, w);

	c = texture(cobble_albedo, uv * 1.6).rgb;
	w = blend_weight(a.g, c);
	col = mix(col, c * 0.85, w);
	nrm = mix(nrm, texture(cobble_normal, uv * 1.6).rgb, w);

	// Variacion de tono a gran escala (manchas mas claras y mas oscuras).
	col *= mix(0.8, 1.12, b.g);

	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
