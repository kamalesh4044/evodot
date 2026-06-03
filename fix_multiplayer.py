import re

# 1. Add MultiplayerSpawner to Main.tscn
main_tscn = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Main.tscn'
with open(main_tscn, 'r', encoding='utf-8') as f:
    main_data = f.read()

if 'MultiplayerSpawner' not in main_data:
    # Add Player.tscn and Bot.tscn to spawnable scenes
    main_data = main_data.replace(
        '[node name="Players" type="Node3D" parent="." unique_id=434712245]',
        '''[node name="Players" type="Node3D" parent="." unique_id=434712245]

[node name="MultiplayerSpawner" type="MultiplayerSpawner" parent="." unique_id=50000001]
_spawnable_scenes = PackedStringArray("res://Player.tscn", "res://Bot.tscn")
spawn_path = NodePath("../Players")
'''
    )
    with open(main_tscn, 'w', encoding='utf-8') as f:
        f.write(main_data)


# 2. Add SceneReplicationConfig to Player.tscn
player_tscn = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.tscn'
with open(player_tscn, 'r', encoding='utf-8') as f:
    player_data = f.read()

if 'SceneReplicationConfig' not in player_data:
    replication_resource = '''[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_player"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath("CameraPivot:rotation")
properties/2/spawn = true
properties/2/replication_mode = 1
properties/3/path = NodePath(".:current_weapon_index")
properties/3/spawn = true
properties/3/replication_mode = 2
'''
    # Insert SubResource at the top after ext_resources
    player_data = player_data.replace(
        '[sub_resource type="CapsuleShape3D"', 
        replication_resource + '\n[sub_resource type="CapsuleShape3D"'
    )
    
    # Link it to the MultiplayerSynchronizer
    player_data = player_data.replace(
        '[node name="MultiplayerSynchronizer" type="MultiplayerSynchronizer" parent="." unique_id=1957972390]',
        '[node name="MultiplayerSynchronizer" type="MultiplayerSynchronizer" parent="." unique_id=1957972390]\nreplication_config = SubResource("SceneReplicationConfig_player")'
    )
    
    with open(player_tscn, 'w', encoding='utf-8') as f:
        f.write(player_data)


# 3. Add SceneReplicationConfig to Bot.tscn
bot_tscn = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Bot.tscn'
with open(bot_tscn, 'r', encoding='utf-8') as f:
    bot_data = f.read()

if 'SceneReplicationConfig' not in bot_data:
    bot_replication = '''[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_bot"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1
'''
    bot_data = bot_data.replace(
        '[sub_resource type="CapsuleShape3D"', 
        bot_replication + '\n[sub_resource type="CapsuleShape3D"'
    )
    
    # Add a MultiplayerSynchronizer node to Bot.tscn
    if 'MultiplayerSynchronizer' not in bot_data:
        bot_data += '''
[node name="MultiplayerSynchronizer" type="MultiplayerSynchronizer" parent="." unique_id=50000002]
replication_config = SubResource("SceneReplicationConfig_bot")
'''
    with open(bot_tscn, 'w', encoding='utf-8') as f:
        f.write(bot_data)

print("Multiplayer fixed")
