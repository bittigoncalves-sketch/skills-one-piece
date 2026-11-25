class_name NpcDaIlha
extends StaticBody3D
# ============================================================================
#  NPC DA ILHA — os personagens com loja do Modo História (03/10/2026).
#
#  Decisão do dono (pescador, 03/10): "personagem do elenco (Base)" com outra cor,
#  E para conversar. O domador e o vendedor de frutas seguem a mesma regra. O corpo é
#  o MESMO `PlayerRig` do jogador e do boneco de duelo (mesmo modelo, mesmo animador,
#  parado em idle), pintado com as cores da FICHA — as mesmas cores pintam o .glb da
#  loja do editor (`tools/importar_npcs_na_loja.gd`): fonte única em `tingir`.
#
#  NPC novo = uma ficha em `FICHAS` (nome, cores, item na mão, loja) + a classe da loja
#  dele (`LojaDeNpc`). Quem acha o NPC mais perto e abre a loja é o `NpcsDaIlha`.
# ============================================================================

## Comportamento no catálogo → ficha. `item` = o que segura na mão direita ("" = nada).
const FICHAS := {
 "npc_comida": {"nome": "Vendedor de provisões", "capa": Color(0.85, 0.65, 0.28), "calca": Color(0.22, 0.16, 0.12), "item": "", "loja": "res://src/historia/npcs/loja_de_comida.gd"},
 "npc_ferreiro": {"nome": "Ferreiro", "capa": Color(0.3, 0.22, 0.18), "calca": Color(0.15, 0.17, 0.2), "item": "", "loja": "res://src/historia/npcs/loja_do_ferreiro.gd"},
	"npc_pescador": {
		"nome": "Pescador",
		"capa": Color(0.95, 0.74, 0.18), "calca": Color(0.13, 0.22, 0.36),
		"item": "vara", "loja": "res://src/historia/npcs/loja_do_pescador.gd",
	},
	"npc_domador": {
		"nome": "Domador",
		"capa": Color(0.38, 0.52, 0.22), "calca": Color(0.42, 0.27, 0.14),
		"item": "", "loja": "res://src/historia/npcs/loja_do_domador.gd",
	},
	"npc_vendedor_frutas": {
		"nome": "Vendedor de frutas",
		"capa": Color(0.56, 0.24, 0.62), "calca": Color(0.2, 0.18, 0.26),
		"item": "", "loja": "res://src/historia/npcs/loja_de_frutas.gd",
	},
	# Corrida de caranguejos (06/10/2026): inscreve na corrida; bandeira quadriculada ao lado.
	"npc_corrida": {
		"nome": "Organizador da corrida",
		"capa": Color(0.84, 0.2, 0.17), "calca": Color(0.93, 0.91, 0.86),
		"item": "bandeira", "loja": "res://src/historia/npcs/loja_da_corrida.gd",
	},
	# Vendedor de barcos (10/10/2026): 1 moeda cada; o barco atraca no cais ao lado.
	# Um remo fincado ao lado (como a bandeira do organizador da corrida).
	"npc_vendedor_barcos": {
		"nome": "Vendedor de barcos",
		"capa": Color(0.1, 0.52, 0.58), "calca": Color(0.12, 0.16, 0.3),
		"item": "remo", "loja": "res://src/historia/npcs/loja_de_barcos.gd",
	},
	# Barba Negra (15/10/2026): o MESMO personagem da arena (`rig`; o rig já o faz 1,5× maior — `escala` só ergue colisor e rótulo para os 2,25 m dele). Mais alto que os
	# demais. Retira a fruta e vende pulo no ar e dash no ar. As cores são só do
	# boneco-placeholder da loja do editor; no jogo vale o modelo de verdade.
	"npc_barba_negra": {
		"nome": "Barba Negra", "rig": "blackbeard", "escala": 1.25, "missao": "resgate_do_bau",
		"capa": Color(0.12, 0.1, 0.12), "calca": Color(0.2, 0.12, 0.1),
		"item": "", "loja": "res://src/historia/npcs/loja_do_barba_negra.gd",
	},
	# Mestre do Geppo (18/11/2026): macaco-mestre da Ilha dos Macacos; ensina pulos no ar e dash sem recarga.
	"npc_mestre_geppo": {
		"nome": "Mestre do Geppo",
		"capa": Color(0.55, 0.34, 0.17), "calca": Color(0.36, 0.22, 0.12),
		"item": "", "loja": "res://src/historia/npcs/loja_do_mestre_geppo.gd",
	},
	# Ilha dos Macacos v2 (22/11/2026): moradores que dão as 5 missões (`missoes.gd`). Corpos reaproveitados do manequim, pintados em tons de macaco.
	"npc_macaco_cozinheira": {
		"nome": "Cozinheira da vila", "missao": "cesto_de_bananas",
		"capa": Color(0.7, 0.45, 0.2), "calca": Color(0.4, 0.28, 0.14),
		"item": "", "loja": "res://src/historia/missoes/loja_de_missao.gd",
	},
	"npc_macaco_pescador": {
		"nome": "Pescador do cais", "missao": "pesca_do_cais",
		"capa": Color(0.22, 0.5, 0.62), "calca": Color(0.45, 0.32, 0.18),
		"item": "vara", "loja": "res://src/historia/missoes/loja_de_missao.gd",
	},
	"npc_macaco_vigia": {
		"nome": "Vigia da torre", "missao": "os_saqueadores",
		"capa": Color(0.45, 0.22, 0.16), "calca": Color(0.3, 0.25, 0.2),
		"item": "", "loja": "res://src/historia/missoes/loja_de_missao.gd",
	},
	"npc_macaco_curandeiro": {
		"nome": "Curandeiro", "missao": "os_quatro_totens",
		"capa": Color(0.32, 0.55, 0.3), "calca": Color(0.52, 0.4, 0.22),
		"item": "", "loja": "res://src/historia/missoes/loja_de_missao.gd",
	},
	# Instrutor do campo de treino (20/11/2026): dá a primeira missão e inicia o minigame de treino (`treino_de_soco.gd`). Placeholder de cores até o design do Codex
	# (art_src/references/treino/).
	"npc_treinador": {
		"nome": "Instrutor",
		"capa": Color(0.2, 0.2, 0.42), "calca": Color(0.27, 0.19, 0.17),
		"item": "", "loja": "res://src/historia/npcs/loja_do_treinador.gd", "missao": "treino",
		"vestir": "res://src/historia/treino/visual_do_instrutor.gd",
		"corpo": "masculino", "tom": "medio", "tamanho": 1.13,       # quadrado como um personagem do Minecraft (21/11/2026)
	},
	# Guarda da vila (era o NPC das missões dos bandidos, retiradas em 20/11/2026): fica parado, sem missão.
	# Missão dos bandidos (08/10/2026): "?" amarela acima da cabeça, dá a missão no E.
	"npc_missao_bandidos": {
		"nome": "Guarda da vila",
		"capa": Color(0.2, 0.32, 0.56), "calca": Color(0.26, 0.21, 0.15),
		"item": "",
	},
}
## A "?" de missão: amarela (tem missão para dar ou para entregar), cinza (aceita, em
## andamento); some depois de entregue.
const COR_MISSAO := Color(1.0, 0.84, 0.12)
const COR_MISSAO_EM_ANDAMENTO := Color(0.62, 0.62, 0.62)
const COR_PELE := Color(0.86, 0.68, 0.52)
## Pedaços do manequim por nome da malha (substring). O que não casa vira capa.
const PARTES_CALCA := ["Thigh", "Shin", "Knee", "Ankle", "Foot", "Toe", "Heel", "Pelvis"]
const PARTES_PELE := ["Head", "Neck", "Palm", "Index", "Middle", "Ring", "Little", "Thumb", "Wrist"]
const RAIO := 0.45
const ALTURA := 1.8
## O `PlayerRig` assenta os pés a meia altura do colisor do jogador ABAIXO da origem
## do dono (no Player e no boneco, a origem é o centro do corpo). A origem do NPC é o
## chão; o corpo fica num nó a esta altura (`Player.COLISOR_BASE.y / 2`).
const CENTRO_DO_CORPO := 0.8
const PES_DO_CORPO := 0.83         # distância do centro do corpo à sola (medida: pés em y −0,03 com o centro em 0,8)
const FALA_DURA := 4.0

## Comportamento do catálogo (chave de `FICHAS`). Antes do `add_child`.
var tipo := "npc_pescador"
var biblioteca: BibliotecaDeModelos

var _rig: PlayerRig
var _corpo: Node3D
var _vara: VaraDePescaVisual = null
var _fala: Label3D
var _fala_ate := 0.0
var _relogio := 0.0
## CORRIDA (21/11/2026, desafio do Buggy): o morador vai até `destino` em linha reta, colado ao chão, correndo (o animador recebe a velocidade) e ao chegar olha para `_olhar_para`.
## GATILHO: se o teste achar morador preso em parede, trocar a linha reta por `NavigationAgent3D`.
const VELOCIDADE_DA_CORRIDA := 7.0          # corrida de verdade (o jogador anda ~5): 150 m em ~21 s
var _destino := Vector3.INF
var piso_minimo := -INF           # a corrida nunca afunda abaixo disto (o píer não tem colisão: o chão sob ele é o fundo do mar)
var _olhar_para := Vector3.INF
var _correndo := false
var _visual_animado = null      # o script de visual com `pose_animada` (instrutor); null = pose fixa
var _loja: LojaDeNpc = null
var _marca: Label3D = null      # a "?" de missão (só NPC com `missao` na ficha)


static func ficha(t: String) -> Dictionary:
	return FICHAS.get(t, {})


## Pinta o manequim Base com as cores da ficha. Vale para o rig do jogo e para a cena
## exportada para a loja (nos dois as malhas do corpo se chamam `Geo_*`).
static func tingir(raiz: Node, f: Dictionary) -> void:
	# Só o corpo (`Geo_*`): o rig também pendura as armas escondidas (pistolas, Buki).
	if raiz is MeshInstance3D and String(raiz.name).begins_with("Geo_"):
		var mi := raiz as MeshInstance3D
		var cor: Color = f.get("capa", Color.WHITE)
		for parte in PARTES_CALCA:
			if parte in String(mi.name):
				cor = f.get("calca", cor)
		for parte in PARTES_PELE:
			if parte in String(mi.name):
				cor = COR_PELE
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var original := mi.get_active_material(s)
				var mat: StandardMaterial3D = original.duplicate() if original is StandardMaterial3D else StandardMaterial3D.new()
				# As juntas do manequim são um tom mais escuras: mantém a proporção.
				var escuro: float = (original as StandardMaterial3D).albedo_color.v / 0.735 if original is StandardMaterial3D else 1.0
				mat.albedo_color = Color(cor.r * escuro, cor.g * escuro, cor.b * escuro)
				mi.set_surface_override_material(s, mat)
	for filho in raiz.get_children():
		tingir(filho, f)


func _ready() -> void:
	add_to_group("npc")
	var f := ficha(tipo)
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = RAIO
	var altura := ALTURA * float(f.get("escala", 1.0))
	forma.height = altura
	col.shape = forma
	col.position = Vector3.UP * altura * 0.5
	add_child(col)
	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	_corpo.position = Vector3.UP * CENTRO_DO_CORPO
	add_child(_corpo)
	# Corpo em CAIXAS do Minecraft (o mesmo do jogador); o `PlayerRig` o lê da meta do dono. Ficha com `corpo` (instrutor) usa o dela; os moradores vêm do `VisualDeMorador`.
	var morador := not f.has("rig") and not f.has("corpo") and VisualDeMorador.tem(tipo)
	if f.has("corpo") or morador:
		_corpo.set_meta("corpo_historia", str(f["corpo"]) if f.has("corpo") else VisualDeMorador.corpo(tipo))
		_corpo.set_meta("tom_de_pele", str(f["tom"]) if f.has("tom") else VisualDeMorador.tom(tipo))
		if morador:
			_corpo.set_meta("aparencia_historia", VisualDeMorador.aparencia(tipo))
	_rig = PlayerRig.new()
	_rig.name = "Rig"
	_corpo.add_child(_rig)
	_rig.montar_em(_corpo)
	_rig.montar(str(f.get("rig", "base")))
	if morador:
		VisualDeMorador.vestir(_rig.modelo(), f)
	elif _rig.modelo() != null and not f.has("rig"):
		tingir(_rig.modelo(), f)       # personagem do elenco com modelo próprio não se pinta
	if f.has("vestir"):
		var visual = load(str(f["vestir"]))
		visual.vestir(_rig.modelo())      # roupa/acessórios próprios do NPC (o instrutor: `visual_do_instrutor.gd`)
		if visual.has_method("pose"):
			_corpo.set_meta("pose_de_skill", visual.pose())      # pose fixa do NPC (o instrutor aponta para o boneco)
		if visual.has_method("pose_animada"):
			_visual_animado = visual          # o instrutor se mexe: `pose_animada(t, falando)` a cada quadro (21/11/2026)
	if f.has("tamanho"):
		# Mais alto que o jogador (1,5 m de corpo): escala o corpo em volta dos PÉS (o modelo mede ~0,83 m do centro do corpo até a sola) — colisor e rótulos seguem `escala`.
		var k := float(f["tamanho"])
		_corpo.scale = Vector3.ONE * k
		_corpo.position = Vector3.UP * (PES_DO_CORPO * k)
	if str(f.get("item", "")) == "vara":
		_vara = VaraDePescaVisual.new()
		_vara.name = "Vara"
		_vara.biblioteca = biblioteca
		add_child(_vara)
		# Braço da vara na pose da pesca do jogador (o animador lê a meta do dono).
		_corpo.set_meta("pesca_pose", "segura")
	if str(f.get("item", "")) == "bandeira":
		add_child(_bandeira())
	if str(f.get("item", "")) == "remo":
		add_child(_remo())
	var rotulo := Label3D.new()
	rotulo.name = "Nome"
	rotulo.text = nome()
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.font_size = 40
	rotulo.pixel_size = 0.0035
	rotulo.outline_size = 10
	rotulo.modulate = EstiloDaHistoria.DOURADO
	rotulo.position = Vector3.UP * (altura + 0.35)
	add_child(rotulo)
	_fala = Label3D.new()
	_fala.name = "Fala"
	_fala.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_fala.font_size = 34
	_fala.pixel_size = 0.0035
	_fala.outline_size = 10
	_fala.width = 520
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.position = Vector3.UP * (altura + 0.8)
	_fala.visible = false
	add_child(_fala)
	if f.has("missao"):
		_marca = Label3D.new()
		_marca.name = "MarcaDeMissao"
		_marca.text = "?"
		_marca.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marca.font_size = 150
		_marca.pixel_size = 0.0042
		_marca.outline_size = 22
		_marca.outline_modulate = Color(0.25, 0.16, 0.0)
		_marca.modulate = COR_MISSAO
		_marca.position = Vector3.UP * (ALTURA + 0.85)
		add_child(_marca)
		_fala.position = Vector3.UP * (ALTURA + 1.45)       # a fala acima da "?"


## Bandeira quadriculada de chegada num mastro fincado ao lado (o organizador da corrida).
static func _bandeira() -> Node3D:
	var b := Node3D.new()
	b.name = "Bandeira"
	b.position = Vector3(0.75, 0, 0.15)
	var mastro := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.03
	cil.bottom_radius = 0.04
	cil.height = 2.6
	mastro.mesh = cil
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.76, 0.8)
	metal.metallic = 0.7
	metal.roughness = 0.35
	mastro.material_override = metal
	mastro.position.y = 1.3
	b.add_child(mastro)
	var quadro := BoxMesh.new()
	quadro.size = Vector3(0.2, 0.2, 0.02)
	var preto := StandardMaterial3D.new()
	preto.albedo_color = Color(0.07, 0.07, 0.07)
	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color(0.95, 0.95, 0.95)
	for i in 5:
		for j in 3:
			var q := MeshInstance3D.new()
			q.mesh = quadro
			q.material_override = preto if (i + j) % 2 == 0 else branco
			q.position = Vector3(0.14 + i * 0.2, 2.42 - j * 0.2, 0)
			b.add_child(q)
	return b


## Remo de madeira fincado ao lado, inclinado (o vendedor de barcos).
static func _remo() -> Node3D:
	var r := Node3D.new()
	r.name = "Remo"
	r.position = Vector3(0.7, 0, 0.2)
	r.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(20.0), deg_to_rad(-9.0))
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.55, 0.36, 0.2)
	madeira.roughness = 0.8
	var cabo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.03
	cil.bottom_radius = 0.035
	cil.height = 1.7
	cabo.mesh = cil
	cabo.material_override = madeira
	cabo.position.y = 1.35
	r.add_child(cabo)
	var pa := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.2, 0.62, 0.035)
	pa.mesh = caixa
	pa.material_override = madeira
	pa.position.y = 0.31
	r.add_child(pa)
	var punho := MeshInstance3D.new()
	var anel := CylinderMesh.new()
	anel.top_radius = 0.045
	anel.bottom_radius = 0.045
	anel.height = 0.16
	punho.mesh = anel
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.2, 0.13, 0.08)
	punho.material_override = escuro
	punho.position.y = 2.12
	r.add_child(punho)
	return r


func nome() -> String:
	return str(ficha(tipo).get("nome", tipo))


## A missão que este NPC dá ("" = nenhuma). Com o progresso, a DA VEZ na cadeia dele
## ("" quando todas foram entregues).
func missao(prog: ProgressaoDoPersonagem = null) -> String:
	if not ficha(tipo).has("missao"):
		return ""
	if prog == null:
		return str(ficha(tipo)["missao"])
	return preload("res://src/historia/missoes/missoes.gd").atual_do_npc(tipo, prog)


## A "?" conforme o estado da missão (ver `COR_MISSAO`).
func marcar_missao(estado: String) -> void:
	if _marca == null:
		return
	_marca.visible = estado != "entregue"
	_marca.modulate = COR_MISSAO_EM_ANDAMENTO if estado == "aceita" else COR_MISSAO


## A loja deste NPC (criada na primeira conversa).
func loja() -> LojaDeNpc:
	if _loja == null:
		var caminho := str(ficha(tipo).get("loja", ""))
		if not caminho.is_empty():
			_loja = load(caminho).new()
			if ficha(tipo).has("missao"):
				_loja.set("missao", str(ficha(tipo)["missao"]))
				_loja.set("npc", tipo)              # cadeia: a missão da vez
	return _loja


## Balão sobre a cabeça por alguns segundos.
func falar(texto: String) -> void:
	_fala.text = texto
	_fala.visible = not texto.is_empty()
	_fala_ate = _relogio + FALA_DURA


func falando() -> bool:
	return _fala.visible


## O animador de idle custava 1,98 ms por quadro com 12 NPCs (165 µs cada, medido 04/11/2026) e é só visual: fora do campo de
## visão da câmera não é calculado. Perto (< RAIO_SEMPRE_ANIMA) sempre anima: corpo parcialmente visível e sombra projetada.
## O idle é periódico: ao voltar à vista continua do mesmo ponto, sem salto. Desligar só nas medições.
static var economia_fora_da_tela := true
const RAIO_SEMPRE_ANIMA := 6.0


func _fora_da_vista() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var centro := global_position + Vector3.UP * 1.0
	if cam.global_position.distance_squared_to(centro) < RAIO_SEMPRE_ANIMA * RAIO_SEMPRE_ANIMA:
		return false
	var lado := cam.global_basis.x
	for ponto in [centro, centro + lado, centro - lado, centro + Vector3.UP * 0.9, centro - Vector3.UP * 0.9]:
		if cam.is_position_in_frustum(ponto):
			return false
	return true


func _process(delta: float) -> void:
	var t := Cronometro.ini()
	_process_corpo(delta)
	Cronometro.fim(&"NpcDaIlha.process", t)


## Manda o morador correr até `destino` (chão), e ao chegar olhar para `olhar_para`. Nova ordem substitui a anterior.
func correr_para(destino: Vector3, olhar_para := Vector3.INF) -> void:
	_destino = destino
	_olhar_para = olhar_para
	_correndo = true
	_fala.visible = false


## Põe o morador JÁ no lugar (sem correr): carregou o jogo no meio do desafio.
func posicionar_em(destino: Vector3, olhar_para := Vector3.INF) -> void:
	global_position = destino
	_destino = destino
	_olhar_para = olhar_para
	_correndo = false
	if olhar_para != Vector3.INF:
		_virar_para(olhar_para)


func correndo() -> bool:
	return _correndo


func chegou() -> bool:
	return not _correndo and _destino != Vector3.INF


func _passo_da_corrida(delta: float) -> Vector3:
	var daqui := global_position
	var falta := Vector3(_destino.x - daqui.x, 0.0, _destino.z - daqui.z)
	var passo := VELOCIDADE_DA_CORRIDA * delta
	if falta.length() <= passo:
		global_position = Vector3(_destino.x, _destino.y, _destino.z)
		_correndo = false
		if _olhar_para != Vector3.INF:
			_virar_para(_olhar_para)
		return Vector3.ZERO
	var dir := falta.normalized()
	var nova := daqui + dir * passo
	nova.y = _chao_em(nova, daqui.y)
	global_position = nova
	_virar_para(nova + dir)
	return dir * VELOCIDADE_DA_CORRIDA


func _virar_para(ponto: Vector3) -> void:
	var v := Vector3(ponto.x - global_position.x, 0.0, ponto.z - global_position.z)
	if v.length() > 0.01:
		global_rotation.y = atan2(-v.x, -v.z)          # a frente do NPC é −Z


## Altura do chão sob `p` (raio de cima para baixo; sem chão, mantém `padrao`). O corpo do próprio NPC não conta (é um corpo estático com raio de vara).
func _chao_em(p: Vector3, padrao: float) -> float:
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 6.0)
	q.exclude = [get_rid()]
	var r := espaco.intersect_ray(q)
	return maxf(float((r["position"] as Vector3).y) if not r.is_empty() else padrao, piso_minimo)


func _process_corpo(delta: float) -> void:
	delta *= TempoLocal.fator_de(self)      # vida baixa do jogador: o NPC também passa mais devagar
	_relogio += delta
	if _fala.visible and _relogio >= _fala_ate:
		_fala.visible = false
	if _marca != null:
		_marca.position.y = ALTURA + 0.85 + 0.07 * sin(_relogio * 2.6)    # flutua
	var vel := _passo_da_corrida(delta) if _correndo else Vector3.ZERO      # anda MESMO fora da vista (a economia só pula o animador)
	# Idle de verdade (o mesmo animador do jogador, parado).
	var animador := _rig.procedural() if _rig != null else null
	if animador != null:
		if economia_fora_da_tela and _fora_da_vista():
			Cronometro.contar(&"NPC.animador_pulado")
		else:
			var t_a := Cronometro.ini()
			if _visual_animado != null:
				_corpo.set_meta("pose_de_skill", _visual_animado.pose_animada(_relogio, _fala.visible))
			animador.update(vel, true, false, delta, 0.0)
			Cronometro.fim(&"NPC.animador", t_a)
	if _vara != null:
		# A vara na mão direita, apontada para a frente e para cima, como quem espera.
		_vara.segurar_em(_rig.item_handle if _rig != null else null)
		var corpo := global_basis.orthonormalized()
		_vara.orientar(-corpo.z * cos(deg_to_rad(40.0)) + Vector3.UP * sin(deg_to_rad(40.0)), corpo.x)
