import re

def sanitize_tscn(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Fix TPWeaponPivot rotation
    # Match [node name="TPWeaponPivot" ...]\ntransform = Transform3D(...)
    content = re.sub(
        r'(\[node name="TPWeaponPivot"[^\]]*\]\n)transform = Transform3D\([^)]+\)',
        r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.35, 0.85, 0.25)',
        content
    )
    
    # Strip transforms from weapons under TPWeaponPivot
    # We will look for [node name="ak-74" parent="...TPWeaponPivot"...]
    # and remove any following transform lines
    for weapon in ['ak-74', 'thompson', 'shotgun']:
        pattern = r'(\[node name="' + weapon + r'" parent="[^"]*TPWeaponPivot"[^\]]*\]\n(?:visible = false\n)?)transform = Transform3D\([^)]+\)\n'
        content = re.sub(pattern, r'\1', content)
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
        
sanitize_tscn(r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Player.tscn')
sanitize_tscn(r'C:\Users\kamal\OneDrive\Desktop\code\godot-fps\Bot.tscn')
print("Sanitized transforms.")
