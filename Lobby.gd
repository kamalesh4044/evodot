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
	_build_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
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

	# ── LEFT PANEL: CLASS SELECTION ──
	_build_left_panel()

	# ── CENTER PANEL: MATCH SETTINGS ──
	_build_center_panel()

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

# ── LEFT PANEL: CLASS ──
func _build_left_panel():
	var panel = _make_panel(0.0, 0.0, 0.28, 1.0)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_child(vbox)
	panel.add_child(margin)

	_make_label(vbox, "SELECT CLASS", 20, Color(1.0, 0.4, 0.1))
	var sep = HSeparator.new(); vbox.add_child(sep)

	var class_data = [
		["ASSAULT RIFLE", "30 rnd | Auto | Long Range"],
		["SMG", "40 rnd | Auto | Fast Fire"],
		["SHOTGUN", "6 rnd | Semi | Close Range"],
	]
	for i in range(class_data.size()):
		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		vbox.add_child(row)
		var btn = _make_button(row, class_data[i][0], 16)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var desc = Label.new()
		desc.text = class_data[i][1]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		row.add_child(desc)
		var idx = i
		btn.pressed.connect(func():
			current_class = idx
			_update_model_display()
			status_label.text = "Class: " + class_data[idx][0]
		)

# ── CENTER PANEL: MATCH SETTINGS ──
func _build_center_panel():
	var panel = _make_panel(0.29, 0.0, 0.71, 1.0)
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

	_make_label(vbox, "MATCH SETTINGS", 20, Color(1.0, 0.4, 0.1))
	var sep = HSeparator.new(); vbox.add_child(sep)

	# Match Type
	_make_label(vbox, "MATCH TYPE", 14, Color(0.7, 0.7, 0.8))
	var mt_box = HBoxContainer.new()
	mt_box.add_theme_constant_override("separation", 8)
	vbox.add_child(mt_box)
	var ffa_btn = _make_button(mt_box, "FREE FOR ALL", 14)
	ffa_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tdm_btn = _make_button(mt_box, "TEAM DEATHMATCH", 14)
	tdm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ffa_btn.pressed.connect(func(): GameManager.match_type = "FFA"; status_label.text = "Mode: Free For All")
	tdm_btn.pressed.connect(func(): GameManager.match_type = "TDM"; status_label.text = "Mode: Team Deathmatch")

	# Kill Limit
	_make_label(vbox, "KILL LIMIT", 14, Color(0.7, 0.7, 0.8))
	var kl_box = HBoxContainer.new()
	kl_box.add_theme_constant_override("separation", 8)
	vbox.add_child(kl_box)
	for limit in [10, 20, 30, 50]:
		var kb = _make_button(kl_box, str(limit), 16)
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lv = limit
		kb.pressed.connect(func(): GameManager.kill_limit = lv; status_label.text = "Kill limit: " + str(lv))

	# Round Time
	_make_label(vbox, "ROUND TIME", 14, Color(0.7, 0.7, 0.8))
	var rt_box = HBoxContainer.new()
	rt_box.add_theme_constant_override("separation", 8)
	vbox.add_child(rt_box)
	var time_opts = [[180.0, "3 min"], [300.0, "5 min"], [600.0, "10 min"], [0.0, "Unlimited"]]
	for opt in time_opts:
		var tb = _make_button(rt_box, opt[1], 14)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv = opt[0]
		var tn = opt[1]
		tb.pressed.connect(func(): GameManager.round_duration = tv; status_label.text = "Time: " + tn)

	# Removed Bot Settings per user request

# Removed _toggle_bots

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
	status_label.text = "Starting Server..."
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		GameManager.pending_peer = peer
		GameManager.register_player(1, pname)
		status_label.text = "Server Started! Launching..."
		_start_game()
	else:
		status_label.text = "Failed to start server (port in use?)"
		peer = null

func _on_join_pressed():
	if peer != null: return
	var pname = name_input.text.strip_edges()
	if pname == "": pname = "Player"
	GameManager.local_player_name = pname
	var address = address_input.text.strip_edges()
	if address == "": address = "localhost"
	status_label.text = "Connecting to " + address + "..."
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		GameManager.pending_peer = peer
	else:
		status_label.text = "Failed to connect"
		peer = null

func _on_peer_connected(id: int):
	pass

func _on_peer_disconnected(id: int):
	pass

func _on_connected_to_server():
	var pname = GameManager.local_player_name
	if pname == "": pname = "Player " + str(multiplayer.get_unique_id())
	GameManager.register_player(multiplayer.get_unique_id(), pname)
	status_label.text = "Connected! Entering match..."
	await get_tree().create_timer(0.8).timeout
	_start_game()

func _on_connection_failed():
	status_label.text = "Connection Failed — check IP and try again"
	peer = null

func _start_game():
	GameManager.local_class_selection = current_class
	GameManager.start_round()
	get_tree().change_scene_to_file("res://Main.tscn")
