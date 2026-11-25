extends Node
## Orquestra tempo, corpos e cargos; dados ficam no progresso, jamais no menu.
signal aviso(texto: String)
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const Aliado := preload("res://src/historia/tripulantes/aliado_da_tripulacao.gd")
var caminho_progresso := ""
var progressao: ProgressaoDoPersonagem
var jogador_de: Callable
var companhia: Node
var navegacao: Node
var biblioteca: BibliotecaDeModelos
var corpos := {}
var _segundos := 0.0
var _servico := 0.0
var _sincronizando := false
var _sede_alertada := false

func _ready() -> void:
	add_to_group("sobrevivencia_historia")
	progressao.mudou.connect(_sincronizar)
	_sincronizar.call_deferred()

func _sincronizar() -> void:
	if _sincronizando: return
	_sincronizando = true
	var d := P.estado(progressao)
	for id in d.membros.keys():
		if Tripulacao.aliado(progressao, biblioteca, id).is_empty():
			d.membros.erase(id)
			for i in d.vagas.size():
				if d.vagas[i] == id: d.vagas[i] = ""
	for id in corpos.keys():
		if not is_instance_valid(corpos[id]):
			corpos.erase(id)
		elif not d.vagas.has(id):
			_guardar_corpo(id)
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j != null:
		j.set_meta("fome", float(d.fome))
		for vaga in d.vagas.size():
			var id := str(d.vagas[vaga])
			if id.is_empty() or corpos.has(id) or not d.membros.has(id) or bool(d.membros[id].get("morto", false)): continue
			var c: Node3D
			# Bordo e terra compartilham a mesma identidade. Não criar uma segunda Nami.
			var embarcados: Dictionary = navegacao.get("_humanos") if is_instance_valid(navegacao) else {}
			if is_instance_valid(embarcados.get(id)):
				c = embarcados[id]
			elif Tripulacao.e_humano(id) and is_instance_valid(navegacao) and is_instance_valid(navegacao.get("_barco_da_viagem")):
				navegacao.call("_embarcar_humano", id, Tripulacao.tripulante_de(id), vaga)
				c = navegacao.get("_humanos").get(id)
			elif Tripulacao.e_humano(id):
				c = Aliado.new()
				c.set("sistema", self)
				c.set("id", id)
				get_parent().add_child(c)
				c.global_position = j.global_position + Vector3(2 + vaga % 3, 1, 2 + vaga / 3)
				c.call("montar", Tripulacao.tripulante_de(id), biblioteca)
			elif companhia != null and companhia.chamar(id):
				c = companhia.pet_fora(id)
			if c == null: continue
			corpos[id] = c
			c.set_meta("membro_tripulacao", id)
			if c.has_method("ligar_sobrevivencia"): c.call("ligar_sobrevivencia", self, id)
			if c.get("max_health") != null:
				var maximo := float(c.get("max_health"))
				# A fração salva migra para a vida da espécie, sem curar ao recolher.
				var anterior := maxf(1, float(d.membros[id].get("vida_max", 100)))
				c.set("health", maximo * float(d.membros[id].get("vida", anterior)) / anterior)
				d.membros[id].vida_max = maximo
	if P.tem_cargo(progressao, 4):
		var modo: StringName = ModoDoPet.SEGUIR if d.alinhamento == "amigavel" else (ModoDoPet.AGRESSIVO if d.alinhamento == "maligno" else ModoDoPet.GUARDA)
		for c in corpos.values():
			if is_instance_valid(c) and c.has_method("definir_modo") and c.get("modo") != modo: c.call("definir_modo", modo)
	_sincronizando = false

func _guardar_corpo(id: String) -> void:
	var c = corpos.get(id)
	if is_instance_valid(c):
		if c.get("health") != null and P.estado(progressao).membros.has(id):
			P.estado(progressao).membros[id].vida = float(c.get("health"))
		if Tripulacao.e_humano(id):
			if is_instance_valid(navegacao):
				var humanos: Dictionary = navegacao.get("_humanos")
				if humanos.get(id) == c:
					humanos.erase(id)
					navegacao.get("tripulacao").erase(id)
			c.queue_free()
		elif companhia != null: companhia.recolher(id)
	corpos.erase(id)

func avancar(dias: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	var j: Node = jogador_de.call() if jogador_de.is_valid() else null
	if not is_instance_valid(j): return
	if bool(j.get_meta("em_cena", false)): return        # cena/duelo em curso (ex.: Alvida): fome e sede pausam — sede crítica não pode matar no meio
	var morreu := P.avancar(progressao, dias)
	var d := P.estado(progressao)
	j.set_meta("fome", float(d.fome))
	if float(d.sede) <= 75 and not _sede_alertada:
		aviso.emit("Sede crítica: beba água potável (M › Pets). Sem água, você morrerá.")
		_sede_alertada = true
	if float(d.sede) > 75: _sede_alertada = false
	if morreu:
		aviso.emit("Você morreu de sede. Beba água potável durante a próxima viagem.")
		# Nova vida restaura necessidades; salvar zero faria um ciclo infinito de mortes.
		d.sede = P.SEDE_MAX
		d.fome = P.FOME_MAX
		j.set_meta("fome", P.FOME_MAX)
		j.call("die_and_respawn")
		progressao.mudou.emit()
	var segundos := dias * CicloDiaNoite.DURACAO_DO_DIA
	_atualizar_cativos(segundos)
	_segundos += segundos
	_servico += segundos
	for id in d.membros:
		var m: Dictionary = d.membros[id]
		var c = corpos.get(id)
		if is_instance_valid(c) and c.get("health") != null:
			m.vida = float(c.get("health"))
		if not bool(m.get("morto", false)) and float(m.vida) < float(m.vida_max):
			m.vida = minf(float(m.vida_max), float(m.vida) + float(m.vida_max) * 0.005 * segundos)
			if is_instance_valid(c) and c.get("health") != null: c.set("health", m.vida)
	if _servico >= 5:
		_servico = 0
		servir_cargos()
		_sincronizar()
	if _segundos >= 15:
		_segundos = 0
		progressao.mudou.emit()

func necessidades() -> Dictionary:
	var d := P.estado(progressao)
	var feridos := 0
	for m: Dictionary in d.membros.values():
		if bool(m.get("morto", false)): continue
		feridos += ceili(maxf(0, float(m.vida_max) * 0.5 - float(m.vida)) / 25.0)
	var paes := 0 # Companheiros não geram despesas de alimentação.
	var madeira := 0
	if is_instance_valid(navegacao):
		for b in navegacao.get("barcos"):
			if is_instance_valid(b) and not bool(b.get("afundando")):
				madeira += ceili(maxf(0, float(b.get("max_health")) - float(b.get("health"))) / 25.0)
	return {"comida": paes, "saude": feridos, "madeira": maxi(0, madeira - progressao.madeira), "total": paes + feridos + maxi(0, madeira - progressao.madeira)}

func servir_cargos() -> void:
	var d := P.estado(progressao)
	var n := necessidades()
	var ouro_antes := progressao.ouro
	var mudou := false
	if P.tem_cargo(progressao, 3) and int(d.pedido_dia) != int(d.dias):
		d.pedido_dia = int(d.dias)
		var falta := maxi(0, int(n.total) - int(d.reserva))
		if falta > 0: aviso.emit("Estoquista: preciso de %d moedas hoje (comida %d, saúde %d, madeira %d). Deposite no B." % [falta, n.comida, n.saude, n.madeira])
		mudou = true
	# Cargos mantidos; só tratamento e reparos podem gastar a reserva.
	if P.tem_cargo(progressao, 2):
		for id in d.membros:
			var m: Dictionary = d.membros[id]
			if not bool(m.get("morto", false)) and float(m.vida) < float(m.vida_max) * 0.5 and P.pagar(progressao, 1):
				m.vida = minf(float(m.vida_max), float(m.vida) + 25)
				if is_instance_valid(corpos.get(id)): corpos[id].set("health", m.vida)
				mudou = true
	if P.tem_cargo(progressao, 1) and is_instance_valid(navegacao):
		for b in navegacao.get("barcos"):
			if not is_instance_valid(b) or bool(b.get("afundando")): continue
			while float(b.get("health")) < float(b.get("max_health")):
				if progressao.madeira <= 0:
					if not P.pagar(progressao, 1): break
					progressao.madeira += 1
				progressao.madeira -= 1
				b.set("health", minf(float(b.get("max_health")), float(b.get("health")) + 25))
				mudou = true
	if progressao.ouro < ouro_antes:
		aviso.emit("Tripulação: %d moedas em provisões/reparos. Limite diário sem estoquista: %d." % [ouro_antes - progressao.ouro, P.GASTO_DIRETO_MAX_DIA])
	if mudou: progressao.mudou.emit()

func proteger(corpo: Node, dano: float) -> bool:
	var id := str(corpo.get_meta("membro_tripulacao", ""))
	var d := P.estado(progressao)
	if not d.membros.has(id) or dano < float(corpo.get("health")): return false
	if not P.tem_cargo(progressao, 2) or bool(corpo.get_meta("dano_de_boss", false)) or not bool(corpo.get_meta("dano_de_npc", false)): return false
	corpo.set("health", 1.0)
	d.membros[id].vida = 1.0
	aviso.emit("Médico salvou %s da morte." % Tripulacao.aliado(progressao, biblioteca, id).get("nome", id))
	progressao.mudou.emit()
	return true

func registrar_morte(id: String) -> void:
	var d := P.estado(progressao)
	if not d.membros.has(id): return
	d.membros[id].vida = 0.0
	d.membros[id].morto = true
	d.historico_membros[id] = d.membros[id].duplicate(true)
	for i in d.vagas.size():
		if d.vagas[i] == id: d.vagas[i] = ""
	progressao.mudou.emit()

func _exit_tree() -> void:
	# O salvamento periódico e os eventos usam o caminho de teste quando houver.
	if progressao != null and not caminho_progresso.is_empty() and not bool(get_parent().get("_reiniciando_campanha")):
		progressao.salvar(caminho_progresso)

func preparar_embarque(ids: Array[String]) -> Array[String]:
	_sincronizando = true
	var d := P.estado(progressao)
	var aceitos: Array[String] = []
	for id in ids:
		if not d.membros.has(id): P.adicionar(progressao, id)
		if d.membros.has(id) and not bool(d.membros[id].morto): aceitos.append(id)
	for id in corpos.keys(): _guardar_corpo(id)
	for i in d.vagas.size():
		if not aceitos.has(str(d.vagas[i])): d.vagas[i] = ""
	for id in aceitos:
		if not d.vagas.has(id):
			var livre: int = d.vagas.find("")
			if livre >= 0: d.vagas[livre] = id
	return aceitos

func concluir_embarque() -> void:
	_sincronizando = false
	progressao.mudou.emit()

func _atualizar_cativos(delta: float) -> void:
	var dono: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if dono == null: return
	var vaga := 0
	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc is Node3D or not bool(npc.get_meta("escravizado", false)): continue
		var destino: Vector3 = dono.global_position + Vector3((vaga % 3 - 1) * 1.5, 0, 5 + vaga / 3 * 2)
		vaga += 1
		var dir: Vector3 = destino - npc.global_position
		dir.y = 0
		if dir.length() < 2: continue
		var passo: Vector3 = npc.global_position + dir.normalized() * minf(dir.length(), 3 * delta)
		var consulta := PhysicsRayQueryParameters3D.create(npc.global_position + Vector3.UP, passo + Vector3.UP, 1)
		consulta.exclude = [npc.get_rid()]
		if not npc.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty(): continue
		consulta.from = passo + Vector3.UP * 2
		consulta.to = passo + Vector3.DOWN * 3
		var chao: Dictionary = npc.get_world_3d().direct_space_state.intersect_ray(consulta)
		if chao.is_empty(): continue
		npc.global_position = chao.position
		npc.rotation.y = atan2(-dir.x, -dir.z)
