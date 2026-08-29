class_name ChamaLunar
extends RefCounted
# ============================================================================
#  A CHAMA DAS COSTAS DO LUNARIANO — 2D.
#
#  ⚠️ ERA PARTÍCULA, E O DONO PEDIU 2D (2026-08-29). A primeira versão era
#  `GPUParticles3D`: fogo volumétrico, com partículas soltando em profundidade.
#  Ele viu e pediu "faz como se fosse um fogo em 2D nas costas" — e a folha de
#  referência confirma: a chama é uma silhueta chapada subindo pelas costas, do
#  mesmo jeito que o resto do jogo é chapado.
#
#  Agora é UM plano com shader procedural (`chama_lunar.gdshader`). O plano faz
#  o "2D"; o shader faz o fogo se mexer, sem textura nem atlas de quadros para
#  alguém manter.
#
#  O billboard mora no VERTEX do shader, e não em `BaseMaterial3D.billboard_mode`
#  — este material É um `ShaderMaterial`, e aquele campo não vale para ele. É
#  billboard em torno do eixo Y de propósito: a chama roda para encarar a
#  câmera mas continua EM PÉ. Billboard cheio a deitaria junto com a câmera
#  quando o jogador olhasse de cima.
# ============================================================================

const CAMINHO_SHADER := "res://src/fx/shaders/chama_lunar.gdshader"

## Em metros, nas unidades do modelo. Alta o bastante para passar da cabeça,
## como na folha.
# ⚠️ MEDIDA CONTRA O CORPO, não escolhida no olho. Medido: o Torso vai até
# y=2,25 no espaço do modelo e a cabeça até 2,95. Na folha a chama sai do meio
# das costas e sobe BEM acima da cabeça, passando entre as asas — com 1,85 ela
# terminava na altura dos ombros e as asas a engoliam.
const LARGURA := 1.10
const ALTURA := 2.45


static func criar(escala: float = 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(LARGURA * escala, ALTURA * escala)
	# A origem vai para a BASE da chama: ancorada pelo pé nas costas, cresce
	# para cima. Centrada, metade dela ficaria enterrada no tronco.
	quad.center_offset = Vector3(0.0, ALTURA * escala * 0.5, 0.0)
	m.mesh = quad

	var sh: Shader = load(CAMINHO_SHADER)
	if sh == null:
		push_warning("[ChamaLunar] shader ausente: " + CAMINHO_SHADER)
		return m
	var mat := ShaderMaterial.new()
	mat.shader = sh
	m.material_override = mat
	# Fogo não projeta nem recebe sombra — e o `unshaded` do shader já diz isso
	# para a luz; isto tira o custo de a malha entrar no passe de sombra.
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m
