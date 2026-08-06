extends Node
# res://scripts/audio/sound_library.gd
# Registro centralizado de todos os sons do jogo para evitar "magic strings" e caminhos hardcoded.

# Estrutura preparada para receber novos sons, materiais, frutas, ataques, etc.
var _sounds: Dictionary = {
	"footsteps": {
		"grass": [
			"res://assets/audio/footsteps/grass/step_01.wav",
			"res://assets/audio/footsteps/grass/step_02.wav"
		],
		"dirt": [],
		"stone": [],
		"wood": [],
		"sand": [],
		"metal": [],
		"ice": [],
		"water": []
	},
	"movement": {
		"jump": [
			"res://assets/audio/movement/jump.wav"
		],
		"land": [
			"res://assets/audio/movement/land.wav"
		],
		"run_cloth": [] # Exemplo de som de roupa balançando ao correr
	},
	"combat": {},
	"fruits": {},
	"ui": {},
	"ambience": {}
}

var _loaded_streams: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# Retorna uma stream de áudio aleatória dentre as variações de um determinado som
func get_sound_variation(category: String, sound_name: String) -> AudioStream:
	if not _sounds.has(category) or typeof(_sounds[category]) != TYPE_DICTIONARY:
		push_warning("SoundLibrary: Categoria não encontrada -> %s" % category)
		return null
		
	var category_dict = _sounds[category]
	if not category_dict.has(sound_name):
		push_warning("SoundLibrary: Som não encontrado -> %s / %s" % [category, sound_name])
		return null
		
	var variations: Array = category_dict[sound_name]
	if variations.is_empty():
		# Retorna null silenciosamente caso a variação exista na biblioteca mas esteja sem sons mapeados (em desenvolvimento)
		return null
		
	var choice = variations[rng.randi() % variations.size()]
	
	if not _loaded_streams.has(choice):
		var stream = load(choice) as AudioStream
		if stream:
			_loaded_streams[choice] = stream
		else:
			push_warning("SoundLibrary: Falha ao carregar áudio no caminho -> %s" % choice)
			return null
			
	return _loaded_streams[choice]
