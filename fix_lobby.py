import re

# Fix Lobby.gd title
path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Lobby.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('title_label.text = "DEADSHOT.io"', 'title_label.text = "VELOCITY"')
text = text.replace('title_label.add_theme_font_size_override("font_size", 48)', 'title_label.add_theme_font_size_override("font_size", 56)')
text = text.replace('top_bar.custom_minimum_size.y = 80', 'top_bar.custom_minimum_size.y = 100')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)

# Fix Lobby.tscn Camera3D position so it shows the whole body
tscn_path = r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Lobby.tscn'
with open(tscn_path, 'r', encoding='utf-8') as f:
    tscn = f.read()

tscn = tscn.replace('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 2.5)', 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.0, 3.5)')

with open(tscn_path, 'w', encoding='utf-8') as f:
    f.write(tscn)

print("Lobby fixed")
