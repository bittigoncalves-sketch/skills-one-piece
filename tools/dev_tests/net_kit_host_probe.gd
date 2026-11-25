extends SceneTree
# ============================================================================
#  KIT DO BUILDER EM REDE — LADO HOST (2 processos). É o JUIZ e o ALVO (06/10/2026).
#
#  Decisão do dono: na arena o kit vem do botão do menu do M, equipado PELO
#  SERVIDOR (`Player.pedir_kit_do_builder` → `FruitNet.pickup`). Perguntas:
#    1. o pedido do cliente equipa o kit (a cópia do servidor vê `kit_builder`)?
#    2. o golpe do cliente vira DamageZone NESTE processo (dano é do servidor)?
#    3. a vida do host cai exatamente o dano do Builder (arena: escala 1)?
#  O cliente confere do lado dele que viu o golpe e a vida do host cair.
#
#  NORO NORO (06/10/2026, fechamento da Z): depois do kit o cliente troca para a Noro
#  Noro no Mi (a skill PUBLICADA no projeto, copiada para a pasta de teste), segura a Z
#  e solta. Aqui se confere:
#    4. a troca de fruta passou pelo servidor;
#    5. o raio do cliente deixou ESTE corpo 5× lento (o acerto só existe no servidor);
#    6. o raio não feriu (a Noro só deixa lento).
#
#  Skills publicadas numa pasta de TESTE, a mesma nos dois processos (a mesma
#  máquina = o mesmo user://), como duas cópias da mesma versão do jogo.
#
#    godot --headless --path . --script tools/dev_tests/net_kit_host_probe.gd
#    (5 s depois) godot --headless --path . --script tools/dev_tests/net_kit_client_probe.gd
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const PASTA := "user://net_kit_skills"
const DANO := 150.0
const NORO := "noro_noro"
const NORO_SKILL := "res://mapas/skills/noro_noro_beam.json"

var _eu: Node = null
var _cli: Node = null
var _nome_cli := ""
var _zonas_vistas := {}
var _zonas_do_cliente := 0
var _hp_inicial := 0.0
var _hp_final := 0.0
var _fruta_do_cliente := ""
var _viu_kit := false
var _hp_antes_da_noro := -1.0
var _menor_fator := 1.0
var _falhas: Array[String] = []


func _init() -> void:
	await process_frame
	publicar_skills_de_teste()
	get_root().get_node("GameFlow").create_room()
	print("[HOST] sala criada — esperando o cliente...")
	for i in 1200:
		await process_frame
		_eu = _corpo("1")
		if _eu != null:
			break
	if _eu == null:
		print("[HOST] ❌ meu corpo nunca apareceu"); quit(2); return
	# Ninguém mais me machuca: os bonecos da arena vão embora.
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
	_nome_cli = str(_cli.name)
	_eu.health = _eu.max_health
	_hp_inicial = float(_eu.health)
	print("[HOST] cliente '%s' conectado; minha vida %.1f" % [_nome_cli, _hp_inicial])
	var fim := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < fim:
		await process_frame
		_eu.health = maxf(float(_eu.health), 1.0)    # o teste é de rede, não de morte
		_varrer()
		if is_instance_valid(_cli):
			_fruta_do_cliente = str(_cli.get("current_fruit_id"))
			_viu_kit = _viu_kit or _fruta_do_cliente == KitDoBuilder.ID
			if _fruta_do_cliente == NORO and _hp_antes_da_noro < 0.0:
				_hp_antes_da_noro = float(_eu.health)
		if _hp_antes_da_noro >= 0.0:
			_menor_fator = minf(_menor_fator, Lentidao.fator(_eu))
		if _zonas_do_cliente > 0 and _hp_final == 0.0 and float(_eu.health) < _hp_inicial - 1.0:
			_hp_final = float(_eu.health)
	if _hp_final == 0.0:
		_hp_final = float(_eu.health)
	_relatorio()
	SkillsPublicadas.pasta_forcada = ""
	quit(0 if _falhas.is_empty() else 1)


static func publicar_skills_de_teste() -> void:
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	var s := Dados.novo()
	s.identificacao.id = "rede_z"
	s.identificacao.nome = "Soco de rede"
	s.ativacao.tecla = "Z"
	s.condicoes.exige_alvo = false
	s.dano.valor = DANO
	s.dano.empurrao = 0.0
	s.dano.atordoamento = 0.0
	s.configuracoes.custo = 5.0
	s.configuracoes.recarga = 1.0
	s.eventos = [{"id": "hb", "tipo": "hitbox", "inicio": 0.0, "duracao": 0.3, "habilitado": true,
		"parametros": {"z": -2.5, "raio": 1.5}}]
	s.configuracoes.duracao = 0.3
	var r := SkillsPublicadas.publicar(s)
	print("[HOST] skill de teste publicada: %s %s" % [r.caminho, str(r.erros)])
	# A Noro de verdade (a do projeto), como fruta na pasta de teste.
	var noro: Variant = JSON.parse_string(FileAccess.get_file_as_string(NORO_SKILL))
	if not noro is Dictionary:
		print("[HOST] ❌ não li %s" % NORO_SKILL)
		return
	if SkillsPublicadas.fruta(NORO).is_empty():
		SkillsPublicadas.criar_fruta("Noro Noro no Mi", "#ff7ad9")
	r = SkillsPublicadas.publicar(noro)
	print("[HOST] Noro publicada na pasta de teste: %s %s" % [r.caminho, str(r.erros)])


func _varrer() -> void:
	if current_scene == null:
		return
	for z in current_scene.find_children("*", "DamageZone", true, false):
		if _zonas_vistas.has(z.get_instance_id()):
			continue
		_zonas_vistas[z.get_instance_id()] = true
		var cst: Variant = z.get("caster")
		if cst != null and is_instance_valid(cst) and str((cst as Node).name) == _nome_cli:
			_zonas_do_cliente += 1
			print("[HOST] 💥 DamageZone do cliente nasceu aqui — dano=%.1f" % float(z.get("damage")))


func _relatorio() -> void:
	print("\n── KIT DO BUILDER EM REDE (host) ──")
	_ok("1. o pedido do cliente equipou o kit na cópia do servidor", _viu_kit)
	_ok("2. o golpe do cliente virou DamageZone no servidor (%d)" % _zonas_do_cliente, _zonas_do_cliente > 0)
	var caiu := _hp_inicial - _hp_final
	_ok("3. minha vida caiu o dano do Builder, %.0f (caiu %.1f)" % [DANO, caiu], absf(caiu - DANO) < 3.0)
	_ok("4. o cliente trocou para a Noro pelo servidor ('%s')" % _fruta_do_cliente, _fruta_do_cliente == NORO)
	_ok("5. o raio do cliente me deixou 5× lento aqui (menor fator %.2f)" % _menor_fator, is_equal_approx(_menor_fator, 0.2))
	_ok("6. o raio não feriu (%.1f → %.1f)" % [_hp_antes_da_noro, float(_eu.health)],
		_hp_antes_da_noro > 0.0 and float(_eu.health) >= _hp_antes_da_noro - 1.0)
	print("%s" % ("✅ KIT EM REDE OK (host)" if _falhas.is_empty() else "❌ %d falha(s): %s" % [_falhas.size(), str(_falhas)]))


func _ok(rotulo: String, cond: bool) -> void:
	print("   %s %s" % ["✅" if cond else "❌", rotulo])
	if not cond:
		_falhas.append(rotulo)


func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null
