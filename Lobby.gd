extends Node3D

const PORT = 8080
const MAX_CLIENTS = 16

var peer: ENetMultiplayerPeer

# UI refs
var canvas: CanvasLayer
var status_label: Label
var name_input: LineEdit
var address_input: LineEdit
var bot_count_label: Label
var bot_count_slider: HSlider
var bot_toggle_btn: Button
var active_tab: String = "PLAY"
var tab_panels: Dictionary = {}
var class_buttons: Array = []
var selected_class_btns: Array = []

var current_class: int = 0
var bots_on: bool = false

@onready var soldier_mesh = $low_poly_soldier
@onready var weapon_pivot = $low_poly_soldier/WeaponPivot
@onready var cam = $Camera3D

# Slow idle bob
var bob_time: float = 0.0

func _ready():
	_build_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	# Load weapon models for display
	var weapons = [
		preload("res://models/ak-74.glb").instantiate(),
		preload("res://models/thompson.glb").instantiate(),
		preload("res://models/shotgun.glb").instantiate()
	]
	for child in weapon_pivot.get_children():
		child.queue_free()
	for w in weapons:
		weapon_pivot.add_child(w)
		w.visible = false
	_update_model_display()
	_set_tab("PLAY")

func _process(delta):
	# Subtle idle breathing bob for the character
	bob_time += delta
	if is_instance_valid(soldier_mesh):
		soldier_mesh.position.y = sin(bob_time * 1.2) * 0.012

func _update_model_display():
	if not is_instance_valid(weapon_pivot): return
	var children = weapon_pivot.get_children()
	for i in range(children.size()):
		children[i].visible = (i == current_class)

# ─────────────────────────────────────────────────────────
# UI BUILD
# ─────────────────────────────────────────────────────────
func _build_ui():
	canvas = $CanvasLayer
	if not canvas:
		canvas = CanvasLayer.new()
		add_child(canvas)

	# ── VIGNETTE OVERLAY (dark edges like Deadshot) ──
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0, 0, 0, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(vignette)
	# Real vignette via shader material would be ideal; we use a gradient approximation
	var vig_left = ColorRect.new()
	vig_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	vig_left.offset_right = 300
	vig_left.color = Color(0, 0, 0, 0.55)
	vig_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(vig_left)
	var vig_right = ColorRect.new()
	vig_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	vig_right.offset_left = -300
	vig_right.color = Color(0, 0, 0, 0.55)
	vig_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(vig_right)
	var vig_top = ColorRect.new()
	vig_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vig_top.offset_bottom = 120
	vig_top.color = Color(0, 0, 0, 0.65)
	vig_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(vig_top)
	var vig_bot = ColorRect.new()
	vig_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	vig_bot.offset_top = -90
	vig_bot.color = Color(0, 0, 0, 0.6)
	vig_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(vig_bot)

	# ── TITLE BAR ──
	_build_title_bar()

	# ── TAB PANELS ──
	tab_panels["PLAY"]     = _build_play_panel()
	tab_panels["SETTINGS"] = _build_settings_panel()

	# ── LEFT PANEL (Patch Notes) ──
	_build_left_panel()

	# ── BOTTOM STATUS ──
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position.y = -22
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	status_label.text = "1337 Players Online"
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(status_label)

func _build_title_bar():
	var bar = ColorRect.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 74
	bar.color = Color(0.0, 0.0, 0.0, 0.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bar)

	# Game Title
	var title = Label.new()
	title.text = "VELOCITY"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position.y = 6
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(title)

	# Thin orange accent line under title
	var line = ColorRect.new()
	line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	line.offset_top = 62
	line.offset_bottom = 65
	line.offset_left = 380
	line.offset_right = -380
	line.color = Color(1.0, 0.38, 0.08)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(line)

	# ── TABS ──
	var tabs = ["PLAY GAME", "SETTINGS", "LOCKER", "LEADERBOARD"]
	var tab_container = HBoxContainer.new()
	tab_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tab_container.position.y = 42
	tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_container.add_theme_constant_override("separation", 0)
	tab_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(tab_container)

	for t in tabs:
		var tab_key = "PLAY" if t == "PLAY GAME" else t
		var btn = Button.new()
		btn.text = t
		btn.custom_minimum_size = Vector2(148, 34)
		btn.add_theme_font_size_override("font_size", 14)
		btn.flat = true
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0, 0, 0, 0)
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", normal_style)
		btn.add_theme_stylebox_override("pressed", normal_style)
		tab_container.add_child(btn)
		var tk = tab_key
		btn.pressed.connect(func(): _set_tab(tk))

func _set_tab(tab_key: String):
	active_tab = tab_key
	for k in tab_panels:
		if is_instance_valid(tab_panels[k]):
			tab_panels[k].visible = (k == tab_key)

# ─────────────────────────────────────────────────────────
# PLAY PANEL (Center — like Deadshot with big PLAY button)
# ─────────────────────────────────────────────────────────
func _build_play_panel() -> Control:
	var panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)

	# ── CLASS SELECTION (3 cards to left/right of character) ──
	var class_data = [
		{"name": "ASSAULT RIFLE", "sub": "Auto · 30 rnd · Long range", "idx": 0},
		{"name": "SMG", "sub": "Auto · 40 rnd · Fast fire", "idx": 1},
		{"name": "SHOTGUN", "sub": "Semi · 6 rnd · Close range", "idx": 2},
	]

	# Left cards (class 0 & 1)
	for i in range(2):
		var card = _build_class_card(class_data[i])
		card.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		card.position = Vector2(30, -60 + i * 140)
		card.custom_minimum_size = Vector2(210, 120)
		panel.add_child(card)

	# Right card (class 2)
	var right_card = _build_class_card(class_data[2])
	right_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right_card.position = Vector2(-240, -60)
	right_card.custom_minimum_size = Vector2(210, 120)
	panel.add_child(right_card)

	# ── BOTTOM CENTER: PLAY / Private / Join ──
	var bottom_center = VBoxContainer.new()
	bottom_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_center.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_center.add_theme_constant_override("separation", 6)
	bottom_center.position.y = -130
	bottom_center.custom_minimum_size.x = 400
	panel.add_child(bottom_center)

	# Name input
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your name..."
	name_input.text = "Player"
	name_input.custom_minimum_size = Vector2(320, 38)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.add_theme_font_size_override("font_size", 17)
	var ni_style = StyleBoxFlat.new()
	ni_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	ni_style.border_width_bottom = 2
	ni_style.border_color = Color(0.3, 0.3, 0.4)
	name_input.add_theme_stylebox_override("normal", ni_style)
	bottom_center.add_child(name_input)

	# Big PLAY button (like Deadshot — teal/blue)
	var play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(320, 58)
	play_btn.add_theme_font_size_override("font_size", 28)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.18, 0.48, 0.72)
	ps.corner_radius_top_left = 4
	ps.corner_radius_top_right = 4
	ps.corner_radius_bottom_left = 4
	ps.corner_radius_bottom_right = 4
	play_btn.add_theme_stylebox_override("normal", ps)
	var psh = ps.duplicate()
	psh.bg_color = Color(0.25, 0.6, 0.9)
	play_btn.add_theme_stylebox_override("hover", psh)
	play_btn.pressed.connect(_on_host_pressed)
	bottom_center.add_child(play_btn)

	# Private / Join row
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	bottom_center.add_child(row)

	var private_btn = _make_secondary_btn("HOST PRIVATE", 200, 40)
	private_btn.pressed.connect(_on_host_pressed)
	row.add_child(private_btn)

	var join_btn = _make_secondary_btn("JOIN", 110, 40)
	join_btn.pressed.connect(_show_join_popup)
	row.add_child(join_btn)

	return panel

func _build_class_card(data: Dictionary) -> Panel:
	var card = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.82)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.2, 0.3, 0.6)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.add_child(vbox)
	card.add_child(margin)

	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = data["sub"]
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	vbox.add_child(sub_lbl)

	var sel_btn = Button.new()
	sel_btn.text = "SELECT"
	sel_btn.custom_minimum_size.y = 30
	sel_btn.add_theme_font_size_override("font_size", 12)
	var sbs = StyleBoxFlat.new()
	sbs.bg_color = Color(0.12, 0.12, 0.18)
	sbs.border_width_left = 1; sbs.border_width_right = 1
	sbs.border_width_top = 1; sbs.border_width_bottom = 1
	sbs.border_color = Color(0.3, 0.3, 0.45)
	sbs.corner_radius_top_left = 4; sbs.corner_radius_top_right = 4
	sbs.corner_radius_bottom_left = 4; sbs.corner_radius_bottom_right = 4
	sel_btn.add_theme_stylebox_override("normal", sbs)
	var sbsh = sbs.duplicate()
	sbsh.bg_color = Color(0.18, 0.48, 0.72)
	sbsh.border_color = Color(0.3, 0.7, 1.0)
	sel_btn.add_theme_stylebox_override("hover", sbsh)
	vbox.add_child(sel_btn)

	var idx = data["idx"]
	selected_class_btns.append({"btn": sel_btn, "style": sbs, "hover": sbsh, "idx": idx})
	sel_btn.pressed.connect(func():
		current_class = idx
		_update_model_display()
		_refresh_class_buttons(idx)
	)
	return card

func _refresh_class_buttons(selected: int):
	for entry in selected_class_btns:
		var is_sel = (entry["idx"] == selected)
		var s = entry["style"].duplicate()
		if is_sel:
			s.bg_color = Color(0.18, 0.48, 0.72)
			s.border_color = Color(0.4, 0.75, 1.0)
		else:
			s.bg_color = Color(0.12, 0.12, 0.18)
			s.border_color = Color(0.3, 0.3, 0.45)
		entry["btn"].add_theme_stylebox_override("normal", s)

# ─────────────────────────────────────────────────────────
# SETTINGS PANEL
# ─────────────────────────────────────────────────────────
func _build_settings_panel() -> Control:
	var panel = Panel.new()
	panel.anchor_left = 0.25; panel.anchor_right = 0.75
	panel.anchor_top = 0.12; panel.anchor_bottom = 0.92
	panel.visible = false
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.06, 0.1, 0.93)
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.border_color = Color(0.2, 0.2, 0.35)
	ps.corner_radius_top_left = 8; ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_left = 8; ps.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", ps)
	canvas.add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_section_label(vbox, "MATCH SETTINGS")
	_divider(vbox)

	# Match type
	_row_label(vbox, "MATCH TYPE")
	var mt = HBoxContainer.new(); mt.add_theme_constant_override("separation", 8); vbox.add_child(mt)
	var ffa = _make_secondary_btn("FREE FOR ALL", 0, 40); ffa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tdm = _make_secondary_btn("TEAM DEATHMATCH", 0, 40); tdm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ffa.pressed.connect(func(): GameManager.match_type = "FFA"; _set_status("Mode: Free For All"))
	tdm.pressed.connect(func(): GameManager.match_type = "TDM"; _set_status("Mode: Team Deathmatch"))
	mt.add_child(ffa); mt.add_child(tdm)

	# Kill limit
	_row_label(vbox, "KILL LIMIT")
	var kl = HBoxContainer.new(); kl.add_theme_constant_override("separation", 8); vbox.add_child(kl)
	for limit in [10, 20, 30, 50]:
		var kb = _make_secondary_btn(str(limit), 0, 40); kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lv = limit; kb.pressed.connect(func(): GameManager.kill_limit = lv; _set_status("Kill limit: " + str(lv)))
		kl.add_child(kb)

	# Round time
	_row_label(vbox, "ROUND TIME")
	var rt = HBoxContainer.new(); rt.add_theme_constant_override("separation", 8); vbox.add_child(rt)
	for opt in [[180.0, "3 min"], [300.0, "5 min"], [600.0, "10 min"], [0.0, "Unlimited"]]:
		var tb = _make_secondary_btn(opt[1], 0, 40); tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv = opt[0]; var tn = opt[1]
		tb.pressed.connect(func(): GameManager.round_duration = tv; _set_status("Time: " + tn))
		rt.add_child(tb)

	_divider(vbox)
	_section_label(vbox, "BOT SETTINGS")

	bot_toggle_btn = _make_secondary_btn("BOTS: OFF", 0, 44)
	bot_toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_toggle_btn.pressed.connect(_toggle_bots)
	vbox.add_child(bot_toggle_btn)

	var bot_row = HBoxContainer.new(); bot_row.add_theme_constant_override("separation", 12); vbox.add_child(bot_row)
	bot_count_label = Label.new()
	bot_count_label.text = "Bot count:  4"
	bot_count_label.add_theme_font_size_override("font_size", 15)
	bot_count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	bot_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_row.add_child(bot_count_label)
	bot_count_slider = HSlider.new()
	bot_count_slider.min_value = 1; bot_count_slider.max_value = 8
	bot_count_slider.step = 1; bot_count_slider.value = 4
	bot_count_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_count_slider.value_changed.connect(func(v): GameManager.bot_count = int(v); bot_count_label.text = "Bot count:  " + str(int(v)))
	bot_row.add_child(bot_count_slider)

	_divider(vbox)
	_section_label(vbox, "CONNECT")

	_row_label(vbox, "SERVER IP")
	address_input = LineEdit.new()
	address_input.text = "localhost"
	address_input.custom_minimum_size.y = 40
	address_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(address_input)

	return panel

# ─────────────────────────────────────────────────────────
# LEFT PANEL — Patch Notes
# ─────────────────────────────────────────────────────────
func _build_left_panel():
	var panel = Panel.new()
	panel.anchor_left = 0.0; panel.anchor_right = 0.0
	panel.anchor_top = 0.1; panel.anchor_bottom = 0.9
	panel.offset_left = 14; panel.offset_right = 210
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	ps.border_width_right = 1
	ps.border_color = Color(0.18, 0.18, 0.28)
	panel.add_theme_stylebox_override("panel", ps)
	canvas.add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var patch_title = Label.new()
	patch_title.text = "Latest Update"
	patch_title.add_theme_font_size_override("font_size", 15)
	patch_title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(patch_title)

	var patch_notes = [
		"• Bot toggle in lobby",
		"• Match type: FFA / TDM",
		"• 3-sec spawn shield",
		"• Server-auth damage",
		"• Kill streaks",
		"• Round timer & game over",
		"• Scoreboard KDR",
		"• Weapon name on HUD",
	]
	for note in patch_notes:
		var lbl = Label.new()
		lbl.text = note
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	var sep = HSeparator.new(); vbox.add_child(sep)

	var discord_btn = Button.new()
	discord_btn.text = "Join Discord"
	discord_btn.custom_minimum_size.y = 36
	discord_btn.add_theme_font_size_override("font_size", 13)
	var ds = StyleBoxFlat.new()
	ds.bg_color = Color(0.22, 0.26, 0.72)
	ds.corner_radius_top_left = 5; ds.corner_radius_top_right = 5
	ds.corner_radius_bottom_left = 5; ds.corner_radius_bottom_right = 5
	discord_btn.add_theme_stylebox_override("normal", ds)
	vbox.add_child(discord_btn)

# ─────────────────────────────────────────────────────────
# JOIN POPUP
# ─────────────────────────────────────────────────────────
var join_popup: Panel = null

func _show_join_popup():
	if is_instance_valid(join_popup): join_popup.queue_free()
	join_popup = Panel.new()
	join_popup.anchor_left = 0.35; join_popup.anchor_right = 0.65
	join_popup.anchor_top = 0.4; join_popup.anchor_bottom = 0.68
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.07, 0.11, 0.97)
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.border_color = Color(0.3, 0.3, 0.5)
	ps.corner_radius_top_left = 8; ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_left = 8; ps.corner_radius_bottom_right = 8
	join_popup.add_theme_stylebox_override("panel", ps)
	canvas.add_child(join_popup)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	join_popup.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "JOIN GAME"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var ip_lbl = Label.new()
	ip_lbl.text = "Server IP Address"
	ip_lbl.add_theme_font_size_override("font_size", 13)
	ip_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(ip_lbl)

	address_input = LineEdit.new()
	address_input.text = "localhost"
	address_input.custom_minimum_size.y = 42
	address_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(address_input)

	var jbtn = Button.new()
	jbtn.text = "CONNECT"
	jbtn.custom_minimum_size.y = 44
	jbtn.add_theme_font_size_override("font_size", 18)
	var js = StyleBoxFlat.new()
	js.bg_color = Color(0.18, 0.48, 0.72)
	js.corner_radius_top_left = 5; js.corner_radius_top_right = 5
	js.corner_radius_bottom_left = 5; js.corner_radius_bottom_right = 5
	jbtn.add_theme_stylebox_override("normal", js)
	jbtn.pressed.connect(_on_join_pressed)
	vbox.add_child(jbtn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.flat = true
	cancel_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	cancel_btn.pressed.connect(func(): if is_instance_valid(join_popup): join_popup.queue_free())
	vbox.add_child(cancel_btn)

# ─────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────
func _make_secondary_btn(text: String, min_w: float, min_h: float) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.add_theme_font_size_override("font_size", 15)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_color = Color(0.28, 0.28, 0.4)
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate(); sh.bg_color = Color(0.18, 0.18, 0.28); sh.border_color = Color(0.5, 0.5, 0.75)
	b.add_theme_stylebox_override("hover", sh)
	return b

func _section_label(parent: Control, text: String):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1.0, 0.38, 0.08))
	parent.add_child(l)

func _row_label(parent: Control, text: String):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	parent.add_child(l)

func _divider(parent: Control):
	var s = HSeparator.new()
	parent.add_child(s)

func _set_status(text: String):
	if is_instance_valid(status_label):
		status_label.text = text

func _toggle_bots():
	bots_on = !bots_on
	GameManager.bots_enabled = bots_on
	bot_toggle_btn.text = "BOTS: ON" if bots_on else "BOTS: OFF"
	var s = StyleBoxFlat.new()
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	if bots_on:
		s.bg_color = Color(0.08, 0.22, 0.08)
		s.border_color = Color(0.15, 0.75, 0.15)
	else:
		s.bg_color = Color(0.12, 0.12, 0.18, 0.9)
		s.border_color = Color(0.28, 0.28, 0.4)
	bot_toggle_btn.add_theme_stylebox_override("normal", s)

# ─────────────────────────────────────────────────────────
# NETWORKING
# ─────────────────────────────────────────────────────────
func _on_host_pressed():
	if peer != null: return
	var pname = name_input.text.strip_edges()
	if pname == "": pname = "Host"
	GameManager.local_player_name = pname
	_set_status("Starting server...")
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error == OK:
		GameManager.pending_peer = peer
		GameManager.register_player(1, pname)
		_set_status("Server started! Loading match...")
		_start_game()
	else:
		_set_status("Failed to start server (port " + str(PORT) + " in use?)")
		peer = null

func _on_join_pressed():
	if peer != null: return
	var pname = name_input.text.strip_edges()
	if pname == "": pname = "Player"
	GameManager.local_player_name = pname
	var address = "localhost"
	if is_instance_valid(address_input):
		address = address_input.text.strip_edges()
		if address == "": address = "localhost"
	_set_status("Connecting to " + address + "...")
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error == OK:
		GameManager.pending_peer = peer
	else:
		_set_status("Failed to connect — check IP")
		peer = null

func _on_peer_connected(_id: int): pass
func _on_peer_disconnected(_id: int): pass

func _on_connected_to_server():
	var pname = GameManager.local_player_name
	if pname == "": pname = "Player " + str(multiplayer.get_unique_id())
	GameManager.register_player(multiplayer.get_unique_id(), pname)
	_set_status("Connected! Entering match...")
	await get_tree().create_timer(0.8).timeout
	_start_game()

func _on_connection_failed():
	_set_status("Connection failed — check IP and try again")
	peer = null

func _start_game():
	GameManager.local_class_selection = current_class
	GameManager.start_round()
	get_tree().change_scene_to_file("res://Main.tscn")
