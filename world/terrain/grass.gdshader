shader_type spatial;
render_mode cull_disabled, world_vertex_coords, specular_disabled;

// Matas de pasto (scripts/world/grass_field.gd): se mecen con el viento en
// ondas que recorren el campo y se apartan alrededor del jugador. El color es
// el del pasto del piso en ese lugar (misma textura, tinte y manchas que
// terrain.gdshader), mas oscuro abajo y mas claro en la punta; las matas de
// lugares secos (cementerio, ruinas) tiran a amarillo.

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D splat_b : hint_default_black, filter_linear;   // g = variacion de tono
uniform vec3 grass_tint : source_color = vec3(0.78, 0.84, 0.62);
uniform vec3 dry_tint : source_color = vec3(0.66, 0.6, 0.42);
uniform float tile_size = 420.0;
uniform float world_size = 20000.0;

uniform vec3 player_position = vec3(0.0, -10000.0, 0.0);
uniform float push_radius = 180.0;
uniform float wind_strength = 1.0;
uniform vec2 wind_direction = vec2(0.8, 0.6);
uniform float wind_speed = 1.5;

varying vec2 origin_xz;
varying float tip;
varying float dryness;
varying float shade;

void vertex() {
	// UV.y: 0 en la base de la hoja, 1 en la punta.
	tip = UV.y;
	origin_xz = MODEL_MATRIX[3].xz;
	dryness = INSTANCE_CUSTOM.r;
	shade = INSTANCE_CUSTOM.g;
	float bend = tip * tip;

	// Viento: dos ondas que avanzan en la direccion del viento.
	float phase = dot(origin_xz, wind_direction) * 0.0035 - TIME * wind_speed;
	float gust = sin(phase) * 0.55 + sin(phase * 2.7 + origin_xz.y * 0.004) * 0.2 + 0.3;
	vec2 sway = wind_direction * gust * wind_strength * 11.0 * bend;

	// El jugador las aparta (y las aplasta un poco).
	vec2 away = VERTEX.xz - player_position.xz;
	float distance = length(away);
	float push = (1.0 - smoothstep(push_radius * 0.35, push_radius, distance)) * bend;
	vec2 push_dir = away / max(distance, 0.001);

	VERTEX.xz += sway + push_dir * push * 30.0;
	VERTEX.y -= push * 18.0 + length(sway) * 0.25;
}

void fragment() {
	vec2 uv = origin_xz / tile_size;
	vec3 ground = mix(texture(grass_albedo, uv).rgb, texture(grass_albedo, uv * 0.27 + vec2(0.31, 0.17)).rgb, 0.35) * grass_tint;
	ground *= mix(0.8, 1.12, texture(splat_b, origin_xz / world_size + 0.5).g);
	ground = mix(ground, ground * dry_tint * 1.35, dryness);
	ALBEDO = ground * mix(0.78, 1.15, tip) * mix(0.9, 1.08, shade);
	ROUGHNESS = 0.9;
	// Iluminadas como el piso, de los dos lados (si no, las hojas de canto
	// y las caras de atras quedan negras).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
