extends Node

## Autoload: GameManager
## Handles input setup, game state, spawning, scoring, and match settings.

# Signals
signal player_killed(killer_id: int, victim_id: int)
signal score_updated(player_id: int, kills: int, deaths: int)
signal player_spawned(player_id: int)
signal game_state_changed(new_state: String)
signal game_over(winner_name: String)
signal round_timer_updated(seconds_left: float)

# Game state
enum GameState { LOBBY, PLAYING, GAME_OVER }
var current_state: GameState = GameState.LOBBY

var pending_peer: MultiplayerPeer = null

# ──────────────────────────────────────────
# MATCH SETTINGS (set from Lobby)
# ──────────────────────────────────────────
var bots_enabled: bool = false
var bot_count: int = 4
var match_type: String = "FFA"  # "FFA" or "TDM"
var kill_limit: int = 30
var round_duration: float = 300.0  # seconds (0 = unlimited)
var local_player_name: String = "Player"
var local_class_selection: int = 0

# ──────────────────────────────────────────
# RUNTIME STATE
# ──────────────────────────────────────────
# Player data: { peer_id: { "kills": 0, "deaths": 0, "name": "Player", "team": 0, "is_bot": false } }
var player_data: Dictionary = {}

# Team scores (for TDM)
var team_scores: Dictionary = { 0: 0, 1: 0 }

# Round timer
var round_timer: float = 0.0
var round_active: bool = false

# Spawn points (filled by Main scene)
var spawn_points: Array[Vector3] = []
var next_spawn_index: int = 0

# Player scene reference
var player_scene: PackedScene
var bot_scene: PackedScene

# Kill feed
var kill_feed: Array[Dictionary] = []
const MAX_KILL_FEED = 5

func _ready():
	setup_input_actions()
	player_scene = load("res://Player.tscn")
	bot_scene = load("res://Bot.tscn")

func _process(delta):
	if not round_active:
		return
	if not multiplayer.is_server():
		return
	if round_duration <= 0.0:
		return  # Unlimited time
	round_timer -= delta
	if round_timer <= 0.0:
		round_timer = 0.0
		_end_round()
	else:
		_sync_round_timer.rpc(round_timer)

@rpc("authority", "call_local", "reliable")
func _sync_round_timer(t: float):
	round_timer = t
	round_timer_updated.emit(t)

# ──────────────────────────────────────────
# INPUT SETUP
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
func register_player(peer_id: int, player_name: String = "", team: int = -1, is_bot: bool = false):
	if player_name == "":
		player_name = "Player " + str(peer_id)
	# Auto-assign teams in TDM
	var assigned_team = team
	if assigned_team < 0:
		if match_type == "TDM":
			# Balance teams
			var t0 = player_data.values().filter(func(d): return d["team"] == 0).size()
			var t1 = player_data.values().filter(func(d): return d["team"] == 1).size()
			assigned_team = 0 if t0 <= t1 else 1
		else:
			assigned_team = 0
	player_data[peer_id] = {
		"name": player_name,
		"kills": 0,
		"deaths": 0,
		"team": assigned_team,
		"is_bot": is_bot,
	}

func unregister_player(peer_id: int):
	player_data.erase(peer_id)

func get_spawn_position() -> Vector3:
	if spawn_points.is_empty():
		return Vector3(0, 2, 0)
	var pos = spawn_points[next_spawn_index]
	next_spawn_index = (next_spawn_index + 1) % spawn_points.size()
	return pos

func get_team_spawn_position(team: int) -> Vector3:
	# Split spawn points between teams
	if spawn_points.is_empty():
		return Vector3(0, 2, 0)
	var half = max(1, spawn_points.size() / 2)
	var start_idx = 0 if team == 0 else half
	var end_idx = half if team == 0 else spawn_points.size()
	var idx = randi() % (end_idx - start_idx) + start_idx
	return spawn_points[idx]

# ──────────────────────────────────────────
# SCORING & KILL FEED
# ──────────────────────────────────────────
func record_kill(killer_id: int, victim_id: int):
	if killer_id in player_data:
		player_data[killer_id]["kills"] += 1
		# TDM team score
		if match_type == "TDM":
			var killer_team = player_data[killer_id].get("team", 0)
			team_scores[killer_team] = team_scores.get(killer_team, 0) + 1
	if victim_id in player_data:
		player_data[victim_id]["deaths"] += 1

	var killer_name = player_data.get(killer_id, {}).get("name", "Unknown")
	var victim_name = player_data.get(victim_id, {}).get("name", "Unknown")

	var entry = {
		"killer": killer_name,
		"victim": victim_name,
		"killer_id": killer_id,
		"victim_id": victim_id,
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

	# Check kill limit
	if kill_limit > 0 and killer_id in player_data:
		if player_data[killer_id]["kills"] >= kill_limit:
			_end_round()

func _end_round():
	if current_state == GameState.GAME_OVER:
		return
	set_state(GameState.GAME_OVER)
	var winner = _get_winner_name()
	game_over.emit(winner)

func _get_winner_name() -> String:
	if match_type == "TDM":
		var t0 = team_scores.get(0, 0)
		var t1 = team_scores.get(1, 0)
		if t0 > t1: return "Team Alpha"
		elif t1 > t0: return "Team Bravo"
		else: return "DRAW"
	# FFA — most kills
	var top_id = -1
	var top_kills = -1
	for id in player_data:
		if player_data[id]["kills"] > top_kills:
			top_kills = player_data[id]["kills"]
			top_id = id
	if top_id >= 0:
		return player_data[top_id].get("name", "Unknown")
	return "Unknown"

func get_scoreboard() -> Array[Dictionary]:
	var board: Array[Dictionary] = []
	for id in player_data:
		var k = player_data[id]["kills"]
		var d = player_data[id]["deaths"]
		var kdr = float(k) / max(1.0, float(d))
		board.append({
			"id": id,
			"name": player_data[id]["name"],
			"kills": k,
			"deaths": d,
			"kdr": snappedf(kdr, 0.01),
			"team": player_data[id].get("team", 0),
			"is_bot": player_data[id].get("is_bot", false),
		})
	board.sort_custom(func(a, b): return a["kills"] > b["kills"])
	return board

func get_kill_streak_label(kills_in_row: int) -> String:
	match kills_in_row:
		2: return "DOUBLE KILL!"
		3: return "TRIPLE KILL!"
		4: return "RAMPAGE!"
		5: return "UNSTOPPABLE!"
		_: return "LEGENDARY!" if kills_in_row >= 6 else ""

func start_round():
	round_timer = round_duration
	round_active = true
	set_state(GameState.PLAYING)

func reset():
	player_data.clear()
	team_scores = { 0: 0, 1: 0 }
	kill_feed.clear()
	next_spawn_index = 0
	round_active = false
	round_timer = 0.0

func set_state(new_state: GameState):
	current_state = new_state
	game_state_changed.emit(GameState.keys()[new_state])
