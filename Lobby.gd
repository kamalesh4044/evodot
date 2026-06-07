extends Node3D

const PORT = 8080
const MAX_CLIENTS = 16

var peer: ENetMultiplayerPeer

# UI
var canvas: CanvasLayer
var status_label: Label
var name_input: LineEdit
var address_input: LineEdit
var bot_count_label: Label
var bot_count_slider: HSlider

var current_class: int = 0

@onready var soldier_mesh = $low_poly_soldier
@onready var weapon_pivot = $low_poly_soldier/WeaponPivot
@onready var cam = $Camera3D

func _ready():
	if "--server" in OS.get_cmdline_args():
		GameManager.local_player_name = "DedicatedServer"
		GameManager.is_host = true
		call_deferred("_start_game")
		return
		
	_build_ui()
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

func _process(delta):
	if is_instance_valid(soldier_mesh):
		soldier_mesh.rotation.y += 0.2 * delta

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

	# Full dark background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	canvas.add_child(bg)

	# ── TITLE BAR ──
	var title_bg = ColorRect.new()
	title_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bg.custom_minimum_size.y = 80
	title_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	canvas.add_child(title_bg)

	var title = Label.new()
	title.text = "VELOCITY"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.1))
	title_bg.add_child(title)

	var sub = Label.new()
	sub.text = "MULTIPLAYER FPS"
	sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position.y = -8
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title_bg.add_child(sub)

	# ── LEFT PANEL: CLASS & SETTINGS ──
	_build_left_panel()

	# ── RIGHT PANEL: CONNECT ──
	_build_right_panel()

	# ── BOTTOM STATUS ──
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position.y = -28
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_label.text = "Choose settings and HOST or JOIN"
	canvas.add_child(status_label)

func _make_panel(ax: float, ay: float, bx: float, by: float) -> Panel:
	var p = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.25, 0.25, 0.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	p.add_theme_stylebox_override("panel", style)
	p.anchor_left = ax; p.anchor_right = bx
	p.anchor_top = ay; p.anchor_bottom = by
	p.offset_left = 10; p.offset_right = -10
	p.offset_top = 90; p.offset_bottom = -50
	canvas.add_child(p)
	return p

func _make_label(parent: Control, text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _make_button(parent: Control, text: String, size: int = 18) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", size)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.22)
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_color = Color(0.3, 0.3, 0.45)
	normal.corner_radius_top_left = 6; normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6; normal.corner_radius_bottom_right = 6
	b.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color(0.22, 0.22, 0.32)
	hover.border_color = Color(1.0, 0.4, 0.1)
	b.add_theme_stylebox_override("hover", hover)
	parent.add_child(b)
	return b

# ── LEFT PANEL: CLASS & SETTINGS ──
func _build_left_panel():
	var panel = _make_panel(0.0, 0.0, 0.28, 1.0)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_make_label(vbox, "SELECT CLASS", 18, Color(1.0, 0.4, 0.1))
	var sep1 = HSeparator.new(); vbox.add_child(sep1)

	var class_ob = OptionButton.new()
	class_ob.add_item("Assault Rifle")
	class_ob.add_item("SMG")
	class_ob.add_item("Shotgun")
	class_ob.custom_minimum_size.y = 36
	class_ob.add_theme_font_size_override("font_size", 16)
	class_ob.item_selected.connect(func(idx):
		current_class = idx
		_update_model_display()
		status_label.text = "Class: " + class_ob.get_item_text(idx)
	)
	vbox.add_child(class_ob)

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	vbox.add_child(spacer)

	_make_label(vbox, "MATCH SETTINGS", 18, Color(1.0, 0.4, 0.1))
	var sep2 = HSeparator.new(); vbox.add_child(sep2)

	_make_label(vbox, "MATCH TYPE", 14, Color(0.7, 0.7, 0.8))
	var mt_ob = OptionButton.new()
	mt_ob.add_item("Free For All")
	mt_ob.add_item("Team Deathmatch")
	mt_ob.custom_minimum_size.y = 36
	mt_ob.item_selected.connect(func(idx):
		GameManager.match_type = "FFA" if idx == 0 else "TDM"
		status_label.text = "Mode: " + mt_ob.get_item_text(idx)
	)
	vbox.add_child(mt_ob)

	_make_label(vbox, "KILL LIMIT", 14, Color(0.7, 0.7, 0.8))
	var kl_ob = OptionButton.new()
	kl_ob.add_item("10 Kills"); kl_ob.set_item_metadata(0, 10)
	kl_ob.add_item("20 Kills"); kl_ob.set_item_metadata(1, 20)
	kl_ob.add_item("30 Kills"); kl_ob.set_item_metadata(2, 30)
	kl_ob.add_item("50 Kills"); kl_ob.set_item_metadata(3, 50)
	kl_ob.select(2) # Default 30
	kl_ob.custom_minimum_size.y = 36
	kl_ob.item_selected.connect(func(idx):
		GameManager.kill_limit = kl_ob.get_item_metadata(idx)
		status_label.text = "Kill Limit: " + kl_ob.get_item_text(idx)
	)
	vbox.add_child(kl_ob)

	_make_label(vbox, "ROUND TIME", 14, Color(0.7, 0.7, 0.8))
	var rt_ob = OptionButton.new()
	rt_ob.add_item("3 min"); rt_ob.set_item_metadata(0, 180.0)
	rt_ob.add_item("5 min"); rt_ob.set_item_metadata(1, 300.0)
	rt_ob.add_item("10 min"); rt_ob.set_item_metadata(2, 600.0)
	rt_ob.add_item("Unlimited"); rt_ob.set_item_metadata(3, 0.0)
	rt_ob.select(1) # Default 5 min
	rt_ob.custom_minimum_size.y = 36
	rt_ob.item_selected.connect(func(idx):
		GameManager.round_duration = rt_ob.get_item_metadata(idx)
		status_label.text = "Time: " + rt_ob.get_item_text(idx)
	)
	vbox.add_child(rt_ob)
# ── RIGHT PANEL: CONNECT ──
func _build_right_panel():
	var panel = _make_panel(0.72, 0.0, 1.0, 1.0)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_make_label(vbox, "CONNECT", 20, Color(1.0, 0.4, 0.1))
	var sep = HSeparator.new(); vbox.add_child(sep)

	# Name
	_make_label(vbox, "YOUR NAME", 14, Color(0.7, 0.7, 0.8))
	name_input = LineEdit.new()
	name_input.text = "Player"
	name_input.placeholder_text = "Enter name..."
	name_input.custom_minimum_size.y = 42
	name_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_input)

	# Server IP
	_make_label(vbox, "SERVER IP", 14, Color(0.7, 0.7, 0.8))
	address_input = LineEdit.new()
	address_input.text = "localhost"
	address_input.placeholder_text = "IP address..."
	address_input.custom_minimum_size.y = 42
	address_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(address_input)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# HOST button (orange accent)
	var host_btn = Button.new()
	host_btn.text = "HOST GAME"
	host_btn.custom_minimum_size = Vector2(0, 56)
	host_btn.add_theme_font_size_override("font_size", 22)
	var hs = StyleBoxFlat.new()
	hs.bg_color = Color(0.8, 0.3, 0.05)
	hs.corner_radius_top_left = 8; hs.corner_radius_top_right = 8
	hs.corner_radius_bottom_left = 8; hs.corner_radius_bottom_right = 8
	host_btn.add_theme_stylebox_override("normal", hs)
	var hsh = hs.duplicate()
	hsh.bg_color = Color(1.0, 0.45, 0.1)
	host_btn.add_theme_stylebox_override("hover", hsh)
	host_btn.pressed.connect(_on_host_pressed)
	
	if not OS.has_feature("web"):
		vbox.add_child(host_btn)

	# JOIN button
	var join_btn = _make_button(vbox, "JOIN GAME", 22)
	join_btn.custom_minimum_size = Vector2(0, 56)
	join_btn.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	if peer != null: return
	var pname = name_input.text.strip_edges()
	if pname == "": pname = "Host"
	GameManager.local_player_name = pname
	GameManager.is_host = true
	status_label.text = "Starting Server..."
	_start_game()

func _on_join_pressed():
	if peer != null: return
	var pname = name_input.text.strip_edges()
	if pname == "": pname = "Player"
	GameManager.local_player_name = pname
	var address = address_input.text.strip_edges()
	if address == "": address = "localhost"
	GameManager.join_address = address
	GameManager.is_host = false
	status_label.text = "Connecting to " + address + "..."
	_start_game()

func _start_game():
	GameManager.local_class_selection = current_class
	GameManager.start_round()
	get_tree().change_scene_to_file("res://Main.tscn")
