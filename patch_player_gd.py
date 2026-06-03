path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Add weapon references
weapon_refs = '''@onready var weapon_models = [
	$CameraPivot/WeaponPivot/\"ak-74\",
	$CameraPivot/WeaponPivot/thompson,
	$CameraPivot/WeaponPivot/shotgun
]
@onready var muzzle_flash = $CameraPivot/WeaponPivot/MuzzleFlash'''

if 'weapon_models' not in text:
    text = text.replace('@onready var weapon_pivot = $CameraPivot/WeaponPivot', '@onready var weapon_pivot = $CameraPivot/WeaponPivot\n' + weapon_refs)

# Update switch_weapon
old_switch = '''func switch_weapon(index: int):
	if index == current_weapon_index or index < 0 or index >= weapons.size(): return
	current_weapon_index = index
	is_reloading = false
	reload_timer = 0
	fire_timer = 0
	_update_hud()'''

new_switch = '''func switch_weapon(index: int):
	if index == current_weapon_index or index < 0 or index >= weapons.size(): return
	current_weapon_index = index
	is_reloading = false
	reload_timer = 0
	fire_timer = 0
	for i in range(weapon_models.size()):
		weapon_models[i].visible = (i == index)
	_update_hud()'''
	
text = text.replace(old_switch, new_switch)

# Update _fire for MuzzleFlash
if 'muzzle_flash.visible = true' not in text:
    text = text.replace('state["ammo"] -= 1', 'state["ammo"] -= 1\n\tmuzzle_flash.visible = true')

# Add process for MuzzleFlash decay
if 'muzzle_flash.visible = false' not in text:
    old_proc = '''func _handle_recoil_recovery(delta: float):'''
    new_proc = '''func _handle_recoil_recovery(delta: float):
	if muzzle_flash and muzzle_flash.visible:
		muzzle_flash.light_energy = lerp(muzzle_flash.light_energy, 0.0, 20.0 * delta)
		if muzzle_flash.light_energy < 0.1:
			muzzle_flash.visible = false
			muzzle_flash.light_energy = 5.0\n'''
    text = text.replace(old_proc, new_proc)
    
# Add bullet trails to _fire loop
old_ray = '''if shoot_ray.is_colliding():
			var collider = shoot_ray.get_collider()
			if collider and collider.has_method(\"take_damage\"):
				collider.take_damage.rpc(weapon[\"damage\"], multiplayer.get_unique_id())
			else:
				var hit_point = shoot_ray.get_collision_point()
				var hit_normal = shoot_ray.get_collision_normal()
				_spawn_bullet_hole.rpc(hit_point, hit_normal)'''

new_ray = '''if shoot_ray.is_colliding():
			var collider = shoot_ray.get_collider()
			if collider and collider.has_method(\"take_damage\"):
				collider.take_damage.rpc(weapon[\"damage\"], multiplayer.get_unique_id())
			else:
				var hit_point = shoot_ray.get_collision_point()
				var hit_normal = shoot_ray.get_collision_normal()
				_spawn_bullet_hole.rpc(hit_point, hit_normal)
			_spawn_tracer.rpc(shoot_ray.global_position, shoot_ray.get_collision_point())
		else:
			_spawn_tracer.rpc(shoot_ray.global_position, shoot_ray.global_position + ray_dir * 100.0)'''
text = text.replace(old_ray, new_ray)

# Add _spawn_tracer and update _spawn_bullet_hole
new_funcs = '''@rpc("call_local", "any_peer")
func _spawn_tracer(start: Vector3, end: Vector3):
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
		
	# Spawn impact particles
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
	pmat_process.scale_min = 0.5
	pmat_process.scale_max = 1.0
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
	if is_instance_valid(parts): parts.queue_free()'''

text = re.sub(r'@rpc\("call_local", "any_peer"\)\nfunc _spawn_bullet_hole\(pos: Vector3, normal: Vector3\):.*?(?=\n\n|\Z)', new_funcs, text, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Patched Player.gd with weapons and VFX")
