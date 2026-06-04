extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var sight_ray = $SightRay

const SPEED = 4.0
const FIRE_RATE = 0.5
const DAMAGE = 15
const MAX_HEALTH = 100
const GRAVITY = 15.0

var health = MAX_HEALTH
var fire_timer = 0.0
var target_player: Node3D = null

@onready var mesh = $low_poly_soldier
@onready var muzzle_flash = $WeaponPivot/MuzzleFlash

enum State { IDLE, CHASE, ATTACK }
var current_state = State.IDLE

func _ready():
	# Make the bot red so we know it's an enemy
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	if is_instance_valid(mesh):
		_apply_material_recursive(mesh, mat)

func _apply_material_recursive(node: Node, mat: Material):
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _physics_process(delta):
	# Only host controls AI
	if not multiplayer.is_server():
		return

	fire_timer -= delta

	# Find closest player
	target_player = _find_closest_player()

	if target_player == null:
		current_state = State.IDLE
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var dist = global_position.distance_to(target_player.global_position)
	var has_line_of_sight = _check_line_of_sight(target_player)

	if has_line_of_sight and dist < 15.0:
		current_state = State.ATTACK
	else:
		current_state = State.CHASE

	match current_state:
		State.CHASE:
			nav_agent.target_position = target_player.global_position
			var next_path_pos = nav_agent.get_next_path_position()
			
			# Fallback if navmesh is unbaked or path is too short
			if next_path_pos.distance_to(global_position) < 0.5:
				next_path_pos = target_player.global_position
				
			var dir = global_position.direction_to(next_path_pos)
			dir.y = 0
			if dir.length() > 0:
				dir = dir.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			look_at_target(next_path_pos, delta)

		State.ATTACK:
			velocity.x = 0
			velocity.z = 0
			look_at_target(target_player.global_position, delta)
			if fire_timer <= 0:
				_shoot(target_player)
				fire_timer = FIRE_RATE

	# Procedural Animation
	var h_vel = Vector2(velocity.x, velocity.z).length()
	if is_instance_valid(mesh):
		if h_vel > 0.5:
			mesh.position.y = sin(Time.get_ticks_msec() / 150.0) * 0.15
			mesh.rotation.x = lerp(mesh.rotation.x, -h_vel * 0.015, 5.0 * delta)
		else:
			mesh.position.y = lerp(mesh.position.y, 0.0, 10.0 * delta)
			mesh.rotation.x = lerp(mesh.rotation.x, 0.0, 10.0 * delta)
			
	# Muzzle Flash fade
	if is_instance_valid(muzzle_flash) and muzzle_flash.visible:
		muzzle_flash.light_energy = lerp(muzzle_flash.light_energy, 0.0, 20.0 * delta)
		if muzzle_flash.light_energy < 0.1:
			muzzle_flash.visible = false

	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1

	move_and_slide()

func look_at_target(target_pos: Vector3, delta: float):
	var look_pos = target_pos
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		var target_basis = Basis.looking_at(look_pos - global_position, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, 10.0 * delta)

func _find_closest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("players")
	var closest = null
	var min_dist = 9999.0
	for p in players:
		if not is_instance_valid(p):
			continue
		var player_health = p.get("health")
		if player_health == null or player_health <= 0:
			continue
		if p.global_position.y < -20.0:
			continue
		var d = global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			closest = p
	return closest

func _check_line_of_sight(target: Node3D) -> bool:
	sight_ray.target_position = sight_ray.to_local(target.global_position + Vector3(0, 1, 0))
	sight_ray.force_raycast_update()
	if sight_ray.is_colliding():
		if sight_ray.get_collider() == target:
			return true
	return false

func _shoot(target: Node3D):
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = true
		muzzle_flash.light_energy = 5.0
		
	if target.has_method("take_damage"):
		target.take_damage.rpc(DAMAGE, 0) # 0 ID means AI

@rpc("any_peer", "call_local")
func take_damage(amount: int, attacker_id: int):
	if not multiplayer.is_server(): return
	health -= amount
	if health <= 0:
		queue_free()
