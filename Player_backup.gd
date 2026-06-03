extends CharacterBody3D

## Player.gd - Full FPS character controller
## Implements: movement, camera, shooting, health, multiplayer sync

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# MOVEMENT CONSTANTS
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const BASE_SPEED := 6.0
const SPRINT_MULT := 1.6
const ACCEL := 8.0
const AIR_ACCEL := 2.0
const FRICTION := 10.0
const JUMP_VEL := 5.5
const AIR_CONTROL := 1.25
const GRAVITY := 15.0

# Slide
const SLIDE_BOOST := 1.35
const SLIDE_DURATION := 0.8
const SLIDE_COOLDOWN := 1.2
const SLIDE_CAMERA_Y := 0.3  # how far the camera lowers during slide

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# WEAPON CONSTANTS
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const FIRE_RATE := 0.1          # seconds between shots
const DAMAGE := 20
const MAX_AMMO := 30
const RESERVE_AMMO := 90
const RELOAD_TIME := 1.8
const WEAPON_RANGE := 200.0

# Recoil
const RECOIL_PITCH_MIN := 0.008
const RECOIL_PITCH_MAX := 0.02
const RECOIL_YAW_RANGE := 0.008
const RECOIL_RECOVERY := 5.0

# Spread (radians)
const BASE_SPREAD := 0.005
const MOVE_SPREAD := 0.015
const AIR_SPREAD := 0.025
const CROUCH_SPREAD_MULT := 0.5
const ADS_SPREAD_MULT := 0.3

# ADS
const ADS_FOV := 50.0
const NORMAL_FOV := 75.0
const ADS_SPEED := 8.0

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# NODE REFERENCES
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var weapon_pivot: Node3D = $CameraPivot/WeaponPivot
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
var current_ammo: int = MAX_AMMO
var reserve: int = RESERVE_AMMO
var fire_timer: float = 0.0
var is_reloading: bool = false
var reload_timer: float = 0.0
var is_aiming: bool = false

# Health
var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var respawn_timer: float = 0.0
const RESPAWN_TIME := 3.0

# Sync vars (replicated via MultiplayerSynchronizer)
@export var synced_position: Vector3 = Vector3.ZERO
@export var synced_rotation_y: float = 0.0
@export var synced_camera_x: float = 0.0
@export var synced_health: int = 100

# HUD reference
var hud_script: Node = null

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
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
	else:
		if hud:
			hud.visible = false
		# Show body for other players
		if mesh_core:
			mesh_core.visible = true

func _unhandled_input(event: InputEvent):
	if not is_multiplayer_authority() or is_dead:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
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
	else:
		# Interpolate remote player
		global_position = global_position.lerp(synced_position, 10.0 * delta)
		rotation.y = lerp_angle(rotation.y, synced_rotation_y, 10.0 * delta)
		if camera_pivot:
			camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, synced_camera_x, 10.0 * delta)
		health = synced_health

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# GRAVITY & JUMP
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _handle_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		# Tiny downward force to stay perfectly snapped to floor seams without bouncing
		velocity.y = -0.1

func _handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VEL
		if is_sliding:
			_end_slide()

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# SLIDE
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# MOVEMENT
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _handle_movement(delta: float):
	if is_sliding:
		return

	is_sprinting = Input.is_action_pressed("sprint") and is_on_floor()
	is_crouching = Input.is_action_pressed("crouch") and not is_sliding

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_speed = BASE_SPEED
	if is_sprinting and not is_aiming:
		target_speed *= SPRINT_MULT
	if is_crouching:
		target_speed *= 0.6

	# Apply friction BEFORE acceleration to allow smooth sliding
	if is_on_floor():
		# Stair stepping logic
		if direction != Vector3.ZERO and is_on_wall():
			var step_height = 0.4
			var test_trans = global_transform
			test_trans.origin.y += step_height
			if not test_move(test_trans, direction * 0.1):
				global_position.y += 6.0 * delta
				
		if direction == Vector3.ZERO:
			# Stop quickly if no input
			velocity.x = lerp(velocity.x, 0.0, FRICTION * delta)
			velocity.z = lerp(velocity.z, 0.0, FRICTION * delta)
		else:
			# Accelerate smoothly
			velocity.x = lerp(velocity.x, direction.x * target_speed, ACCEL * delta)
			velocity.z = lerp(velocity.z, direction.z * target_speed, ACCEL * delta)
	else:
		# Air control
		if direction != Vector3.ZERO:
			velocity.x = lerp(velocity.x, direction.x * target_speed, AIR_ACCEL * delta)
			velocity.z = lerp(velocity.z, direction.z * target_speed, AIR_ACCEL * delta)

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# SHOOTING (Hitscan)
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _handle_shooting(delta: float):
	fire_timer -= delta

	if Input.is_action_pressed("shoot") and fire_timer <= 0 and current_ammo > 0 and not is_reloading:
		_fire()
		fire_timer = FIRE_RATE

	# Auto-reload when empty
	if current_ammo <= 0 and reserve > 0 and not is_reloading:
		_start_reload()

func _fire():
	current_ammo -= 1

	# Calculate spread
	var spread = _get_current_spread()

	# Apply spread to shoot ray direction
	var spread_offset = Vector3(
		randf_range(-spread, spread),
		randf_range(-spread, spread),
		0.0
	)

	shoot_ray.target_position = Vector3(spread_offset.x, spread_offset.y, -WEAPON_RANGE)
	shoot_ray.force_raycast_update()

	# Apply recoil
	var pitch_kick = randf_range(RECOIL_PITCH_MIN, RECOIL_PITCH_MAX)
	var yaw_kick = randf_range(-RECOIL_YAW_RANGE, RECOIL_YAW_RANGE)
	recoil_pitch += pitch_kick
	recoil_yaw += yaw_kick
	camera_pivot.rotation.x += pitch_kick
	rotation.y += yaw_kick

	# Muzzle flash effect on weapon
	if weapon_pivot:
		_flash_muzzle()

	# Check hit
	if shoot_ray.is_colliding():
		var collider = shoot_ray.get_collider()
		var hit_point = shoot_ray.get_collision_point()
		var hit_normal = shoot_ray.get_collision_normal()

		# Spawn bullet hole decal
		_spawn_bullet_hole(hit_point, hit_normal)

		# Damage other players
		if collider is CharacterBody3D and collider.has_method("take_damage"):
			collider.take_damage.rpc(DAMAGE, multiplayer.get_unique_id())

func _get_current_spread() -> float:
	var spread = BASE_SPREAD
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()

	# Movement penalty
	spread += (h_speed / (BASE_SPEED * SPRINT_MULT)) * MOVE_SPREAD

	# Air penalty
	if not is_on_floor():
		spread += AIR_SPREAD

	# Crouch bonus
	if is_crouching:
		spread *= CROUCH_SPREAD_MULT

	# ADS bonus
	if is_aiming:
		spread *= ADS_SPREAD_MULT

	return spread

func _flash_muzzle():
	# Quick white flash on the weapon mesh
	var gun = weapon_pivot.get_node_or_null("GunMesh")
	if gun and gun is MeshInstance3D:
		var mat = gun.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var orig_emission = mat.emission
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.9, 0.5)
			mat.emission_energy_multiplier = 5.0
			await get_tree().create_timer(0.05).timeout
			mat.emission = orig_emission
			mat.emission_energy_multiplier = 1.0
			mat.emission_enabled = false

func _spawn_bullet_hole(_pos: Vector3, _normal: Vector3):
	# Decals are not supported on WebGL â€” skip for web builds
	pass


# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# RELOAD
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _handle_reload(delta: float):
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < MAX_AMMO and reserve > 0:
		_start_reload()

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			_finish_reload()

func _start_reload():
	is_reloading = true
	reload_timer = RELOAD_TIME

func _finish_reload():
	is_reloading = false
	var needed = MAX_AMMO - current_ammo
	var available = min(needed, reserve)
	current_ammo += available
	reserve -= available

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# ADS (Aim Down Sights)
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _handle_aim(delta: float):
	is_aiming = Input.is_action_pressed("aim")
	var target_fov = ADS_FOV if is_aiming else NORMAL_FOV
	camera.fov = lerp(camera.fov, target_fov, ADS_SPEED * delta)

	# Move weapon closer to center when aiming
	if weapon_pivot:
		var target_x = -0.05 if is_aiming else 0.25
		weapon_pivot.position.x = lerp(weapon_pivot.position.x, target_x, ADS_SPEED * delta)

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# RECOIL RECOVERY
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _handle_recoil_recovery(delta: float):
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

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# HEALTH & DAMAGE
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int, attacker_id: int):
	if is_dead:
		return
	health -= amount
	health = max(health, 0)

	if health <= 0:
		_die(attacker_id)

func _die(killer_id: int):
	is_dead = true
	respawn_timer = RESPAWN_TIME
	velocity = Vector3.ZERO

	# Record kill
	var my_id = name.to_int()
	GameManager.record_kill(killer_id, my_id)

	# Hide player mesh
	if mesh_core:
		mesh_core.visible = false

	# Disable collision
	$CollisionShape3D.disabled = true

func _handle_respawn(delta: float):
	respawn_timer -= delta
	if respawn_timer <= 0:
		_respawn()

func _respawn():
	is_dead = false
	health = max_health
	current_ammo = MAX_AMMO
	reserve = RESERVE_AMMO

	# Move to spawn point
	global_position = GameManager.get_spawn_position()
	velocity = Vector3.ZERO

	# Re-enable
	$CollisionShape3D.disabled = false
	if not is_multiplayer_authority() and mesh_core:
		mesh_core.visible = true

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# PROCEDURAL ANIMATIONS
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _handle_procedural_animations(delta: float):
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()

	# Dynamic lean (lean forward when moving fast)
	if mesh_core and mesh_core.visible:
		var lean = min(h_speed / (BASE_SPEED * SPRINT_MULT), 1.0) * 0.15
		mesh_core.rotation.x = lerp(mesh_core.rotation.x, lean, 10.0 * delta)

		# Footstep bob
		if is_on_floor() and h_speed > 1.0:
			var t = Time.get_ticks_msec() / 1000.0
			var bob = sin(t * h_speed * 2.0) * 0.04
			mesh_core.position.y = lerp(mesh_core.position.y, bob, 15.0 * delta)
		else:
			mesh_core.position.y = lerp(mesh_core.position.y, 0.0, 10.0 * delta)

	# Weapon sway (subtle)
	if weapon_pivot and is_multiplayer_authority():
		var t = Time.get_ticks_msec() / 1000.0
		if h_speed > 1.0 and is_on_floor():
			var sway_x = sin(t * h_speed * 1.5) * 0.003
			var sway_y = abs(cos(t * h_speed * 3.0)) * 0.004
			weapon_pivot.rotation.x = lerp(weapon_pivot.rotation.x, sway_y, 8.0 * delta)
			weapon_pivot.rotation.z = lerp(weapon_pivot.rotation.z, sway_x, 8.0 * delta)
		else:
			weapon_pivot.rotation.x = lerp(weapon_pivot.rotation.x, 0.0, 5.0 * delta)
			weapon_pivot.rotation.z = lerp(weapon_pivot.rotation.z, 0.0, 5.0 * delta)

# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# HUD UPDATE
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _update_hud():
	if hud_script and hud_script.has_method("update_hud"):
		hud_script.update_hud(health, max_health, current_ammo, MAX_AMMO, reserve, is_reloading, reload_timer, RELOAD_TIME, is_dead, respawn_timer)

