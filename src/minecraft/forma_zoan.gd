class_name FormaZoan
extends Node3D
## FORMA ZOAN DO JOGADOR (09/11/2026, "frutas zoan não estão transformando"): a tecla J já mudava o atributo `minepiece:form` do mod,
## mas nada desenhava a forma. No mod quem desenha é o `KleidersRenderEventProcedure` (esconde o corpo e desenha as classes
## `Model*_humanbeast`); `tools/mine_piece/extrair_formas_zoan.py` extrai isso para `mapas/east_blue/formas_zoan.json` e este nó monta as
## peças (as mesmas caixas/UV do mod) e as faz SEGUIR as juntas do corpo do jogador — o rig do jogo é uma árvore de nós sem Skeleton3D,
## então cada peça de topo (Head, Body, braços, pernas) copia a rotação da sua junta; extras (cauda, asas, chifres) vão com o pai.
##
## Limites conhecidos (docs/FORMAS_ZOAN.md): braço/perna rígidos, exceto o Buda autoral articulado; só a forma 1
## (o mod só tem 0↔1 fora do Kaidou); variantes `_fly`/`_slim` fora; só o dono vê (a forma é atributo do servidor, não replicada).

const ARQUIVO := "res://mapas/east_blue/formas_zoan.json"
const CORPO := ["Head", "Body", "RightArm", "LeftArm", "RightLeg", "LeftLeg"]
## Peça do modelo do mod → junta do rig do jogador que a move. O que não é CORPO segue "Body".
const JUNTAS := {"Head": "Neck", "Body": "Chest", "RightArm": "UpperArm_R", "LeftArm": "UpperArm_L", "RightLeg": "Thigh_R", "LeftLeg": "Thigh_L"}
## O modelo do mod é desenhado a 0,9375 (`poseStack.scale` do evento) e tem o pivô a 24 px do chão.
const ESCALA_DO_MOD := 0.9375
const PIVO_PX := 24.0
const META_ATIVA := "forma_zoan_ativa"
const BUDA_MODELO := "res://assets/models/buda/buda_transformacao.tscn"
const BUDA_JUNTAS := {
	"RightForeArm": "ForeArm_R", "LeftForeArm": "ForeArm_L",
	"RightShin": "Shin_R", "LeftShin": "Shin_L",
	"RightFoot": "Foot_R", "LeftFoot": "Foot_L",
}

static var _dados: Dictionary = {}

var _ator: Node3D
var _juntas: Dictionary = {}          # nome da peça de topo → Node3D (junta do jogador)
var _topo: Dictionary = {}            # nome da peça de topo → Node3D (peça da forma)
var _base: Dictionary = {}            # nome da peça de topo → Basis de repouso
var _k := 0.0
var _buda_autoral := false
var peso_flor := 0.0
var pos_seguir: Callable          # gancho (Ushi Ushi): corrige a pose depois de copiar as juntas — recebe esta forma
var _posicoes_buda := {}
var _diamante: ShaderMaterial
var _materiais_anteriores := {}


static func dados() -> Dictionary:
	if _dados.is_empty():
		var f := FileAccess.open(ARQUIVO, FileAccess.READ)
		_dados = JSON.parse_string(f.get_as_text()) if f != null else {}
	return _dados


static func tem(fruta: String) -> bool:
	return dados().has(fruta)


## A forma esconde o corpo do jogador? Só quando algum modelo traz caixas no corpo (o Batto Batto só acrescenta asas).
static func substitui_corpo(fruta: String) -> bool:
	# Kira Kira usa Modeloverlay: o PNG é transparente e deve ser desenhado
	# sobre a skin do jogador, como no renderer do mod, não no lugar dela.
	if fruta == "kira_kira":
		return false
	for camada: Dictionary in dados().get(fruta, []):
		var pai_do_topo := _pai_de_topo(camada)
		for p: Dictionary in camada.partes:
			if not (p.caixas as Array).is_empty() and CORPO.has(pai_do_topo.get(p.nome, p.nome)):
				return true
	return false


## nome da peça → nome da peça de topo (filha da raiz) de onde ela desce.
static func _pai_de_topo(camada: Dictionary) -> Dictionary:
	var topo := {}
	for p: Dictionary in camada.partes:
		topo[p.nome] = p.nome if str(p.pai) == "" else topo.get(p.pai, p.pai)
	return topo


## Liga (forma > 0) ou desliga a forma no jogador. Idempotente.
static func aplicar(ator: Node3D, fruta: String, forma: int) -> void:
	if not is_instance_valid(ator):
		return
	var atual := ator.get_node_or_null("FormaZoan")
	if atual != null:
		if atual is FormaZoan:
			(atual as FormaZoan)._desvestir_diamante()
		# Também é chamado do _exit_tree do controlador, com o pai ocupado removendo filhos.
		# Libera o nome e esconde imediatamente; queue_free retira o nó com segurança.
		atual.name = "FormaZoanRetirada_%d" % atual.get_instance_id()
		atual.visible = false
		atual.process_mode = Node.PROCESS_MODE_DISABLED
		atual.queue_free()
	ator.set_meta(META_ATIVA, false)
	if forma > 0 and tem(fruta):
		var no := FormaZoan.new()
		no.name = "FormaZoan"
		ator.add_child(no)
		no._montar(ator, fruta)
		ator.set_meta(META_ATIVA, substitui_corpo(fruta))
	if ator.has_method("_atualizar_visibilidade_corpo"):
		ator._atualizar_visibilidade_corpo()


func _montar(ator: Node3D, fruta: String) -> void:
	_ator = ator
	_k = MundoMinePiece.METROS_POR_BLOCO / 16.0 * ESCALA_DO_MOD
	var raiz := ator.get("_char_model") as Node3D
	var indice_da_camada := -1
	if fruta == "hito_hito_daibutsu":
		_montar_buda(raiz)
		_seguir()
		return
	for camada: Dictionary in dados()[fruta]:
		indice_da_camada += 1
		var tex := Vector2(float(camada.tex_w), float(camada.tex_h))
		var material := _material(str(camada.textura))
		var nos := {"": self}
		for p: Dictionary in camada.partes:
			var no := Node3D.new()
			# Peça de topo de camada extra (o `Modeloverlay` e os `…humanbeast2` repetem Head/Body/RightArm…): nome próprio, para não ser
			# renomeada pelo motor e para a chave de `_topo` ficar legível.
			no.name = str(p.nome) if indice_da_camada == 0 or str(p.pai) != "" else "%s_c%d" % [p.nome, indice_da_camada]
			var pai: Node3D = nos.get(p.pai, self)
			pai.add_child(no)
			nos[p.nome] = no
			no.transform = _pose(p.pos, p.rot)
			if (p.caixas as Array).is_empty():
				continue
			var vs := PackedVector3Array()
			var uvs := PackedVector2Array()
			var idx := PackedInt32Array()
			for c: Array in p.caixas:
				McVisual._caixa_mc(vs, uvs, idx, c, Vector3.ZERO, Basis.IDENTITY, _k, tex)
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = vs
			arr[Mesh.ARRAY_TEX_UV] = uvs
			arr[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.material_override = material
			if fruta == "kira_kira":
				m.visible = false # O overlay original não acompanha os membros articulados do personagem.
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			no.add_child(m)
		# TODAS as camadas seguem as juntas (11/11/2026, "partes desconectadas" na Uo Uo): antes só a primeira registrava as peças de topo
		# (`not _topo.has(nome)` recusava a repetida) e o overlay/`humanbeast2` de 9 das 14 frutas ficava parado na pose de repouso
		# enquanto o resto girava. A chave da primeira camada continua o nome da peça; as seguintes levam o sufixo `#N`.
		for nome: String in nos:
			if nome != "" and (nos[nome] as Node).get_parent() == self:
				var chave := nome if indice_da_camada == 0 else "%s#%d" % [nome, indice_da_camada]
				if _topo.has(chave):
					continue
				_topo[chave] = nos[nome]
				_base[chave] = (nos[nome] as Node3D).basis
				var junta_nome: String = JUNTAS.get(nome, JUNTAS["Body"])
				_juntas[chave] = raiz.find_child(junta_nome, true, false)
	if fruta == "kira_kira":
		_vestir_diamante(raiz)
	_seguir()


## Uma única cabeça sólida; membros com cotovelos/joelhos próprios.
## A cena contém a paleta em vértices, sem depender de PNG externo no export.
func _montar_buda(raiz: Node3D) -> void:
	_buda_autoral = true
	var modelo := (load(BUDA_MODELO) as PackedScene).instantiate()
	for filho in modelo.get_children():
		modelo.remove_child(filho)
		add_child(filho)
	modelo.free()
	var juntas := JUNTAS.duplicate()
	juntas.merge(BUDA_JUNTAS)
	for nome: String in juntas:
		var peca := find_child(nome, true, false) as Node3D
		_topo[nome] = peca
		_base[nome] = peca.basis
		_posicoes_buda[nome] = peca.position
		_juntas[nome] = raiz.find_child(juntas[nome], true, false)


## Pose de uma peça do Minecraft (translada, depois gira Z, Y, X) no espaço do Godot: conjugada por (x, −y, −z).
func _pose(pos: Array, rot: Array) -> Transform3D:
	var b := Basis.from_euler(Vector3(rot[0], rot[1], rot[2]), EULER_ORDER_ZYX)
	var f := Basis.from_scale(Vector3(1, -1, -1))
	return Transform3D(f * b * f, f * Vector3(pos[0], pos[1], pos[2]) * _k)


func _material(textura: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = McVisual._textura_arquivo("entidades/" + textura)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return mat


func _vestir_diamante(raiz: Node3D) -> void:
	if raiz == null:
		return
	_diamante = ShaderMaterial.new()
	_diamante.shader = load("res://src/combat/kira/diamante.gdshader")
	for no in raiz.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		_materiais_anteriores[malha] = malha.material_overlay
		malha.material_overlay = _diamante


func _desvestir_diamante() -> void:
	for no in _materiais_anteriores:
		if is_instance_valid(no) and no.material_overlay == _diamante:
			no.material_overlay = _materiais_anteriores[no]
	_materiais_anteriores.clear()


func _exit_tree() -> void:
	_desvestir_diamante()


func _process(_delta: float) -> void:
	# Flashes temporários podem usar a mesma camada e depois soltá-la.
	if _diamante != null:
		for no in _materiais_anteriores:
			if is_instance_valid(no) and no.material_overlay == null:
				no.material_overlay = _diamante
	_seguir()


## Acompanha o corpo do jogador: posição/direção do `_char_model` (sem a escala dele) e a rotação de cada junta.
func _seguir() -> void:
	if not is_instance_valid(_ator):
		return
	var raiz := _ator.get("_char_model") as Node3D
	if raiz == null:
		return
	var cam: Variant = _ator.get("_camera")
	visible = not (cam != null and cam.has_method("em_primeira_pessoa") and cam.em_primeira_pessoa())
	var giro := raiz.global_basis.orthonormalized()
	# O modelo do mod olha para +Z (e a sua direita é −X); o corpo do jogo olha para −Z: meia-volta em Y.
	# Forma gigante (Hito Hito ×3,5, girafa/braquiossauro ×1,75…): o mod escala o corpo pelo atributo de altura (Pehkui) e o jogo passa isso
	# ao `_char_model`/cápsula; a forma vai na mesma escala.
	var esc := float(McEntidade.de(_ator).escala(&"height"))
	global_transform = Transform3D(giro * Basis(Vector3.UP, PI) * Basis.from_scale(Vector3.ONE * esc), raiz.global_position + Vector3.UP * PIVO_PX * _k * esc)
	for nome: String in _topo:
		var junta := _juntas.get(nome) as Node3D
		if junta == null or not is_instance_valid(junta):
			continue
		var rel := (giro.inverse() * junta.global_basis).orthonormalized()
		# rel está no espaço do jogador (−Z à frente); a peça vive no do modelo (meia-volta em Y): conjuga pela meia-volta.
		var meia := Basis(Vector3.UP, PI)
		var destino := meia * rel * meia.inverse() * (_base[nome] as Basis)
		var peca := _topo[nome] as Node3D
		if _buda_autoral:
			# O antebraço já herda o ombro. Retirar o giro do pai evita dobrar duas vezes.
			var pai_rel := global_basis.orthonormalized().inverse() * (peca.get_parent() as Node3D).global_basis.orthonormalized()
			peca.basis = pai_rel.inverse() * destino
		else:
			peca.basis = destino
	if _buda_autoral:
		_pose_flor()
	if pos_seguir.is_valid():
		pos_seguir.call(self)


## Pose sentada própria da malha: não altera o rig escondido, a cápsula nem as animações do jogador.
func _pose_flor() -> void:
	var peso := clampf(peso_flor, 0.0, 1.0)
	for nome: String in _posicoes_buda:
		(_topo[nome] as Node3D).position = _posicoes_buda[nome]
	if peso <= 0.0: return
	global_position.y -= 0.48 * float(McEntidade.de(_ator).escala(&"height")) * peso
	for nome in ["Body", "Head"]:
		var peca := _topo[nome] as Node3D
		peca.basis = peca.basis.slerp(Basis(Vector3.RIGHT, 0.08 if nome == "Head" else 0.0), peso)
	for lado in [-1.0, 1.0]:
		var prefixo := "Right" if lado < 0 else "Left"
		var coxa := Basis(Quaternion(Vector3.DOWN, Vector3(lado*0.75,-0.06,0.72).normalized()))
		var canela := Basis(Quaternion(Vector3.DOWN, Vector3(-lado*0.92,0.04,-0.38).normalized()))
		var braco := Basis(Quaternion(Vector3.DOWN, Vector3(lado*0.22,-0.90,0.38).normalized()))
		var antebraco := Basis(Quaternion(Vector3.DOWN, Vector3(-lado*0.50,-0.10,0.86).normalized()))
		var poses := {prefixo+"Leg": coxa, prefixo+"Shin": coxa.inverse()*canela,
			prefixo+"Foot": canela.inverse(), prefixo+"Arm": braco, prefixo+"ForeArm": braco.inverse()*antebraco}
		for nome: String in poses:
			var peca := _topo[nome] as Node3D
			peca.basis = peca.basis.slerp(poses[nome], peso)
