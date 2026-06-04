import re

with open("Player.gd", "r", encoding="utf-8") as f:
    content = f.read()

target = """	var ap_list = mesh_root.find_children("*", "AnimationPlayer", true, false)
	if ap_list.size() > 0:
		anim_player = ap_list[0]
		if anim_player.has_animation("mixamo.com"):
			anim_player.rename_animation("mixamo.com", "Idle")
			anim_player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			
		var anim_files = {
			"Run": "res://models/Rifle Run.glb",
			"Jump": "res://models/Rifle Jump.glb",
			"Fire": "res://models/Firing Rifle.glb"
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
				instance.free()"""

replacement = """	var ap_list = mesh_root.find_children("*", "AnimationPlayer", true, false)
	if ap_list.size() > 0:
		anim_player = ap_list[0]
		# Get the first animation that isn't RESET and rename it to Idle
		var idle_anims = anim_player.get_animation_list()
		for a in idle_anims:
			if a != "RESET" and a != "Idle":
				anim_player.rename_animation(a, "Idle")
				anim_player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
				break
			
		var anim_files = {
			"Run": "res://models/Rifle Run.glb",
			"Jump": "res://models/Rifle Jump.glb",
			"Fire": "res://models/Firing Rifle.glb"
		}
		for anim_name in anim_files:
			var scene = load(anim_files[anim_name])
			if scene:
				var instance = scene.instantiate()
				var ap = instance.find_children("*", "AnimationPlayer", true, false)
				if ap.size() > 0:
					var other_anims = ap[0].get_animation_list()
					for a in other_anims:
						if a != "RESET":
							var anim = ap[0].get_animation(a).duplicate()
							if anim_name == "Run": anim.loop_mode = Animation.LOOP_LINEAR
							anim_player.add_animation(anim_name, anim)
							break
				instance.free()"""

content = content.replace(target, replacement)

with open("Player.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Patched animation logic")
