extends SceneTree
# ============================================================================
#  PIKA REFEITA NO BUILDER, EM REDE — LADO HOST (2 processos). É o JUIZ e o ALVO
#  (06/10/2026).
#
#  A Pika da arena com Z/X/C do Builder (`tools/criar_pika_pika.gd`) e o V do código.
#  O host copia as três skills PUBLICADAS no projeto para uma pasta de TESTE (a mesma
#  máquina = o mesmo user:// nos dois processos), entrega a Pika ao cliente pelo
#  servidor (`FruitNet.pickup`, como a árvore) e confere AQUI, onde o dano nasce:
#    1. a cópia do cliente no servidor está com a Pika;
#    2. o Z, o X e o C do cliente viram golpe do Builder neste processo;
#    3. minha vida cai: Z = 98, X = 160 (a esfera no fim do zigue-zague), C ≥ 2 × 48.
#
#    godot --headless --path . --script tools/dev_tests/net_pika_host_probe.gd
#    (5 s depois) godot --headless --path . --script tools/dev_tests/net_pika_client_probe.gd
# ============================================================================

const PASTA := "user://net_pika_skills"
const SKILLS := ["pika_raio_z", "pika_yata_x", "pika_yasakani_c", "pika_voo_f"]

var _eu: Node = null
var _cli: Node = null
var _falhas: Array[String] = []
var _viu_pika := false
var _execs := {}        # id da skill do Builder → quantas vezes nasceu aqui


func _init() -> void:
	await process_frame
	publicar()
	get_root().get_node("GameFlow").create_room()
	print("[HOST] sala criada — esperando o cliente...")
	for i in 1200:
		await process_frame
		_eu = _corpo("1")
		if _eu != null:
			break
	if _eu == null:
		print("[HOST] ❌ meu corpo nunca apareceu"); quit(2); return
	for d in get_nodes_in_group("enemy"):
		if d is Node3D:
			(d as Node3D).global_position = Vector3(0, -1000, 0)
			d.set_physics_process(false)
	var esperou := 0
	while _cli == null and esperou < 3000:
		await process_frame
		esperou += 1
		for n in get_nodes_in_group("player"):
			if n.name != "1":
				_cli = n
	if _cli == null:
		print("[HOST] ❌ o cliente nunca conectou"); quit(3); return
	await _esperar(1.5)
	# O servidor entrega a fruta (como a árvore da arena).
	get_root().get_node("FruitNet").pickup("pika_pika", str(_cli.name).to_int())
	print("[HOST] Pika entregue ao cliente '%s'" % _cli.name)
	var fim := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < fim:
		await process_frame
		_eu.health = maxf(float(_eu.health), 1.0)
		if is_instance_valid(_cli):
			_viu_pika = _viu_pika or str(_cli.get("current_fruit_id")) == "pika_pika"
		for e in current_scene.find_children("SkillBuilder_*", "", true, false):
			if not e.has_meta("contado"):
				e.set_meta("contado", true)
				var id := str((e.get("skill") as Dictionary).get("identificacao", {}).get("id", "?"))
				_execs[id] = int(_execs.get(id, 0)) + 1
				print("[HOST] %s nasceu: cliente (cópia) em %s, eu em %s, ponto mirado %s, rumo %s" % [id,
					_cli.global_position.snapped(Vector3.ONE * 0.1), _eu.global_position.snapped(Vector3.ONE * 0.1),
					(e.get("ponto_mirado") as Vector3).snapped(Vector3.ONE * 0.1), (e.get("_rumo3d") as Vector3).snapped(Vector3.ONE * 0.01)])
	print("\n── PIKA EM REDE (host) ──")
	_ok("1. a cópia do cliente no servidor está com a Pika", _viu_pika)
	_ok("2. Z, X, C e F do cliente viraram golpe do Builder aqui (%s)" % str(_execs),
		_execs.has("pika_raio_z") and _execs.has("pika_yata_x") and _execs.has("pika_yasakani_c") and _execs.has("pika_voo_f"))
	print("%s" % ("✅ PIKA EM REDE OK (host)" if _falhas.is_empty() else "❌ %d falha(s): %s" % [_falhas.size(), str(_falhas)]))
	SkillsPublicadas.pasta_forcada = ""
	quit(0 if _falhas.is_empty() else 1)


## A Pika do PROJETO numa pasta de teste (a mesma que o cliente lê).
static func publicar() -> void:
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	SkillsPublicadas.reconstruir_fruta_da_arena("pika_pika", "Pika Pika no Mi", "#ffd23f")
	for id in SKILLS:
		var s: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/skills/%s.json" % id))
		var r := SkillsPublicadas.publicar(s) if s is Dictionary else {"ok": false, "erros": ["não li"]}
		print("[HOST] %s: %s %s" % [id, r.ok, str(r.get("erros", []))])


func _ok(rotulo: String, cond: bool) -> void:
	print("   %s %s" % ["✅" if cond else "❌", rotulo])
	if not cond:
		_falhas.append(rotulo)


func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
