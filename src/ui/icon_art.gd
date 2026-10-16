class_name IconArt
extends RefCounted
## Shared immutable textures; the slot still owns cooldown, count and input overlays.
static var _cache := {}

static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/ui/icons/" + key + ".svg"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = tex
	return tex

static func spell_key(id: String, fallback: String) -> String:
	var key := "skills/" + id
	return key if texture(key) != null else fallback

## Overlay children never participate in minimum-size negotiation.
static func decorate_button(button: Button, id: String, caption: String, icon_only: bool = false) -> void:
	button.text = ""
	button.accessibility_name = caption
	var glyph := TextureRect.new()
	glyph.texture = texture("ui/" + id)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.position = Vector2(6, 11)
	glyph.size = Vector2(18, 18)
	button.add_child(glyph)
	if icon_only:
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.offset_left = 7
		glyph.offset_right = -7
		glyph.offset_top = 7
		glyph.offset_bottom = -7
		glyph.modulate = Color("e0d9cb")
		button.add_theme_stylebox_override("normal", UITheme.sb(Color(0.1, 0.095, 0.085, 0.22), 2, 0, UITheme.LINE, 0))
		button.add_theme_stylebox_override("hover", UITheme.sb(Color(0.3, 0.27, 0.22, 0.75), 2, 1, Color(UITheme.GOLD, 0.45), 0))
		button.add_theme_stylebox_override("pressed", UITheme.sb(Color(0.43, 0.38, 0.3, 0.85), 2, 1, UITheme.GOLD, 0))
		button.mouse_entered.connect(func(): glyph.modulate = Color.WHITE)
		button.mouse_exited.connect(func(): glyph.modulate = Color("e0d9cb"))
		return
	var label := UITheme.label(caption, 15, UITheme.TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 25
	label.offset_right = -3
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)
	button.button_down.connect(func(): label.modulate = Color("b2a083"); glyph.modulate = Color("776b58"))
	button.button_up.connect(func(): label.modulate = Color.WHITE; glyph.modulate = Color.WHITE)
