extends SceneTree
func _initialize():
	var output = ""
	
	var idle_scene = load("res://animation/Rifle Idle (2).glb")
	if idle_scene:
		var node = idle_scene.instantiate()
		var ap_list = node.find_children("*", "AnimationPlayer", true, false)
		if ap_list.size() > 0:
			var ap = ap_list[0]
			var anims = ap.get_animation_list()
			for a in anims:
				if not "RESET" in a:
					var anim = ap.get_animation(a)
					if anim.get_track_count() > 0:
						output += "IDLE TRACK 0 PATH: " + str(anim.track_get_path(0)) + "\n"
					break
		else: output += "NO IDLE AP\n"
	else: output += "NO IDLE SCENE\n"

	var run_scene = load("res://animation/Rifle Run (3).glb")
	if run_scene:
		var node = run_scene.instantiate()
		var ap_list = node.find_children("*", "AnimationPlayer", true, false)
		if ap_list.size() > 0:
			var ap = ap_list[0]
			var anims = ap.get_animation_list()
			for a in anims:
				if not "RESET" in a:
					var anim = ap.get_animation(a)
					if anim.get_track_count() > 0:
						output += "RUN TRACK 0 PATH: " + str(anim.track_get_path(0)) + "\n"
					break
		else: output += "NO RUN AP\n"
	else: output += "NO RUN SCENE\n"
		
	var f = FileAccess.open("res://debug_tracks.txt", FileAccess.WRITE)
	f.store_string(output)
	f.close()
	quit()
