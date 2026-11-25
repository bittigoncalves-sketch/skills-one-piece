class_name BocaFalante
extends Node3D
# ============================================================================
#  BOCA FALANTE (22/11/2026, pedido do dono: "alteração da textura da boca para imitar fala humana") — um quadro fino colado na FRENTE (−Z) da cabeça do personagem; enquanto ele
#  fala, a textura troca entre três visemas — FECHADA, MEIA e ABERTA — a ~8 Hz num padrão não periódico (fala humana não é metrônomo); ao parar, fecha. Serve a qualquer modelo em caixas
#  (vendedor, Alvida, Buggy…): o tamanho e o lugar saem do AABB da malha da cabeça (nó `head`), nada fixo por personagem.
#  Arte: as três texturas são desenhadas por código (pixel-art 12×6, filtro "nearest"); se existirem `res://assets/textures/bocas_falantes/boca_{fechada,meia,aberta}.png` (do Codex),
#  elas valem no lugar. GATILHO: boca diferente por personagem → pasta por id.
# ============================================================================
const PASTA := "res://assets/textures/bocas_falantes/"
const VISEMAS := ["fechada", "meia", "aberta"]
const HZ := 8.0
## Ordem dos visemas enquanto fala (índices de VISEMAS): variada, abre mais do que fecha, volta a fechar de vez em quando (as "consoantes").
const PADRAO := [2, 1, 2, 0, 1, 2, 2, 1, 0, 2, 1, 1, 2, 0, 1, 2]
const COR_LABIO := Color(0.50, 0.14, 0.12)
const COR_INTERIOR := Color(0.14, 0.03, 0.04)
const COR_LINGUA := Color(0.86, 0.34, 0.38)

static var _texturas: Dictionary = {}

var cabeca: Node3D
var _quadro: MeshInstance3D
var _falando := false
var _relogio := 0.0
var boca_pintada := false      # a textura do personagem já traz a boca: o quadro só aparece falando
var visema := 0           # índice atual em VISEMAS (a leitura que os testes e a cena usam)


## Cola a boca na cabeça de `modelo` (nó chamado `head`). Devolve null (e não faz nada) se o modelo não tem cabeça com malha.
static func de(modelo: Node) -> BocaFalante:
	var cab := modelo.find_child("head", true, false) as Node3D           # modelos `mp_*`
	if cab == null:
		cab = modelo.find_child("Head", true, false) as Node3D           # corpo em caixas da campanha (`corpo_historia.gd`)
	if cab == null:
		return null
	var caixa := _caixa_da_cabeca(cab)
	if not caixa.has_volume():
		return null
	var b := BocaFalante.new()
	b.name = "BocaFalante"
	b.cabeca = cab
	cab.add_child(b)
	b._montar(caixa)
	return b


## AABB (no espaço local da cabeça) do ROSTO: a caixa "Cabeca" do corpo da campanha (sem cabelo/chapéu, que são filhos dela) ou, nos `mp_*`, as malhas da cabeça menos a armadura (`armor*`).
static func _caixa_da_cabeca(cab: Node3D) -> AABB:
	var alvo: Array[MeshInstance3D] = []
	var so_a_caixa := cab.find_child("Cabeca", true, false) as MeshInstance3D
	if so_a_caixa != null:
		alvo.append(so_a_caixa)
	else:
		var candidatos: Array = cab.find_children("*", "MeshInstance3D", true, false)
		if cab is MeshInstance3D:
			candidatos.append(cab)                         # nos `mp_*` o próprio nó "head" costuma ser a malha
		for mi in candidatos:
			var m := mi as MeshInstance3D
			if m.mesh != null and not str(m.name).begins_with("armor") and not str(m.get_parent().name).begins_with("armor"):
				alvo.append(m)
	var caixa := AABB()
	var primeiro := true
	var inv := cab.global_transform.affine_inverse()
	for m in alvo:
		if m.mesh == null:
			continue
		var a: AABB = (inv * m.global_transform) * m.mesh.get_aabb()
		caixa = a if primeiro else caixa.merge(a)
		primeiro = false
	return caixa


func _montar(caixa: AABB) -> void:
	var largura := caixa.size.x * 0.36
	var altura := largura * 0.5
	_quadro = MeshInstance3D.new()
	_quadro.name = "Quadro"
	var q := QuadMesh.new()
	q.size = Vector2(largura, altura)
	_quadro.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_quadro.material_override = mat
	# frente da cabeça = −Z; o quadro (que olha para +Z) gira meia volta e fica 4 mm à frente do rosto, no terço de baixo
	_quadro.rotation.y = PI
	# z: a face MAIS À FRENTE entre a cabeça e a sobreposição de cabelo/chapéu (`armor*`, ligeiramente maior): sem isso o quadro ficaria escondido DENTRO dela
	_quadro.position = Vector3(caixa.get_center().x, caixa.position.y + caixa.size.y * 0.17, minf(caixa.position.z, _frente_com_sobreposicao(cabeca)) - 0.006)
	add_child(_quadro)
	_aplicar(0)


static func _frente_com_sobreposicao(cab: Node3D) -> float:
	var frente := INF
	var inv := cab.global_transform.affine_inverse()
	for mi in cab.find_children("*", "MeshInstance3D", true, false) + ([cab] if cab is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		if m.mesh != null and not str(m.name) in ["BocaFalante", "Quadro"]:
			frente = minf(frente, ((inv * m.global_transform) * m.mesh.get_aabb()).position.z)
	return frente


func usar_boca_pintada() -> void:
	boca_pintada = true
	if _quadro != null:
		_quadro.visible = _falando


func falar(sim: bool) -> void:
	if sim == _falando:
		return
	_falando = sim
	_relogio = 0.0
	_aplicar(1 if sim else 0)
	if _quadro != null:
		_quadro.visible = sim or not boca_pintada      # quem tem boca PINTADA no rosto (a Alvida) só mostra o quadro ao falar; os demais mantêm o traço fechado


func falando() -> bool:
	return _falando


func _process(delta: float) -> void:
	if not _falando:
		return
	_relogio += delta
	_aplicar(PADRAO[int(_relogio * HZ) % PADRAO.size()])


func _aplicar(i: int) -> void:
	visema = i
	if _quadro != null:
		(_quadro.material_override as StandardMaterial3D).albedo_texture = textura(VISEMAS[i])


## A textura de um visema: a arte do Codex se existir, senão a pixel-art por código (cache estático).
static func textura(nome: String) -> Texture2D:
	if _texturas.has(nome):
		return _texturas[nome]
	var t: Texture2D = null
	var caminho := PASTA + "boca_%s.png" % nome
	if ResourceLoader.exists(caminho):
		t = load(caminho) as Texture2D
	if t == null:
		t = ImageTexture.create_from_image(_desenhar(nome))
	_texturas[nome] = t
	return t


## 12×6 px. Fechada: um traço; meia: abertura de 2 linhas; aberta: 4 linhas com a língua no fundo. Fora do desenho, alfa 0 (recortado).
static func _desenhar(nome: String) -> Image:
	var img := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var linhas := 1 if nome == "fechada" else (2 if nome == "meia" else 4)
	var x0 := 2 if nome != "aberta" else 3
	var x1 := 9 if nome != "aberta" else 8
	var y0 := 3 - linhas / 2
	for y in range(y0, y0 + linhas):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, COR_INTERIOR if nome != "fechada" else COR_LABIO)
	if nome != "fechada":                     # lábios: contorno de cima e de baixo
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y0 - 1 if y0 > 0 else y0, COR_LABIO)
			img.set_pixel(x, mini(y0 + linhas, 5), COR_LABIO)
	if nome == "aberta":
		for x in range(4, 8):
			img.set_pixel(x, y0 + linhas - 1, COR_LINGUA)
	return img
