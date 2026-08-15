extends SceneTree
# SONDA DE LADO — mede, no espaço LOCAL do modelo, em que x mora cada nó com
# sufixo de lado. Frente do jogo = -Z, logo DIREITA anatômica = +X.
#
# Existe porque o nome do nó não é prova de nada: `base.scn` nasceu com os lados
# trocados de nome e ninguém notou por meses. Aqui a pergunta é geométrica.
#
# Uso: godot --headless --path . -s tools/dev_tests/medir_lados.gd

const MODELOS := {
	"base.scn":  "res://assets/models/base.scn",
	"base.glb":  "res://assets/models/base.glb",
	"buggy.scn": "res://assets/models/buggy.scn",
	"nami.glb":  "res://assets/models/nami.glb",
	"ace.glb":   "res://assets/models/ace.glb",
}

const PAPEIS := [
	"UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R",
	"Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R",
]

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	for nome in MODELOS:
		var caminho: String = MODELOS[nome]
		if not ResourceLoader.exists(caminho):
			print("\n== %s == (ausente)" % nome)
			continue
		var raiz: Node3D = null
		if caminho.ends_with(".glb"):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(ProjectSettings.globalize_path(caminho), st) != OK:
				print("\n== %s == (falhou o import)" % nome)
				continue
			raiz = doc.generate_scene(st) as Node3D
		else:
			raiz = (load(caminho) as PackedScene).instantiate() as Node3D
		get_root().add_child(raiz)
		print("\n== %s ==" % nome)
		var inv := raiz.global_transform.affine_inverse()
		var trocado := 0
		var certo := 0
		for p in PAPEIS:
			var n := raiz.find_child(p, true, false) as Node3D
			if n == null:
				print("  %-11s ausente" % p)
				continue
			var x: float = (inv * n.global_position).x
			var lado_real := "direito(+X)" if x > 0.001 else ("esquerdo(-X)" if x < -0.001 else "centro")
			var esperado := "esquerdo(-X)" if p.ends_with("_L") else "direito(+X)"
			var ok := (lado_real == esperado)
			if ok: certo += 1
			else: trocado += 1
			print("  %-11s x=%+.4f  real=%-12s esperado=%-12s %s"
				% [p, x, lado_real, esperado, "ok" if ok else "TROCADO"])
		print("  -> %d ok, %d trocados" % [certo, trocado])
		raiz.queue_free()
	quit()
