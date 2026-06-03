import re

path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.tscn'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Add ext_resource tags at the top
ext_resources = '''[ext_resource type="Script" uid="uid://dy54kajtxxpo" path="res://Player.gd" id="1"]
[ext_resource type="Script" uid="uid://pae17o41ubv2" path="res://HUD.gd" id="2"]
[ext_resource type="PackedScene" path="res://models/low_poly_soldier.glb" id="3"]
[ext_resource type="PackedScene" path="res://models/ak-74.glb" id="4"]
[ext_resource type="PackedScene" path="res://models/thompson.glb" id="5"]
[ext_resource type="PackedScene" path="res://models/shotgun.glb" id="6"]'''
text = re.sub(r'\[ext_resource.*?id="1"\]\n\[ext_resource.*?id="2"\]', ext_resources, text)

# Replace MeshCore
old_mesh_core = '''[node name="MeshCore" type="Node3D" parent="." unique_id=135583648]

[node name="BodyMesh" type="MeshInstance3D" parent="MeshCore" unique_id=1532550124]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)
mesh = SubResource("CapsuleMesh_body")
surface_material_override/0 = SubResource("BodyMaterial")'''

new_mesh_core = '''[node name="MeshCore" type="Node3D" parent="." unique_id=135583648]

[node name="low_poly_soldier" parent="MeshCore" unique_id=1532550124 instance=ExtResource("3")]
transform = Transform3D(-1, 0, -8.74228e-08, 0, 1, 0, 8.74228e-08, 0, -1, 0, 0, 0)'''

text = text.replace(old_mesh_core, new_mesh_core)

# Replace GunMesh
old_gun_mesh = '''[node name="WeaponPivot" type="Node3D" parent="CameraPivot" unique_id=2104671614]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.25, -0.15, -0.4)

[node name="GunMesh" type="MeshInstance3D" parent="CameraPivot/WeaponPivot" unique_id=1898479620]
mesh = SubResource("BoxMesh_gun")
surface_material_override/0 = SubResource("GunMaterial")'''

new_gun_mesh = '''[node name="WeaponPivot" type="Node3D" parent="CameraPivot" unique_id=2104671614]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.25, -0.25, -0.4)

[node name="ak-74" parent="CameraPivot/WeaponPivot" unique_id=1898479620 instance=ExtResource("4")]
visible = false

[node name="thompson" parent="CameraPivot/WeaponPivot" unique_id=1898479621 instance=ExtResource("5")]
visible = false

[node name="shotgun" parent="CameraPivot/WeaponPivot" unique_id=1898479622 instance=ExtResource("6")]
visible = false

[node name="MuzzleFlash" type="OmniLight3D" parent="CameraPivot/WeaponPivot" unique_id=1898479623]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.5)
visible = false
light_color = Color(1, 0.8, 0.2, 1)
light_energy = 5.0
shadow_enabled = true
omni_range = 10.0'''

text = text.replace(old_gun_mesh, new_gun_mesh)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("Patched Player.tscn")
