import re

path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Replace _ready to set class
old_ready = '''func _ready():
	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.visible = true
		hud.get_child(0).setup(self)
		switch_weapon(0)'''

new_ready = '''func _ready():
	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.visible = true
		hud.get_child(0).setup(self)
		switch_weapon(GameManager.local_class_selection)'''

text = text.replace(old_ready, new_ready)

# Remove weapon switching input
old_input = '''	if not is_reloading:
		if Input.is_action_just_pressed("weapon_1"): switch_weapon(0)
		elif Input.is_action_just_pressed("weapon_2"): switch_weapon(1)
		elif Input.is_action_just_pressed("weapon_3"): switch_weapon(2)'''

text = text.replace(old_input, "\t# Weapon switching disabled for class system")

# Add ADS logic to _handle_procedural_animations
old_bob = '''	# Dynamic lean (lean forward when moving fast)
	var vel_xz = h_speed

	if mesh_core and mesh_core.visible:
		var lean = min(h_speed / (BASE_SPEED * SPRINT_MULT), 1.0) * 0.15
		mesh_core.rotation.x = lerp(mesh_core.rotation.x, lean, 10.0 * delta)
		
		# Footstep bob
		if is_on_floor() and vel_xz > 1.0:
			var target_bob = BOB_AMP * sin(Time.get_ticks_msec() / 1000.0 * BOB_FREQ)
			if is_sprinting:
				target_bob *= 1.5
			weapon_pivot.position.y = lerp(weapon_pivot.position.y, -0.15 + target_bob, 10.0 * delta)
		
		# Bounce and lean the character model
		if is_instance_valid(mesh_core):
			mesh_core.position.y = sin(Time.get_ticks_msec() / 100.0) * 0.1
			mesh_core.rotation.x = lerp(mesh_core.rotation.x, -vel_xz * 0.015, 5.0 * delta)
	else:
		weapon_pivot.position.y = lerp(weapon_pivot.position.y, -0.15, 10.0 * delta)
		if is_instance_valid(mesh_core):
			mesh_core.position.y = lerp(mesh_core.position.y, 0.0, 5.0 * delta)
			mesh_core.rotation.x = lerp(mesh_core.rotation.x, 0.0, 5.0 * delta)'''

new_bob = '''	# Dynamic lean
	var vel_xz = h_speed
	if mesh_core and mesh_core.visible:
		var lean = min(h_speed / (BASE_SPEED * SPRINT_MULT), 1.0) * 0.15
		mesh_core.rotation.x = lerp(mesh_core.rotation.x, lean, 10.0 * delta)
		if is_on_floor() and vel_xz > 1.0:
			mesh_core.position.y = sin(Time.get_ticks_msec() / 100.0) * 0.1
		else:
			mesh_core.position.y = lerp(mesh_core.position.y, 0.0, 5.0 * delta)

	# ADS (Aim Down Sights)
	var is_aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_reloading
	
	if is_multiplayer_authority():
		var ui = hud.get_child(0)
		if ui.has_method("set_crosshair_visible"):
			ui.set_crosshair_visible(not is_aiming)
			
	var default_pos = Vector3(0.25, -0.25, -0.4)
	var ads_pos = Vector3(0.0, -0.23, -0.3)
	if current_weapon_index == 1: ads_pos = Vector3(0.0, -0.25, -0.3)
	elif current_weapon_index == 2: ads_pos = Vector3(0.0, -0.15, -0.3)
	
	if is_aiming:
		camera.fov = lerp(camera.fov, 50.0, 15.0 * delta)
		weapon_pivot.position = weapon_pivot.position.lerp(ads_pos, 15.0 * delta)
	else:
		camera.fov = lerp(camera.fov, 75.0, 10.0 * delta)
		var target_bob = 0.0
		if is_on_floor() and vel_xz > 1.0:
			target_bob = BOB_AMP * sin(Time.get_ticks_msec() / 1000.0 * BOB_FREQ)
			if is_sprinting: target_bob *= 1.5
		weapon_pivot.position = weapon_pivot.position.lerp(default_pos + Vector3(0, target_bob, 0), 10.0 * delta)'''

text = text.replace(old_bob, new_bob)

# Ensure switch_weapon broadcasts class change
if 'sync_weapon' not in text:
    old_switch = '''func switch_weapon(index: int):
	if index == current_weapon_index or index < 0 or index >= weapons.size(): return
	current_weapon_index = index'''
    
    new_switch = '''@rpc("call_local", "any_peer")
func sync_weapon(index: int):
	current_weapon_index = index
	for i in range(weapon_models.size()):
		if is_instance_valid(weapon_models[i]):
			weapon_models[i].visible = (i == index)

func switch_weapon(index: int):
	if index < 0 or index >= weapons.size(): return
	sync_weapon.rpc(index)'''
    text = text.replace(old_switch, new_switch)
    
    # Need to clean up the rest of the original switch_weapon inside the new one
    old_switch_rest = '''	current_weapon_index = index
	is_reloading = false
	reload_timer = 0
	fire_timer = 0
	for i in range(weapon_models.size()):
		if is_instance_valid(weapon_models[i]):
			weapon_models[i].visible = (i == index)
	_update_hud()'''
    
    new_switch_rest = '''	is_reloading = false
	reload_timer = 0
	fire_timer = 0
	_update_hud()'''
    text = text.replace(old_switch_rest, new_switch_rest)


with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Player.gd patched for ADS and Classes")
