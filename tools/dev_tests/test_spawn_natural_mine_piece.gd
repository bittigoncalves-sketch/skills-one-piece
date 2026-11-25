extends SceneTree
# ============================================================================
#  SPAWN NATURAL DO MINE PIECE EM TODAS AS ILHAS (23/10/2026,
#  src/historia/east_blue/spawn_natural_mine_piece.gd). Mapa real, as 11 ilhas:
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_spawn_natural_mine_piece.gd
#
#    • as regras vieram do mod (93) e as que nascem têm ficha no jogo;
#    • em CADA ilha nasce alguém, no topo do relevo, de 24 a 128 blocos do centro;
#    • teto de 8 MONSTER perto do jogador;
#    • região: personagem do East Blue no Grand Line só pelo 1 % do mod (raro);
#    • longe (> 128 blocos), todos somem.
# ============================================================================

const B := MundoMinePiece.METROS_POR_BLOCO
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_spawn_natural_mine_piece.json")
	SpawnNaturalMinePiece.ligado = false          # o teste chama os ciclos ele mesmo
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var sp: SpawnNaturalMinePiece = current_scene.get("spawn_natural")
	ok(sp != null, "o Modo História liga o spawn natural")
	if sp == null:
		quit(1)
		return
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SpawnNaturalMinePiece.ARQUIVO))
	ok((dados["entradas"] as Array).size() == 93, "93 regras do mod no arquivo")
	var nascem := SpawnNaturalMinePiece.entradas_que_nascem()
	var com_ficha := nascem.all(func(e): return not DadosEastBlue.ficha(str(e["id"])).is_empty())
	ok(nascem.size() >= 20 and com_ficha, "%d entradas podem nascer, todas com ficha no jogo" % nascem.size())
	var regra_de := {}
	for e: Dictionary in nascem:
		regra_de[str(e["id"])] = str(e["regra"])

	sp.rng.seed = 23102026
	var ilhas_ok := 0
	var fora_da_regiao := 0
	var no_grand_line := 0
	for ilha in sp._caixas:
		var caixa: Rect2 = sp._caixas[ilha]
		var centro := Vector3(caixa.get_center().x, 0.0, caixa.get_center().y)
		var antes := int(sp.nascidos_por_ilha.get(ilha, 0))
		var maximo_vivo := 0
		var no_relevo := true
		var na_distancia := true
		for i in 120:
			sp.ciclo(centro)
			maximo_vivo = maxi(maximo_vivo, sp._quantos("MONSTER"))
		await quadros(2)
		var mar := str(Ilhas.TABELA[ilha]["mar"])
		for p in sp._vivos:
			if not is_instance_valid(p) or p.get_meta("ilha_do_spawn", "") != ilha:
				continue
			var r: RelevoEmBlocos = sp._relevos[ilha]
			no_relevo = no_relevo and absf(p.ponto_de_origem.y - r.altura(p.ponto_de_origem.x, p.ponto_de_origem.z)) < 0.05
			var d := Vector2(p.ponto_de_origem.x - centro.x, p.ponto_de_origem.z - centro.z).length()
			na_distancia = na_distancia and d >= 24.0 * B - 4.5 and d <= 128.0 * B + 4.5   # bando: ±3 m
			if mar == "grand_line":
				no_grand_line += 1
				if regra_de.get(str(p.id_personagem), "") == "east_blue":
					fora_da_regiao += 1
		var nasceram := int(sp.nascidos_por_ilha.get(ilha, 0)) - antes
		ilhas_ok += 1 if nasceram > 0 else 0
		ok(nasceram > 0 and no_relevo and na_distancia and maximo_vivo <= 8,
			"%s (%s): %d nasceram, no relevo %s, distância %s, máx. vivos %d" % [ilha, mar, nasceram, no_relevo, na_distancia, maximo_vivo])
		# Longe: todos somem (> 128 blocos).
		sp._sumir(centro + Vector3(5000, 0, 5000))
		await quadros(2)
	ok(ilhas_ok == sp._caixas.size(), "nasceu gente nas %d ilhas" % ilhas_ok)
	ok(no_grand_line > 0 and fora_da_regiao * 5 <= no_grand_line,
		"no Grand Line, personagem do East Blue é raro (%d de %d)" % [fora_da_regiao, no_grand_line])
	ok(sp.vivos_por_ilha().is_empty(), "longe do jogador, todos sumiram")

	print("\n%d/%d" % [total - falhas, total])
	SpawnNaturalMinePiece.ligado = true
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
