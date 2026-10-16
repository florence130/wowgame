extends Node
## 区域生成入口：godot --headless --path . res://tools/gen.tscn -- vale
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	if args.is_empty() or "vale" in args:
		GenVale.build()
	# 圣堂须先于潮风高地生成：高地的圣堂传送门只在副本场景存在时才放置
	if args.is_empty() or "sanctum" in args:
		GenSanctum.build()
	if args.is_empty() or "tidewind" in args:
		GenTidewind.build()
	print("generation done in %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()
