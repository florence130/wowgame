extends Node
## 脚本加载检查：逐个加载并确认可实例化（解析/编译错误会让 can_instantiate() 为 false）
func _ready():
	var files := []
	_scan("res://src", files)
	_scan("res://addons", files)
	_scan("res://tools", files)
	_scan("res://tests", files)
	var bad := []
	for f in files:
		if f == get_script().resource_path:
			continue   # 重新加载自身会破坏正在运行的实例
		var s = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not (s is Script) or not s.can_instantiate():
			bad.append(f)
	for f in bad:
		print("FAILED ", f)
	print("CHECKED %d files, failed %d" % [files.size(), bad.size()])
	get_tree().quit(1 if bad.size() > 0 else 0)
func _scan(d: String, out: Array):
	var da := DirAccess.open(d)
	if da == null:
		return
	for f in da.get_files():
		if f.ends_with(".gd"):
			out.append(d + "/" + f)
	for sd in da.get_directories():
		_scan(d + "/" + sd, out)
