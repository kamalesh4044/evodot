extends SceneTree

func _init():
	_fix_scene("res://Player.tscn", "MeshCore/low_poly_soldier/TPWeaponPivot")
	_fix_scene("res://Bot.tscn", "low_poly_soldier/TPWeaponPivot")
	quit()

func _fix_scene(path: String, pivot_path: String):
	var packed = load(path)
	if not packed: return
	var scene = packed.instantiate()
	var pivot = scene.get_node_or_null(pivot_path)
	if pivot:
		pivot.position = Vector3(-0.35, 0.8, 0.2)
		pivot.rotation_degrees = Vector3(-15, 180, 0)
		
		# For Player, we also need to fix the FP WeaponPivot just in case
		if path == "res://Player.tscn":
			var fp_pivot = scene.get_node_or_null("CameraPivot/WeaponPivot")
			if fp_pivot:
				fp_pivot.position = Vector3(0.25, -0.25, -0.4)
				fp_pivot.rotation_degrees = Vector3.ZERO
			
			var cam = scene.get_node_or_null("CameraPivot/Camera3D")
			if cam:
				cam.position = Vector3.ZERO
				cam.rotation_degrees = Vector3.ZERO
				
	var new_packed = PackedScene.new()
	new_packed.pack(scene)
	ResourceSaver.save(new_packed, path)
	print("Fixed " + path)
