extends Node

## Autoload: GameManager
## Handles input setup, game state, spawning, and scoring.

# Signals
signal player_killed(killer_id: int, victim_id: int)
signal score_updated(player_id: int, kills: int, deaths: int)
signal player_spawned(player_id: int)
signal game_state_changed(new_state: String)

# Game state
enum GameState { LOBBY, PLAYING, GAME_OVER }
var current_state: GameState = GameState.LOBBY

# Player data: { peer_id: { "kills": 0, "deaths": 0, "name": "Player" } }
var player_data: Dictionary = {}

var local_class_selection: int = 0

# Spawn points (filled by Main scene)
var spawn_points: Array[Vector3] = []
var next_spawn_index: int = 0

# Player scene reference
var player_scene: PackedScene

# Kill feed
var kill_feed: Array[Dictionary] = []
const MAX_KILL_FEED = 5

func _ready():
	setup_input_actions()
	player_scene = load("res://Player.tscn")

# ──────────────────────────────────────────
# INPUT SETUP (programmatic for reliability)
# ──────────────────────────────────────────
func setup_input_actions():
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_backward", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("crouch", KEY_C)
	_add_key_action("reload", KEY_R)
	_add_key_action("scoreboard", KEY_TAB)
	_add_key_action("quit_menu", KEY_ESCAPE)
	_add_key_action("weapon_1", KEY_1)
	_add_key_action("weapon_2", KEY_2)
	_add_key_action("weapon_3", KEY_3)
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)
	_add_mouse_action("aim", MOUSE_BUTTON_RIGHT)

func _add_key_action(action_name: String, keycode: Key):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var event = InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _add_mouse_action(action_name: String, button: MouseButton):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var event = InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action_name, event)

# ──────────────────────────────────────────
# PLAYER MANAGEMENT
# ──────────────────────────────────────────
func register_player(peer_id: int, player_name: String = ""):
	if player_name == "":
		player_name = "Player " + str(peer_id)
	player_data[peer_id] = {
		"name": player_name,
		"kills": 0,
		"deaths": 0,
	}

func unregister_player(peer_id: int):
	player_data.erase(peer_id)

func get_spawn_position() -> Vector3:
	if spawn_points.is_empty():
		return Vector3(0, 2, 0)
	var pos = spawn_points[next_spawn_index]
	next_spawn_index = (next_spawn_index + 1) % spawn_points.size()
	return pos

# ──────────────────────────────────────────
# SCORING & KILL FEED
# ──────────────────────────────────────────
func record_kill(killer_id: int, victim_id: int):
	if killer_id in player_data:
		player_data[killer_id]["kills"] += 1
	if victim_id in player_data:
		player_data[victim_id]["deaths"] += 1

	var killer_name = player_data.get(killer_id, {}).get("name", "Unknown")
	var victim_name = player_data.get(victim_id, {}).get("name", "Unknown")

	var entry = {
		"killer": killer_name,
		"victim": victim_name,
		"time": Time.get_ticks_msec() / 1000.0
	}
	kill_feed.push_front(entry)
	if kill_feed.size() > MAX_KILL_FEED:
		kill_feed.pop_back()

	player_killed.emit(killer_id, victim_id)
	if killer_id in player_data:
		score_updated.emit(killer_id, player_data[killer_id]["kills"], player_data[killer_id]["deaths"])
	if victim_id in player_data:
		score_updated.emit(victim_id, player_data[victim_id]["kills"], player_data[victim_id]["deaths"])

func get_scoreboard() -> Array[Dictionary]:
	var board: Array[Dictionary] = []
	for id in player_data:
		board.append({
			"id": id,
			"name": player_data[id]["name"],
			"kills": player_data[id]["kills"],
			"deaths": player_data[id]["deaths"],
		})
	board.sort_custom(func(a, b): return a["kills"] > b["kills"])
	return board

func set_state(new_state: GameState):
	current_state = new_state
	game_state_changed.emit(GameState.keys()[new_state])
