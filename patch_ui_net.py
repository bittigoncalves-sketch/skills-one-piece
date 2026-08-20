import os

def apply_patch(filepath, old_text, new_text):
    with open(filepath, 'r') as f:
        content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Patched {filepath}")
    else:
        print(f"Did not find text in {filepath}")

# AmmoHud
apply_patch('src/ui/AmmoHud.gd', 
    'if eu == null or not eu.has_method("buki_arma") or not _com_a_fruta(eu):',
    'if not is_instance_valid(eu) or not eu.has_method("buki_arma") or not _com_a_fruta(eu):')

# SkillBar
apply_patch('src/ui/SkillBar.gd',
    'if not player or not ("_skill_cooldowns" in player):',
    'if not is_instance_valid(player) or not ("_skill_cooldowns" in player):')

# SkillSystem
apply_patch('SkillSystem.gd',
    'if t != yami_user and t is Node3D:',
    'if is_instance_valid(t) and t != yami_user and t is Node3D:')

# cast_controller.gd
apply_patch('src/player/cast_controller.gd',
    'func pedir_cast(slot_pedido: String) -> void:\n\tif not _dono._is_authority or _suprimido:\n\t\treturn\n\tif _dono._skill_cooldowns.get(slot_pedido, 0.0) > 0.0:\n\t\treturn',
    'func pedir_cast(slot_pedido: String) -> void:\n\tif not _dono._is_authority or _suprimido:\n\t\t_dono.set_meta("is_casting", false)\n\t\treturn\n\tif _dono._skill_cooldowns.get(slot_pedido, 0.0) > 0.0:\n\t\t_dono.set_meta("is_casting", false)\n\t\treturn')
