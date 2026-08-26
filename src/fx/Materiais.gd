class_name Materiais
extends RefCounted
# ============================================================================
#  A FÁBRICA DE MATERIAL — Fase 3 de docs/PLANO_VISUAL.md
#
#  Um lugar só para "de que é feita a superfície deste jogo". Antes disto havia
#  **58 materiais iluminados criados à mão** em 20 arquivos, cada um com a sua
#  rugosidade e o seu jeito — e nenhum ponto onde trocar o estilo de todos.
#
#  ⚠️ NÃO É PARA EFEITO. Os 33 materiais `unshaded` dos golpes continuam onde
#  estão: efeito é auto-iluminado, não recebe banda de luz, e escurecê-lo na
#  sombra seria o defeito que `FxUtil.brilho()` documenta.
#
#  A migração começou pelos FUNIS — as poucas funções por onde passa quase toda
#  a tela:
#    `MapBuilder._gray`               o chão e todos os blocos do mapa
#    `VoxelMeshes.voxel_material`     o corpo dos personagens
#    `TreeAndFruitGenerator._material_tingido`  as árvores
#
#  Quatro funções cobrem mais pixel que os outros 54 sítios somados. O resto
#  migra quando encostar nele, não numa varredura.
# ============================================================================

const CAMINHO_CEL := "res://src/fx/shaders/cel.gdshader"

static var _shader: Shader = null
# Um `ShaderMaterial` por combinação (cor + textura): recriar por objeto
# custaria uma compilação de material a cada bloco do mapa.
static var _cache: Dictionary = {}


static func _cel() -> Shader:
	if _shader == null and ResourceLoader.exists(CAMINHO_CEL):
		_shader = load(CAMINHO_CEL)
	return _shader


## A superfície padrão do jogo: cor chapada com a luz em faixas.
##
## `textura` é opcional — quem tem (a árvore) passa; quem não tem (o chão, os
## blocos, o corpo) fica só com a cor.
static func superficie(cor: Color, textura: Texture2D = null) -> Material:
	var sh := _cel()
	if sh == null:
		# ⚠️ RESERVA. Sem o shader o jogo não pode ficar sem material: um mapa
		# inteiro em rosa-de-material-faltando é pior que sem estilo.
		push_warning("[Materiais] shader ausente: " + CAMINHO_CEL)
		var f := StandardMaterial3D.new()
		f.albedo_color = cor
		f.albedo_texture = textura
		f.roughness = 1.0
		return f

	var chave := "%s|%s" % [cor, textura.get_instance_id() if textura else 0]
	if _cache.has(chave):
		return _cache[chave]

	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("cor", cor)
	if textura != null:
		m.set_shader_parameter("textura", textura)
		m.set_shader_parameter("usar_textura", true)
	_cache[chave] = m
	return m


## Limpa o cache — o respawn do mundo recria tudo, e material de mundo antigo
## segurando textura antiga é vazamento.
static func esquecer() -> void:
	_cache.clear()
