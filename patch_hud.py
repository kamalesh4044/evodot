import re

path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\HUD.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Update Health Bar to bottom left HP
old_health = '''func _build_health_bar():
	var hb_bg = ColorRect.new()
	hb_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	hb_bg.custom_minimum_size = Vector2(250, 30)
	hb_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hb_bg.position = Vector2(30, -60)
	add_child(hb_bg)

	health_bar = ProgressBar.new()
	health_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_bar.show_percentage = false
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0, 0, 0, 0.5)
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.1, 0.8, 0.2, 1.0)
	health_bar.add_theme_stylebox_override("background", style_bg)
	health_bar.add_theme_stylebox_override("fill", style_fg)
	health_bar.max_value = 100
	health_bar.value = 100
	hb_bg.add_child(health_bar)

	health_label = Label.new()
	health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_label.text = "100"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 20)
	hb_bg.add_child(health_label)'''

new_health = '''func _build_health_bar():
	var hb_bg = HBoxContainer.new()
	hb_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hb_bg.position = Vector2(50, -80)
	hb_bg.add_theme_constant_override("separation", 15)
	add_child(hb_bg)
	
	var cross_rect = ColorRect.new()
	cross_rect.color = Color(0.4, 0.8, 0.4)
	cross_rect.custom_minimum_size = Vector2(30, 30)
	hb_bg.add_child(cross_rect) # Simplified cross icon

	health_label = Label.new()
	health_label.text = "100 HP"
	health_label.add_theme_font_size_override("font_size", 42)
	health_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hb_bg.add_child(health_label)'''

text = text.replace(old_health, new_health)

# Update Ammo display to bottom right
old_ammo = '''func _build_ammo_display():
	var ammo_bg = ColorRect.new()
	ammo_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	ammo_bg.custom_minimum_size = Vector2(200, 70)
	ammo_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_bg.position = Vector2(-230, -100)
	add_child(ammo_bg)

	ammo_label = Label.new()
	ammo_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ammo_label.text = "Ammo\\n30 / 90"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ammo_label.add_theme_font_size_override("font_size", 24)
	ammo_bg.add_child(ammo_label)'''

new_ammo = '''func _build_ammo_display():
	var ammo_bg = VBoxContainer.new()
	ammo_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_bg.position = Vector2(-200, -120)
	ammo_bg.alignment = BoxContainer.ALIGNMENT_END
	add_child(ammo_bg)

	var w_label = Label.new()
	w_label.text = "Assault Rifle"
	w_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	w_label.add_theme_font_size_override("font_size", 24)
	w_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ammo_bg.add_child(w_label)

	ammo_label = Label.new()
	ammo_label.text = "30 / 30"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 48)
	ammo_label.add_theme_color_override("font_color", Color(1, 1, 1))
	ammo_bg.add_child(ammo_label)'''

text = text.replace(old_ammo, new_ammo)

# Update update_hud to match new layout
old_update = '''func update_hud(health: float, ammo: int, max_ammo: int, reserve: int, weapon_name: String):
	if health_bar: health_bar.value = health
	if health_label: health_label.text = str(ceil(health))
	if ammo_label: ammo_label.text = "%s\\n%d / %d" % [weapon_name, ammo, reserve]'''

new_update = '''func update_hud(health: float, ammo: int, max_ammo: int, reserve: int, weapon_name: String):
	if health_label: health_label.text = "%d HP" % ceil(health)
	if ammo_label: 
		var w_node = ammo_label.get_parent().get_child(0)
		w_node.text = weapon_name
		ammo_label.text = "%d / %d" % [ammo, reserve]'''

text = text.replace(old_update, new_update)

# Make crosshair invisible during ADS. 
# We'll just provide a function Player.gd can call.
if 'func set_crosshair_visible(vis: bool):' not in text:
    text += '''
func set_crosshair_visible(vis: bool):
	if crosshair_container:
		crosshair_container.visible = vis
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print("HUD patched")
