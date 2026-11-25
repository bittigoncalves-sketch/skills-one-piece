class_name InventarioMinecraft
extends RefCounted
## INVENTÁRIO ESTILO MINECRAFT do jogador (10/11/2026; layout e ordem medidos no jar 1.20.1 pelo REA — `docs/INVENTARIO_MINECRAFT.md`).
## Slots na ordem do `InventoryMenu`: 0 resultado · 1–4 grade 2×2 · 5–8 armadura (cabeça, peito, pernas, pés) · 9–35 mochila · 36–44 hotbar · 45 mão secundária.
## Pilhas são `McItem.Pilha` (a mesma da camada Minecraft: `ItemStack`). Cliques seguem o Minecraft (esquerdo/direito/shift/número). Só o MODELO: a janela é
## `MochilaMinecraft`; quem põe item aqui é o mod (`ItemHandlerHelper.giveItemToPlayer` → `ItensDoMod`) ou a janela.
signal mudou

const RESULTADO := 0
const GRADE_INI := 1
const GRADE_FIM := 5               # exclusivo
const ARMADURA_INI := 5
const ARMADURA_FIM := 9
const MOCHILA_INI := 9
const MOCHILA_FIM := 36
const HOTBAR_INI := 36
const HOTBAR_FIM := 45
const MAO_SECUNDARIA := 45
const TOTAL := 46

var slots: Array = []
var cursor: McItem.Pilha = McItem.pilha(null, 0)
var selecionado := 0               # slot da hotbar na mão (0..8)


func _init() -> void:
	for i in TOTAL:
		slots.append(McItem.pilha(null, 0))


static func vazia() -> McItem.Pilha:
	return McItem.pilha(null, 0)


static func nova(id: String, quantidade: int = 1) -> McItem.Pilha:
	return McItem.pilha(Mc.item(StringName(id)), quantidade)


static func id_de(p: McItem.Pilha) -> String:
	return "" if p == null or p.isEmpty() else String(p.item.id)


func pilha(i: int) -> McItem.Pilha:
	return slots[i]


func na_mao() -> McItem.Pilha:
	return slots[HOTBAR_INI + selecionado]


func aceita(i: int, p: McItem.Pilha) -> bool:
	if i == RESULTADO:
		return false
	if p == null or p.isEmpty():
		return true
	if i >= ARMADURA_INI and i < ARMADURA_FIM:
		return RegrasDeItens.peca_de_armadura(id_de(p)) == i - ARMADURA_INI
	return true


func limite_de(p: McItem.Pilha) -> int:
	return RegrasDeItens.limite(id_de(p))


func _igual(a: McItem.Pilha, b: McItem.Pilha) -> bool:
	return not a.isEmpty() and not b.isEmpty() and a.item == b.item and a.dano == b.dano


func _avisar() -> void:
	_recalcular_resultado()
	mudou.emit()


func _recalcular_resultado() -> void:
	var grade: Array = []
	for i in range(GRADE_INI, GRADE_FIM):
		grade.append(slots[i])
	var r := ReceitasMinecraft.achar(grade)
	slots[RESULTADO] = nova(str(r.id), int(r.count)) if not r.is_empty() else vazia()


## Esvazia TUDO no próprio objeto (a janela da mochila guarda a referência, então não se troca o inventário): slots, grade, armadura, mão secundária e cursor. Um aviso só.
## Quantos itens (pilhas) havia, para o aviso ao jogador (22/11/2026: a derrota da Alvida).
## `poupar_frutas`: as Akuma e as frutas do pomar ficam (são permanentes: antes eram uma lista à parte da mochila, e a derrota da Alvida nunca as tirava).
func esvaziar(poupar_frutas := false) -> int:
	var havia := 0
	for i in range(GRADE_INI, TOTAL):
		if poupar_frutas and ItensDeFruta.e_de(id_de(slots[i])):
			continue
		if not slots[i].isEmpty():
			havia += 1
		slots[i] = vazia()
	if not cursor.isEmpty() and not (poupar_frutas and ItensDeFruta.e_de(id_de(cursor))):
		havia += 1
		cursor = vazia()
	_avisar()
	return havia


# ------------------------------------------------------------------ inserir / contar / remover
## Soma `p` ao inventário (hotbar e mochila; completa pilhas antes de usar vagas). Devolve o que NÃO coube.
func inserir(p: McItem.Pilha) -> McItem.Pilha:
	if p == null or p.isEmpty():
		return vazia()
	var resto := p.copy()
	var ordem: Array[int] = []
	for i in range(HOTBAR_INI, HOTBAR_FIM):
		ordem.append(i)
	for i in range(MOCHILA_INI, MOCHILA_FIM):
		ordem.append(i)
	ordem.append(MAO_SECUNDARIA)
	var lim := limite_de(resto)
	for i in ordem:
		if resto.isEmpty():
			break
		var s: McItem.Pilha = slots[i]
		if _igual(s, resto) and s.quantidade < lim:
			var n := mini(lim - s.quantidade, resto.quantidade)
			s.quantidade += n
			resto.quantidade -= n
	for i in ordem:
		if resto.isEmpty():
			break
		if slots[i].isEmpty() and i != MAO_SECUNDARIA:
			var n := mini(lim, resto.quantidade)
			var novo := resto.copy()
			novo.quantidade = n
			slots[i] = novo
			resto.quantidade -= n
	_avisar()
	return vazia() if resto.quantidade <= 0 else resto


## Cabe ao menos 1 do item `id` em hotbar/mochila (vaga livre ou pilha dele incompleta)?
func pode_receber(id: String) -> bool:
	var limite := RegrasDeItens.limite(id)
	for i in range(MOCHILA_INI, HOTBAR_FIM):
		if slots[i].isEmpty() or (id_de(slots[i]) == id and slots[i].quantidade < limite):
			return true
	return false


func contar(id: String) -> int:
	var total := 0
	for i in range(MOCHILA_INI, TOTAL):
		if id_de(slots[i]) == id:
			total += slots[i].quantidade
	return total


## Tira `n` do item `id` (hotbar/mochila/mão secundária). false e nada some se não houver o bastante.
func remover(id: String, n: int) -> bool:
	if n <= 0:
		return true
	if contar(id) < n:
		return false
	var falta := n
	for i in range(MOCHILA_INI, TOTAL):
		if falta <= 0:
			break
		if id_de(slots[i]) == id:
			var t := mini(slots[i].quantidade, falta)
			slots[i].quantidade -= t
			falta -= t
			if slots[i].quantidade <= 0:
				slots[i] = vazia()
	_avisar()
	return true


# ------------------------------------------------------------------ cliques (a mecânica do Minecraft)
## `botao`: 0 esquerdo, 1 direito. `shift`: mover rápido.
func clique(i: int, botao := 0, shift := false) -> void:
	if i < 0 or i >= TOTAL:
		return
	if i == RESULTADO:
		_clique_no_resultado(shift)
		return
	if shift:
		_mover_rapido(i)
		_avisar()
		return
	var s: McItem.Pilha = slots[i]
	if cursor.isEmpty():
		if s.isEmpty():
			return
		if botao == 0:
			cursor = s
			slots[i] = vazia()
		else:
			var metade := (s.quantidade + 1) / 2
			cursor = s.copy()
			cursor.quantidade = metade
			s.quantidade -= metade
			if s.quantidade <= 0:
				slots[i] = vazia()
	else:
		if not aceita(i, cursor):
			_avisar()
			return
		var lim := limite_de(cursor)
		if s.isEmpty():
			var n := cursor.quantidade if botao == 0 else 1
			n = mini(n, lim)
			var novo := cursor.copy()
			novo.quantidade = n
			slots[i] = novo
			cursor.quantidade -= n
		elif _igual(s, cursor):
			var n := mini(cursor.quantidade if botao == 0 else 1, lim - s.quantidade)
			s.quantidade += n
			cursor.quantidade -= n
		else:
			var tmp := s
			slots[i] = cursor
			cursor = tmp
		if cursor.quantidade <= 0:
			cursor = vazia()
	_avisar()


func _clique_no_resultado(shift: bool) -> void:
	var r: McItem.Pilha = slots[RESULTADO]
	if r.isEmpty():
		return
	if shift:
		for _k in 64:
			r = slots[RESULTADO]
			if r.isEmpty() or not _cabe(r):
				break
			inserir(r.copy())
			_consumir_grade()
			_recalcular_resultado()
		_avisar()
		return
	if cursor.isEmpty() or (_igual(cursor, r) and cursor.quantidade + r.quantidade <= limite_de(r)):
		if cursor.isEmpty():
			cursor = r.copy()
		else:
			cursor.quantidade += r.quantidade
		_consumir_grade()
	_avisar()


func _consumir_grade() -> void:
	for i in range(GRADE_INI, GRADE_FIM):
		if not slots[i].isEmpty():
			slots[i].quantidade -= 1
			if slots[i].quantidade <= 0:
				slots[i] = vazia()


## Cabe ao menos um `p` inteiro no inventário?
func _cabe(p: McItem.Pilha) -> bool:
	var lim := limite_de(p)
	for i in range(MOCHILA_INI, MAO_SECUNDARIA):
		var s: McItem.Pilha = slots[i]
		if s.isEmpty() or (_igual(s, p) and s.quantidade + p.quantidade <= lim):
			return true
	return false


func _mover_rapido(i: int) -> void:
	var p: McItem.Pilha = slots[i]
	if p.isEmpty():
		return
	var peca := RegrasDeItens.peca_de_armadura(id_de(p))
	if i >= MOCHILA_INI and peca >= 0 and slots[ARMADURA_INI + peca].isEmpty():
		slots[ARMADURA_INI + peca] = p
		slots[i] = vazia()
		return
	var ini := MOCHILA_INI
	var fim := HOTBAR_FIM
	if i >= MOCHILA_INI and i < MOCHILA_FIM:
		ini = HOTBAR_INI
		fim = HOTBAR_FIM
	elif i >= HOTBAR_INI and i < HOTBAR_FIM:
		ini = MOCHILA_INI
		fim = MOCHILA_FIM
	var resto := _guardar_em(p, ini, fim)
	slots[i] = resto if resto != null and not resto.isEmpty() else vazia()


func _guardar_em(p: McItem.Pilha, ini: int, fim: int) -> McItem.Pilha:
	var resto := p.copy()
	var lim := limite_de(resto)
	for i in range(ini, fim):
		var s: McItem.Pilha = slots[i]
		if _igual(s, resto) and s.quantidade < lim:
			var n := mini(lim - s.quantidade, resto.quantidade)
			s.quantidade += n
			resto.quantidade -= n
	for i in range(ini, fim):
		if resto.quantidade <= 0:
			break
		if slots[i].isEmpty():
			var n := mini(lim, resto.quantidade)
			var novo := resto.copy()
			novo.quantidade = n
			slots[i] = novo
			resto.quantidade -= n
	return vazia() if resto.quantidade <= 0 else resto


## Tecla 1–9 com o mouse sobre o slot `i`: troca com a hotbar.
func trocar_com_hotbar(i: int, n: int) -> void:
	var h := HOTBAR_INI + n
	if i == RESULTADO or i == h or n < 0 or n > 8:
		return
	if not aceita(i, slots[h]) or not aceita(h, slots[i]):
		return
	var tmp: McItem.Pilha = slots[i]
	slots[i] = slots[h]
	slots[h] = tmp
	_avisar()


## Fecha a janela: o que está no cursor e na grade volta para o inventário (o que não couber fica onde está).
func fechar() -> void:
	if not cursor.isEmpty():
		cursor = inserir(cursor)
	for i in range(GRADE_INI, GRADE_FIM):
		if not slots[i].isEmpty():
			var resto := inserir(slots[i])
			slots[i] = resto
	_avisar()


# ------------------------------------------------------------------ salvar / carregar
func para_dict() -> Dictionary:
	var s := {}
	for i in range(GRADE_INI, TOTAL):
		if not slots[i].isEmpty():
			s[str(i)] = {"id": id_de(slots[i]), "n": slots[i].quantidade, "d": slots[i].dano}
	return {"slots": s, "sel": selecionado}


static func de_dict(d: Variant) -> InventarioMinecraft:
	var inv := InventarioMinecraft.new()
	if not (d is Dictionary):
		return inv
	var s: Variant = d.get("slots", {})
	if s is Dictionary:
		for k in s:
			var i := int(str(k))
			var e: Variant = s[k]
			if i >= GRADE_INI and i < TOTAL and e is Dictionary and not str(e.get("id", "")).is_empty() and int(e.get("n", 0)) > 0:
				var p := nova(str(e["id"]), int(e["n"]))
				p.dano = int(e.get("d", 0))
				inv.slots[i] = p
	inv.selecionado = clampi(int(d.get("sel", 0)), 0, 8)
	inv._recalcular_resultado()
	return inv
