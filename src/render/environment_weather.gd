class_name EnvironmentWeather
extends RefCounted
## All atmosphere consumers share the same continuous weather state.
const PROFILES := {
	"clear": [0.30, 0.0, 0.0, 0.0, 0.14, 0.0],
	"cloudy": [0.76, 0.0, 0.0, 0.0, 0.23, 0.50],
	"rain": [0.93, 1.0, 0.0, 0.0, 0.35, 0.78],
	"storm": [1.0, 1.0, 1.0, 0.0, 0.65, 1.0],
	"fog": [0.56, 0.0, 0.0, 1.0, 0.10, 0.38],
}
var cloud := 0.30
var rain := 0.0
var storm := 0.0
var mist := 0.0
var wind := 0.14
var overcast := 0.0
var motion_time := 0.0

func advance(kind: String, delta: float) -> void:
	var target: Array = PROFILES.get(kind, PROFILES.clear)
	var blend := 1.0 - exp(-maxf(delta, 0.0) / 6.0)
	cloud = lerpf(cloud, target[0], blend)
	rain = lerpf(rain, target[1], blend)
	storm = lerpf(storm, target[2], blend)
	mist = lerpf(mist, target[3], blend)
	wind = lerpf(wind, target[4], blend)
	overcast = lerpf(overcast, target[5], blend)
	motion_time += maxf(delta, 0.0) * (0.7 + wind * 2.0)

func publish(sky_tint: Color, night: float) -> void:
	RenderingServer.global_shader_parameter_set("env_wind", wind)
	RenderingServer.global_shader_parameter_set("env_motion_time", motion_time)
	RenderingServer.global_shader_parameter_set("env_rain", rain)
	RenderingServer.global_shader_parameter_set("env_night", night)
	RenderingServer.global_shader_parameter_set("env_sky_tint", sky_tint)

static func reset_globals() -> void:
	RenderingServer.global_shader_parameter_set("env_wind", 0.14)
	RenderingServer.global_shader_parameter_set("env_motion_time", 0.0)
	RenderingServer.global_shader_parameter_set("env_rain", 0.0)
	RenderingServer.global_shader_parameter_set("env_night", 0.0)
	RenderingServer.global_shader_parameter_set("env_sky_tint", Color("b0d1dd"))
