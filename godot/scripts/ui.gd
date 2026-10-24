## All screens and the HUD, built in code: title, intro, HUD, notes, pause, settings, death, ending.
extends CanvasLayer

signal new_game
signal continue_game
signal night2
signal resume
signal load_checkpoint
signal quit_to_title
signal retry
signal play_again
signal settings_changed

var post: ColorRect
var fade: ColorRect
var flash_white: ColorRect
var hud: Control
var objective: Label
var prompt: Label
var subtitle: Label
var toast_label: Label
var fuse_label: Label
var battery_bar: ProgressBar
var stamina_bar: ProgressBar
var diff_label: Label
var breath_box: VBoxContainer
var breath_bar: ProgressBar
var note_panel: Control
var note_title: Label
var note_body: RichTextLabel
var title: Control
var intro: Control
var intro_text: Label
var pause_menu: Control
var settings_panel: Control
var death: Control
var ending: Control
var end_text: VBoxContainer
var end_title: Label
var load_label: Label
var continue_btn: Button
var night2_btn: Button
var diff_buttons := {}

var _sub_t := 0.0
var _toast_t := 0.0
var title_font := SystemFont.new()
var type_font := SystemFont.new()
var body_font := SystemFont.new()

func _ready() -> void:
	layer = 10
	title_font.font_names = PackedStringArray(["Oswald", "Bahnschrift", "Impact", "Arial Narrow"])
	type_font.font_names = PackedStringArray(["Special Elite", "Courier New", "Consolas"])
	body_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	post = ColorRect.new(); post.set_anchors_preset(Control.PRESET_FULL_RECT); post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/post.gdshader"); post.material = sm
	add_child(post)
	_build_hud()
	flash_white = _rect(Color.WHITE); flash_white.modulate.a = 0.0
	fade = _rect(Color.BLACK)
	_build_note(); _build_title(); _build_intro(); _build_pause(); _build_settings(); _build_death(); _build_end()

func _process(dt: float) -> void:
	if _sub_t > 0.0:
		_sub_t -= dt
		if _sub_t <= 0.0: create_tween().tween_property(subtitle, "modulate:a", 0.0, 0.4)
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0: create_tween().tween_property(toast_label, "modulate:a", 0.0, 0.5)

# ---------------------------------------------------------------- helpers
func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new(); r.color = c; r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r); return r

func _label(text: String, size: int, color := Color("e9e2d4"), font: Font = null) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font if font else body_font)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8)); l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text.to_upper(); b.custom_minimum_size = Vector2(280, 44); b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", title_font); b.add_theme_font_size_override("font_size", 18)
	var n := StyleBoxFlat.new(); n.bg_color = Color(0, 0, 0, 0); n.border_color = Color("6b6255"); n.set_border_width_all(1)
	var h := n.duplicate() as StyleBoxFlat; h.bg_color = Color(0.91, 0.89, 0.83, 0.1); h.border_color = Color("cfc6b4")
	b.add_theme_stylebox_override("normal", n); b.add_theme_stylebox_override("hover", h); b.add_theme_stylebox_override("focus", h); b.add_theme_stylebox_override("pressed", h)
	b.pressed.connect(cb)
	return b

func _screen(bg: Color) -> Control:
	var c := ColorRect.new(); c.color = bg; c.set_anchors_preset(Control.PRESET_FULL_RECT); c.visible = false
	add_child(c)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); c.add_child(center)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 12)
	center.add_child(v); c.set_meta("box", v)
	return c

func _box(c: Control) -> VBoxContainer: return c.get_meta("box")

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.visible = false
	add_child(hud)
	var ob := VBoxContainer.new(); ob.position = Vector2(28, 22); hud.add_child(ob)
	ob.add_child(_label("OBJECTIVE", 12, Color("8d8577"), title_font))
	objective = _label("", 17, Color("cfc6b4"), title_font); objective.autowrap_mode = TextServer.AUTOWRAP_WORD; objective.custom_minimum_size = Vector2(560, 0)
	ob.add_child(objective)
	var cross := ColorRect.new(); cross.color = Color(1, 1, 1, 0.45); cross.size = Vector2(4, 4); cross.set_anchors_preset(Control.PRESET_CENTER); cross.position -= Vector2(2, 2)
	hud.add_child(cross)
	prompt = _label("", 18, Color("e9e2d4"), title_font); _center_h(prompt, 0.6); hud.add_child(prompt)
	subtitle = _label("", 21, Color("f0e8d6"), type_font); subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _center_h(subtitle, 0.76, 900); subtitle.modulate.a = 0.0; hud.add_child(subtitle)
	toast_label = _label("", 22, Color("e9e2d4"), title_font); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _center_h(toast_label, 0.3, 900); toast_label.modulate.a = 0.0; hud.add_child(toast_label)
	var st := VBoxContainer.new(); st.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); st.position = Vector2(-220, -150); st.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	st.alignment = BoxContainer.ALIGNMENT_END; hud.add_child(st)
	fuse_label = _label("FUSES 0/3", 13, Color("b9b09f"), title_font); st.add_child(fuse_label)
	st.add_child(_label("FLASHLIGHT", 13, Color("b9b09f"), title_font)); battery_bar = _bar(Color("e8dcb8")); st.add_child(battery_bar)
	st.add_child(_label("STAMINA", 13, Color("b9b09f"), title_font)); stamina_bar = _bar(Color("8fa3b8")); st.add_child(stamina_bar)
	diff_label = _label("", 10, Color("6b6255"), title_font); st.add_child(diff_label)
	breath_box = VBoxContainer.new(); _center_h(breath_box, 0.82, 420); breath_box.visible = false; hud.add_child(breath_box)
	var bl := _label("HOLD [SPACE] / RIGHT MOUSE / B TO HOLD YOUR BREATH", 12, Color("b9b09f"), title_font); bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breath_box.add_child(bl); breath_bar = _bar(Color("cfc6b4")); breath_bar.custom_minimum_size = Vector2(420, 6); breath_box.add_child(breath_bar)
	var lv := _label("[E] LEAVE", 12, Color("b9b09f"), title_font); lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; breath_box.add_child(lv)

func _center_h(c: Control, y_frac: float, w := 700.0) -> void:
	c.anchor_left = 0.5; c.anchor_right = 0.5; c.anchor_top = y_frac; c.anchor_bottom = y_frac
	c.offset_left = -w / 2; c.offset_right = w / 2
	if c is Label: (c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _bar(c: Color) -> ProgressBar:
	var b := ProgressBar.new(); b.custom_minimum_size = Vector2(170, 5); b.show_percentage = false; b.max_value = 1.0; b.step = 0.001
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(1, 1, 1, 0.12); var fg := StyleBoxFlat.new(); fg.bg_color = c
	b.add_theme_stylebox_override("background", bg); b.add_theme_stylebox_override("fill", fg)
	return b

func set_objective(t: String) -> void: objective.text = t.to_upper()
func set_prompt(t: String) -> void: prompt.text = t
func say(text: String, seconds: float, who := "") -> void:
	subtitle.text = (who + "\n" if who != "" else "") + text; subtitle.modulate.a = 1.0; _sub_t = seconds
func toast(text: String, seconds := 2.5) -> void:
	toast_label.text = text.to_upper(); toast_label.modulate.a = 1.0; _toast_t = seconds

# ---------------------------------------------------------------- notes
func _build_note() -> void:
	note_panel = ColorRect.new(); (note_panel as ColorRect).color = Color(0, 0, 0, 0.72); note_panel.set_anchors_preset(Control.PRESET_FULL_RECT); note_panel.visible = false
	add_child(note_panel)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); note_panel.add_child(center)
	var paper := PanelContainer.new(); paper.custom_minimum_size = Vector2(620, 0); paper.rotation = -0.01
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("e7dfcc"); sb.set_content_margin_all(36); sb.shadow_color = Color(0, 0, 0, 0.6); sb.shadow_size = 24
	paper.add_theme_stylebox_override("panel", sb); center.add_child(paper)
	var v := VBoxContainer.new(); paper.add_child(v)
	note_title = _label("", 13, Color("6d5d45"), title_font); note_title.remove_theme_color_override("font_shadow_color"); v.add_child(note_title)
	note_body = RichTextLabel.new(); note_body.bbcode_enabled = true; note_body.fit_content = true; note_body.custom_minimum_size = Vector2(548, 0)
	note_body.add_theme_font_override("normal_font", type_font); note_body.add_theme_font_override("italics_font", type_font); note_body.add_theme_font_override("bold_font", type_font)
	note_body.add_theme_font_size_override("normal_font_size", 17); note_body.add_theme_color_override("default_color", Color("2a241c"))
	v.add_child(note_body)
	var c := _label("[E] PUT IT DOWN", 12, Color("7a6a52"), title_font); c.remove_theme_color_override("font_shadow_color"); v.add_child(c)

func show_note(t: String, body: String) -> void:
	note_title.text = t.to_upper(); note_body.text = body; note_panel.visible = true
func hide_note() -> void: note_panel.visible = false

# ---------------------------------------------------------------- title & intro
func _build_title() -> void:
	title = _screen(Color("0a0807")); title.visible = true
	var v := _box(title)
	var t := _label("CLOSING TIME", 110, Color("e8e0cf"), title_font); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var sub := _label("Halvorsen Galleria — the last shift" if Session.night == 1 else "Night 2 — the morning after", 20, Color("a39a88"), type_font)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sub)
	v.add_child(Control.new())
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8); v.add_child(row)
	for d in ["easy", "normal", "nightmare"]:
		var b := _button(d, func(): Session.settings.diff = d; Session.save_settings(); _mark_diff(); settings_changed.emit())
		b.custom_minimum_size = Vector2(120, 38); row.add_child(b); diff_buttons[d] = b
	_mark_diff()
	continue_btn = _button("Continue", func(): continue_game.emit()); v.add_child(continue_btn)
	v.add_child(_button("New shift", func(): new_game.emit()))
	night2_btn = _button("Night 2", func(): night2.emit()); v.add_child(night2_btn)
	v.add_child(_button("Settings", func(): settings_panel.visible = true))
	v.add_child(_button("Quit", func(): get_tree().quit()))
	load_label = _label("LOADING THE MALL…", 12, Color("6b6255"), title_font); load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(load_label)
	var keys := _label("WASD move · MOUSE look · SHIFT run · F flashlight · E interact / hide · hold C wind the flashlight · SPACE hold breath · ESC pause\nController: sticks move/look · A interact · X flashlight · Y wind · RT run · LT/B hold breath · START pause", 13, Color("7d7566"), title_font)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(keys)
	var w := _label("HEADPHONES RECOMMENDED · CONTAINS JUMP SCARES AND FLASHING LIGHTS", 12, Color("6a4a44"), title_font); w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(w)

func _mark_diff() -> void:
	for d in diff_buttons:
		var b: Button = diff_buttons[d]
		b.add_theme_color_override("font_color", Color("0b0a09") if d == Session.settings.diff else Color("cfc6b4"))
		var sb := StyleBoxFlat.new(); sb.bg_color = Color("cfc6b4") if d == Session.settings.diff else Color(0, 0, 0, 0); sb.border_color = Color("6b6255"); sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)

func _build_intro() -> void:
	intro = _screen(Color.BLACK)
	intro_text = _label("", 23, Color("d8cfbd"), type_font); intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD; intro_text.custom_minimum_size = Vector2(760, 0)
	_box(intro).add_child(intro_text)

func play_intro(lines: Array) -> void:
	intro_text.text = "\n\n".join(PackedStringArray(lines)); intro.visible = true; intro.modulate.a = 0.0
	var tw := create_tween(); tw.tween_property(intro, "modulate:a", 1.0, 1.5); tw.tween_interval(7.5); tw.tween_property(intro, "modulate:a", 0.0, 1.5)
	tw.tween_callback(func(): intro.visible = false)

# ---------------------------------------------------------------- pause & settings
func _build_pause() -> void:
	pause_menu = _screen(Color(0, 0, 0, 0.78))
	var v := _box(pause_menu)
	var t := _label("PAUSED", 30, Color("e9e2d4"), title_font); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	v.add_child(_button("Resume", func(): resume.emit()))
	v.add_child(_button("Settings", func(): settings_panel.visible = true))
	v.add_child(_button("Load checkpoint", func(): load_checkpoint.emit()))
	v.add_child(_button("Quit to title", func(): quit_to_title.emit()))

func _build_settings() -> void:
	settings_panel = _screen(Color(0, 0, 0, 0.92))
	var v := _box(settings_panel)
	var t := _label("SETTINGS", 30, Color("e9e2d4"), title_font); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	_slider(v, "MOUSE SENSITIVITY", "sens", 0.3, 3.0, 0.05)
	_slider(v, "VOLUME", "vol", 0.0, 1.0, 0.02)
	_slider(v, "BRIGHTNESS", "bright", 0.6, 2.0, 0.05)
	_slider(v, "FIELD OF VIEW", "fov", 60, 95, 1)
	_check(v, "INVERT LOOK Y", "invert")
	_check(v, "VOLUMETRIC FOG (slower)", "vfog")
	v.add_child(_button("Back", func(): settings_panel.visible = false))

func _slider(v: Container, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := HBoxContainer.new(); h.custom_minimum_size = Vector2(480, 0); v.add_child(h)
	var l := _label(text, 15, Color("cfc6b4"), title_font); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = step; s.value = float(Session.settings[key]); s.custom_minimum_size = Vector2(220, 0)
	s.value_changed.connect(func(x): Session.settings[key] = x; Session.save_settings(); settings_changed.emit())
	h.add_child(s)

func _check(v: Container, text: String, key: String) -> void:
	var c := CheckBox.new(); c.text = text; c.button_pressed = bool(Session.settings[key])
	c.add_theme_font_override("font", title_font)
	c.toggled.connect(func(on): Session.settings[key] = on; Session.save_settings(); settings_changed.emit())
	v.add_child(c)

# ---------------------------------------------------------------- death & ending
func _build_death() -> void:
	death = _screen(Color(0.15, 0, 0, 0.6))
	var v := _box(death)
	var t := _label("SHE KEPT YOU", 60, Color("f1d8d0"), title_font); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var s := _label("…for closing.", 20, Color("d1a9a0"), type_font); s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(s)
	v.add_child(_button("Try again", func(): retry.emit()))

func _build_end() -> void:
	ending = _screen(Color.BLACK)
	var v := _box(ending)
	end_text = VBoxContainer.new(); end_text.add_theme_constant_override("separation", 14); v.add_child(end_text)
	end_title = _label("", 64, Color("e9e2d4"), title_font); end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(end_title)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 10); v.add_child(row)
	row.add_child(_button("Play again", func(): play_again.emit()))
	var n2 := _button("Night 2", func(): night2.emit()); n2.visible = Session.night == 1; row.add_child(n2)
	row.set_meta("row", true); end_title.set_meta("row", true)

func show_ending(head: String, lines: Array) -> void:
	for c in end_text.get_children(): c.queue_free()
	end_title.text = head
	var parts: Array = []
	for l in lines:
		var p := _label(l, 21, Color("d8cfbd"), type_font); p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.autowrap_mode = TextServer.AUTOWRAP_WORD; p.custom_minimum_size = Vector2(760, 0); p.modulate.a = 0.0
		end_text.add_child(p); parts.append(p)
	end_title.modulate.a = 0.0; parts.append(end_title)
	var row := end_title.get_parent().get_child(end_title.get_index() + 1) as Control; row.modulate.a = 0.0; parts.append(row)
	ending.visible = true
	var tw := create_tween()
	for p in parts: tw.tween_property(p, "modulate:a", 1.0, 2.0); tw.tween_interval(0.6)
