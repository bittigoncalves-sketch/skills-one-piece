class_name McComandos
extends RefCounted
# ============================================================================
#  COMANDOS EM TEXTO do Mine Piece (`performPrefixedCommand(fonte, "effect give @s …")`, 253 arquivos
#  do mod). E1: os que mudam o JOGO — effect, kill, data merge entity (NoAI, Invulnerable,
#  PersistenceRequired, Attributes), tp/teleport, attribute. Os que dependem de sistemas que ainda não
#  existem (title, advancement, team, setblock, spreadplayers, scale,
#  worldborder) são CONTADOS em `Mc.pedidos_sem_implementacao` ("comando:<nome>").
#  Seletores: @s, @p, @a. `execute … run X` executa X com a mesma fonte.
# ============================================================================


## `new CommandSourceStack(fonte, posição, rotação, mundo, permissão, nome, nome exibido, servidor, entidade)`.
class Fonte:
	extends RefCounted
	var posicao: McVec3 = McVec3.new()
	var mundo: McMundo
	var entidade: McEntidade
	func withSuppressedOutput() -> Fonte: return self
	func withPosition(p: McVec3) -> Fonte:
		var f := Fonte.new()
		f.posicao = p
		f.mundo = mundo
		f.entidade = entidade
		return f
	func getEntity() -> McEntidade: return entidade
	func getLevel() -> McMundo: return mundo
	func getPosition() -> McVec3: return posicao


## `CommandContext<CommandSourceStack>`: o que as procedures de comando do mod recebem em `arguments` (`EntityArgument.getEntities(arguments, "target")`,
## `DoubleArgumentType.getDouble(arguments, "amount")`…). Os valores já vêm resolvidos da linha de texto.
class Contexto:
	extends RefCounted
	var valores := {}                  # nome do argumento → valor (Array de McEntidade, float ou texto)
	var fonte: Fonte
	func getSource() -> Fonte: return fonte
	func valor(nome: String) -> Variant: return valores.get(nome)
	func alvos(nome: String) -> Array:
		var v: Variant = valores.get(nome)
		return v if v is Array else []


static func fonte_de(args: Array) -> Fonte:
	var f := Fonte.new()
	f.posicao = args[1] if args.size() > 1 and args[1] is McVec3 else McVec3.new()
	f.mundo = args[3] if args.size() > 3 and args[3] is McMundo else null
	f.entidade = args[8] if args.size() > 8 and args[8] is McEntidade else null
	return f


## Executa um comando. Devolve 1 se fez algo, 0 se não (como o resultado do Minecraft).
static func executar(fonte: Variant, texto: String) -> int:
	var f := fonte as Fonte
	var linha := texto.strip_edges().trim_prefix("/")
	if linha.begins_with("execute ") and " run " in linha:
		linha = linha.split(" run ", true, 1)[1]
	var p := linha.split(" ", false)
	if p.is_empty():
		return 0
	match p[0]:
		"effect": return _efeito(f, p)
		"kill": return _matar(f, p)
		"data": return _dados(f, linha)
		"tp", "teleport": return _teleportar(f, p)
		"attribute": return _atributo(f, p)
		"particle": return _particula(f, p)
		"playsound": return _som(f, p)
		"setblock": return _por_bloco(f, p)
		"advancement": return _conquista(f, p)
		"scale": return _escala(f, p)
		"spreadplayers": return _espalhar(f, p)
		"weather": return 1                     # o tempo do jogo é da ilha; só o relâmpago do mod interessa
		"fill": return _preencher(f, p)
		"stopsound": return 1                   # parar um som já tocando: os sons do jogo são curtos
		"minepiece": return _minepiece(f, p)
	Mc._falta("comando", p[0])
	return 0


# ------------------------------------------------------------ /minepiece … (os comandos do mod, `MinePieceCommandsLv2Command`)
## `minepiece bounty set|add|limit <alvo> <valor>`, `minepiece bounty query <alvo>`, `minepiece summon eastblue|grandline|newworld pirate|marine <1–20>`.
## Cada um chama a procedure do mod com um `Contexto`. O que o jogo já tem nativo (raid, PVP) não é redirecionado aqui.
const _REGIOES := {"eastblue": "EastBlue", "grandline": "GrandLine", "newworld": "NewWorld"}


static func _minepiece(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 3 or f == null or f.mundo == null:
		return 0
	var ctx := Contexto.new()
	ctx.fonte = f
	if p[1] == "bounty":
		var verbo := p[2]
		if p.size() < 4:
			return 0
		ctx.valores["target"] = alvos(f, p[3])
		if ctx.valores["target"].is_empty():
			return 0
		if verbo == "query":
			if f.entidade == null:
				return 0
			Mc.proc(&"MinepieceCommandQueryBountyProcedure").execute(ctx, f.entidade)
			return 1
		if p.size() < 5 or not p[4].is_valid_float():
			return 0
		ctx.valores["amount"] = float(p[4])
		match verbo:
			"set": Mc.proc(&"MinepieceCommandSetBountyProcedure").execute(f.mundo, ctx)
			"add": Mc.proc(&"MinepieceCommandAddBountyProcedure").execute(f.mundo, ctx)
			"limit": Mc.proc(&"MinepieceCommandSetBountyLimitProcedure").execute(f.mundo, ctx)
			_: return 0
		return 1
	if p[1] == "summon" and p.size() >= 5 and _REGIOES.has(p[2]) and p[3] in ["pirate", "marine"] and p[4].is_valid_float():
		var n := float(p[4])
		if n < 1.0 or n > 20.0:
			return 0                            # o mod limita a 1–20 (`doubleArg(1.0, 20.0)`)
		ctx.valores["number"] = n
		var nome := "CommandSummon%s%sProcedure" % ["Pirate" if p[3] == "pirate" else "Marine", _REGIOES[p[2]]]
		Mc.proc(StringName(nome)).execute(f.mundo, f.posicao.x, f.posicao.y, f.posicao.z, ctx)
		return 1
	Mc._falta("comando", "minepiece " + " ".join(p.slice(1, 3)))
	return 0


# ------------------------------------------------------------ particle / playsound
## `particle <nome> [x y z [dx dy dz velocidade [quantidade [force|normal [quem]]]]]` (Minecraft 1.20.1).
## Sem posição, é a da fonte; `~` é relativo a ela. Quantidade 0 = UMA partícula que anda na direção (dx,dy,dz).
## `dust r g b tamanho` traz a cor no próprio nome. Nome que o jogo original não conhece é erro do comando
## ("Unknown particle") — não faz nada e não conta como falta nossa.
static func _particula(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 2 or f == null or f.mundo == null:
		return 0
	var nome := _id(p[1])
	var i := 2
	var cor := Color(0, 0, 0, 0)
	if nome == "minecraft:dust":
		if p.size() < 6:
			return 0
		cor = Color(clampf(float(p[2]), 0.0, 1.0), clampf(float(p[3]), 0.0, 1.0), clampf(float(p[4]), 0.0, 1.0))
		i = 6
	var base := f.posicao
	var x := base.x
	var y := base.y
	var z := base.z
	if p.size() >= i + 3:
		x = _coord(p[i], base.x)
		y = _coord(p[i + 1], base.y)
		z = _coord(p[i + 2], base.z)
		i += 3
	var dx := 0.0
	var dy := 0.0
	var dz := 0.0
	var vel := 0.0
	var n := 0
	if p.size() >= i + 4:
		dx = float(p[i])
		dy = float(p[i + 1])
		dz = float(p[i + 2])
		vel = float(p[i + 3])
		n = int(p[i + 4]) if p.size() > i + 4 else 0
	if not McVisual.particula(f.mundo.arvore, nome, McVec3.de(x, y, z), n, dx, dy, dz, vel, cor):
		if not McVisual.particula_existe(nome):
			return 0
		Mc._falta("particula", nome)
		return 0
	return maxi(n, 1)


## `playsound <som> <fonte> <alvos> [x y z [volume [tom [volumeMín]]]]`. Num jogo só, todo som é ouvido por quem
## está perto (3D); a posição padrão é a da fonte do comando. Som sem arquivo extraído é contado.
static func _som(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 4 or f == null or f.mundo == null:
		return 0
	var base := f.posicao
	var pos := McVec3.de(base.x, base.y, base.z)
	var i := 4
	if p.size() >= i + 3:
		pos = McVec3.de(_coord(p[i], base.x), _coord(p[i + 1], base.y), _coord(p[i + 2], base.z))
		i += 3
	var volume := float(p[i]) if p.size() > i else 1.0
	var tom := float(p[i + 1]) if p.size() > i + 1 else 1.0
	if McVisual.som(f.mundo.arvore, _id(p[1]), pos, volume, tom):
		return 1
	Mc._falta("som", _id(p[1]))
	return 0


# ------------------------------------------------------------ setblock / fill
const MAX_FILL := 4096                               # o do Minecraft é 32768; o jogo limita a sobreposição

## `setblock <x y z> <bloco> [destroy|keep|replace]`: `keep` só põe onde há ar.
static func _por_bloco(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 5 or f == null or f.mundo == null:
		return 0
	var base := f.posicao
	var pos := McVec3.de(floorf(_coord(p[1], base.x)), floorf(_coord(p[2], base.y)), floorf(_coord(p[3], base.z)))
	var modo := p[5] if p.size() > 5 else "replace"
	if modo == "keep" and not f.mundo.getBlockState(pos).isAir():
		return 0
	var estado := McBloco.Estado.de(Mc.bloco(StringName(_id(_sem_propriedades(p[4])))))
	return 1 if f.mundo.setBlock(pos, estado, 3) else 0


## `fill <x1 y1 z1> <x2 y2 z2> <bloco> [replace [filtro]|destroy|keep|hollow|outline]`.
static func _preencher(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 8 or f == null or f.mundo == null:
		return 0
	var base := f.posicao
	var a := Vector3i(floori(_coord(p[1], base.x)), floori(_coord(p[2], base.y)), floori(_coord(p[3], base.z)))
	var b := Vector3i(floori(_coord(p[4], base.x)), floori(_coord(p[5], base.y)), floori(_coord(p[6], base.z)))
	var lo := a.min(b)
	var hi := a.max(b)
	var n := (hi.x - lo.x + 1) * (hi.y - lo.y + 1) * (hi.z - lo.z + 1)
	if n > MAX_FILL:
		Mc._falta("comando", "fill:grande_demais")
		return 0
	var id := StringName(_id(_sem_propriedades(p[7])))
	var modo := p[8] if p.size() > 8 else "replace"
	var filtro := StringName(_id(_sem_propriedades(p[9]))) if modo == "replace" and p.size() > 9 else &""
	var feitos := 0
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var casca := x == lo.x or x == hi.x or y == lo.y or y == hi.y or z == lo.z or z == hi.z
				if modo == "hollow" and not casca:
					continue
				if modo == "outline" and not casca:
					continue
				var pos := McVec3.de(float(x), float(y), float(z))
				var atual := f.mundo.getBlockState(pos)
				if modo == "keep" and not atual.isAir():
					continue
				if filtro != &"" and atual.bloco.id != filtro:
					continue
				var alvo := &"minecraft:air" if (modo == "hollow" and not casca) else id
				if f.mundo.setBlock(pos, McBloco.Estado.de(Mc.bloco(alvo)), 3):
					feitos += 1
	return feitos


## `minecraft:ice[facing=north]{…}` → `minecraft:ice`.
static func _sem_propriedades(t: String) -> String:
	for corte in ["[", "{"]:
		if corte in t:
			t = t.substr(0, t.find(corte))
	return t


# ------------------------------------------------------------ seletores
static func alvos(f: Fonte, seletor: String) -> Array:
	if f == null:
		return []
	var tipo := seletor.substr(0, 2)
	match tipo:
		"@s":
			return [f.entidade] if f.entidade != null else []
		"@p", "@a":
			var arvore := f.mundo.arvore if f.mundo != null else (f.entidade.no.get_tree() if f.entidade != null else null)
			if arvore == null:
				return []
			var jogadores := arvore.get_nodes_in_group("player").map(func(n): return McEntidade.de(n))
			if tipo == "@a" or jogadores.is_empty():
				return jogadores
			jogadores.sort_custom(func(a, b): return a.position().distanceToSqr(f.posicao) < b.position().distanceToSqr(f.posicao))
			return [jogadores[0]]
	Mc._falta("seletor", seletor)
	return []


# ------------------------------------------------------------ effect give|clear
static func _efeito(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 3:
		return 0
	var feitos := 0
	for e: McEntidade in alvos(f, p[2]):
		if p[1] == "clear":
			if p.size() > 3:
				feitos += int(e.removeEffect(Mc.efeito(StringName(_id(p[3])))))
			else:
				feitos += int(e.removeAllEffects())
		elif p[1] == "give" and p.size() > 3:
			# effect give <alvo> <efeito> [segundos|infinite] [amplificador] [esconder partículas]
			var segundos := p[4] if p.size() > 4 else "30"
			var ticks := -1 if segundos == "infinite" else int(float(segundos) * 20.0)
			var amp := int(p[5]) if p.size() > 5 else 0
			var esconder := p.size() > 6 and p[6] == "true"
			feitos += int(e.addEffect(McEfeito.instancia(Mc.efeito(StringName(_id(p[3]))), ticks, amp, false, not esconder, not esconder)))
	return feitos


## `minepiece:stun` fica; `speed` vira `minecraft:speed`.
static func _id(t: String) -> String:
	return t if ":" in t else "minecraft:" + t


# ------------------------------------------------------------ kill
static func _matar(f: Fonte, p: PackedStringArray) -> int:
	var lista := alvos(f, p[1] if p.size() > 1 else "@s")
	var mortos := 0
	for e: McEntidade in lista:
		# Aliado permanente do jogador (guerreiro de biscoito, pedido do dono): o `tick` do mod o apaga com `kill @s` ao fim do ataque (modo 1) ou
		# por tempo de vida; enquanto o DONO está vivo o comando é ignorado. Dono morto/ausente: morre como no mod.
		if e.valida() and e.no.has_meta("aliado_permanente"):
			var dono: Variant = e.no.get_meta("dono_no") if e.no.has_meta("dono_no") else null
			if dono is Node and is_instance_valid(dono) and float(dono.get("health")) > 0.0:
				continue
		e.kill()
		mortos += 1
	return mortos


# ------------------------------------------------------------ data merge entity <alvo> {SNBT}
## Só as marcas que o mod usa: NoAI, Invulnerable, PersistenceRequired, LeftHanded e
## Attributes:[{Name:generic.x,Base:v}] (medido: 201 comandos, só estas chaves).
static func _dados(f: Fonte, linha: String) -> int:
	var m := RegEx.create_from_string(r"^data merge entity (\S+) (\{.*\})\s*$").search(linha)
	if m == null:
		Mc._falta("comando", "data " + linha.split(" ")[1] if linha.split(" ").size() > 1 else "data")
		return 0
	var snbt := m.get_string(2)
	var feitos := 0
	for e: McEntidade in alvos(f, m.get_string(1)):
		for marca in ["NoAI", "Invulnerable", "PersistenceRequired", "LeftHanded"]:
			var v := RegEx.create_from_string(marca + r":(\d)b?").search(snbt)
			if v != null:
				e.definir_marca(marca, v.get_string(1) != "0")
		for a in RegEx.create_from_string(r"\{Name:(?:minecraft:)?generic\.(\w+),Base:([-\d.]+)[df]?\}").search_all(snbt):
			e.getAttribute(Mc.atributo(StringName("minecraft:" + a.get_string(1)))).setBaseValue(float(a.get_string(2)))
		feitos += 1
	return feitos


# ------------------------------------------------------------ tp / teleport
static func _teleportar(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 5:
		Mc._falta("comando", "tp (formato)")
		return 0
	var feitos := 0
	for e: McEntidade in alvos(f, p[1]):
		var base := e.position()
		e.teleportTo(_coord(p[2], base.x), _coord(p[3], base.y), _coord(p[4], base.z))
		feitos += 1
	return feitos


## `scale set|add|subtract|get|reset pehkui:<height|width|reach> [valor] <alvos>` (mod Pehkui). Outros tipos de escala
## (motion, drops…) o Mine Piece não usa: contados como falta.
static func _escala(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 4:
		Mc._falta("comando", "scale (formato)")
		return 0
	var modo := p[1]
	var tipo := StringName(p[2].trim_prefix("pehkui:"))
	if not (tipo in [&"height", &"width", &"reach"]):
		Mc._falta("comando", "scale:" + String(tipo))
		return 0
	var valor := float(p[3]) if modo in ["set", "add", "subtract"] and p.size() >= 5 else 0.0
	var feitos := 0
	for e: McEntidade in alvos(f, p[p.size() - 1]):
		var atual := e.escala(tipo)
		match modo:
			"set": e.definirEscala(tipo, valor)
			"add": e.definirEscala(tipo, atual + valor)
			"subtract": e.definirEscala(tipo, atual - valor)
			"reset": e.definirEscala(tipo, 1.0)
			"get": pass
			_: return 0
		feitos += 1
	return feitos


## `advancement grant|revoke <alvos> only|until|from|through <conquista> | everything`.
##   only X = só X; until X = X e os ANCESTRAIS (da raiz até X); from X = X e os DESCENDENTES; through = os dois.
## Conceder = todos os critérios que faltam (completa e dispara o AdvancementEvent, como o `award`); revogar = tira todos.
static func _conquista(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 3 or not (p[1] in ["grant", "revoke"]):
		Mc._falta("comando", "advancement (formato)")
		return 0
	var defs := McConquistas.definicoes()
	var escolhidas: Array = []
	if p[3 if p.size() > 3 else 2] == "everything":
		escolhidas = defs.values()
	elif p.size() >= 5:
		var alvo: Variant = defs.get(_id(p[4]))
		if alvo == null:
			return 0
		escolhidas = _ramo(defs, alvo, p[3])
	else:
		return 0
	var feitos := 0
	for e: McEntidade in alvos(f, p[2]):
		var av = e.getAdvancements()
		if not (av is McConquistas.Avancos):
			continue
		for d: McConquistas.Def in escolhidas:
			for c in d.criterios:
				if (av.award(d, c) if p[1] == "grant" else av.revoke(d, c)):
					feitos += 1
	return feitos


static func _ramo(defs: Dictionary, alvo: McConquistas.Def, modo: String) -> Array:
	var saida: Array = [alvo]
	if modo in ["until", "through"]:
		var d: McConquistas.Def = alvo
		while d.pai != "" and defs.has(d.pai):
			d = defs[d.pai]
			saida.push_front(d)                    # da raiz até a alvo: os ancestrais concluem antes dos filhos
	if modo in ["from", "through"]:
		var fila: Array = [alvo]
		while not fila.is_empty():
			var atual: McConquistas.Def = fila.pop_front()
			for outra: McConquistas.Def in defs.values():
				if outra != null and outra.pai == atual.id and not saida.has(outra):
					saida.append(outra)
					fila.append(outra)
	return saida


## `spreadplayers <x> <z> <distânciaMínima> <raioMáximo> [under <altura>] <respeitaEquipes> <alvos>`:
## cada alvo cai num ponto sorteado no círculo de raio máximo (x,z do centro), no mesmo y — a gravidade assenta.
## Sem a checagem da distância mínima entre alvos (um alvo só nas procedures do mod).
static func _espalhar(f: Fonte, p: PackedStringArray) -> int:
	# 1.20.1 exige `respeitaEquipes` (true|false) antes dos alvos. O mod tem `spreadplayers ~ ~ 5 10 @s`
	# (sem ele): no original o comando é rejeitado e não faz nada — e aqui também (erro do comando, não falta).
	if p.size() < 7 or not (p[p.size() - 2] in ["true", "false"]):
		return 0
	var feitos := 0
	var raio := maxf(0.0, float(p[4]))
	for e: McEntidade in alvos(f, p[p.size() - 1]):
		var base := e.position()
		var cx := _coord(p[1], base.x)
		var cz := _coord(p[2], base.z)
		var ang := randf() * TAU
		var dist := sqrt(randf()) * raio
		var px := cx + cos(ang) * dist
		var pz := cz + sin(ang) * dist
		e.teleportTo(px, _y_da_superficie(e, px, pz, base.y), pz)
		feitos += 1
	return feitos


## O y onde o `spreadplayers` pousa o alvo: a superfície mais alta de (x, z) perto da altura dele (o vanilla pousa no topo do
## chão, não no y de partida). Sem isso o Kuro do Shakushi (2 saltos por tick, até 28 m de distância) nascia no ar ou DENTRO do
## morro e a colisão o cuspia para cima — "saiu voando para longe" (11/11/2026). Sem chão no raio, fica o y de partida.
## Unidades de blocos (como `teleportTo`); o raio do mundo é em metros.
const _SUPERFICIE_ACIMA_M := 40.0
const _SUPERFICIE_ABAIXO_M := 80.0

static func _y_da_superficie(e: McEntidade, x: float, z: float, y_atual: float) -> float:
	if e.no == null or not e.no.is_inside_tree():
		return y_atual
	var b := McEntidade.B
	var topo := e.no.global_position.y + _SUPERFICIE_ACIMA_M
	var q := PhysicsRayQueryParameters3D.create(Vector3(x * b, topo, z * b),
			Vector3(x * b, topo - _SUPERFICIE_ACIMA_M - _SUPERFICIE_ABAIXO_M, z * b), MundoMinePiece.MASCARA_MUNDO)
	if e.no is CollisionObject3D:
		q.exclude = [(e.no as CollisionObject3D).get_rid()]
	var h := e.no.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h["position"].y) / b + 0.05 if not h.is_empty() else y_atual


## `~` relativo, `~2.5`, ou absoluto.
static func _coord(t: String, base: float) -> float:
	if t.begins_with("~"):
		return base + (float(t.substr(1)) if t.length() > 1 else 0.0)
	return float(t)


# ------------------------------------------------------------ attribute <alvo> <atributo> base set|get [v]
static func _atributo(f: Fonte, p: PackedStringArray) -> int:
	if p.size() < 5 or p[3] != "base":
		Mc._falta("comando", "attribute (formato)")
		return 0
	var feitos := 0
	for e: McEntidade in alvos(f, p[1]):
		var id := p[2].trim_prefix("minecraft:").trim_prefix("generic.")
		var inst := e.getAttribute(Mc.atributo(StringName("minecraft:" + id if not ":" in p[2] or p[2].begins_with("minecraft:") else p[2])))
		if inst == null:
			continue
		if p[4] == "set" and p.size() > 5:
			inst.setBaseValue(float(p[5]))
		feitos += 1
	return feitos
