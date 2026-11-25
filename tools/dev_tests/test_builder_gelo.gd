extends SceneTree
# ============================================================================
#  CAMPOS DE GELO DO SKILLS BUILDER — prévia (07/10/2026, Hie refeita).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_builder_gelo.gd
#
#  O Z novo da Hie usa "Congelar (s)", "Sai de: Entre as mãos" e os sons "Gelo: …"; o que
#  o jogo faz (`test_hie_builder`) a prévia do editor também mostra:
#    • o esquema aceita os campos e os sons novos;
#    • no meio da skill, o alvo de treino está "Congelado", dentro do bloco de gelo;
#    • as estacas da prévia nascem entre as mãos do Base.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/skills/Z_ice.json"))
	var v := Dados.validar(s)
	_ok("o Z da Hie (congelar, sai de, sons de gelo) é válido (%s)" % str(v.erros), bool(v.ok)
		and "Gelo: disparo" in Dados.SONS and float(s.dano.congelar) == 0.7)
	root.get_node("GameFlow").start_skills_builder()
	for i in 60:
		await process_frame
	var ed := current_scene
	ed.call("_documento", s)
	for i in 5:
		await process_frame
	var arena: Node = ed.get("arena")
	arena.call("buscar", 0.42)
	await process_frame
	var mao_d: Vector3 = arena.call("_osso_na_previa", "Mão direita")
	var mao_e: Vector3 = arena.call("_osso_na_previa", "Mão esquerda")
	var meio := (mao_d + mao_e) * 0.5
	var pior := 0.0
	var n := 0
	for pr in arena.get("_projeteis"):
		if str(pr.id).begins_with("salva_0:"):
			var nasceu: Vector3 = (pr.node as Node3D).global_position - (pr.vel as Vector3) * float(pr.idade)
			pior = maxf(pior, nasceu.distance_to(meio))
			n += 1
	_ok("prévia: a 1ª salva tem 8 estacas (%d) nascendo entre as mãos (pior %.2f m)" % [n, pior], n == 8 and pior < 0.25)
	arena.call("buscar", 0.75)
	await process_frame
	var bloco: Variant = arena.get("_bloco_de_gelo")
	_ok("prévia: aos 0,75 s o alvo está \"%s\" e dentro do bloco de gelo" % str(arena.get("_efeito")),
		str(arena.get("_efeito")) == "Congelado" and bloco != null and (bloco as Node3D).visible)
	print("\nBUILDER_GELO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
