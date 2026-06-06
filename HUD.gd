extends Control

## HUD.gd - Heads-Up Display
## Creates all HUD elements programmatically. Attached to a Control inside CanvasLayer.

var player_ref: CharacterBody3D = null

# UI elements
var crosshair_container: Control
var crosshair_dot: Panel
var crosshair_lines: Array[Panel] = []
var health_bar: ProgressBar
var health_label: Label
var ammo_label: Label
var weapon_name_label: Label
var reload_label: Label
var hitmarker_label: Label
var kill_feed_container: VBoxContainer
var death_overlay: ColorRect
var death_label: Label
var respawn_label: Label
var scoreboard_panel: PanelContainer
var scoreboard_content: VBoxContainer
var round_timer_label: Label
var kill_streak_label: Label
var spawn_shield_overlay: ColorRect
var game_over_overlay: Control
var match_mode_label: Label
var scope_overlay: ColorRect

# Crosshair settings
var crosshair_gap: float = 6.0
var crosshair_length: float = 12.0
var crosshair_thickness: float = 2.0
var crosshair_color: Color = Color(0.0, 1.0, 0.5, 0.9)
var crosshair_dot_size: float = 3.0

func setup(player: CharacterBody3D):
	player_ref = player
	_build_hud()
	GameManager.player_killed.connect(_on_player_killed)

func _build_hud():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_crosshair()
	_build_health_bar()
	_build_ammo_display()
	_build_weapon_name()
	_build_reload_indicator()
	_build_hitmarker()
	_build_kill_feed()
	_build_death_overlay()
	_build_scoreboard()
	_build_round_timer()
	_build_kill_streak_notification()
	_build_spawn_shield_indicator()
	_build_scope_overlay()
	_build_game_over_overlay()
	_build_match_mode_label()
	GameManager.game_over.connect(_on_game_over)
	GameManager.round_timer_updated.connect(_on_round_timer_updated)

# ──────────────────────────────────────────
# CROSSHAIR
# ──────────────────────────────────────────
func _build_crosshair():
	crosshair_container = Control.new()
	crosshair_container.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair_container)

	# Center dot
	crosshair_dot = Panel.new()
	crosshair_dot.custom_minimum_size = Vector2(crosshair_dot_size, crosshair_dot_size)
	crosshair_dot.position = Vector2(-crosshair_dot_size / 2.0, -crosshair_dot_size / 2.0)
	crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_style = StyleBoxFlat.new()
	dot_style.bg_color = crosshair_color
	dot_style.corner_radius_top_left = 1
	dot_style.corner_radius_top_right = 1
	dot_style.corner_radius_bottom_left = 1
	dot_style.corner_radius_bottom_right = 1
	crosshair_dot.add_theme_stylebox_override("panel", dot_style)
	crosshair_container.add_child(crosshair_dot)

	# 4 directional lines
	for i in range(4):
		var line = Panel.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = crosshair_color
		line.add_theme_stylebox_override("panel", style)
		crosshair_container.add_child(line)
		crosshair_lines.append(line)

	_update_crosshair_lines(crosshair_gap)

func _update_crosshair_lines(gap: float):
	if crosshair_lines.size() < 4:
		return
	# Top
	crosshair_lines[0].position = Vector2(-crosshair_thickness / 2.0, -(gap + crosshair_length))
	crosshair_lines[0].custom_minimum_size = Vector2(crosshair_thickness, crosshair_length)
	crosshair_lines[0].size = Vector2(crosshair_thickness, crosshair_length)
	# Bottom
	crosshair_lines[1].position = Vector2(-crosshair_thickness / 2.0, gap)
	crosshair_lines[1].custom_minimum_size = Vector2(crosshair_thickness, crosshair_length)
	crosshair_lines[1].size = Vector2(crosshair_thickness, crosshair_length)
	# Left
	crosshair_lines[2].position = Vector2(-(gap + crosshair_length), -crosshair_thickness / 2.0)
	crosshair_lines[2].custom_minimum_size = Vector2(crosshair_length, crosshair_thickness)
	crosshair_lines[2].size = Vector2(crosshair_length, crosshair_thickness)
	# Right
	crosshair_lines[3].position = Vector2(gap, -crosshair_thickness / 2.0)
	crosshair_lines[3].custom_minimum_size = Vector2(crosshair_length, crosshair_thickness)
	crosshair_lines[3].size = Vector2(crosshair_length, crosshair_thickness)

# ──────────────────────────────────────────
# HEALTH BAR
# ──────────────────────────────────────────
func _build_health_bar():
	# Health bar container (bottom left)
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(20, -80)
	container.custom_minimum_size = Vector2(220, 0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	health_label = Label.new()
	health_label.text = "100 HP"
	health_label.add_theme_font_size_override("font_size", 22)
	health_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(health_label)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(200, 12)
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style the health bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.9, 0.4, 0.9)
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("fill", fill_style)

	container.add_child(health_bar)

# ──────────────────────────────────────────
# AMMO DISPLAY
# ──────────────────────────────────────────
func _build_ammo_display():
	ammo_label = Label.new()
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.position = Vector2(-190, -60)
	ammo_label.text = "30 / 90"
	ammo_label.add_theme_font_size_override("font_size", 28)
	ammo_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.custom_minimum_size = Vector2(160, 0)
	ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ammo_label)

# ──────────────────────────────────────────
# WEAPON NAME
# ──────────────────────────────────────────
func _build_weapon_name():
	weapon_name_label = Label.new()
	weapon_name_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_name_label.position = Vector2(-220, -90)
	weapon_name_label.text = "ASSAULT RIFLE"
	weapon_name_label.add_theme_font_size_override("font_size", 14)
	weapon_name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_name_label.custom_minimum_size = Vector2(200, 0)
	weapon_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(weapon_name_label)

# ──────────────────────────────────────────
# RELOAD INDICATOR
# ──────────────────────────────────────────
func _build_reload_indicator():
	reload_label = Label.new()
	reload_label.set_anchors_preset(Control.PRESET_CENTER)
	reload_label.position = Vector2(-60, 40)
	reload_label.text = "RELOADING..."
	reload_label.add_theme_font_size_override("font_size", 16)
	reload_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 0.9))
	reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_label.custom_minimum_size = Vector2(120, 0)
	reload_label.visible = false
	reload_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reload_label)

func _build_hitmarker():
	hitmarker_label = Label.new()
	hitmarker_label.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker_label.position = Vector2(-10, -13)
	hitmarker_label.text = "X"
	hitmarker_label.add_theme_font_size_override("font_size", 24)
	hitmarker_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	hitmarker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker_label.custom_minimum_size = Vector2(20, 20)
	hitmarker_label.visible = false
	hitmarker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hitmarker_label)

func show_hitmarker(headshot: bool = false):
	if not hitmarker_label:
		return
	hitmarker_label.text = "X"
	hitmarker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0) if headshot else Color(1.0, 1.0, 1.0, 0.95))
	hitmarker_label.visible = true
	var tween = create_tween()
	tween.tween_property(hitmarker_label, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		if is_instance_valid(hitmarker_label):
			hitmarker_label.visible = false
			hitmarker_label.modulate.a = 1.0
	)

# ──────────────────────────────────────────
# KILL FEED
# ──────────────────────────────────────────
func _build_kill_feed():
	kill_feed_container = VBoxContainer.new()
	kill_feed_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kill_feed_container.position = Vector2(-320, 10)
	kill_feed_container.custom_minimum_size = Vector2(300, 0)
	kill_feed_container.add_theme_constant_override("separation", 4)
	kill_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(kill_feed_container)

func _on_player_killed(killer_id: int, victim_id: int):
	var killer_name = GameManager.player_data.get(killer_id, {}).get("name", "???")
	var victim_name = GameManager.player_data.get(victim_id, {}).get("name", "???")

	var entry = Label.new()
	entry.text = killer_name + "  ▸  " + victim_name
	entry.add_theme_font_size_override("font_size", 14)
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Highlight if we're involved
	var my_id = player_ref.name.to_int() if player_ref else 0
	if killer_id == my_id:
		entry.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	elif victim_id == my_id:
		entry.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		entry.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 0.8))

	kill_feed_container.add_child(entry)

	# Remove old entries
	while kill_feed_container.get_child_count() > 5:
		kill_feed_container.get_child(0).queue_free()

	# Fade out after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(entry):
		entry.queue_free()

# ──────────────────────────────────────────
# DEATH OVERLAY
# ──────────────────────────────────────────
func _build_death_overlay():
	death_overlay = ColorRect.new()
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.color = Color(0.5, 0.0, 0.0, 0.4)
	death_overlay.visible = false
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_overlay)

	var death_center = CenterContainer.new()
	death_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.add_child(death_center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_center.add_child(vbox)

	death_label = Label.new()
	death_label.text = "YOU DIED"
	death_label.add_theme_font_size_override("font_size", 48)
	death_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(death_label)

	respawn_label = Label.new()
	respawn_label.text = "Respawning in 3..."
	respawn_label.add_theme_font_size_override("font_size", 20)
	respawn_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(respawn_label)

# ──────────────────────────────────────────
# SCOREBOARD
# ──────────────────────────────────────────
func _build_scoreboard():
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard_panel.position = Vector2(-200, -150)
	scoreboard_panel.custom_minimum_size = Vector2(400, 300)
	scoreboard_panel.visible = false
	scoreboard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style.border_color = Color(0.0, 0.7, 1.0, 0.5)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.set_content_margin_all(16)
	scoreboard_panel.add_theme_stylebox_override("panel", style)
	add_child(scoreboard_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scoreboard_panel.add_child(vbox)

	var title = Label.new()
	title.text = "SCOREBOARD"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Header row
	var header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	_add_scoreboard_cell(header, "PLAYER", Color(0.7, 0.7, 0.8), 180)
	_add_scoreboard_cell(header, "K", Color(0.7, 0.7, 0.8), 50)
	_add_scoreboard_cell(header, "D", Color(0.7, 0.7, 0.8), 50)
	_add_scoreboard_cell(header, "KDR", Color(0.7, 0.7, 0.8), 60)

	scoreboard_content = VBoxContainer.new()
	scoreboard_content.add_theme_constant_override("separation", 4)
	scoreboard_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(scoreboard_content)

func _add_scoreboard_cell(parent: Node, text: String, color: Color, min_width: float):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.custom_minimum_size = Vector2(min_width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _update_scoreboard():
	# Clear old entries
	for child in scoreboard_content.get_children():
		child.queue_free()

	var board = GameManager.get_scoreboard()
	for entry in board:
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scoreboard_content.add_child(row)

		var is_me = false
		if player_ref:
			is_me = entry["id"] == player_ref.name.to_int()

		var name_color = Color(1.0, 0.6, 0.1) if is_me else Color(0.9, 0.9, 0.95)
		if entry.get("is_bot", false):
			name_color = Color(0.5, 0.5, 0.6)
		_add_scoreboard_cell(row, entry["name"], name_color, 180)
		_add_scoreboard_cell(row, str(entry["kills"]), Color(0.4, 1.0, 0.5), 50)
		_add_scoreboard_cell(row, str(entry["deaths"]), Color(1.0, 0.4, 0.4), 50)
		_add_scoreboard_cell(row, str(entry.get("kdr", 0.0)), Color(0.8, 0.8, 0.9), 60)

# ──────────────────────────────────────────
# MAIN UPDATE (called by Player.gd)
# ──────────────────────────────────────────
func update_hud(hp: int, max_hp: int, ammo: int, _max_ammo: int, reserve_ammo: int,
				reloading: bool, _reload_time_left: float, _reload_total: float,
				is_dead: bool, respawn_time: float):
	# Health
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp
	if health_label:
		health_label.text = str(hp) + " HP"
		if hp > 60:
			health_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		elif hp > 30:
			health_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			health_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	# Ammo
	if ammo_label:
		ammo_label.text = str(ammo) + " / " + str(reserve_ammo)
		if ammo <= 5:
			ammo_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		else:
			ammo_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))

	# Weapon name
	if weapon_name_label and player_ref:
		var wi = player_ref.current_weapon_index
		if wi >= 0 and wi < player_ref.weapons.size():
			weapon_name_label.text = player_ref.weapons[wi]["name"].to_upper()

	# Reload
	if reload_label:
		reload_label.visible = reloading

	# Death overlay
	if death_overlay:
		death_overlay.visible = is_dead
	if respawn_label and is_dead:
		respawn_label.text = "Respawning in " + str(ceili(respawn_time)) + "..."

	# Crosshair spread based on player velocity
	if player_ref and crosshair_container:
		var h_speed = Vector3(player_ref.velocity.x, 0, player_ref.velocity.z).length()
		var spread_visual = crosshair_gap + (h_speed / player_ref.BASE_SPEED) * 10.0
		if not player_ref.is_on_floor():
			spread_visual += 8.0
		if player_ref.is_aiming:
			spread_visual = max(0.0, spread_visual * 0.1) # Super sharp when aiming
		_update_crosshair_lines(spread_visual)

	# Scoreboard (hold TAB)
	if scoreboard_panel:
		scoreboard_panel.visible = Input.is_action_pressed("scoreboard")
		if scoreboard_panel.visible:
			_update_scoreboard()

func set_crosshair_visible(vis: bool):
	if crosshair_container:
		crosshair_container.visible = vis

# ──────────────────────────────────────────
# ROUND TIMER
# ──────────────────────────────────────────
func _build_round_timer():
	round_timer_label = Label.new()
	round_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	round_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_timer_label.position.y = 12
	round_timer_label.text = ""
	round_timer_label.add_theme_font_size_override("font_size", 22)
	round_timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	round_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(round_timer_label)
	# Don't show if unlimited
	if GameManager.round_duration <= 0.0:
		round_timer_label.visible = false

func _on_round_timer_updated(seconds: float):
	if not is_instance_valid(round_timer_label): return
	var total_secs: int = int(seconds)
	var mins: int = total_secs / 60
	var secs: int = total_secs % 60
	round_timer_label.text = "%d:%02d" % [mins, secs]
	if seconds <= 30.0:
		round_timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

# ──────────────────────────────────────────
# MATCH MODE LABEL
# ──────────────────────────────────────────
func _build_match_mode_label():
	match_mode_label = Label.new()
	match_mode_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	match_mode_label.position = Vector2(12, 12)
	match_mode_label.text = GameManager.match_type
	match_mode_label.add_theme_font_size_override("font_size", 14)
	match_mode_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	match_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(match_mode_label)

# ── SCOPE OVERLAY ──
func _build_scope_overlay():
	scope_overlay = ColorRect.new()
	scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_overlay.visible = false
	
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	void fragment() {
		vec2 uv = UV * 2.0 - 1.0;
		// Adjust for aspect ratio roughly
		uv.x *= 1.777;
		float d = length(uv);
		float alpha = smoothstep(0.45, 0.9, d);
		COLOR = vec4(0.0, 0.0, 0.0, alpha * 0.98);
		// Add a thin black ring
		if (d > 0.43 && d < 0.45) {
			COLOR = vec4(0.0, 0.0, 0.0, 0.85);
		}
	}
	"""
	mat.shader = shader
	scope_overlay.material = mat
	add_child(scope_overlay)

func set_scope_visible(is_visible: bool):
	pass # Disabled scope overlay per user request

# ──────────────────────────────────────────
# KILL STREAK NOTIFICATION
# ──────────────────────────────────────────
func _build_kill_streak_notification():
	kill_streak_label = Label.new()
	kill_streak_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	kill_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_streak_label.position.y = 80
	kill_streak_label.position.x = -150
	kill_streak_label.custom_minimum_size.x = 300
	kill_streak_label.text = ""
	kill_streak_label.add_theme_font_size_override("font_size", 28)
	kill_streak_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
	kill_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_streak_label.visible = false
	add_child(kill_streak_label)

func show_kill_streak(text: String):
	if not is_instance_valid(kill_streak_label): return
	kill_streak_label.text = text
	kill_streak_label.visible = true
	kill_streak_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(kill_streak_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): if is_instance_valid(kill_streak_label): kill_streak_label.visible = false)

# ──────────────────────────────────────────
# SPAWN SHIELD INDICATOR
# ──────────────────────────────────────────
func _build_spawn_shield_indicator():
	spawn_shield_overlay = ColorRect.new()
	spawn_shield_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	spawn_shield_overlay.color = Color(0.1, 0.4, 1.0, 0.0)
	spawn_shield_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spawn_shield_overlay.visible = false
	add_child(spawn_shield_overlay)

func show_spawn_shield():
	if not is_instance_valid(spawn_shield_overlay): return
	spawn_shield_overlay.visible = true
	spawn_shield_overlay.color.a = 0.18

func hide_spawn_shield():
	if not is_instance_valid(spawn_shield_overlay): return
	var tween = create_tween()
	tween.tween_property(spawn_shield_overlay, "color:a", 0.0, 0.5)
	tween.tween_callback(func(): if is_instance_valid(spawn_shield_overlay): spawn_shield_overlay.visible = false)

func flash_spawn_shield():
	if not is_instance_valid(spawn_shield_overlay): return
	spawn_shield_overlay.color.a = 0.35
	var tween = create_tween()
	tween.tween_property(spawn_shield_overlay, "color:a", 0.18, 0.2)

# ──────────────────────────────────────────
# GAME OVER OVERLAY
# ──────────────────────────────────────────
func _build_game_over_overlay():
	game_over_overlay = Control.new()
	game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_overlay.visible = false
	add_child(game_over_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.05, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var over_label = Label.new()
	over_label.name = "OverLabel"
	over_label.text = "MATCH OVER"
	over_label.add_theme_font_size_override("font_size", 64)
	over_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.1))
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(over_label)

	var winner_label = Label.new()
	winner_label.name = "WinnerLabel"
	winner_label.text = ""
	winner_label.add_theme_font_size_override("font_size", 32)
	winner_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(winner_label)

	var return_label = Label.new()
	return_label.name = "ReturnLabel"
	return_label.text = "Returning to lobby in 10..."
	return_label.add_theme_font_size_override("font_size", 18)
	return_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(return_label)

func _on_game_over(winner_name: String):
	if not is_instance_valid(game_over_overlay): return
	game_over_overlay.visible = true
	var winner_label = game_over_overlay.find_child("WinnerLabel", true, false)
	if winner_label:
		winner_label.text = "Winner: " + winner_name
	var return_label = game_over_overlay.find_child("ReturnLabel", true, false)
	# Countdown
	for i in range(10, 0, -1):
		if is_instance_valid(return_label):
			return_label.text = "Returning to lobby in %d..." % i
		await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://Lobby.tscn")
