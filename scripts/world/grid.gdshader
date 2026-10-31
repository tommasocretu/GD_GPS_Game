shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.82, 0.86, 0.80);
uniform vec3 minor_color : source_color = vec3(0.66, 0.72, 0.66);
uniform vec3 major_color : source_color = vec3(0.52, 0.58, 0.52);
uniform float minor_cell = 10.0;
uniform float major_cell = 50.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p, float cell) {
	vec2 coord = p / cell;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	return 1.0 - min(min(grid.x, grid.y), 1.0);
}

void fragment() {
	float minor = grid_line(world_pos.xz, minor_cell);
	float major = grid_line(world_pos.xz, major_cell);
	vec3 color = mix(base_color, minor_color, minor * 0.55);
	color = mix(color, major_color, major * 0.8);
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
