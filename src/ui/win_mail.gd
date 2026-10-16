class_name MailWindow
extends UIWindow
## 邮箱：左侧收件列表，右侧正文与附件。附件可单封领取或一键全领。
## 打开方式：底栏「邮箱」按钮 / O 键 / 世界里的邮箱柱（src/world/postbox.gd）。

const LIST_W := 268.0

var list: ItemList
var subject_label: Label
var from_label: RichTextLabel
var body_text: RichTextLabel
var attach_box: VBoxContainer
var claim_btn: Button
var erase_btn: Button
var footer: Label
var _cur_id := 0

func _init() -> void:
	_init_window("邮箱", Vector2(720, 470), "mail")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)

	# ---- 左：收件列表
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIST_W, 0)
	row.add_child(left)
	left.add_child(UITheme.label("收件箱", 15, UITheme.TEXT_DIM))
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(LIST_W, 300)
	list.auto_height = false
	list.item_selected.connect(_on_pick)
	left.add_child(list)
	var lbtns := HBoxContainer.new()
	left.add_child(lbtns)
	lbtns.add_child(UITheme.button("全部领取", func(): Mail.claim_all(); _refresh()))
	lbtns.add_child(UITheme.button("清理已读", func(): Mail.erase_read(); _refresh()))

	# ---- 右：正文与附件
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	subject_label = UITheme.label("—", 20, UITheme.GOLD, true)
	right.add_child(subject_label)
	from_label = RichTextLabel.new()
	from_label.bbcode_enabled = true
	from_label.fit_content = true
	from_label.scroll_active = false
	from_label.custom_minimum_size = Vector2(0, 22)
	right.add_child(from_label)
	var sep := HSeparator.new()
	right.add_child(sep)
	body_text = RichTextLabel.new()
	body_text.bbcode_enabled = true
	body_text.fit_content = false
	body_text.scroll_active = true
	body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_text.custom_minimum_size = Vector2(0, 150)
	right.add_child(body_text)
	attach_box = VBoxContainer.new()
	attach_box.add_theme_constant_override("separation", 3)
	right.add_child(attach_box)
	var btns := HBoxContainer.new()
	right.add_child(btns)
	claim_btn = UITheme.button("领取附件", func(): _claim(), 120)
	erase_btn = UITheme.button("删除邮件", func(): _erase(), 120)
	btns.add_child(claim_btn)
	btns.add_child(erase_btn)
	footer = UITheme.label("", 14, UITheme.TEXT_DIM)
	right.add_child(footer)

	Game.mail_changed.connect(func(): if visible: _refresh())

func open_window() -> void:
	super()
	_refresh()

## 外部入口：直接定位到某一封（例如从首领战报提示点进来）
func focus_mail(id: int) -> void:
	_cur_id = id
	_refresh()

func _refresh() -> void:
	var mails := Mail.box()
	list.clear()
	var sel := -1
	for i in mails.size():
		var m: Dictionary = mails[i]
		var tag := ""
		if not m.get("read", false):
			tag += "● "
		if Mail.has_attach(m) and not m.get("done", false):
			tag += "✉ "
		list.add_item("%s%s" % [tag, m.get("subj", "")])
		list.set_item_tooltip(i, "%s —— %s" % [m.get("from", ""), m.get("subj", "")])
		if int(m.get("id", 0)) == _cur_id:
			sel = i
	if sel < 0 and not mails.is_empty():
		sel = mails.size() - 1
	if sel >= 0:
		list.select(sel)
		_cur_id = int((mails[sel] as Dictionary).get("id", 0))
	_show(_cur_id)
	footer.text = "共 %d 封 · 未读 %d" % [mails.size(), Mail.unread()]

func _on_pick(i: int) -> void:
	var mails := Mail.box()
	if i < 0 or i >= mails.size():
		return
	_cur_id = int((mails[i] as Dictionary).get("id", 0))
	Mail.mark_read(_cur_id)
	_show(_cur_id)

func _show(id: int) -> void:
	var m := Mail.by_id(id)
	subject_label.text = String(m.get("subj", "—"))
	if m.is_empty():
		from_label.text = "[color=#a8adb8]收件箱是空的。[/color]"
		body_text.text = "训练师、军需官与各方势力会往这里寄信；信件里的附件记得领取。"
		attach_box.visible = false
		claim_btn.disabled = true
		erase_btn.disabled = true
		return
	var fid := String(m.get("fid", ""))
	var col := UITheme.TEXT_DIM
	if fid != "":
		col = DataRep.tier_color(Rep.tier(fid))
	from_label.text = "[color=#%s]来自 %s[/color]  [color=#a8adb8]· 第 %d 天[/color]" % [
		col.to_html(false), String(m.get("from", "")), int(m.get("day", 0))]
	body_text.text = String(m.get("body", "")).replace("\\n", "\n")
	for c in attach_box.get_children():
		c.queue_free()
	var lines := _attach_lines(m)
	attach_box.visible = not lines.is_empty()
	for t in lines:
		attach_box.add_child(UITheme.label(t, 15, Color("ffe9a8")))
	var done: bool = m.get("done", false)
	claim_btn.disabled = done or not Mail.has_attach(m)
	claim_btn.text = "已领取" if done else "领取附件"
	erase_btn.disabled = Mail.has_attach(m) and not done

func _attach_lines(m: Dictionary) -> Array:
	var out := []
	for st in m.get("items", []) as Array:
		var it := DB.get_item(String(st["id"]))
		if it.is_empty():
			continue
		out.append("附件：[%s] ×%d" % [it.get("name", st["id"]), int(st["n"])])
	var pay := int(m.get("money", 0))
	if pay > 0:
		out.append("附件：%s" % U.money_text(pay))
	return out

func _claim() -> void:
	Mail.claim(_cur_id)
	_refresh()

func _erase() -> void:
	if Mail.erase(_cur_id):
		_cur_id = 0
		_refresh()
