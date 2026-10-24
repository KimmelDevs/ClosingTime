// Full-screen look: vignette, film grain, red tension edge, the hiding tunnel, and the death glitch.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int glitch = 0;          // 0 off, 1 harsh grey, 2 inverted, 3 washed out
uniform float glitch_bright = 1.5;
uniform float red = 0.0;         // 0..1 tension
uniform float hide_tunnel = 0.0; // 0..1 while hiding
uniform float grain = 0.06;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	if (glitch == 1) c = clamp((vec3(l) - 0.5) * 2.2 + 0.5, 0.0, 1.0) * glitch_bright;
	else if (glitch == 2) c = clamp((1.0 - c - 0.5) * 1.6 + 0.5, 0.0, 1.0);
	else if (glitch == 3) c = clamp((mix(vec3(l), c, 0.3) - 0.5) * 1.5 + 0.5, 0.0, 1.0);
	float r = length((UV - 0.5) * vec2(1.4, 1.0));
	c *= 1.0 - smoothstep(0.45, 0.95, r) * 0.75;
	c = mix(c, vec3(0.55, 0.0, 0.0), red * smoothstep(0.25, 0.9, r));
	c *= 1.0 - hide_tunnel * smoothstep(0.12, 0.55, r) * 0.95;
	c += (hash(floor(UV * vec2(480.0, 270.0)) + fract(TIME * 7.0)) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
