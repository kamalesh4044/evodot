import re

with open("Player.gd", "r", encoding="utf-8") as f:
    content = f.read()

target = """	var ap_list = mesh_root.find_children("*", "AnimationPlayer", true, false)
	if ap_list.size() > 0:
		var imported_ap = ap_list[0]
		anim_player = AnimationPlayer.new()
		mesh_root.add_child(anim_player)
		var lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
		
		# Get the first animation that isn't RESET and copy it as Idle
		var idle_anims = imported_ap.get_animation_list()
		for a in idle_anims:
			if not "RESET" in a:
				var anim = imported_ap.get_animation(a).duplicate()
				anim.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation("Idle", anim)
				break
			
		var anim_files = {
			"Run": "res://animation/Rifle Run (3).glb",
			"Jump": "res://animation/Rifle Jump (1).glb",
			"Fire": "res://animation/Firing Rifle (3).glb"
		}
		for anim_name in anim_files:
			var scene = load(anim_files[anim_name])
			if scene:
				var instance = scene.instantiate()
				var ap = instance.find_children("*", "AnimationPlayer", true, false)
				if ap.size() > 0:
					var other_anims = ap[0].get_animation_list()
					for a in other_anims:
						if not "RESET" in a:
							var anim = ap[0].get_animation(a).duplicate()
							if anim_name == "Run": anim.loop_mode = Animation.LOOP_LINEAR
							lib.add_animation(anim_name, anim)
							break
				instance.free()"""

replacement = """	var ap_list = mesh_root.find_children("*", "AnimationPlayer", true, false)
	if ap_list.size() > 0:
		var imported_ap = ap_list[0]
		anim_player = AnimationPlayer.new()
		mesh_root.add_child(anim_player)
		var lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
		
		# Get the first animation that isn't RESET and copy it as Idle
		var idle_anims = imported_ap.get_animation_list()
		var base_skeleton_path = ""
		for a in idle_anims:
			if not "RESET" in a:
				var anim = imported_ap.get_animation(a).duplicate()
				anim.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation("Idle", anim)
				
				# Extract base skeleton path for remapping
				for i in range(anim.get_track_count()):
					var path_str = String(anim.track_get_path(i))
					if ":" in path_str:
						base_skeleton_path = path_str.get_slice(":", 0)
						break
				break
			
		var anim_files = {
			"Run": "res://animation/Rifle Run (3).glb",
			"Jump": "res://animation/Rifle Jump (1).glb",
			"Fire": "res://animation/Firing Rifle (3).glb"
		}
		for anim_name in anim_files:
			var scene = load(anim_files[anim_name])
			if scene:
				var instance = scene.instantiate()
				var ap = instance.find_children("*", "AnimationPlayer", true, false)
				if ap.size() > 0:
					var other_anims = ap[0].get_animation_list()
					for a in other_anims:
						if not "RESET" in a:
							var anim = ap[0].get_animation(a).duplicate()
							if anim_name == "Run": anim.loop_mode = Animation.LOOP_LINEAR
							
							# Remap all tracks to the base skeleton path
							if base_skeleton_path != "":
								for i in range(anim.get_track_count()):
									var p_str = String(anim.track_get_path(i))
									if ":" in p_str:
										var bone = p_str.get_slice(":", 1)
										anim.track_set_path(i, NodePath(base_skeleton_path + ":" + bone))
										
							lib.add_animation(anim_name, anim)
							break
				instance.free()"""

content = content.replace(target, replacement)

with open("Player.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Patched AnimationPlayer track remapping logic")
