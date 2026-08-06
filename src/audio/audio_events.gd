extends Node
# res://scripts/audio/audio_events.gd
# Central de eventos de áudio global
# Usado para comunicar intenções de áudio sem acoplar diretamente os sistemas

# Sinais globais de ambiente e UI
signal play_ui_sound(sound_name: String)
signal play_music(music_name: String)
signal play_ambient(ambient_name: String)

# Eventos futuros previstos
signal attack_started(attacker: Node3D, attack_type: String)
signal attack_released(attacker: Node3D, attack_type: String)
signal dash_started(character: Node3D)
signal roll_started(character: Node3D)
signal fruit_activated(user: Node3D, fruit_name: String)
signal block_started(character: Node3D)
signal damage_received(receiver: Node3D, amount: float)
signal character_death(character: Node3D)
signal climb_started(character: Node3D)
