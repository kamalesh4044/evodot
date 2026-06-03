extends Node3D

const PORT = 8080
const MAX_CLIENTS = 16

var peer: WebSocketMultiplayerPeer

# UI elements
var canvas_layer: CanvasLayer
var title_label: Label
var host_btn: Button
var join_btn: Button
var address_input: LineEdit
var status_label: Label

# Class Selection
var class_panel: Panel
var ar_btn: Button
var smg_btn: Button
var shotgun_btn: Button
var current_class: int = 0 # 0=AR, 1=SMG, 2=Shotgun

@onready var soldier_mesh = $low_poly_soldier
@onready var weapon_pivot = $low_poly_soldier/WeaponPivot
@onready var cam = $Camera3D

func _ready():
	_build_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	# Load weapon models for the display
	var weapons = [
		preload("res://models/ak-74.glb").instantiate(),
		preload("res://models/thompson.glb").instantiate(),
		preload("res://models/shotgun.glb").instantiate()
	]
	
	# Clear existing
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

func _build_ui():
	canvas_layer = $CanvasLayer
	if not canvas_layer:
		canvas_layer = CanvasLayer.new()
		add_child(canvas_layer)
		
	# Top bar
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.1, 0.1, 0.15, 0.8)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size.y = 100
	canvas_layer.add_child(top_bar)
	
	title_label = Label.new()
	title_label.text = "VELOCITY"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	top_bar.add_child(title_label)

	# Bottom Center Buttons
	var bottom_stack = VBoxContainer.new()
	bottom_stack.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_stack.position.y -= 120
	bottom_stack.add_theme_constant_override("separation", 10)
	canvas_layer.add_child(bottom_stack)

	address_input = LineEdit.new()
	address_input.text = "ws://localhost:" + str(PORT)
	address_input.placeholder_text = "ws://server-ip:" + str(PORT)
	address_input.custom_minimum_size = Vector2(420, 42)
	address_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	address_input.add_theme_font_size_override("font_size", 18)
	bottom_stack.add_child(address_input)

	var bottom_box = HBoxContainer.new()
	bottom_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_box.add_theme_constant_override("separation", 20)
	bottom_stack.add_child(bottom_box)
	
	host_btn = Button.new()
	host_btn.text = "HOST (Private)"
	host_btn.custom_minimum_size = Vector2(200, 60)
	host_btn.add_theme_font_size_override("font_size", 24)
	host_btn.pressed.connect(_on_host_pressed)
	bottom_box.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "JOIN GAME"
	join_btn.custom_minimum_size = Vector2(200, 60)
	join_btn.add_theme_font_size_override("font_size", 24)
	join_btn.pressed.connect(_on_join_pressed)
	bottom_box.add_child(join_btn)
	
	status_label = Label.new()
	status_label.text = "1924 Players Online"
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position.y -= 30
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	canvas_layer.add_child(status_label)
	
	# Class Selection Panel (Left)
	class_panel = Panel.new()
	class_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	class_panel.offset_left = 50
	class_panel.offset_top = 120
	class_panel.offset_right = 300
	class_panel.offset_bottom = -120
	canvas_layer.add_child(class_panel)
	
	var class_vbox = VBoxContainer.new()
	class_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	class_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	class_vbox.add_theme_constant_override("separation", 15)
	class_panel.add_child(class_vbox)
	
	var class_title = Label.new()
	class_title.text = "SELECT CLASS"
	class_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_title.add_theme_font_size_override("font_size", 24)
	class_vbox.add_child(class_title)
	
	ar_btn = Button.new()
	ar_btn.text = "Assault Rifle"
	ar_btn.custom_minimum_size.y = 50
	ar_btn.pressed.connect(func(): current_class = 0; _update_model_display())
	class_vbox.add_child(ar_btn)
	
	smg_btn = Button.new()
	smg_btn.text = "SMG"
	smg_btn.custom_minimum_size.y = 50
	smg_btn.pressed.connect(func(): current_class = 1; _update_model_display())
	class_vbox.add_child(smg_btn)
	
	shotgun_btn = Button.new()
	shotgun_btn.text = "Shotgun"
	shotgun_btn.custom_minimum_size.y = 50
	shotgun_btn.pressed.connect(func(): current_class = 2; _update_model_display())
	class_vbox.add_child(shotgun_btn)

func _on_host_pressed():
	if peer != null: return
	
	status_label.text = "Starting Server..."
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		GameManager.register_player(multiplayer.get_unique_id(), "Host")
		status_label.text = "MATCH FOUND"
		# Auto-start after a short delay
		await get_tree().create_timer(1.0).timeout
		_start_game()
	else:
		status_label.text = "Failed to start server"
		peer = null

func _on_join_pressed():
	if peer != null: return
	
	status_label.text = "Connecting to Server..."
	peer = WebSocketMultiplayerPeer.new()
	var address = address_input.text.strip_edges()
	if address == "":
		address = "ws://localhost:" + str(PORT)
	if not address.begins_with("ws://") and not address.begins_with("wss://"):
		address = "ws://" + address
	var error = peer.create_client(address)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	else:
		status_label.text = "Failed to create client"
		peer = null

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)

func _on_connected_to_server():
	GameManager.register_player(multiplayer.get_unique_id(), "Player " + str(multiplayer.get_unique_id()))
	status_label.text = "MATCH FOUND"
	await get_tree().create_timer(1.0).timeout
	_start_game()

func _on_connection_failed():
	status_label.text = "Connection Failed"
	peer = null

func _start_game():
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.local_class_selection = current_class
	get_tree().change_scene_to_file("res://Main.tscn")
