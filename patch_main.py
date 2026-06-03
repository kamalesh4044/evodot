path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Main.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

bot_logic = '''
var bots_spawned: bool = false
var bot_scene: PackedScene = preload("res://Bot.tscn")

func _process(delta):
	if multiplayer.is_server():
		var num_players = GameManager.player_data.size()
		if num_players == 1 and not bots_spawned:
			_spawn_bots()
		elif num_players > 1 and bots_spawned:
			_despawn_bots()

func _spawn_bots():
	bots_spawned = true
	# Bake navigation mesh dynamically before spawning bots
	if $Map is NavigationRegion3D:
		$Map.bake_navigation_mesh()
		
	for i in range(4):
		var bot = bot_scene.instantiate()
		bot.position = GameManager.get_spawn_position()
		add_child(bot)

func _despawn_bots():
	bots_spawned = false
	for bot in get_tree().get_nodes_in_group("bots"):
		bot.queue_free()
'''

if 'var bots_spawned' not in text:
    text += bot_logic

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Patched Main.gd with Bot Manager")
