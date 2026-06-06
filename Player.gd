extends CharacterBody3D

## Player.gd - Full FPS character controller
## Implements: movement, camera, shooting, health, multiplayer sync

# ──────────────────────────────────────────
# MOVEMENT CONSTANTS (Now vars so they can scale with the player size)
# ──────────────────────────────────────────
var BASE_SPEED := 6.2
var SPRINT_MULT := 1.45
var ACCEL := 18.0
var AIR_ACCEL := 5.0
var COUNTER_STRAFE_ACCEL := 28.0
var FRICTION := 14.0
var JUMP_VEL := 5.7
var AIR_CONTROL := 1.15
var GRAVITY := 15.0

# Slide
const SLIDE_BOOST := 1.55
const SLIDE_DURATION := 0.72
const SLIDE_COOLDOWN := 0.65
const SLIDE_CAMERA_Y := 0.3  # how far the camera lowers during slide

# ──────────────────────────────────────────
# WEAPONS
var weapons = [
	{
		"name": "Assault Rifle", "fire_rate": 0.095, "damage": 27, "max_ammo": 30,
		"reload_time": 1.9, "range": 220.0, "auto": true, "pellets": 1,
		"spread": 0.0035, "move_spread": 0.022, "air_spread": 0.032,
		"head_mult": 2.4, "falloff_start": 45.0, "falloff_end": 150.0,
		"recoil_pattern": [Vector2(0.018, -0.004), Vector2(0.021, 0.003), Vector2(0.024, 0.006), Vector2(0.026, -0.008), Vector2(0.027, 0.01), Vector2(0.029, -0.012)]
	},
	{
		"name": "SMG", "fire_rate": 0.055, "damage": 16, "max_ammo": 40,
		"reload_time": 1.45, "range": 115.0, "auto": true, "pellets": 1,
		"spread": 0.006, "move_spread": 0.015, "air_spread": 0.022,
		"head_mult": 2.0, "falloff_start": 28.0, "falloff_end": 95.0,
		"recoil_pattern": [Vector2(0.01, 0.002), Vector2(0.012, -0.003), Vector2(0.014, 0.004), Vector2(0.015, -0.005)]
	},
	{
		"name": "Shotgun", "fire_rate": 0.78, "damage": 11, "max_ammo": 6,
		"reload_time": 2.4, "range": 55.0, "auto": false, "pellets": 9,
		"spread": 0.075, "move_spread": 0.02, "air_spread": 0.035,
		"head_mult": 1.45, "falloff_start": 14.0, "falloff_end": 48.0,
		"recoil_pattern": [Vector2(0.045, 0.012), Vector2(0.045, -0.012)]
	}
]
var weapon_states = [
	{ "ammo": 30, "reserve": 90 },
	{ "ammo": 40, "reserve": 120 },
	{ "ammo": 6, "reserve": 24 }
]
var current_weapon_index: int = 0 :
	set(value):
		current_weapon_index = value
		_update_weapon_models(value)

func _update_weapon_models(index: int):
	if typeof(weapon_models) != TYPE_ARRAY or typeof(tp_weapon_models) != TYPE_ARRAY:
		return
	for i in range(weapon_models.size()):
		if is_instance_valid(weapon_models[i]):
			# Only show first-person weapons if we are the local player!
			weapon_models[i].visible = (i == index and is_multiplayer_authority())
		if is_instance_valid(tp_weapon_models[i]):
			# The Mixamo model already holds a gun, so we don't need these anymore!
			tp_weapon_models[i].visible = false
	_update_hud()

# Recoil
const RECOIL_RECOVERY := 8.0
const RECOIL_RESET_TIME := 0.24

# Spread (radians)
const BASE_SPREAD := 0.005
const MOVE_SPREAD := 0.015
const AIR_SPREAD := 0.025
const CROUCH_SPREAD_MULT := 0.5
const ADS_SPREAD_MULT := 0.3

# Procedural Animation Constants
const BOB_AMP := 0.05
const BOB_FREQ := 10.0

# ADS
const ADS_FOV := 50.0
const NORMAL_FOV := 75.0
const ADS_SPEED := 8.0
const VIEWMODEL_LERP := 13.0

# ──────────────────────────────────────────
# NODE REFERENCES
# ──────────────────────────────────────────
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var weapon_pivot = $CameraPivot/WeaponPivot
@onready var weapon_models = [
	$CameraPivot/WeaponPivot/"ak-74",
	$CameraPivot/WeaponPivot/thompson,
	$CameraPivot/WeaponPivot/shotgun
]
@onready var muzzle_flash = $CameraPivot/WeaponPivot/MuzzleFlash
@onready var mesh_core: Node3D = $MeshCore
@onready var shoot_ray: RayCast3D = $CameraPivot/ShootRay
@onready var hud: CanvasLayer = $HUD

# Camera
@export var mouse_sensitivity: float = 0.002
var camera_default_y: float = 1.5
var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0

# Movement state
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var is_crouching: bool = false
var is_sprinting: bool = false

# Weapon state
var fire_timer: float = 0.0
var is_reloading: bool = false
var reload_timer: float = 0.0
var is_aiming: bool = false
var recoil_shot_index: int = 0
var recoil_reset_timer: float = 0.0
var viewmodel_kick: float = 0.0
var viewmodel_roll: float = 0.0
var last_mouse_delta: Vector2 = Vector2.ZERO
var weapon_idle_position: Vector3 = Vector3(0.24, -0.2, -0.58)
var weapon_ads_position: Vector3 = Vector3(0.0, -0.16, -0.42)
var weapon_base_rotation: Vector3 = Vector3.ZERO

# Health
var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var respawn_timer: float = 0.0
const RESPAWN_TIME := 3.0

# Spawn shield
var spawn_shield: bool = true
var spawn_shield_timer: float = 3.0

# Kill streak
var kill_streak: int = 0
var last_kill_time: float = 0.0
const KILL_STREAK_WINDOW := 5.0  # seconds between kills to count as streak

# Sync vars (replicated via MultiplayerSynchronizer)
@export var synced_position: Vector3 = Vector3.ZERO
@export var synced_rotation_y: float = 0.0
@export var synced_camera_x: float = 0.0
@export var synced_health: int = 100
@export var synced_anim_state: String = "Idle"

# Animation vars
const THIRD_PERSON_MODEL_SCALE := 0.30
const THIRD_PERSON_ARMATURE_MODEL_SCALE := 30.0
const THIRD_PERSON_WEAPON_SCALE := 0.008
const TP_WEAPON_SCENES: Array[PackedScene] = [
	preload("res://models/ak-74.glb"),
	preload("res://models/thompson.glb"),
	preload("res://models/shotgun.glb")
]
const THIRD_PERSON_ANIM_SCENES := {
	"Idle": "res://animation/Rifle Idle (2).glb",
	"Run": "res://animation/Rifle Run (3).glb",
	"Jump": "res://animation/Rifle Jump (1).glb",
	"Fire": "res://animation/Firing Rifle (3).glb",
}

var anim_player: AnimationPlayer
var mesh_root: Node3D
var tp_weapon_pivot: Node3D
var tp_weapon_models: Array[Node3D] = []
var anim_roots: Dictionary = {}
var anim_players: Dictionary = {}
var current_visible_anim: String = ""
var fire_anim_timer: float = 0.0

# HUD reference
var hud_script: Node = null

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	add_to_group("players")
	_configure_weapon_model_transforms()
	_setup_animations()
	
	# Dynamically adjust player collision, camera height, and speeds based on scale
	var s = THIRD_PERSON_MODEL_SCALE
	var cam_pivot = get_node_or_null("CameraPivot")
	if cam_pivot:
		cam_pivot.position.y = 1.5 * s
		
	var col = get_node_or_null("CollisionShape3D")
	if col and col.shape is CapsuleShape3D:
		var cap = col.shape.duplicate()
		cap.height = 1.8 * s
		cap.radius = 0.4 * s
		col.shape = cap
		col.position.y = cap.height / 2.0
		
	# Scale movement variables
	BASE_SPEED = 6.2 * s
	JUMP_VEL = 5.7 * (s ** 0.5)
	GRAVITY = 15.0 * s
	ACCEL = 18.0 * s
	synced_position = global_position
	synced_rotation_y = rotation.y
	synced_camera_x = camera_pivot.rotation.x
	synced_health = health

	# Setup HUD
	if hud:
		hud_script = hud.get_node_or_null("HUDControl")
		if hud_script and hud_script.has_method("setup"):
			hud_script.setup(self)

	if is_multiplayer_authority():
		camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if hud:
			hud.visible = true
		# Hide own body mesh (first person)
		if mesh_core:
			mesh_core.visible = false
		
		# Hide TP weapons from our own view
		for w in tp_weapon_models:
			if is_instance_valid(w): w.hide()
			
		switch_weapon(GameManager.local_class_selection)
	else:
		if hud:
			hud.visible = false
		# Show body for other players
		if mesh_core:
			mesh_core.visible = true
			
		# Hide FP weapons from other players' views
		for w in weapon_models:
			if is_instance_valid(w): w.hide()
			
	# Ensure the correct models are visible when late joining
	_update_weapon_models(current_weapon_index)

func _configure_weapon_model_transforms():
	var fp_positions = [
		Vector3(0.12, -0.18, -0.72),
		Vector3(0.12, -0.18, -0.72),
		Vector3(0.13, -0.2, -0.78),
	]
	var fp_rotations = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
	]
	var fp_scales = [
		Vector3.ONE * 0.012,
		Vector3.ONE * 0.012,
		Vector3.ONE * 0.012,
	]
	for i in range(min(weapon_models.size(), fp_positions.size())):
		var weapon = weapon_models[i]
		if is_instance_valid(weapon):
			weapon.position = fp_positions[i]
			weapon.rotation = fp_rotations[i]
			weapon.scale = fp_scales[i]

	var tp_positions = [
		Vector3(0.06, 0.04, 0.02),
		Vector3(0.06, 0.04, 0.02),
		Vector3(0.07, 0.035, 0.02),
	]
	for i in range(min(tp_weapon_models.size(), tp_positions.size())):
		var weapon = tp_weapon_models[i]
		if is_instance_valid(weapon):
			weapon.position = tp_positions[i]
			weapon.rotation = Vector3(0.0, deg_to_rad(180.0), 0.0)
			weapon.scale = Vector3.ONE * THIRD_PERSON_WEAPON_SCALE

func _unhandled_input(event: InputEvent):
	if not is_multiplayer_authority() or is_dead:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		last_mouse_delta = event.relative
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Toggle mouse capture
	if event.is_action_pressed("quit_menu"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float):
	if is_multiplayer_authority():
		if is_dead:
			_handle_respawn(delta)
			return

		# Tick spawn shield
		if spawn_shield:
			spawn_shield_timer -= delta
			if spawn_shield_timer <= 0.0:
				spawn_shield = false
				if hud_script and hud_script.has_method("hide_spawn_shield"):
					hud_script.hide_spawn_shield()

		_handle_gravity(delta)
		_handle_jump()
		_handle_slide(delta)
		_handle_movement(delta)
		_handle_shooting(delta)
		_handle_reload(delta)
		_handle_aim(delta)
		_handle_recoil_recovery(delta)
		_handle_procedural_animations(delta)
		move_and_slide()
		_update_hud()

		# Fall out of world safety check
		if global_position.y < -30.0:
			global_position = GameManager.get_spawn_position()
			velocity = Vector3.ZERO

		# Sync
		synced_position = global_position
		synced_rotation_y = rotation.y
		synced_camera_x = camera_pivot.rotation.x
		synced_health = health
		
		# Determine anim state
		var h_speed = Vector3(velocity.x, 0, velocity.z).length()
		var target_anim = "Idle"
		if not is_on_floor():
			target_anim = "Jump"
		elif h_speed > 1.0:
			target_anim = "Run"
			
		if fire_anim_timer > 0:
			target_anim = "Fire"
			fire_anim_timer -= delta
			
		synced_anim_state = target_anim
	else:
		# Interpolate remote player
		global_position = global_position.lerp(synced_position, 10.0 * delta)
		rotation.y = lerp_angle(rotation.y, synced_rotation_y, 10.0 * delta)
		if camera_pivot:
			camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, synced_camera_x, 10.0 * delta)
		health = synced_health

	_play_third_person_animation(synced_anim_state)

# ──────────────────────────────────────────
# GRAVITY & JUMP
# ──────────────────────────────────────────
func _handle_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		# Tiny downward force to stay perfectly snapped to floor seams without bouncing
		velocity.y = -0.1

func _handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if is_sliding:
			var boost = max(Vector3(velocity.x, 0, velocity.z).length(), BASE_SPEED * SPRINT_MULT)
			var dir = slide_direction if slide_direction.length() > 0.1 else -transform.basis.z
			velocity.x = dir.x * boost
			velocity.z = dir.z * boost
			_end_slide()
		velocity.y = JUMP_VEL

# ──────────────────────────────────────────
# SLIDE
# ──────────────────────────────────────────
func _handle_slide(delta: float):
	if slide_cooldown_timer > 0:
		slide_cooldown_timer -= delta

	if is_sliding:
		slide_timer -= delta
		var progress = 1.0 - (slide_timer / SLIDE_DURATION)
		var slide_speed = BASE_SPEED * SPRINT_MULT * lerp(SLIDE_BOOST, 0.8, progress)
		
		# Allow slight steering during slide
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var target_slide_dir = slide_direction.lerp(direction, 2.0 * delta).normalized()
		if target_slide_dir.length() > 0:
			slide_direction = target_slide_dir
			
		velocity.x = slide_direction.x * slide_speed
		velocity.z = slide_direction.z * slide_speed

		camera_pivot.position.y = lerp(camera_pivot.position.y, camera_default_y - SLIDE_CAMERA_Y, 10.0 * delta)

		if slide_timer <= 0 or not is_on_floor() or Input.is_action_just_released("crouch"):
			_end_slide()
	else:
		camera_pivot.position.y = lerp(camera_pivot.position.y, camera_default_y, 10.0 * delta)

	if not is_sliding and Input.is_action_just_pressed("crouch") and is_sprinting and is_on_floor() and slide_cooldown_timer <= 0:
		_start_slide()

func _start_slide():
	is_sliding = true
	slide_timer = SLIDE_DURATION
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	if horizontal_vel.length() > 0.5:
		slide_direction = horizontal_vel.normalized()
	else:
		slide_direction = -transform.basis.z

func _end_slide():
	is_sliding = false
	slide_cooldown_timer = SLIDE_COOLDOWN

# ──────────────────────────────────────────
# MOVEMENT
# ──────────────────────────────────────────
func _handle_movement(delta: float):
	if is_sliding:
		return

	is_sprinting = Input.is_action_pressed("sprint") and is_on_floor() and not is_aiming
	is_crouching = Input.is_action_pressed("crouch") and not is_sliding

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_speed = BASE_SPEED
	if is_sprinting and not is_aiming:
		target_speed *= SPRINT_MULT
	if is_crouching:
		target_speed *= 0.6

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)

	if is_on_floor():
		if direction != Vector3.ZERO and is_on_wall():
			var step_height = 0.4
			var test_trans = global_transform
			test_trans.origin.y += step_height
			if not test_move(test_trans, direction * 0.1):
				global_position.y += 6.0 * delta

		if direction == Vector3.ZERO:
			horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, FRICTION * target_speed * delta)
		else:
			var same_dir = horizontal_velocity.normalized().dot(direction) if horizontal_velocity.length() > 0.1 else 1.0
			var accel = COUNTER_STRAFE_ACCEL if same_dir < -0.25 else ACCEL
			horizontal_velocity = horizontal_velocity.move_toward(direction * target_speed, accel * target_speed * delta)
	else:
		if direction != Vector3.ZERO:
			var air_target = direction * target_speed * AIR_CONTROL
			horizontal_velocity = horizontal_velocity.move_toward(air_target, AIR_ACCEL * target_speed * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

# ──────────────────────────────────────────
# SHOOTING (Hitscan)
# ──────────────────────────────────────────
@rpc("call_local", "any_peer")
func sync_weapon(index: int):
	current_weapon_index = index
	_update_weapon_models(index)

func switch_weapon(index: int):
	if index < 0 or index >= weapons.size(): return
	sync_weapon.rpc(index)
	is_reloading = false
	reload_timer = 0
	fire_timer = 0
	recoil_shot_index = 0
	recoil_reset_timer = 0.0
	for i in range(weapon_models.size()):
		if is_instance_valid(weapon_models[i]):
			weapon_models[i].visible = (i == index)
		if i < tp_weapon_models.size() and is_instance_valid(tp_weapon_models[i]):
			tp_weapon_models[i].visible = (i == index)
	_update_hud()

func _handle_shooting(delta: float):
	fire_timer -= delta
	recoil_reset_timer -= delta
	if recoil_reset_timer <= 0.0:
		recoil_shot_index = 0

	# Weapon switching disabled for class system

	var weapon = weapons[current_weapon_index]
	var state = weapon_states[current_weapon_index]
	var is_shooting = Input.is_action_pressed("shoot") if weapon["auto"] else Input.is_action_just_pressed("shoot")

	if is_shooting and fire_timer <= 0 and state["ammo"] > 0 and not is_reloading:
		_fire()
		fire_timer = weapon["fire_rate"]

	# Auto-reload when empty
	if state["ammo"] <= 0 and state["reserve"] > 0 and not is_reloading:
		_start_reload()

func _fire():
	fire_anim_timer = 0.3
	var weapon = weapons[current_weapon_index]
	var state = weapon_states[current_weapon_index]
	state["ammo"] -= 1
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = true
		muzzle_flash.light_energy = 5.0

	var spread = _get_current_spread()
	_apply_recoil(weapon)

	var ray_dir = -camera_pivot.global_transform.basis.z

	for i in range(weapon["pellets"]):
		var p_spread = spread + (weapon["spread"] if i > 0 else 0)
		var spread_offset = Vector3(randf_range(-p_spread, p_spread), randf_range(-p_spread, p_spread), 0.0)
		shoot_ray.target_position = Vector3(spread_offset.x, spread_offset.y, -weapon["range"])
		shoot_ray.force_raycast_update()

		if shoot_ray.is_colliding():
			var collider = shoot_ray.get_collider()
			var hit_point = shoot_ray.get_collision_point()
			if collider and collider.has_method("request_damage"):
				var damage = _calculate_hit_damage(weapon, collider, hit_point)
				# Route damage through server for validation
				collider.request_damage.rpc_id(1, damage, multiplayer.get_unique_id())
				var is_hs = damage >= int(weapon["damage"] * weapon["head_mult"] * 0.75)
				if hud_script and hud_script.has_method("show_hitmarker"):
					hud_script.show_hitmarker(is_hs)
			else:
				var hit_normal = shoot_ray.get_collision_normal()
				_spawn_bullet_hole.rpc(hit_point, hit_normal)
			_spawn_tracer.rpc(shoot_ray.global_position, hit_point)
		else:
			_spawn_tracer.rpc(shoot_ray.global_position, shoot_ray.global_position + ray_dir * 100.0)

func _get_current_spread() -> float:
	var weapon = weapons[current_weapon_index]
	var spread = weapon.get("spread", BASE_SPREAD)
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()

	# Movement penalty
	spread += (h_speed / (BASE_SPEED * SPRINT_MULT)) * weapon.get("move_spread", MOVE_SPREAD)

	# Air penalty
	if not is_on_floor():
		spread += weapon.get("air_spread", AIR_SPREAD)

	# Crouch bonus
	if is_crouching:
		spread *= CROUCH_SPREAD_MULT

	# ADS bonus
	if is_aiming:
		spread *= ADS_SPREAD_MULT

	return spread

func _apply_recoil(weapon: Dictionary):
	var pattern: Array = weapon.get("recoil_pattern", [])
	var recoil = Vector2(0.018, randf_range(-0.006, 0.006))
	if not pattern.is_empty():
		recoil = pattern[min(recoil_shot_index, pattern.size() - 1)]
		recoil.x *= randf_range(0.92, 1.08)
		recoil.y *= randf_range(0.85, 1.15)

	recoil_shot_index += 1
	recoil_reset_timer = RECOIL_RESET_TIME
	recoil_pitch += recoil.x
	recoil_yaw += recoil.y
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x + recoil.x, deg_to_rad(-89), deg_to_rad(89))
	rotation.y += recoil.y
	viewmodel_kick = min(viewmodel_kick + 0.08 + recoil.x, 0.24)
	viewmodel_roll = clamp(viewmodel_roll - recoil.y * 2.5, -0.09, 0.09)

func _calculate_hit_damage(weapon: Dictionary, collider: Node, hit_point: Vector3) -> int:
	var damage := float(weapon["damage"])
	var distance := shoot_ray.global_position.distance_to(hit_point)
	var falloff_start := float(weapon.get("falloff_start", weapon["range"] * 0.45))
	var falloff_end := float(weapon.get("falloff_end", weapon["range"]))
	if distance > falloff_start:
		var t = clamp((distance - falloff_start) / max(falloff_end - falloff_start, 1.0), 0.0, 1.0)
		damage *= lerp(1.0, 0.45, t)

	if collider is Node3D:
		var local_hit = (collider as Node3D).to_local(hit_point)
		# Headshot threshold scaled to player model size
		var hs_threshold = 1.25 * THIRD_PERSON_MODEL_SCALE
		if local_hit.y > hs_threshold:
			damage *= float(weapon.get("head_mult", 2.0))

	return max(1, int(round(damage)))

@rpc("call_local", "any_peer")
func _spawn_tracer(start: Vector3, end: Vector3):
	if start.distance_to(end) < 0.05:
		return
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, start.distance_to(end))
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 3.0
	box.material = mat
	mesh.mesh = box
	get_tree().root.add_child(mesh)
	mesh.global_position = (start + end) / 2.0
	mesh.look_at(end, Vector3.UP)
	var t = get_tree().create_tween()
	t.tween_property(mesh, "scale", Vector3(0, 0, 1), 0.1)
	t.tween_callback(mesh.queue_free)

@rpc("call_local", "any_peer")
func _spawn_bullet_hole(pos: Vector3, normal: Vector3):
	var hole = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mat.albedo_texture = preload("res://icon.svg")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	hole.mesh = quad
	get_tree().root.add_child(hole)
	hole.global_position = pos + normal * 0.01
	if normal != Vector3.UP and normal != Vector3.DOWN:
		hole.look_at(pos + normal, Vector3.UP)
	elif normal == Vector3.UP:
		hole.rotation_degrees.x = -90
	else:
		hole.rotation_degrees.x = 90
		
	# Impact particles
	var parts = GPUParticles3D.new()
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.5, 0.5, 0.5)
	var pmesh = BoxMesh.new()
	pmesh.size = Vector3(0.05, 0.05, 0.05)
	pmesh.material = pmat
	parts.draw_pass_1 = pmesh
	var pmat_process = ParticleProcessMaterial.new()
	pmat_process.direction = normal
	pmat_process.initial_velocity_min = 2.0
	pmat_process.initial_velocity_max = 5.0
	parts.process_material = pmat_process
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.amount = 10
	parts.lifetime = 0.5
	get_tree().root.add_child(parts)
	parts.global_position = pos
	
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(hole): hole.queue_free()
	if is_instance_valid(parts): parts.queue_free()

# ──────────────────────────────────────────
# RELOAD
# ──────────────────────────────────────────
func _handle_reload(delta: float):
	var w = weapons[current_weapon_index]
	var s = weapon_states[current_weapon_index]
	if Input.is_action_just_pressed("reload") and not is_reloading and s["ammo"] < w["max_ammo"] and s["reserve"] > 0:
		_start_reload()

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			_finish_reload()

func _start_reload():
	is_reloading = true
	var w = weapons[current_weapon_index]
	reload_timer = w["reload_time"]

func _finish_reload():
	is_reloading = false
	var w = weapons[current_weapon_index]
	var s = weapon_states[current_weapon_index]
	var needed = w["max_ammo"] - s["ammo"]
	var amount = min(needed, s["reserve"])
	s["ammo"] += amount
	s["reserve"] -= amount

# ──────────────────────────────────────────
# ADS (Aim Down Sights)
# ──────────────────────────────────────────
func _handle_aim(delta: float):
	is_aiming = Input.is_action_pressed("aim")
	var target_fov = ADS_FOV if is_aiming else NORMAL_FOV
	camera.fov = lerp(camera.fov, target_fov, ADS_SPEED * delta)

# ──────────────────────────────────────────
# RECOIL RECOVERY
# ──────────────────────────────────────────
func _handle_recoil_recovery(delta: float):
	if muzzle_flash and muzzle_flash.visible:
		muzzle_flash.light_energy = lerp(muzzle_flash.light_energy, 0.0, 20.0 * delta)
		if muzzle_flash.light_energy < 0.1:
			muzzle_flash.visible = false
			muzzle_flash.light_energy = 5.0
			
	if is_dead: return

	if recoil_pitch > 0:
		var recovery = recoil_pitch * RECOIL_RECOVERY * delta
		camera_pivot.rotation.x -= recovery
		recoil_pitch -= recovery
		if recoil_pitch < 0.001:
			recoil_pitch = 0.0

	if abs(recoil_yaw) > 0:
		var recovery = recoil_yaw * RECOIL_RECOVERY * delta
		rotation.y -= recovery
		recoil_yaw -= recovery
		if abs(recoil_yaw) < 0.001:
			recoil_yaw = 0.0

	viewmodel_kick = lerp(viewmodel_kick, 0.0, 14.0 * delta)
	viewmodel_roll = lerp(viewmodel_roll, 0.0, 12.0 * delta)

# ──────────────────────────────────────────
# HEALTH & DAMAGE
# ──────────────────────────────────────────
# Clients request damage from server — server validates and applies it
@rpc("any_peer", "reliable")
func request_damage(amount: int, attacker_id: int):
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	# Only accept from the attacker themselves or server
	if sender != attacker_id and sender != 1 and sender != 0: return
	take_damage.rpc(amount, attacker_id)

@rpc("authority", "call_local", "reliable")
func take_damage(amount: int, attacker_id: int):
	if is_dead:
		return
	# Spawn shield blocks all damage
	if spawn_shield:
		if is_multiplayer_authority() and hud_script and hud_script.has_method("flash_spawn_shield"):
			hud_script.flash_spawn_shield()
		return
	health -= amount
	health = max(health, 0)

	if health <= 0:
		_die(attacker_id)

func _die(killer_id: int):
	if not is_multiplayer_authority(): return
	is_dead = true
	respawn_timer = RESPAWN_TIME
	velocity = Vector3.ZERO

	# Record kill in GameManager
	var my_id = name.to_int()
	GameManager.record_kill(killer_id, my_id)

	# Kill streak notification for killer
	var now = Time.get_ticks_msec() / 1000.0
	if killer_id == multiplayer.get_unique_id():
		if now - last_kill_time < KILL_STREAK_WINDOW:
			kill_streak += 1
		else:
			kill_streak = 1
		last_kill_time = now
		var streak_text = GameManager.get_kill_streak_label(kill_streak)
		if streak_text != "" and hud_script and hud_script.has_method("show_kill_streak"):
			hud_script.show_kill_streak(streak_text)

	# Hide player mesh
	_sync_death_visual.rpc(true)
	$CollisionShape3D.disabled = true
	_update_hud()

@rpc("authority", "call_local")
func _sync_death_visual(dying: bool):
	if mesh_core:
		if dying:
			mesh_core.visible = false
		else:
			mesh_core.visible = not is_multiplayer_authority()

func _handle_respawn(delta: float):
	respawn_timer -= delta
	if respawn_timer <= 0:
		_respawn()

func _respawn():
	is_dead = false
	health = max_health
	weapon_states = [ { "ammo": 30, "reserve": 90 }, { "ammo": 40, "reserve": 120 }, { "ammo": 6, "reserve": 24 } ]
	velocity = Vector3.ZERO
	recoil_pitch = 0.0
	recoil_yaw = 0.0
	recoil_shot_index = 0

	# Spawn shield — 3 seconds of invincibility
	spawn_shield = true
	spawn_shield_timer = 3.0
	if hud_script and hud_script.has_method("show_spawn_shield"):
		hud_script.show_spawn_shield()

	# Move to spawn point
	global_position = GameManager.get_spawn_position()
	$CollisionShape3D.disabled = false
	_sync_death_visual.rpc(false)
	_update_weapon_models(current_weapon_index)
	_update_hud()


@rpc("any_peer", "call_local")
func heal(amount: int):
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0: return # Only server or self can trigger
	health = min(health + amount, max_health)
	_update_hud()

@rpc("any_peer", "call_local")
func add_ammo(amount: int):
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0: return
	weapon_states[current_weapon_index]["reserve"] += amount
	_update_hud()

# ──────────────────────────────────────────
# PROCEDURAL ANIMATIONS
# ──────────────────────────────────────────
func _handle_procedural_animations(delta: float):
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()

	if mesh_core and mesh_core.visible:
		var lean = min(h_speed / (BASE_SPEED * SPRINT_MULT), 1.0) * 0.15
		mesh_core.rotation.x = lerp(mesh_core.rotation.x, lean, 10.0 * delta)
		if h_speed > 1.0 and is_on_floor():
			mesh_core.position.y = sin(Time.get_ticks_msec() / 140.0) * 0.035
			mesh_core.rotation.z = lerp(mesh_core.rotation.z, -velocity.dot(transform.basis.x) * 0.018, 8.0 * delta)
		else:
			mesh_core.position.y = lerp(mesh_core.position.y, 0.0, 10.0 * delta)
			mesh_core.rotation.z = lerp(mesh_core.rotation.z, 0.0, 8.0 * delta)
	else:
		if is_instance_valid(mesh_core):
			mesh_core.position.y = lerp(mesh_core.position.y, 0.0, 5.0 * delta)
			mesh_core.rotation.x = lerp(mesh_core.rotation.x, 0.0, 5.0 * delta)

	if weapon_pivot and is_multiplayer_authority():
		var t = Time.get_ticks_msec() / 1000.0
		var target_pos = weapon_ads_position if is_aiming else weapon_idle_position
		var bob_scale = 0.35 if is_aiming else 1.0
		if h_speed > 1.0 and is_on_floor():
			target_pos.x += sin(t * h_speed * 1.4) * 0.018 * bob_scale
			target_pos.y += abs(cos(t * h_speed * 2.8)) * 0.025 * bob_scale
		target_pos.z += viewmodel_kick
		target_pos.x += clamp(last_mouse_delta.x, -35.0, 35.0) * -0.0007 * bob_scale
		target_pos.y += clamp(last_mouse_delta.y, -35.0, 35.0) * -0.0005 * bob_scale

		var target_rot = weapon_base_rotation
		target_rot.x += viewmodel_kick * 0.5
		target_rot.y += clamp(last_mouse_delta.x, -35.0, 35.0) * -0.0009 * bob_scale
		target_rot.z += viewmodel_roll + clamp(last_mouse_delta.x, -35.0, 35.0) * -0.0012 * bob_scale

		weapon_pivot.position = weapon_pivot.position.lerp(target_pos, VIEWMODEL_LERP * delta)
		weapon_pivot.rotation = weapon_pivot.rotation.lerp(target_rot, VIEWMODEL_LERP * delta)
		last_mouse_delta = last_mouse_delta.lerp(Vector2.ZERO, 18.0 * delta)

# ──────────────────────────────────────────
# HUD UPDATE
# ──────────────────────────────────────────
func _update_hud():
	if hud_script and hud_script.has_method("update_hud"):
		var w = weapons[current_weapon_index]
		var s = weapon_states[current_weapon_index]
		hud_script.update_hud(health, max_health, s["ammo"], w["max_ammo"], s["reserve"], is_reloading, reload_timer, w["reload_time"], is_dead, respawn_timer)


# ──────────────────────────────────────────
# ANIMATIONS SETUP
# ──────────────────────────────────────────
func _reset_mesh_root_pose():
	for state in anim_roots:
		var root := anim_roots[state] as Node3D
		if not is_instance_valid(root):
			continue
		root.position = Vector3.ZERO
		root.rotation = Vector3(0, PI, 0)
		root.scale = Vector3.ONE * _get_third_person_scale(root)

func _get_third_person_scale(root: Node3D) -> float:
	var armature = root.get_node_or_null("Armature")
	if armature and armature is Node3D and is_equal_approx((armature as Node3D).scale.x, 0.01):
		return THIRD_PERSON_ARMATURE_MODEL_SCALE
	return THIRD_PERSON_MODEL_SCALE

func _build_third_person_weapon_rig():
	tp_weapon_models.clear()
	if not is_instance_valid(mesh_core):
		return

	var old_pivot = mesh_core.get_node_or_null("TPWeaponPivot")
	if old_pivot:
		old_pivot.queue_free()

	tp_weapon_pivot = Node3D.new()
	tp_weapon_pivot.name = "TPWeaponPivot"
	tp_weapon_pivot.position = Vector3(-0.12, 1.08, 0.08)
	mesh_core.add_child(tp_weapon_pivot)

	for scene in TP_WEAPON_SCENES:
		var weapon := scene.instantiate() as Node3D
		if not weapon:
			continue
		tp_weapon_pivot.add_child(weapon)
		tp_weapon_models.append(weapon)

	_configure_weapon_model_transforms()
	_update_weapon_models(current_weapon_index)

func _sanitize_animation(anim: Animation, base_skeleton_path: String = "") -> Animation:
	var tracks_to_remove: Array[int] = []
	for i in range(anim.get_track_count()):
		var p_str = String(anim.track_get_path(i))
		if not ":" in p_str:
			continue
		var node_path = p_str.get_slice(":", 0)
		var subpath = p_str.get_slice(":", 1)
		if node_path == "." or subpath in ["position", "rotation", "scale", "transform", "rotation_degrees"]:
			tracks_to_remove.append(i)
		elif base_skeleton_path != "":
			anim.track_set_path(i, NodePath(base_skeleton_path + ":" + subpath))

	tracks_to_remove.reverse()
	for i in tracks_to_remove:
		anim.remove_track(i)
	return anim

func _get_first_imported_animation_player(root: Node) -> AnimationPlayer:
	var ap_list = root.find_children("*", "AnimationPlayer", true, false)
	if ap_list.size() == 0:
		return null
	return ap_list[0]

func _play_third_person_animation(state: String):
	if not anim_roots.has(state):
		state = "Idle"
	if current_visible_anim != state:
		for anim_state in anim_roots:
			var root := anim_roots[anim_state] as Node3D
			if is_instance_valid(root):
				root.visible = (anim_state == state)
		current_visible_anim = state
		mesh_root = anim_roots[state]
		anim_player = anim_players.get(state)

	var player := anim_players.get(state) as AnimationPlayer
	if not is_instance_valid(player):
		return

	var desired_anim = ""
	for animation_name in player.get_animation_list():
		if not "RESET" in animation_name:
			desired_anim = animation_name
			break
	if desired_anim == "":
		return
	if player.current_animation != desired_anim or not player.is_playing():
		player.play(desired_anim, 0.15)
	_reset_mesh_root_pose()

func _setup_animations():
	if not mesh_core: return
	
	var old_mesh = mesh_core.get_node_or_null("low_poly_soldier")
	var mat = null
	if old_mesh:
		var mi = old_mesh.find_children("*", "MeshInstance3D", true, false)
		if mi.size() > 0:
			mat = mi[0].get_active_material(0)
		mesh_core.remove_child(old_mesh)
		old_mesh.queue_free()

	anim_roots.clear()
	anim_players.clear()
	for state in THIRD_PERSON_ANIM_SCENES:
		var scene = load(THIRD_PERSON_ANIM_SCENES[state])
		if not scene:
			continue
		var root := scene.instantiate() as Node3D
		if not root:
			continue
		root.name = "Anim" + state
		root.visible = false
		mesh_core.add_child(root)
		
		# Fix character facing backwards
		root.rotation.y = PI 
		
		mesh_root = root
		_reset_mesh_root_pose()

		if mat:
			var new_mis = root.find_children("*", "MeshInstance3D", true, false)
			for mesh_instance in new_mis:
				mesh_instance.set_surface_override_material(0, mat)

		var imported_ap = _get_first_imported_animation_player(root)
		if imported_ap:
			anim_players[state] = imported_ap
		anim_roots[state] = root

	_build_third_person_weapon_rig()
	_play_third_person_animation("Idle")
				
	var sync = get_node_or_null("MultiplayerSynchronizer")
	if sync and sync.replication_config:
		if not sync.replication_config.has_property(NodePath(".:synced_anim_state")):
			sync.replication_config.add_property(NodePath(".:synced_anim_state"))
