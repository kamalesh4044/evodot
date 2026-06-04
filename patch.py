import re

with open("Player.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add synced_anim_state and new variables
content = content.replace(
    "@export var synced_health: int = 100",
    "@export var synced_health: int = 100\n@export var synced_anim_state: String = \"Idle\"\n\n# Animation vars\nvar anim_player: AnimationPlayer\nvar mesh_root: Node3D\nvar fire_anim_timer: float = 0.0"
)

# 2. Add _setup_animations to _ready
content = content.replace(
    "_configure_weapon_model_transforms()",
    "_configure_weapon_model_transforms()\n\t_setup_animations()"
)

# 3. Modify _physics_process to handle anim state
process_target = """		# Sync
		synced_position = global_position
		synced_rotation_y = rotation.y
		synced_camera_x = camera_pivot.rotation.x
		synced_health = health
	else:"""
process_replacement = """		# Sync
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
	else:"""

content = content.replace(process_target, process_replacement)

# Play the animation at the end of _physics_process
process_end_target = """		health = synced_health

# ──────────────────────────────────────────
# GRAVITY & JUMP"""
process_end_replacement = """		health = synced_health

	if anim_player and anim_player.has_animation(synced_anim_state):
		if anim_player.current_animation != synced_anim_state:
			anim_player.play(synced_anim_state, 0.2)

# ──────────────────────────────────────────
# GRAVITY & JUMP"""
content = content.replace(process_end_target, process_end_replacement)

# 4. Add fire_anim_timer reset
fire_target = """func _fire():
	var weapon = weapons[current_weapon_index]"""
fire_replacement = """func _fire():
	fire_anim_timer = 0.3
	var weapon = weapons[current_weapon_index]"""
content = content.replace(fire_target, fire_replacement)

# 5. Append _setup_animations function
setup_animations_code = """

# ──────────────────────────────────────────
# ANIMATIONS SETUP
# ──────────────────────────────────────────
func _setup_animations():
	if not mesh_core: return
	
	var old_mesh = mesh_core.get_node_or_null("low_poly_soldier")
	var mat = null
	if old_mesh:
		var mi = old_mesh.find_children("*", "MeshInstance3D", true, false)
		if mi.size() > 0:
			mat = mi[0].get_active_material(0)
		old_mesh.queue_free()
		
	var idle_scene = load("res://models/Rifle Idle (2).fbx")
	if not idle_scene: return
	mesh_root = idle_scene.instantiate()
	mesh_core.add_child(mesh_root)
	
	if mat:
		var new_mis = mesh_root.find_children("*", "MeshInstance3D", true, false)
		for mi in new_mis:
			mi.set_surface_override_material(0, mat)
			
	var ap_list = mesh_root.find_children("*", "AnimationPlayer", true, false)
	if ap_list.size() > 0:
		anim_player = ap_list[0]
		if anim_player.has_animation("mixamo.com"):
			anim_player.rename_animation("mixamo.com", "Idle")
			anim_player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			
		var anim_files = {
			"Run": "res://models/Rifle Run.fbx",
			"Jump": "res://models/Rifle Jump.fbx",
			"Fire": "res://models/Firing Rifle.fbx"
		}
		for anim_name in anim_files:
			var scene = load(anim_files[anim_name])
			if scene:
				var instance = scene.instantiate()
				var ap = instance.find_children("*", "AnimationPlayer", true, false)[0]
				if ap and ap.has_animation("mixamo.com"):
					var anim = ap.get_animation("mixamo.com").duplicate()
					if anim_name == "Run": anim.loop_mode = Animation.LOOP_LINEAR
					anim_player.add_animation(anim_name, anim)
				instance.free()
				
	var sync = get_node_or_null("MultiplayerSynchronizer")
	if sync and sync.replication_config:
		if not sync.replication_config.has_property(NodePath(".:synced_anim_state")):
			sync.replication_config.add_property(NodePath(".:synced_anim_state"))
"""
content += setup_animations_code

with open("Player.gd", "w", encoding="utf-8") as f:
    f.write(content)

print("Patched successfully")
