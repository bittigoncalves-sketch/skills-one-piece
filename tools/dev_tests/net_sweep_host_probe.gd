extends SceneTree
# ============================================================================
#  VARREDURA CLIENTE -> SERVIDOR — LADO HOST (o JUIZ). 2 processos.
#
#  Responde à pergunta que só dois processos respondem:
#  **todas as skills de todas as frutas, conjuradas NO CLIENTE, chegam ao
#  servidor e viram hitbox autoritativa?**
#
#  Num processo só o cliente É o servidor, então o caminho que quebra de verdade
#  nunca é exercitado. Foi assim que o V da Goro Goro passou meses gastando
#  recarga no cliente sem ferir ninguém: no host funcionava.
#
#  ---------------------------------------------------------------- COMO RODAR
#  Dois terminais, HOST PRIMEIRO (a porta 24565 é fixa):
#
#    godot --headless --path . --script tools/dev_tests/net_sweep_host_probe.gd
#    godot --headless --path . --script tools/dev_tests/net_sweep_client_probe.gd
#
#  ------------------------------------------------------------ O QUE ELE MEDE
#  Cada `DamageZone` que NASCE no processo do host, com o `caster` e o dano.
#  Zona nascida aqui = o golpe do cliente atravessou `_net_cast` ->
#  `_do_server_cast` -> `_net_play_cast` e virou hitbox NO LADO QUE DECIDE DANO.
#
#  ⚠️ A VARREDURA É RECURSIVA, e isso não é detalhe. As skills nascem dentro de
#  `Skills_<jogador>` (`Player._get_skills_container`), então as zonas estão em
#  PROFUNDIDADE 2. A sonda antiga (`net_cast_host_probe.gd`) varria só os filhos
#  diretos de `current_scene` e por isso enxergava zero zonas de fruta.
#
#  ------------------------------------------------------- COMO ATRIBUI O SLOT
#  Sem tocar no código do jogo, não há canal para o cliente dizer "vou lançar o
#  X". Então a atribuição é por JANELA DE TEMPO, ancorada num evento que o host
#  observa de verdade: a troca de `current_fruit_id` do corpo do cliente, que é
#  REPLICADA pelo `MultiplayerSynchronizer`.
#
#  O cliente segue um roteiro fixo (equipa -> espera -> Z -> X -> C -> V, uma
#  janela de `JANELA_SLOT` cada). O host ancora o bloco na troca de fruta e
#  calcula o índice do slot pelo tempo decorrido.
#
#  ⚠️ AS TRÊS CONSTANTES ABAIXO TÊM DE SER IGUAIS ÀS DO CLIENTE. Se mudar aqui,
#  mude lá — estão duplicadas de propósito, para as duas sondas rodarem sem
#  depender uma da outra em disco.
# ============================================================================

const JANELA_SLOT := 2.6      # segundos por slot
const ESPERA_FRUTA := 1.2     # espera depois de equipar, antes do primeiro slot
const SLOTS := ["Z", "X", "C", "V"]
const FRUTAS := [
	"gomu_gomu", "gura_gura", "mera_mera", "bara_bara",
	"goro_goro", "yami_yami", "suna_suna", "hie_hie", "buki_buki",
]

# ⚠️ O PONTO CEGO DESTA SONDA, declarado. Ela conta `DamageZone` — então uma
# skill que fere SEM hitbox aparece como muda mesmo funcionando perfeitamente.
# Estas são as que o projeto tem hoje nessa condição; listá-las é o que impede
# alguém de ler a tabela e "consertar" o que não está quebrado.
const MUDAS_ESPERADAS := {
	"gura_gura/Z": "investida: só conjura ao AGARRAR alguém (Player._process_gura_rush)",
	"bara_bara/C": "hold: exige a meta `bara_cleave_active`, que o roteiro não liga",
	"bara_bara/V": "domínio fere pelo CombatResolver, sem DamageZone (por desenho)",
}

var _eu: Node = null
var _cliente: Node = null
var _nome_cliente := ""          # texto: o cliente sai antes do relatório
# ⚠️ MESMO MOTIVO DO NOME SER TEXTO: no fim do roteiro o cliente se desconecta e
# o nó dele é liberado ANTES de o relatório rodar. Ler `cor_idx` lá embaixo dava
# -1 (nó inválido) e acusava um bug que não existia. Copiamos o valor enquanto
# o corpo está vivo.
var _cor_cliente := -1
var _t0 := 0.0
var _hp_inicial := 0.0

var _vistas := {}                # instance_id -> true
var _fruta_atual := ""           # última fruta vista no corpo do cliente
var _t_bloco := -1.0             # quando o bloco da fruta atual começou
# "fruta/slot" -> {"zonas": int, "dano": float}
var _matriz := {}
var _bloco_idx := -1        # posição esperada na lista FRUTAS
var _desalinhado := false

func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0

func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	get_root().get_node("GameFlow").create_room()
	print("[HOST] sala criada — esperando o cliente...")

	for i in 1200:
		await process_frame
		_eu = _corpo("1")
		if _eu != null:
			break
	if _eu == null:
		print("[HOST] ❌ meu próprio corpo nunca apareceu"); quit(2); return
	_hp_inicial = float(_eu.health)
	print("[HOST] meu corpo='%s' hp=%.1f" % [_eu.name, _hp_inicial])

	_marcar_existentes()          # ignora o que já existia

	var esperou := 0
	while _cliente == null and esperou < 3000:
		await process_frame
		esperou += 1
		for n in get_nodes_in_group("player"):
			if n.name != "1":
				_cliente = n
	if _cliente == null:
		print("[HOST] ❌ o cliente nunca conectou"); quit(3); return
	_nome_cliente = str(_cliente.name)
	print("[HOST][t=%6.2f] cliente conectado -> corpo '%s'\n" % [_t(), _nome_cliente])

	# Janela de observação: cabe o roteiro inteiro com folga.
	var total := FRUTAS.size() * (ESPERA_FRUTA + SLOTS.size() * JANELA_SLOT) + 25.0
	var fim := Time.get_ticks_msec() + int(total * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
		_acompanhar_fruta()
		_varrer()
		if is_instance_valid(_cliente) and _cliente.get("cor_idx") != null:
			_cor_cliente = int(_cliente.get("cor_idx"))
		if not is_instance_valid(_cliente):
			print("[HOST][t=%6.2f] o cliente saiu — encerrando a observação" % _t())
			break

	_relatorio()
	# Sai 0 quando toda muda é conhecida: o teste falha por SURPRESA, não por
	# skill que legitimamente não cria hitbox.
	var inesperadas := _slots_mudos().filter(func(k): return not MUDAS_ESPERADAS.has(k))
	quit(0 if inesperadas.is_empty() else 1)

# ------------------------------------------------------------------ medição
# Onde o bloco da fruta começou. O host vê a troca porque `current_fruit_id`
# está no `SceneReplicationConfig` do jogador (ver `Main._make_player_sync`).
func _acompanhar_fruta() -> void:
	if not is_instance_valid(_cliente):
		return
	var f := str(_cliente.get("current_fruit_id"))
	if f != _fruta_atual:
		_fruta_atual = f
		_t_bloco = _t()
		if f != "":
			# ⚠️ A FRUTA DE NASCENÇA TAMBÉM É UM BLOCO. `Main._spawn_player_data`
			# equipa `mera_mera` no spawn, e essa troca ("" -> mera_mera) chega aqui
			# antes de o roteiro começar. Contá-la deslocava TODOS os blocos em um e
			# creditava cada fruta à anterior — silenciosamente, na primeira versão
			# desta sonda. Só começamos a contar quando a PRIMEIRA fruta do roteiro
			# aparece.
			if _bloco_idx < 0 and f != FRUTAS[0]:
				print("[HOST][t=%6.2f] (fruta de nascença '%s' — ignorada, o roteiro ainda não começou)"
					% [_t(), f])
				return
			_bloco_idx += 1
			# ⚠️ CONFERE A ORDEM. A atribuição de slot depende de o bloco observado
			# ser o bloco que o cliente diz estar rodando. Se a fruta de nascença
			# chegar atrasada (ela é `call_deferred`), o primeiro bloco vem com o
			# nome errado e TODAS as hitboxes dele são creditadas à fruta errada —
			# em silêncio. Acusar aqui é o que separa "medi" de "achei que medi".
			var esperada: String = FRUTAS[_bloco_idx] if _bloco_idx < FRUTAS.size() else "(fim)"
			if f != esperada:
				_desalinhado = true
				print("[HOST][t=%6.2f] ⚠️ bloco %d: esperava '%s' e veio '%s' — ATRIBUIÇÃO SUSPEITA"
					% [_t(), _bloco_idx, esperada, f])
			else:
				print("[HOST][t=%6.2f] ── bloco %d: %s" % [_t(), _bloco_idx, f])

func _slot_agora() -> String:
	if _t_bloco < 0.0 or _fruta_atual == "":
		return "?"
	var dt := _t() - _t_bloco - ESPERA_FRUTA
	if dt < 0.0:
		return "?"
	var i := int(dt / JANELA_SLOT)
	return SLOTS[i] if i >= 0 and i < SLOTS.size() else "?"

func _varrer() -> void:
	var cena := current_scene
	if cena == null:
		return
	_varrer_no(cena)

# ⚠️ RECURSIVA. Ver a nota do cabeçalho: as zonas moram dentro de
# `Skills_<jogador>`, não soltas na cena.
func _varrer_no(n: Node) -> void:
	if n is DamageZone and not _vistas.has(n.get_instance_id()):
		_vistas[n.get_instance_id()] = true
		var dono := "?"
		var cst = n.get("caster")
		if cst != null and is_instance_valid(cst):
			dono = str(cst.name)
		if dono == _nome_cliente:
			var dano: float = float(n.get("damage")) if n.get("damage") != null else 0.0
			_registrar(_fruta_atual, _slot_agora(), dano)
	for c in n.get_children():
		_varrer_no(c)

func _registrar(fruta: String, slot: String, dano: float) -> void:
	var k := "%s/%s" % [fruta, slot]
	if not _matriz.has(k):
		_matriz[k] = {"zonas": 0, "dano": 0.0}
	_matriz[k]["zonas"] += 1
	_matriz[k]["dano"] += dano

func _marcar_existentes() -> void:
	var cena := current_scene
	if cena == null:
		return
	_marcar_no(cena)

func _marcar_no(n: Node) -> void:
	if n is DamageZone:
		_vistas[n.get_instance_id()] = true
	for c in n.get_children():
		_marcar_no(c)

# --------------------------------------------------------------- relatório
func _slots_mudos() -> Array:
	var mudos: Array = []
	for f in FRUTAS:
		for s in SLOTS:
			var k := "%s/%s" % [f, s]
			if not _matriz.has(k) or int(_matriz[k]["zonas"]) == 0:
				mudos.append(k)
	return mudos

func _relatorio() -> void:
	print("\n╔═══════════════════════════════════════════════════════════════════╗")
	print("║  VARREDURA CLIENTE -> SERVIDOR — medida no processo do HOST        ║")
	print("╚═══════════════════════════════════════════════════════════════════╝")
	print("Cada célula = nº de DamageZone nascidas NO SERVIDOR com o cliente")
	print("como `caster`. 0 = o golpe do cliente NÃO virou hitbox autoritativa.\n")
	print("  fruta            Z         X         C         V")
	print("  ─────────────────────────────────────────────────────")
	for f in FRUTAS:
		var linha := "  %-14s" % f
		for s in SLOTS:
			var k := "%s/%s" % [f, s]
			var n: int = int(_matriz[k]["zonas"]) if _matriz.has(k) else 0
			linha += ("  %-8s" % ("—" if n == 0 else str(n)))
		print(linha)

	var mudos := _slots_mudos()
	var nao_atribuidas := 0
	for k in _matriz.keys():
		if str(k).ends_with("/?") or str(k).begins_with("/"):
			nao_atribuidas += int(_matriz[k]["zonas"])

	# CORES: o servidor escolhe e o dado de spawn replica. Se os dois corpos
	# tiverem o mesmo índice aqui, a atribuição está furada.
	var c_eu: int = int(_eu.get("cor_idx")) if _eu.get("cor_idx") != null else -1
	var c_cli := _cor_cliente
	print("\n   cores: host=%d (%s) | cliente=%d %s" % [
		c_eu, _eu.nome_da_cor(), c_cli,
		"✅ distintas" if c_eu != c_cli and c_eu >= 0 and c_cli >= 0 else "❌ IGUAIS OU AUSENTES"])

	print("   vida do host: %.1f -> %.1f (perdeu %.1f)" % [
		_hp_inicial, float(_eu.health), _hp_inicial - float(_eu.health)])
	if nao_atribuidas > 0:
		print("   ⚠️ %d zona(s) do cliente fora de qualquer janela de slot —" % nao_atribuidas)
		print("      efeito de vida longa cruzando a fronteira do bloco, provavelmente.")

	if _desalinhado:
		print("\n   ⚠️ A SEQUÊNCIA DE BLOCOS NÃO BATEU com a lista do cliente.")
		print("      A tabela acima pode estar creditando hitbox à fruta errada.")
		print("      Não tire conclusão dela sem antes reconciliar a ordem.")

	if mudos.is_empty():
		print("\n✅ TODAS as %d skills do cliente viraram hitbox no servidor." % (FRUTAS.size() * SLOTS.size()))
	else:
		print("\n❌ %d de %d NÃO chegaram como hitbox ao servidor:" % [
			mudos.size(), FRUTAS.size() * SLOTS.size()])
		var reais: Array = []
		for k in mudos:
			if MUDAS_ESPERADAS.has(k):
				print("     • %s  (esperada — %s)" % [k, MUDAS_ESPERADAS[k]])
			else:
				reais.append(k)
				print("     • %s  ⛔ NÃO EXPLICADA" % k)
		if reais.is_empty():
			print("\n   ✅ Todas as mudas são conhecidas e declaradas em MUDAS_ESPERADAS.")
		else:
			print("\n   ⛔ %d muda(s) SEM explicação — investigar." % reais.size())
		print("\n   Nem toda muda é bug: há skill que é CONTROLE puro (o Black Hole")
		print("   segura, não fere) e skill que só detona muito depois (os Vagalumes")
		print("   da Mera esperam 20 s). Compare com o `test_frutas.gd`, que mede o")
		print("   mesmo em UM processo: o que passa lá e falha aqui é bug DE REDE.")

func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if str(n.name) == nome:
			return n
	return null
