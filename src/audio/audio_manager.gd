extends Node
# res://scripts/audio/audio_manager.gd
# Gerenciador global de áudio, responsável pelo pooling de AudioStreamPlayer3D

const POOL_SIZE_3D: int = 64 # Quantidade de players espaciais reutilizáveis
var _pool_3d: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	# Inicialização do Pool
	for i in range(POOL_SIZE_3D):
		var player := AudioStreamPlayer3D.new()
		add_child(player)
		_pool_3d.append(player)

# Busca um player disponível no pool
func _get_available_player_3d() -> AudioStreamPlayer3D:
	for player in _pool_3d:
		if not player.playing:
			return player
			
	# Fallback caso o pool esteja cheio (rouba o primeiro, que geralmente é o mais antigo)
	var stolen = _pool_3d[0]
	stolen.stop()
	return stolen

# Toca um som espacializado usando o pool, com randomização opcional de pitch e volume
func play_3d(category: String, sound_name: String, position: Vector3, params: Dictionary = {}) -> void:
	var stream = SoundLibrary.get_sound_variation(category, sound_name)
	if not stream:
		return
		
	var player = _get_available_player_3d()
	player.stream = stream
	player.global_position = position
	
	# Parâmetros base e randomização
	var base_pitch: float = params.get("pitch_scale", 1.0)
	var pitch_rand: float = params.get("pitch_rand", 0.0)
	var rng = SoundLibrary.rng
	player.pitch_scale = base_pitch + rng.randf_range(-pitch_rand, pitch_rand)
	
	var base_vol: float = params.get("volume_db", 0.0)
	var vol_rand: float = params.get("vol_rand", 0.0)
	player.volume_db = base_vol + rng.randf_range(-vol_rand, vol_rand)
	
	# Parâmetros espaciais
	player.max_distance = params.get("max_distance", 20.0)
	player.unit_size = params.get("unit_size", 1.0)
	
	player.play()
