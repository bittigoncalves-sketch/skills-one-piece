import re

def apply_patch(filepath, old_text, new_text):
    with open(filepath, 'r') as f:
        content = f.read()
    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Patched {old_text[:30]}...")
    else:
        print(f"Did not find text: {old_text[:30]}...")

# 1. Duplication of combat_mode
apply_patch('Player.gd', '\nvar combat_mode: String = "fruit"\n', '\n')

# 2. Signals
apply_patch('Player.gd', 'class_name Player\nextends CharacterBody3D\n', 'class_name Player\nextends CharacterBody3D\n\nsignal player_damaged(amount: float, hp: float, mhp: float)\nsignal aim_assist_changed(on: bool)\nsignal combat_mode_updated(mode: String, style_id: String, fruit_id: String)\nsignal anim_name_shown(text: String)\n')

# 3. Physics Gura Rush
apply_patch('Player.gd', 
    '\tpar.collide_with_areas = true\n\tpar.collide_with_bodies = true\n\tif self is CollisionObject3D: par.exclude = [get_rid()]',
    '\tpar.collide_with_areas = true\n\tpar.collide_with_bodies = true\n\tpar.collision_mask = 15\n\tif self is CollisionObject3D: par.exclude = [get_rid()]')

# 4. Combo breaker
apply_patch('Player.gd', 
    '\t\tpar.collide_with_areas = false\n\t\tpar.collide_with_bodies = true\n\t\tif self is CollisionObject3D: par.exclude = [get_rid()]\n\t\t\n\t\tvar hits = espaco.intersect_shape(par)\n\t\tfor h in hits:\n\t\t\tvar col = h.get("collider")\n\t\t\tif col != self and col is Node3D and col.has_method("take_damage"):\n\t\t\t\tvar dir = (col.global_position - pos).normalized()\n\t\t\t\tdir.y = 0.5\n\t\t\t\tcol.take_damage(0.0, pos, dir * 25.0, 0.5)',
    '\t\tpar.collide_with_areas = false\n\t\tpar.collide_with_bodies = true\n\t\tpar.collision_mask = 15\n\t\tif self is CollisionObject3D: par.exclude = [get_rid()]\n\t\t\n\t\tvar hits = espaco.intersect_shape(par)\n\t\tfor h in hits:\n\t\t\tvar col = h.get("collider")\n\t\t\tif col != self and col is Node3D and col.has_method("take_damage"):\n\t\t\t\tvar dir = (col.global_position - pos).normalized()\n\t\t\t\tdir.y = 0.5\n\t\t\t\tcol.take_damage(0.0, pos, dir * 25.0, 0.5)\n\t\t\t\tvar placar = get_tree().get_first_node_in_group("scoreboard")\n\t\t\t\tif placar and placar.has_method("register_hit"):\n\t\t\t\t\tplacar.register_hit(col, self)')

# 5. Respawn clean state
apply_patch('Player.gd',
    '\tset_meta("active_skill", "")\n\tset_meta("yami_black_hole_active", false)\n\tset_meta("yami_kurouzu_active", false)\n\n\t_disparo.parar_rajada()',
    '\tset_meta("active_skill", "")\n\tset_meta("yami_black_hole_active", false)\n\tset_meta("yami_kurouzu_active", false)\n\tset_meta("is_frozen", false)\n\tremove_meta("custom_pose")\n\t_gura_rush_active = false\n\t_gura_grab_timer = 0.0\n\t_gura_rush_timer = 0.0\n\tif is_instance_valid(_gura_rush_target):\n\t\t_gura_rush_target.set_meta("is_frozen", false)\n\t\t_gura_rush_target = null\n\n\t_disparo.parar_rajada()')

# 6. Netcode RPCs Validations
apply_patch('Player.gd',
    '@rpc("any_peer", "reliable")\nfunc _net_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:\n\tif multiplayer.is_server():\n\t\t_do_server_cast(slot, aim, origin, charge)',
    '@rpc("any_peer", "reliable")\nfunc _net_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:\n\tif multiplayer.is_server():\n\t\tvar cid = multiplayer.get_remote_sender_id()\n\t\tif cid != 0 and cid != get_multiplayer_authority(): return\n\t\t_do_server_cast(slot, aim, origin, charge)')

apply_patch('Player.gd',
    '@rpc("any_peer", "call_remote", "reliable")\nfunc _net_melee(passo: int, origem: Vector3, fwd: Vector3) -> void:\n\tif multiplayer.is_server():\n\t\t_do_server_melee(passo, origem, fwd)',
    '@rpc("any_peer", "call_remote", "reliable")\nfunc _net_melee(passo: int, origem: Vector3, fwd: Vector3) -> void:\n\tif multiplayer.is_server():\n\t\tvar cid = multiplayer.get_remote_sender_id()\n\t\tif cid != 0 and cid != get_multiplayer_authority(): return\n\t\t_do_server_melee(passo, origem, fwd)')

apply_patch('Player.gd',
    '@rpc("any_peer", "reliable")\nfunc _net_bullet_req(aim: Vector3, origin: Vector3, arma: String) -> void:\n\tif multiplayer.is_server():\n\t\t_do_server_bullet(aim, origin, arma)',
    '@rpc("any_peer", "reliable")\nfunc _net_bullet_req(aim: Vector3, origin: Vector3, arma: String) -> void:\n\tif multiplayer.is_server():\n\t\tvar cid = multiplayer.get_remote_sender_id()\n\t\tif cid != 0 and cid != get_multiplayer_authority(): return\n\t\t_do_server_bullet(aim, origin, arma)')

apply_patch('Player.gd',
    '@rpc("any_peer", "reliable")\nfunc _net_buki_sacar_req(slot: String) -> void:\n\tif multiplayer.is_server():\n\t\t_do_server_buki_sacar(slot)',
    '@rpc("any_peer", "reliable")\nfunc _net_buki_sacar_req(slot: String) -> void:\n\tif multiplayer.is_server():\n\t\tvar cid = multiplayer.get_remote_sender_id()\n\t\tif cid != 0 and cid != get_multiplayer_authority(): return\n\t\t_do_server_buki_sacar(slot)')

apply_patch('Player.gd',
    '@rpc("any_peer", "reliable")\nfunc _net_buki_guardar_req() -> void:\n\tif multiplayer.is_server():\n\t\t_do_server_buki_guardar()',
    '@rpc("any_peer", "reliable")\nfunc _net_buki_guardar_req() -> void:\n\tif multiplayer.is_server():\n\t\tvar cid = multiplayer.get_remote_sender_id()\n\t\tif cid != 0 and cid != get_multiplayer_authority(): return\n\t\t_do_server_buki_guardar()')

# 7. Netcode Play Validations
apply_patch('Player.gd',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_play_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:\n\t_do_play_cast(slot, aim, origin, charge)',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_play_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:\n\tif multiplayer.has_multiplayer_peer():\n\t\tvar sender = multiplayer.get_remote_sender_id()\n\t\tif sender != 0 and sender != 1: return\n\t_do_play_cast(slot, aim, origin, charge)')

apply_patch('Player.gd',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_play_melee(passo: int) -> void:\n\t_do_play_melee(passo)',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_play_melee(passo: int) -> void:\n\tif multiplayer.has_multiplayer_peer():\n\t\tvar sender = multiplayer.get_remote_sender_id()\n\t\tif sender != 0 and sender != 1: return\n\t_do_play_melee(passo)')

apply_patch('Player.gd',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_bullet_play(aim: Vector3, origin: Vector3, arma: String) -> void:\n\t_do_play_bullet(aim, origin, arma)',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_bullet_play(aim: Vector3, origin: Vector3, arma: String) -> void:\n\tif multiplayer.has_multiplayer_peer():\n\t\tvar sender = multiplayer.get_remote_sender_id()\n\t\tif sender != 0 and sender != 1: return\n\t_do_play_bullet(aim, origin, arma)')

apply_patch('Player.gd',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_buki_sacar(slot: String) -> void:\n\t_do_play_buki_sacar(slot)',
    '@rpc("any_peer", "call_local", "reliable")\nfunc _net_buki_sacar(slot: String) -> void:\n\tif multiplayer.has_multiplayer_peer():\n\t\tvar sender = multiplayer.get_remote_sender_id()\n\t\tif sender != 0 and sender != 1: return\n\t_do_play_buki_sacar(slot)')

apply_patch('Player.gd',
    '\t_vida.vida = nova_vida\n\tif dano > 0.0:\n\t\t_feedback_de_dano(dano)',
    '\t_vida.vida = nova_vida\n\tif dano > 0.0:\n\t\t_feedback_de_dano(dano)\n\t\t_cast.liberar_por_dano()\n\t\tSkillSystem.interrupt_casting(self)')

