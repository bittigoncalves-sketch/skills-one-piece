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


## LUZ PRÓPRIA. Para a peça que É uma fonte de luz na arte, não um objeto
## iluminado — hoje só a auréola do menu de Customização.
##
## ⚠️ NÃO É `superficie()` COM A COR MAIS CLARA. O cel shading escurece o que
## está na sombra, e a graça da auréola é justamente não obedecer à luz da cena:
## um anel amarelo chapado, escurecendo do lado oposto ao sol, lê como aro de
## plástico. `unshaded` + `emission` é o que faz o desenho da folha 2D — o anel
## como fonte, e não como refletor.
##
## Fica aqui, e não solto no catálogo, porque material é assunto de Materiais:
## era assim que as cinco cópias da base da câmera nasceram, cada uma num
## arquivo, até uma sair negada.
static func brilho(cor: Color) -> Material:
	var chave := "brilho|%s" % cor
	if _cache.has(chave):
		return _cache[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = 1.6
	_cache[chave] = m
	return m


## O CHÃO. É a superfície com a grade do mapa desenhada — ver a nota da grade
## em `cel.gdshader`. `celula` vem do `MapBuilder`, para a linha cair onde a
## célula de verdade acaba.
static func chao(cor: Color, celula: float) -> Material:
	var m := superficie(cor)
	if m is ShaderMaterial:
		# ⚠️ CÓPIA, não o material do cache. `superficie()` memoriza por cor, e
		# ligar a grade no objeto memorizado ligaria a grade em TUDO que
		# usasse a mesma cor — inclusive num bloco.
		var g := (m as ShaderMaterial).duplicate() as ShaderMaterial
		g.set_shader_parameter("usar_grade", true)
		g.set_shader_parameter("grade_celula", celula)
		g.set_shader_parameter("usar_variacao_chao", true)
		g.set_shader_parameter("variacao_escala", 12.0)
		g.set_shader_parameter("variacao_forca", 0.055)
		return g
	return m

## Famílias da arena. Os nomes carregam a intenção de arte; o cel shader mantém
## a mesma luz em faixas para que pedra, bloco e borda pertençam ao mesmo mundo.
static func pedra_gasta(cor: Color) -> Material:
	var m := superficie(cor)
	if m is ShaderMaterial:
		# Cópia: o material base é cacheado por cor. A variação é exclusiva da
		# família de pedra, nunca deve infiltrar em personagens da mesma cor.
		var pedra := (m as ShaderMaterial).duplicate() as ShaderMaterial
		pedra.set_shader_parameter("usar_variacao_pedra", true)
		pedra.set_shader_parameter("variacao_pedra_escala", 4.5)
		pedra.set_shader_parameter("variacao_pedra_forca", 0.028)
		return pedra
	return m

static func borda_abismo() -> Material:
	return superficie(Color(0.15, 0.20, 0.28))


## Limpa o cache — o respawn do mundo recria tudo, e material de mundo antigo
## segurando textura antiga é vazamento.
static func esquecer() -> void:
	_cache.clear()
