import re

path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Bot.tscn'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

ext_resources = '''[ext_resource type="Script" path="res://Bot.gd" id="1"]
[ext_resource type="PackedScene" path="res://models/low_poly_soldier.glb" id="3"]
[ext_resource type="PackedScene" path="res://models/ak-74.glb" id="4"]'''
text = text.replace('[ext_resource type="Script" path="res://Bot.gd" id="1"]', ext_resources)

old_mesh = '''[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
mesh = SubResource("CapsuleMesh_bot")
surface_material_override/0 = SubResource("StandardMaterial3D_bot")'''

new_mesh = '''[node name="low_poly_soldier" parent="." instance=ExtResource("3")]
transform = Transform3D(-1, 0, -8.74228e-08, 0, 1, 0, 8.74228e-08, 0, -1, 0, 0, 0)

[node name="WeaponPivot" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.25, 1.25, -0.4)

[node name="ak-74" parent="WeaponPivot" instance=ExtResource("4")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.2, 0)

[node name="MuzzleFlash" type="OmniLight3D" parent="WeaponPivot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.2, -0.5)
visible = false
light_color = Color(1, 0.8, 0.2, 1)
light_energy = 5.0
shadow_enabled = true
omni_range = 10.0'''

text = text.replace(old_mesh, new_mesh)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Patched Bot.tscn")
