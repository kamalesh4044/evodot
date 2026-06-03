import re

def add_tp_pivot(tscn_path, parent_node_path, unique_ids):
    with open(tscn_path, 'r', encoding='utf-8') as f:
        tscn = f.read()

    if 'name="TPWeaponPivot"' in tscn:
        return # Already added
        
    pivot_node = f'''[node name="TPWeaponPivot" type="Node3D" parent="{parent_node_path}" unique_id={unique_ids[0]}]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.25, 1.1, -0.3)

[node name="ak-74" parent="{parent_node_path}/TPWeaponPivot" unique_id={unique_ids[1]} instance=ExtResource("4")]
visible = false

[node name="thompson" parent="{parent_node_path}/TPWeaponPivot" unique_id={unique_ids[2]} instance=ExtResource("5")]
visible = false

[node name="shotgun" parent="{parent_node_path}/TPWeaponPivot" unique_id={unique_ids[3]} instance=ExtResource("6")]
visible = false

'''
    
    # We need to insert this right before the HUD or MultiplayerSynchronizer.
    # Let's just append it to the end of the file, Godot will sort it out.
    with open(tscn_path, 'a', encoding='utf-8') as f:
        f.write(pivot_node)

add_tp_pivot(r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.tscn', 'MeshCore/low_poly_soldier', [40001, 40002, 40003, 40004])

# For Bot, we only have the mesh root in Bot.tscn, the mesh is "low_poly_soldier"
with open(r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Bot.tscn', 'r', encoding='utf-8') as f:
    bot_tscn = f.read()
    
if 'name="TPWeaponPivot"' not in bot_tscn:
    bot_pivot = f'''[node name="TPWeaponPivot" type="Node3D" parent="low_poly_soldier" unique_id=50001]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.25, 1.1, -0.3)

[node name="ak-74" parent="low_poly_soldier/TPWeaponPivot" unique_id=50002 instance=ExtResource("3")]

''' # Bot only has ak-74 loaded as ExtResource("3")
    with open(r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Bot.tscn', 'a', encoding='utf-8') as f:
        f.write(bot_pivot)

# Now we need to update Player.gd to toggle these TP weapons
player_gd_path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.gd'
with open(player_gd_path, 'r', encoding='utf-8') as f:
    player_gd = f.read()

# In _ready(), get the TP weapon models
if 'tp_weapon_models' not in player_gd:
    old_vars = '''@onready var weapon_models = [
	$CameraPivot/WeaponPivot/"ak-74",
	$CameraPivot/WeaponPivot/thompson,
	$CameraPivot/WeaponPivot/shotgun
]'''
    new_vars = '''@onready var weapon_models = [
	$CameraPivot/WeaponPivot/"ak-74",
	$CameraPivot/WeaponPivot/thompson,
	$CameraPivot/WeaponPivot/shotgun
]

@onready var tp_weapon_models = [
	$MeshCore/low_poly_soldier/TPWeaponPivot/"ak-74",
	$MeshCore/low_poly_soldier/TPWeaponPivot/thompson,
	$MeshCore/low_poly_soldier/TPWeaponPivot/shotgun
]'''
    player_gd = player_gd.replace(old_vars, new_vars)

    old_sync = '''	for i in range(weapon_models.size()):
		if is_instance_valid(weapon_models[i]):
			weapon_models[i].visible = (i == index)'''
    new_sync = '''	for i in range(weapon_models.size()):
		if is_instance_valid(weapon_models[i]):
			weapon_models[i].visible = (i == index)
		if is_instance_valid(tp_weapon_models[i]):
			tp_weapon_models[i].visible = (i == index)'''
    player_gd = player_gd.replace(old_sync, new_sync)

    # In _ready(), hide TP weapons for the local player (so they don't block view)
    # and hide FP weapons for remote players
    old_ready = '''		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.visible = true
		hud.get_child(0).setup(self)
		switch_weapon(GameManager.local_class_selection)'''
    new_ready = '''		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.visible = true
		hud.get_child(0).setup(self)
		# Hide TP weapons from our own view
		for w in tp_weapon_models: w.hide()
		switch_weapon(GameManager.local_class_selection)
	else:
		# Hide FP weapons from other players' views
		for w in weapon_models: w.hide()'''
    player_gd = player_gd.replace(old_ready, new_ready)

with open(player_gd_path, 'w', encoding='utf-8') as f:
    f.write(player_gd)
    
print("Added 3rd person weapons")
