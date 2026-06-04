extends SceneTree

func _initialize():
	var files = {
		"Idle": "res://animation/Rifle Idle (2).glb",
		"Run": "res://animation/Rifle Run (3).glb",
		"Jump": "res://animation/Rifle Jump (1).glb",
		"Fire": "res://animation/Firing Rifle (3).glb",
	}
	for label in files:
		print("--- ", label, " ---")
		var packed = load(files[label])
		var root = packed.instantiate()
		print("root=", root.name, " pos=", root.position, " rot=", root.rotation_degrees, " scale=", root.scale)
		for child in root.get_children():
			if child is Node3D:
				print("child=", child.name, " type=", child.get_class(), " pos=", child.position, " rot=", child.rotation_degrees, " scale=", child.scale)
		var ap_list = root.find_children("*", "AnimationPlayer", true, false)
		var meshes = root.find_children("*", "MeshInstance3D", true, false)
		var skeletons = root.find_children("*", "Skeleton3D", true, false)
		print("meshes=", meshes.size(), " skeletons=", skeletons.size())
		var min_pos = Vector3(INF, INF, INF)
		var max_pos = Vector3(-INF, -INF, -INF)
		for mesh in meshes:
			var aabb = mesh.get_aabb()
			for x in [aabb.position.x, aabb.position.x + aabb.size.x]:
				for y in [aabb.position.y, aabb.position.y + aabb.size.y]:
					for z in [aabb.position.z, aabb.position.z + aabb.size.z]:
						var p = mesh.global_transform * Vector3(x, y, z)
						min_pos = min_pos.min(p)
						max_pos = max_pos.max(p)
		print("bounds size=", max_pos - min_pos, " min=", min_pos, " max=", max_pos)
		for skeleton in skeletons:
			print("skeleton=", skeleton.get_path(), " bones=", skeleton.get_bone_count())
		if ap_list.size() > 0:
			var ap = ap_list[0]
			for anim_name in ap.get_animation_list():
				if "RESET" in anim_name:
					continue
				var anim = ap.get_animation(anim_name)
				print("anim=", anim_name, " tracks=", anim.get_track_count())
				for i in range(min(anim.get_track_count(), 16)):
					print(i, ": ", anim.track_get_path(i))
				break
		root.free()
	quit()
