class_name SpawnNaturalMinePiece
extends Node
# ============================================================================
#  SPAWN NATURAL DOS PERSONAGENS DO MINE PIECE (23/10/2026). Pedido do dono: "permitir
#  spawn em todas as ilhas para verificação de spawn in game" — decidido: os personagens
#  nascem pelas regras do PRÓPRIO mod, em qualquer ilha.
#
#  Regras: `mapas/east_blue/spawn_natural.json` (tools/mine_piece/extrair_spawn_natural.py,
#  do biome_modifier + SpawnPlacements do mod v14). Como no `NaturalSpawner` do Minecraft:
#    • tentativa em volta do jogador, de 24 a 128 blocos, no topo do relevo de uma ilha,
#      fora d'água e com espaço livre para o corpo (SpawnPlacements.Type.ON_GROUND);
#    • sorteio por PESO entre as entradas do bioma; a regra de região do mod decide:
#      `(na região OU 1 %) E 2,5 %` (East Blue/Grand Line), `… E 1,25 %` (Novo Mundo),
#      100 % na superfície, 1 % na superfície rara;
#    • bando de mínimo..máximo; MONSTER tenta todo ciclo, CREATURE a cada 400 ticks;
#    • some a mais de 128 blocos; além de 32, 1/800 por tick.
#  Adaptações (declaradas): a REGIÃO vem do mar da ilha (`Ilhas.TABELA`), não das
#  coordenadas do mundo do mod; teto de 8 MONSTER e 4 CREATURE perto do jogador (no Minecraft
#  os do mod são ~15 % dos 70 monstros, sorteados junto com os vanilla — aqui não há vanilla);
#  biomas específicos (oceano frio, deserto, neve, floresta, dream) e WATER_CREATURE ficam de
#  fora até as ilhas terem bioma/mar com spawn. Só nasce quem tem FICHA no jogo (id exato).
# ============================================================================

signal nasceu(personagem: PersonagemMinePiece)

const ARQUIVO := "res://mapas/east_blue/spawn_natural.json"
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const B := MundoMinePiece.METROS_POR_BLOCO
const DISTANCIA_MIN := 24.0 * B
const DISTANCIA_MAX := 128.0 * B
const SUMIR_LONGE := 128.0 * B
const SUMIR_ALEATORIO_ALEM := 32.0 * B
## 1/800 por tick, em 20 ticks/s: chance por segundo de sumir além dos 32 blocos.
const SUMIR_POR_SEGUNDO := 1.0 - pow(1.0 - 1.0 / 800.0, 20.0)
const CICLO := 1.0
const TENTATIVAS_POR_CICLO := 4
const CICLOS_DE_CREATURE := 20                 # 400 ticks
const TETO := {"MONSTER": 8, "CREATURE": 4}
## Mar da ilha → regras de região do mod que valem DENTRO dela.
const REGIAO_DO_MAR := {"east_blue": ["east_blue"], "grand_line": ["grand_line"],
	"novo_mundo": ["novo_mundo", "west_e_novo_mundo"], "red_line": ["red_line"]}

## Liga/desliga (painel F8). Desligado: nada nasce; quem já nasceu fica. Começa DESLIGADO
## quando o Godot roda um script de teste (`--script`): personagem hostil nascendo ao acaso
## deixaria instáveis os testes do mapa real. O teste do spawn chama `ciclo()` ele mesmo.
static var ligado := not OS.get_cmdline_args().has("--script")

var rng := RandomNumberGenerator.new()
var _raiz: Node3D
var _caixas := {}
var _relevos := {}                 # ilha → RelevoEmBlocos
var _entradas: Array = []          # só as que podem nascer (ficha no jogo, bioma qualquer)
var _vivos: Array[PersonagemMinePiece] = []
var _relogio := 0.0
var _ciclos := 0
## Povoamento por ilha (10/11/2026): só nasce na ilha em que o jogador está. "" = sem restrição (testes, mapas sem ilhas).
var ilha_unica := ""
var nascidos_por_ilha := {}        # ilha → total que já nasceu (verificação)


## `raiz`: o nó do mapa (onde estão os corpos do relevo em blocos e onde nascem os personagens).
func ligar(raiz: Node3D, mapa: Dictionary) -> void:
	add_to_group("spawn_natural_mine_piece")        # o painel F8 acha por aqui
	_raiz = raiz
	_caixas = Ilhas.caixas(mapa)
	for no in raiz.get_children():
		if no.has_meta(RelevoEmBlocos.META) and no.has_meta("ilha"):
			_relevos[str(no.get_meta("ilha"))] = no.get_meta(RelevoEmBlocos.META)
	_entradas = entradas_que_nascem()


## As entradas do mod que este jogo consegue fazer nascer agora.
static func entradas_que_nascem() -> Array:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
	var saida := []
	if not (dados is Dictionary):
		push_warning("[SpawnNatural] sem " + ARQUIVO)
		return saida
	for e: Dictionary in dados.get("entradas", []):
		if not bool(e.get("qualquer_bioma", false)) or not TETO.has(str(e.get("categoria", ""))):
			continue
		if DadosEastBlue.ficha(str(e["id"])).is_empty():
			continue
		saida.append(e)
	return saida


func _physics_process(delta: float) -> void:
	var jogador := get_tree().get_first_node_in_group("player") as Node3D
	if jogador == null:
		return
	_relogio += delta
	if _relogio < CICLO:
		return
	_relogio -= CICLO
	_ciclos += 1
	_sumir(jogador.global_position)
	if ligado:
		ciclo(jogador.global_position)


## Um ciclo de tentativas (público para o teste chamar sem esperar o relógio).
func ciclo(centro: Vector3) -> void:
	for categoria in TETO:
		if categoria == "CREATURE" and _ciclos % CICLOS_DE_CREATURE != 0:
			continue
		for i in TENTATIVAS_POR_CICLO:
			if _quantos(categoria) >= int(TETO[categoria]):
				break
			_tentar(centro, categoria)


func _tentar(centro: Vector3, categoria: String) -> void:
	var angulo := rng.randf() * TAU
	var dist := rng.randf_range(DISTANCIA_MIN, DISTANCIA_MAX)
	var ponto := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * dist
	var ilha := Ilhas.ilha_em(_caixas, ponto, 0.0)
	var relevo: RelevoEmBlocos = _relevos.get(ilha)
	if relevo == null or (not ilha_unica.is_empty() and ilha != ilha_unica):
		return
	var chao := relevo.altura(ponto.x, ponto.z)
	if is_nan(chao) or chao < RelevoEmBlocos.MEIO:
		return                                   # fora do relevo ou na água/praia rasa
	var entrada := _sortear(categoria, ilha)
	if entrada.is_empty() or not passa_na_regra(str(entrada["regra"]), str(Ilhas.TABELA.get(ilha, {}).get("mar", "")), rng):
		return
	var bando := rng.randi_range(int(entrada["minimo"]), int(entrada["maximo"]))
	for n in bando:
		if _quantos(categoria) >= int(TETO[categoria]):
			return
		var p := ponto + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0)) if n > 0 else ponto
		var y := relevo.altura(p.x, p.z)
		if is_nan(y) or y < RelevoEmBlocos.MEIO:
			continue
		p.y = y
		var ficha := DadosEastBlue.ficha(str(entrada["id"]))
		if not _tem_espaco(p, ficha):
			continue
		_nascer(ficha, p, ilha, categoria)


## A regra de região do mod (procedure `Spawn*Procedure`), com a região vinda do mar da ilha.
static func passa_na_regra(regra: String, mar: String, sorteio: RandomNumberGenerator) -> bool:
	var na_regiao: bool = regra in REGIAO_DO_MAR.get(mar, [])
	match regra:
		"east_blue", "grand_line":
			return (na_regiao or sorteio.randf() < 0.01) and sorteio.randf() < 0.025
		"novo_mundo":
			return (na_regiao or sorteio.randf() < 0.01) and sorteio.randf() < 0.0125
		"superficie":
			return true
		"superficie_rara":
			return sorteio.randf() < 0.01
	return false                                   # red_line, west, corpos: sem ilha/regra ainda


func _sortear(categoria: String, ilha := "") -> Dictionary:
	var elenco := Ilhas.elenco_mp(ilha)
	var total := 0
	for e: Dictionary in _entradas:
		if e["categoria"] == categoria and (elenco.is_empty() or str(e["id"]) in elenco):
			total += int(e["peso"])
	if total <= 0:
		return {}
	var alvo := rng.randi_range(1, total)
	for e: Dictionary in _entradas:
		if e["categoria"] != categoria or (not elenco.is_empty() and not (str(e["id"]) in elenco)):
			continue
		alvo -= int(e["peso"])
		if alvo <= 0:
			return e
	return {}


## ON_GROUND: o corpo (largura × altura da ficha, em blocos) cabe em pé no ponto.
func _tem_espaco(pe: Vector3, ficha: Dictionary) -> bool:
	var forma := CapsuleShape3D.new()
	forma.radius = maxf(float(ficha.get("largura", 0.6)) * B * 0.5, 0.2)
	forma.height = maxf(float(ficha.get("altura", 1.8)) * B, forma.radius * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(), pe + Vector3.UP * (forma.height * 0.5 + 0.05))
	q.collision_mask = 1
	return get_viewport().get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _nascer(ficha: Dictionary, pe: Vector3, ilha: String, categoria: String) -> void:
	var pers := PersonagemMinePiece.new()
	pers.montar(ficha, str(ficha.get("modelo", "")))
	pers.renasce = false
	pers.name = "MPN_%s_%d" % [ficha["id"], Time.get_ticks_usec()]
	pers.position = pe
	pers.rotation.y = rng.randf() * TAU
	pers.ponto_de_origem = pe
	pers.yaw_de_origem = pers.rotation.y
	pers.set_meta("spawn_natural", categoria)
	pers.set_meta("ilha_do_spawn", ilha)
	_raiz.add_child(pers)
	_vivos.append(pers)
	nascidos_por_ilha[ilha] = int(nascidos_por_ilha.get(ilha, 0)) + 1
	print("SPAWN_NATURAL %s em %s (%s)" % [ficha["id"], ilha, categoria])
	nasceu.emit(pers)


func _quantos(categoria: String) -> int:
	var n := 0
	for p in _vivos:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.get_meta("spawn_natural", "") == categoria:
			n += 1
	return n


## Minecraft: além de 128 blocos some na hora; além de 32, 1/800 por tick.
func _sumir(centro: Vector3) -> void:
	var ficam: Array[PersonagemMinePiece] = []
	for p in _vivos:
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		if p.get_meta("mc_persistente", false):
			ficam.append(p)                       # PersistenceRequired: não some
			continue
		var d := Vector2(p.global_position.x - centro.x, p.global_position.z - centro.z).length()
		if d > SUMIR_LONGE or (d > SUMIR_ALEATORIO_ALEM and rng.randf() < SUMIR_POR_SEGUNDO * CICLO):
			p.queue_free()
			continue
		ficam.append(p)
	_vivos = ficam


## Vivos por ilha agora (painel F8).
func vivos_por_ilha() -> Dictionary:
	var c := {}
	for p in _vivos:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			var ilha := str(p.get_meta("ilha_do_spawn", "?"))
			c[ilha] = int(c.get(ilha, 0)) + 1
	return c
