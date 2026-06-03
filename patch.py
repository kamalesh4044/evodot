import re

path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Replace weapon constants
weapons_replacement = '''# WEAPONS
var weapons = [
	{ "name": "Assault Rifle", "fire_rate": 0.1, "damage": 20, "max_ammo": 30, "reload_time": 1.8, "range": 200.0, "auto": true, "pellets": 1, "spread": 0.005 },
	{ "name": "SMG", "fire_rate": 0.06, "damage": 12, "max_ammo": 40, "reload_time": 1.5, "range": 100.0, "auto": true, "pellets": 1, "spread": 0.015 },
	{ "name": "Shotgun", "fire_rate": 0.8, "damage": 15, "max_ammo": 6, "reload_time": 2.5, "range": 50.0, "auto": false, "pellets": 8, "spread": 0.08 }
]
var weapon_states = [
	{ "ammo": 30, "reserve": 90 },
	{ "ammo": 40, "reserve": 120 },
	{ "ammo": 6, "reserve": 24 }
]
var current_weapon_index: int = 0
'''
text = re.sub(r'# WEAPON CONSTANTS\n.*?const WEAPON_RANGE := 200\.0\n', weapons_replacement, text, flags=re.DOTALL)

# 2. Replace current ammo tracking state
text = text.replace('var current_ammo: int = MAX_AMMO\nvar reserve: int = RESERVE_AMMO\n', '')

# 3. Replace reloading functions
reload_old = '''func _start_reload():
	if current_ammo < MAX_AMMO and reserve > 0:
		is_reloading = true
		reload_timer = RELOAD_TIME

func _finish_reload():
	is_reloading = false
	var needed = MAX_AMMO - current_ammo
	var amount = min(needed, reserve)
	current_ammo += amount
	reserve -= amount'''
reload_new = '''func _start_reload():
	var w = weapons[current_weapon_index]
	var s = weapon_states[current_weapon_index]
	if s["ammo"] < w["max_ammo"] and s["reserve"] > 0:
		is_reloading = true
		reload_timer = w["reload_time"]

func _finish_reload():
	is_reloading = false
	var w = weapons[current_weapon_index]
	var s = weapon_states[current_weapon_index]
	var needed = w["max_ammo"] - s["ammo"]
	var amount = min(needed, s["reserve"])
	s["ammo"] += amount
	s["reserve"] -= amount'''
text = text.replace(reload_old, reload_new)

# 4. Replace hud updates
hud_old = '''	if hud:
		var health_pct = health / float(MAX_HEALTH)
		hud.update_health(health_pct, health)
		hud.update_ammo(current_ammo, reserve)
		if is_reloading:
			hud.show_reload_progress(1.0 - (reload_timer / RELOAD_TIME))
		else:
			hud.hide_reload_progress()'''
hud_new = '''	if hud:
		var health_pct = health / float(MAX_HEALTH)
		hud.update_health(health_pct, health)
		hud.update_ammo(weapon_states[current_weapon_index]["ammo"], weapon_states[current_weapon_index]["reserve"])
		if is_reloading:
			hud.show_reload_progress(1.0 - (reload_timer / weapons[current_weapon_index]["reload_time"]))
		else:
			hud.hide_reload_progress()'''
text = text.replace(hud_old, hud_new)

# 5. Replace _respawn ammo resets
respawn_old = '''	current_ammo = MAX_AMMO
	reserve = RESERVE_AMMO'''
respawn_new = '''	weapon_states = [ { "ammo": 30, "reserve": 90 }, { "ammo": 40, "reserve": 120 }, { "ammo": 6, "reserve": 24 } ]'''
text = text.replace(respawn_old, respawn_new)

# 6. Replace _handle_shooting and _fire
shooting_old = '''func _handle_shooting(delta: float):
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
			collider.take_damage.rpc(DAMAGE, multiplayer.get_unique_id())'''
shooting_new = '''func switch_weapon(index: int):
	if index == current_weapon_index or index < 0 or index >= weapons.size(): return
	current_weapon_index = index
	is_reloading = false
	reload_timer = 0
	fire_timer = 0
	_update_hud()

func _handle_shooting(delta: float):
	fire_timer -= delta

	if not is_reloading:
		if Input.is_action_just_pressed("weapon_1"): switch_weapon(0)
		elif Input.is_action_just_pressed("weapon_2"): switch_weapon(1)
		elif Input.is_action_just_pressed("weapon_3"): switch_weapon(2)

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
	var weapon = weapons[current_weapon_index]
	var state = weapon_states[current_weapon_index]
	state["ammo"] -= 1

	var spread = _get_current_spread()

	if weapon_pivot:
		_flash_muzzle()

	var pitch_kick = randf_range(RECOIL_PITCH_MIN, RECOIL_PITCH_MAX)
	var yaw_kick = randf_range(-RECOIL_YAW_RANGE, RECOIL_YAW_RANGE)
	recoil_pitch += pitch_kick
	recoil_yaw += yaw_kick
	camera_pivot.rotation.x += pitch_kick
	rotation.y += yaw_kick

	for i in range(weapon["pellets"]):
		var p_spread = spread + (weapon["spread"] if i > 0 else 0)
		var spread_offset = Vector3(randf_range(-p_spread, p_spread), randf_range(-p_spread, p_spread), 0.0)
		shoot_ray.target_position = Vector3(spread_offset.x, spread_offset.y, -weapon["range"])
		shoot_ray.force_raycast_update()

		if shoot_ray.is_colliding():
			var collider = shoot_ray.get_collider()
			_spawn_bullet_hole(shoot_ray.get_collision_point(), shoot_ray.get_collision_normal())
			if collider is CharacterBody3D and collider.has_method("take_damage"):
				collider.take_damage.rpc(weapon["damage"], multiplayer.get_unique_id())'''
text = text.replace(shooting_old, shooting_new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("SUCCESS")
