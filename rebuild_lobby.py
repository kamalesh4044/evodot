tscn_content = '''[gd_scene load_steps=5 format=3 uid="uid://b4q3p3nwaqqys"]

[ext_resource type="Script" uid="uid://bkfpts1ejh0i6" path="res://Lobby.gd" id="1"]
[ext_resource type="PackedScene" path="res://models/low_poly_soldier.glb" id="2"]
[ext_resource type="PackedScene" path="res://models/ak-74.glb" id="3"]

[sub_resource type="Environment" id="Environment_lobby"]
background_mode = 1
background_color = Color(0.05, 0.05, 0.05, 1)
ambient_light_source = 2
ambient_light_color = Color(0.2, 0.2, 0.2, 1)
tonemap_mode = 2
dof_blur_far_enabled = true
dof_blur_far_distance = 3.0
dof_blur_far_transition = 2.0

[node name="Lobby3D" type="Node3D" unique_id=659062836]
script = ExtResource("1")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_lobby")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, -0.5, -0.612, 0.612, 0, 5, 0)
light_color = Color(0.9, 0.95, 1, 1)
light_energy = 0.8
shadow_enabled = true

[node name="low_poly_soldier" parent="." instance=ExtResource("2")]
transform = Transform3D(-1, 0, -8.74228e-08, 0, 1, 0, 8.74228e-08, 0, -1, 0, 0, 0)

[node name="WeaponPivot" type="Node3D" parent="low_poly_soldier"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.25, 1.1, -0.3)

[node name="ak-74" parent="low_poly_soldier/WeaponPivot" instance=ExtResource("3")]

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 2.5)
fov = 60.0

[node name="CanvasLayer" type="CanvasLayer" parent="."]
'''

with open(r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Lobby.tscn', 'w', encoding='utf-8') as f:
    f.write(tscn_content)
print("Rebuilt Lobby.tscn")
