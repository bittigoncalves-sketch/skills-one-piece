extends SceneTree
## Primeira ilha (25/11/2026): só pirata, galo (suzume) e Chouchou do Mine Piece, com ARTE PRÓPRIA (`pi_*.glb`).
## Confere: os 3 modelos próprios existem e carregam; a ficha aponta para eles; ossos e clipes que a IA usa estão lá;
## o spawn natural da Ilha Inicial só sorteia esses 3; as outras ilhas seguem sem restrição.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_primeira_ilha_reconstruida.gd
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const Spawn := preload("res://src/historia/east_blue/spawn_natural_mine_piece.gd")
const OSSOS := {
	"pirate": ["head", "torso", "right_arm", "left_arm", "right_leg", "left_leg", "itemMainHand"],
	"chouchou": ["head", "bone2", "tail", "leg1", "leg2", "leg3", "leg4"],
	"suzume": ["head", "torso", "right_wing", "left_wing", "right_leg", "left_leg"],
}
const CLIPES := {"pirate": ["idle", "walk"], "chouchou": ["idle", "walk", "attack", "death"], "suzume": ["idle", "walk", "death"]}
var falhas := 0
var total := 0


func ok(cond: bool, msg: String) -> void:
	total += 1
	if not cond:
		falhas += 1
		print("FALHA ", msg)


func _init() -> void:
	DadosEastBlue.recarregar()
	for id in OSSOS:
		var ficha := DadosEastBlue.ficha(id)
		ok(str(ficha.get("modelo", "")) == "pi_" + id, "%s: ficha deve usar pi_%s (usa %s)" % [id, id, ficha.get("modelo")])
		var cena := load("res://mapas/modelos/pi_%s.glb" % id) as PackedScene
		ok(cena != null, "%s: pi_%s.glb não carrega" % [id, id])
		if cena == null:
			continue
		var no := cena.instantiate()
		for osso in OSSOS[id]:
			ok(no.find_child(osso, true, false) != null, "%s: falta o osso %s" % [id, osso])
		var ap := no.find_child("AnimationPlayer", true, false) as AnimationPlayer
		ok(ap != null, "%s: sem AnimationPlayer" % id)
		if ap != null:
			for c in CLIPES[id]:
				var achou := ap.has_animation(c) or ap.has_animation(c + "_loop")
				ok(achou, "%s: falta o clipe %s" % [id, c])
		var caixa := AABB()
		for mi in no.find_children("*", "MeshInstance3D", true, false):
			caixa = caixa.merge((mi as MeshInstance3D).get_aabb()) if caixa.size != Vector3.ZERO else (mi as MeshInstance3D).get_aabb()
		ok(caixa.size.y > 0.3 and caixa.size.y < 3.0, "%s: altura estranha %.2f" % [id, caixa.size.y])
		no.free()
	# Spawn: elenco da Ilha Inicial
	ok(Ilhas.elenco_mp(Ilhas.INICIAL) == ["pirate", "suzume", "chouchou"], "elenco da Ilha Inicial")
	ok(Ilhas.elenco_mp(Ilhas.MACACOS).is_empty(), "Macacos sem restrição")
	var sp := Spawn.new()
	sp._entradas = Spawn.entradas_que_nascem()
	sp.rng.seed = 7
	var vistos := {}
	for i in 400:
		for cat in ["MONSTER", "CREATURE"]:
			var e := sp._sortear(cat, Ilhas.INICIAL)
			if not e.is_empty():
				vistos[str(e["id"])] = true
	ok(vistos.has("pirate") and vistos.has("chouchou") and vistos.has("suzume"), "os 3 são sorteados: %s" % [vistos.keys()])
	ok(vistos.size() == 3, "só os 3 na Ilha Inicial: %s" % [vistos.keys()])
	var fora := {}
	for i in 400:
		for cat in ["MONSTER", "CREATURE"]:
			var e := sp._sortear(cat, Ilhas.MACACOS)
			if not e.is_empty():
				fora[str(e["id"])] = true
	ok(fora.size() > 3, "outras ilhas seguem sem restrição (%d ids)" % fora.size())
	sp.free()
	print("PRIMEIRA_ILHA %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
