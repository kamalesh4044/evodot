path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Main.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

pickup_logic = '''
var pickup_scene: PackedScene = preload("res://Pickup.tscn")

func _spawn_pickups():
	for i in range(5):
		var p = pickup_scene.instantiate()
		p.position = GameManager.get_spawn_position() + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		p.pickup_type = randi() % 2
		add_child(p)
'''

if 'var pickup_scene' not in text:
    text += pickup_logic
    
text = text.replace('func _ready():\n\t_setup_map()', 'func _ready():\n\t_setup_map()\n\tif multiplayer.is_server():\n\t\t_spawn_pickups()')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Patched Main.gd with Pickups")
