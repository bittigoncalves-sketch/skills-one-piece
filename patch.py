import re

with open('src/player/cast_controller.gd', 'r') as f:
    content = f.read()

patch = """	if not _dono._is_authority or _suprimido:
		_dono.set_meta("is_casting", false)
		return
	if _dono.combat_mode == "fruit":
		var fid = _dono.current_fruit_id
		if fid == "" or fid == "sem_fruta":
			_dono.set_meta("is_casting", false)
			return"""

content = content.replace("""	if not _dono._is_authority or _suprimido:
		_dono.set_meta("is_casting", false)
		return""", patch)

with open('src/player/cast_controller.gd', 'w') as f:
    f.write(content)
