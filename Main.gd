extends Node3D

## Main.gd - Game world scene script
## Creates collision in GLOBAL space to handle scaling gracefully.

@onready var players_node: Node3D = $Players
var debug_label: Label

func _log(msg: String):
	print(msg)
	if debug_label:
		debug_label.text += msg + "\n"

func _ready():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	debug_label = Label.new()
	debug_label.position = Vector2(20, 20)
	debug_label.add_theme_font_size_override("font_size", 18)
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	canvas.add_child(debug_label)

	_log("Main _ready started. is_server=" + str(multiplayer.is_server()))

	var map_node = $Map
	if map_node:
		_setup_map(map_node)
	else:
		_create_box_collider(Vector3.ZERO, Vector3(50, 1, 50))
		GameManager.spawn_points = [Vector3(0, 2, 0)]

	# Peer is already assigned in Lobby.gd, no need to reassign here.
	if GameManager.pending_peer:
		_log("Cleared pending_peer")
		GameManager.pending_peer = null

	if multiplayer.is_server():
		_log("Setting up Server...")
		GameManager.register_player(multiplayer.get_unique_id(), GameManager.local_player_name)
		_spawn_player(multiplayer.get_unique_id())
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		# Spawn bots if enabled
		if GameManager.bots_enabled:
			_spawn_bots()
		# Activate pickups
		_spawn_pickups()
		# Handle game over
		GameManager.game_over.connect(_on_game_over)
		# Connect player_spawned to suppress unused signal warning
		GameManager.player_spawned.connect(func(_id): pass)
	else:
		_log("Setting up Client... Status: " + str(multiplayer.multiplayer_peer.get_connection_status()))
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		# If somehow we are already connected (e.g. localhost is too fast)
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_log("Already connected, calling _on_connected_to_server deferred")
			call_deferred("_on_connected_to_server")
		else:
			_log("Waiting for connected_to_server signal...")

func _on_connected_to_server():
	var id = multiplayer.get_unique_id()
	_log("_on_connected_to_server fired. My ID: " + str(id))
	var pname = GameManager.local_player_name
	if pname.strip_edges() == "":
		pname = "Player " + str(id)
	GameManager.register_player(id, pname)
	_log("Sending _request_spawn to server with name: " + pname)
	_request_spawn.rpc_id(1, id, pname)

func _on_connection_failed():
	_log("Connection failed!")
	print("Failed to connect!")
	get_tree().change_scene_to_file("res://Lobby.tscn")

func _setup_map(map_node: Node):
	var meshes: Array = []
	_find_meshes(map_node, meshes)
	if meshes.is_empty():
		return

	var global_min = Vector3(INF, INF, INF)
	var global_max = Vector3(-INF, -INF, -INF)

	for mi in meshes:
		var mesh_inst: MeshInstance3D = mi
		var aabb = mesh_inst.get_aabb()
		for c in range(8):
			var gc = mesh_inst.global_transform * aabb.get_endpoint(c)
			global_min = Vector3(min(global_min.x, gc.x), min(global_min.y, gc.y), min(global_min.z, gc.z))
			global_max = Vector3(max(global_max.x, gc.x), max(global_max.y, gc.y), max(global_max.z, gc.z))

	var map_center = (global_min + global_max) / 2.0
	var map_size = global_max - global_min
	var map_height = map_size.y
	var visual_floor_y = global_min.y + map_height * 0.15

	# MESH COLLISION
	for mi in meshes:
		_create_global_trimesh_collision(mi as MeshInstance3D)

	# Safety floor
	var floor_pos = Vector3(map_center.x, visual_floor_y - 2.5, map_center.z)
	var floor_size = Vector3(map_size.x + 30, 1.0, map_size.z + 30)
	_create_box_collider(floor_pos, floor_size)

	# Boundary walls
	var wall_h = map_height + 4.0
	var wall_y = visual_floor_y + wall_h / 2.0
	_create_box_collider(Vector3(map_center.x, wall_y, global_max.z + 1), Vector3(map_size.x + 30, wall_h, 2))
	_create_box_collider(Vector3(map_center.x, wall_y, global_min.z - 1), Vector3(map_size.x + 30, wall_h, 2))
	_create_box_collider(Vector3(global_max.x + 1, wall_y, map_center.z), Vector3(2, wall_h, map_size.z + 30))
	_create_box_collider(Vector3(global_min.x - 1, wall_y, map_center.z), Vector3(2, wall_h, map_size.z + 30))

	# Spawns
	GameManager.spawn_points.clear()
	var spawn_y = visual_floor_y + 2.0
	var sx = map_size.x * 0.15
	var sz = map_size.z * 0.15
	GameManager.spawn_points = [
		Vector3(map_center.x, spawn_y, map_center.z),
		Vector3(map_center.x + sx, spawn_y, map_center.z + sz),
		Vector3(map_center.x - sx, spawn_y, map_center.z - sz),
		Vector3(map_center.x + sx, spawn_y, map_center.z - sz),
		Vector3(map_center.x - sx, spawn_y, map_center.z + sz),
	]

func _create_global_trimesh_collision(mesh_inst: MeshInstance3D) -> bool:
	if mesh_inst.mesh == null: return false
	
	mesh_inst.create_trimesh_collision()
	
	# The generated StaticBody3D is named like the mesh + "_col"
	for child in mesh_inst.get_children():
		if child is StaticBody3D:
			child.collision_layer = 1
			child.collision_mask = 0
			break
			
	return true

func _create_box_collider(pos: Vector3, size: Vector3):
	var body = StaticBody3D.new()
	body.collision_layer = 1
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	add_child(body)
	body.global_position = pos

func _find_meshes(node: Node, result: Array):
	for child in node.get_children():
		var child_name = child.name.to_lower()
		if "grass" in child_name or "tree" in child_name:
			child.queue_free()
			continue
		if child is MeshInstance3D and child.mesh != null:
			result.append(child)
		_find_meshes(child, result)

func _spawn_player(peer_id: int):
	if not GameManager.player_scene:
		return
	if players_node.has_node(str(peer_id)):
		return
	var player = GameManager.player_scene.instantiate()
	player.name = str(peer_id)
	player.position = GameManager.get_spawn_position()
	players_node.add_child(player, true)
	_log("Server spawned player " + str(peer_id) + " at " + str(player.position))
	GameManager.player_spawned.emit(peer_id)

func _on_peer_connected(_id: int):
	# New peers request their own spawn via RPC
	pass

func _on_peer_disconnected(id: int):
	GameManager.unregister_player(id)
	var player_node = players_node.get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()

@rpc("any_peer", "reliable")
func _request_spawn(peer_id: int, player_name: String = "Player"):
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_log("Server received spawn request from " + str(sender_id) + " for peer " + str(peer_id))
	# sender_id == 0 means called locally (server spawning itself)
	if sender_id != 0 and sender_id != peer_id:
		_log("Spawn rejected: sender_id != peer_id")
		return
	GameManager.register_player(peer_id, player_name)
	_spawn_player(peer_id)

func _process(_delta):
	pass

var pickup_scene: PackedScene = preload("res://Pickup.tscn")

func _spawn_pickups():
	for i in range(8):
		var p = pickup_scene.instantiate()
		p.position = GameManager.get_spawn_position() + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		p.pickup_type = randi() % 2
		add_child(p)

func _spawn_bots():
	if not GameManager.bot_scene: return
	for i in range(GameManager.bot_count):
		var bot = GameManager.bot_scene.instantiate()
		var bot_id = 10000 + i
		bot.name = str(bot_id)
		bot.global_position = GameManager.get_spawn_position()
		players_node.add_child(bot, true)
		GameManager.register_player(bot_id, "Bot " + str(i + 1), -1, true)

func _on_game_over(_winner_name: String):
	# Server resets after the game over screen countdown
	await get_tree().create_timer(12.0).timeout
	GameManager.reset()
	get_tree().change_scene_to_file("res://Lobby.tscn")
