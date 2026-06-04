extends SceneTree
func _initialize():
	var output = ""
	var scene = load("res://models/Rifle Idle (2).glb")
	if scene:
		var node = scene.instantiate()
		var ap_list = node.find_children("*", "AnimationPlayer", true, false)
		if ap_list.size() > 0:
			output += "IDLE ANIMATIONS: " + str(ap_list[0].get_animation_list()) + "\n"
		else:
			output += "IDLE: NO ANIMATION PLAYER\n"
	else:
		output += "IDLE SCENE LOAD FAILED\n"
		
	var run_scene = load("res://models/Rifle Run.glb")
	if run_scene:
		var node = run_scene.instantiate()
		var ap_list = node.find_children("*", "AnimationPlayer", true, false)
		if ap_list.size() > 0:
			output += "RUN ANIMATIONS: " + str(ap_list[0].get_animation_list()) + "\n"
		else:
			output += "RUN: NO ANIMATION PLAYER\n"
	else:
		output += "RUN SCENE LOAD FAILED\n"
		
	var file = FileAccess.open("res://anim_debug.txt", FileAccess.WRITE)
	file.store_string(output)
	file.close()
	quit()
