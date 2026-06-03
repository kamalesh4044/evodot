import re

def adjust_tp_pivot(tscn_path):
    with open(tscn_path, 'r', encoding='utf-8') as f:
        tscn = f.read()

    # Old transform in TPWeaponPivot
    old_transform = 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.25, 1.1, -0.3)'
    # New transform: Positioned at right hand in A-pose.
    # Soldier is rotated 180 degrees, so local right is -X, local forward is +Z.
    # We want it to be held in the right hand (x = -0.35), height (y = 0.8), slightly forward (z = 0.2).
    # And we rotate it around X by 90 degrees to make it point forward (or maybe Y by 90).
    # Actually, in the screenshot, the gun is pointing to the character's right (which is global -X).
    # Let's apply a rotation to point it forward. 
    # Godot Transform3D with rotation: we'll use Euler angles in Godot. It's easier to just inject the rotation in Godot format.
    # Wait, Godot 4 uses Basis for Transform3D.
    # Let's just use Euler rotation in GDScript in _ready() for exact tuning if needed, 
    # but for the TSCN, we can write the Basis matrix.
    # Or, we can just edit the position and let the user tweak it, but it's better if we fix it.
    
    # Rotation of 90 degrees around Y:
    # cos(90) = 0, sin(90) = 1
    # Matrix:
    # 0, 0, -1
    # 0, 1, 0
    # 1, 0, 0
    # Wait, if we want it to point local +Z, and it currently points to... wait, in the screenshot, the gun is pointing to the character's right.
    # Let's just do a 90 degree Y rotation, and point the barrel down slightly.
    
    # Actually, instead of guessing the matrix, I will just patch Bot.tscn and Player.tscn to have the pivot in the hand and I will set rotation in code in Player._ready and Bot._ready. No, it's better to just do it in the TSCN.
    # Let's use a Godot script to run and save the scenes with the correct transforms!
    pass

# We will write a GDScript to fix the transforms and run it in headless mode.
gd_script = """extends SceneTree

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
"""

with open(r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\fix_transforms.gd', 'w', encoding='utf-8') as f:
    f.write(gd_script)
