class_name OperacoesDoEditor
extends RefCounted
# ============================================================================
#  OPERAÇÕES do editor de mapa — tudo o que MUDA o documento, sem nó nenhum.
#
#  O `EditorDeMapa` só traduz mouse e teclado em chamadas daqui. Separado por dois
#  motivos: o teste chama as operações exatamente como o editor chama (sem simular
#  clique), e o orquestrador não passa do teto de 900 linhas.
#
#  Toda operação passa pelo `HistoricoDeEdicao` — é isso que faz o Ctrl+Z valer
#  para qualquer uma. A exceção declarada são as `*_sem_historico`, que existem
#  para arraste e seletor de cor: quem chama abre e fecha a transação.
# ============================================================================

const ROTULO_TIPO := {"caixa": "Caixa", "esfera": "Esfera", "cilindro": "Cilindro", "cunha": "Cunha", "modelo": "Modelo",
	"terreno": "Terreno", "area_animais": "Área de animais"}
const PASSO_GIRAR_GRAUS := 15.0


static func inserir(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor,
		tipo: String, posicao: Vector3, passo: float) -> String:
	var id := doc.novo_id(tipo)
	var p := DocumentoMapa.peca_padrao(tipo, id, _grudar_vetor(posicao, passo))
	hist.executar("Inserir %s" % ROTULO_TIPO.get(tipo, tipo), func(): doc.definir_peca(id, p))
	sel.definir([id])
	return id


## Modelo da loja. A grade gruda só X e Z: a altura vem do chão onde ele pousa, e
## grudar o Y afundaria ou faria flutuar todo modelo que não tem altura redonda.
static func inserir_modelo(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor,
		modelo_id: String, tamanho: Vector3, posicao: Vector3, passo: float, colisao := true) -> String:
	var id := doc.novo_id(modelo_id)
	var pousada := posicao
	if passo > 0.0:
		pousada = Vector3(snappedf(posicao.x, passo), posicao.y, snappedf(posicao.z, passo))
	var p := DocumentoMapa.peca_modelo(id, modelo_id, tamanho, pousada)
	p["colisao"] = colisao       # modelo atravessável (plantação) entra sem colisão
	hist.executar("Inserir modelo", func(): doc.definir_peca(id, p))
	sel.definir([id])
	return id


## Quantas peças do documento usam o modelo (a loja avisa antes de apagar).
static func usos_do_modelo(doc: DocumentoMapa, modelo_id: String) -> int:
	var n := 0
	for id in doc.ids():
		var p := doc.peca(id)
		if p["tipo"] == "modelo" and p.get("modelo", "") == modelo_id:
			n += 1
	return n


## Cópia logo ACIMA do original (encostada no topo), para ficar à vista e não
## nascer dentro dele. O spawn não duplica.
## Grupo duplica a SUBÁRVORE inteira (grupos novos, peças novas), no mesmo pai.
static func duplicar(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor) -> Array[String]:
	var novos: Array[String] = []
	var originais := _itens_existentes(doc, sel)
	if originais.is_empty():
		return novos
	hist.iniciar("Duplicar")
	for id in originais:
		var subida := Vector3.UP * _altura_do_item(doc, id)
		novos.append(_copiar_item(doc, id, doc.pai_de(id), subida))
	hist.concluir()
	sel.definir(novos)
	return novos


static func _copiar_item(doc: DocumentoMapa, id: String, novo_pai: String, deslocamento: Vector3) -> String:
	if doc.tem(id):
		var p := doc.peca(id)
		var novo := doc.novo_id(id)
		p["id"] = novo
		p["grupo"] = novo_pai
		p["posicao"] = (p["posicao"] as Vector3) + deslocamento
		doc.definir_peca(novo, p)
		return novo
	var gid := doc.novo_id(id)
	doc.definir_grupo(gid, {"id": gid, "pai": novo_pai})
	for filho in doc.filhos_de(id):
		_copiar_item(doc, filho, gid, deslocamento)
	return gid


## Altura da caixa (alinhada ao mundo, aproximada pelos tamanhos) de um item.
static func _altura_do_item(doc: DocumentoMapa, id: String) -> float:
	var minimo := INF
	var maximo := -INF
	for pid in doc.pecas_de(id):
		var p := doc.peca(pid)
		var meia: float = (p["tamanho"] as Vector3).y * 0.5
		minimo = minf(minimo, (p["posicao"] as Vector3).y - meia)
		maximo = maxf(maximo, (p["posicao"] as Vector3).y + meia)
	return maxf(maximo - minimo, 0.0) if minimo != INF else 0.0


## Apagar um grupo apaga tudo dentro dele. Devolve quantas PEÇAS saíram.
static func apagar(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor) -> int:
	var itens := _itens_existentes(doc, sel)
	if itens.is_empty():
		return 0
	var pecas := pecas_da_selecao(doc, sel)
	hist.iniciar("Apagar")
	for pid in pecas:
		doc.remover_peca(pid)
	podar_grupos_vazios(doc)
	hist.concluir()
	sel.podar(doc)
	return pecas.size()


## Grupo sem nenhuma peça abaixo dele não tem o que agrupar — some.
static func podar_grupos_vazios(doc: DocumentoMapa) -> void:
	var removeu := true
	while removeu:
		removeu = false
		for gid in doc.grupos_ids():
			if doc.pecas_de(gid).is_empty():
				doc.remover_grupo(gid)
				removeu = true


# ------------------------------------------------------------ agrupar (Ctrl+G)
## Dois ou mais itens viram um grupo novo. Se todos tinham o mesmo pai, o grupo
## novo nasce dentro dele; senão, no topo. Devolve o id do grupo ("" = nada feito).
static func agrupar(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor) -> String:
	var itens := _itens_existentes(doc, sel)
	if itens.size() < 2:
		return ""
	var pai := doc.pai_de(itens[0])
	for id in itens:
		if doc.pai_de(id) != pai:
			pai = ""
			break
	var gid := doc.novo_id("grupo")
	hist.iniciar("Agrupar")
	doc.definir_grupo(gid, {"id": gid, "pai": pai})
	for id in itens:
		_mudar_pai(doc, id, gid)
	hist.concluir()
	sel.definir([gid])
	return gid


## Um grupo selecionado se desfaz UM nível: os filhos diretos sobem para o pai
## dele. Grupo dentro de grupo continua inteiro — é assim que "separar desfaz
## primeiro o que foi unido por último" (pedido do dono, 16/09/2026).
static func desagrupar(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor) -> Array[String]:
	var itens := _itens_existentes(doc, sel)
	var filhos: Array[String] = []
	if itens.size() != 1 or not doc.tem_grupo(itens[0]):
		return filhos
	var gid := itens[0]
	var pai := doc.pai_de(gid)
	filhos = doc.filhos_de(gid)
	hist.iniciar("Separar grupo")
	for filho in filhos:
		_mudar_pai(doc, filho, pai)
	doc.remover_grupo(gid)
	hist.concluir()
	sel.definir(filhos)
	return filhos


static func _mudar_pai(doc: DocumentoMapa, id: String, novo_pai: String) -> void:
	if doc.tem(id):
		var p := doc.peca(id)
		p["grupo"] = novo_pai
		doc.definir_peca(id, p)
	elif doc.tem_grupo(id):
		doc.definir_grupo(id, {"id": id, "pai": novo_pai})


## As PEÇAS por trás da seleção: grupo vira as peças dele (sem repetir, sem spawn).
static func pecas_da_selecao(doc: DocumentoMapa, sel: SelecaoDoEditor) -> Array[String]:
	var saida: Array[String] = []
	for id in sel.pecas():
		for pid in doc.pecas_de(id):
			if not saida.has(pid):
				saida.append(pid)
	return saida


## Itens (peças e grupos) selecionados que ainda existem, sem os que já estão
## dentro de outro item selecionado — senão mover grupo + filho moveria o filho duas vezes.
static func _itens_existentes(doc: DocumentoMapa, sel: SelecaoDoEditor) -> Array[String]:
	var vivos: Array[String] = []
	for id in sel.pecas():
		if doc.tem_item(id):
			vivos.append(id)
	var saida: Array[String] = []
	for id in vivos:
		var coberto := false
		for outro in vivos:
			if outro != id and doc.dentro_de(id, outro):
				coberto = true
				break
		if not coberto:
			saida.append(id)
	return saida


## Devolve "" se deu certo, ou o motivo da recusa (vai para a barra de status).
static func renomear(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor,
		antigo: String, novo: String) -> String:
	novo = novo.strip_edges()
	if novo == antigo:
		return ""
	if not doc.tem_item(antigo):
		return "\"%s\" não existe mais" % antigo
	if not doc.id_valido(novo):
		return "nome inválido: use de 1 a 64 caracteres entre A-Z a-z 0-9 _ -"
	if doc.tem_item(novo):
		return "já existe uma peça ou grupo chamado \"%s\"" % novo
	if doc.tem_grupo(antigo):
		return _renomear_grupo(doc, hist, sel, antigo, novo)
	var ordem := doc.ids()
	ordem[ordem.find(antigo)] = novo
	# ⚠️ Lida ANTES: remover a peça antiga dispara a poda da seleção no editor, e
	# lida depois a peça renomeada já teria saído da seleção.
	var ids := sel.ids()
	hist.iniciar("Renomear")
	var p := doc.peca(antigo)
	p["id"] = novo
	doc.remover_peca(antigo)
	doc.definir_peca(novo, p)
	doc.definir_ordem(ordem)
	hist.concluir()
	if ids.has(antigo):
		ids[ids.find(antigo)] = novo
		sel.definir(ids)
	return ""


static func _renomear_grupo(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor,
		antigo: String, novo: String) -> String:
	var ids := sel.ids()
	var filhos := doc.filhos_de(antigo)
	hist.iniciar("Renomear grupo")
	doc.definir_grupo(novo, {"id": novo, "pai": doc.pai_de(antigo)})
	for filho in filhos:
		_mudar_pai(doc, filho, novo)
	doc.remover_grupo(antigo)
	hist.concluir()
	if ids.has(antigo):
		ids[ids.find(antigo)] = novo
		sel.definir(ids)
	return ""


## Campo digitado no painel de propriedades. Com várias peças, só cor, material e
## colisão valem para todas; forma, posição, rotação e tamanho são de uma peça.
static func alterar(doc: DocumentoMapa, hist: HistoricoDeEdicao, sel: SelecaoDoEditor,
		campo: String, valor: Variant) -> void:
	hist.executar("Alterar %s" % campo, func(): alterar_sem_historico(doc, sel, campo, valor))


static func alterar_sem_historico(doc: DocumentoMapa, sel: SelecaoDoEditor, campo: String, valor: Variant) -> void:
	if campo == "posicao" and sel.ids() == [SelecaoDoEditor.SPAWN]:
		doc.definir_spawn(_prender_coord(valor))
		return
	var itens := _itens_existentes(doc, sel)
	var alvo: Array[String] = []
	if itens.size() == 1 and doc.tem(itens[0]):
		alvo = itens
	elif campo in ["cor", "material", "colisao", "hitbox.remover", "hitbox.aplicar"]:
		# Tirar a hitbox e COPIAR a hitbox valem para a seleção inteira; ajustar os
		# números é sempre de uma peça só (o painel só mostra os campos com uma).
		alvo = pecas_da_selecao(doc, sel)
	elif campo == "posicao" and itens.size() == 1 and doc.tem_grupo(itens[0]):
		# Posição de GRUPO é o centro das peças: digitar um valor move todas juntas.
		var delta: Vector3 = _prender_coord(valor) - centro(doc, sel)
		for pid in doc.pecas_de(itens[0]):
			var pg := doc.peca(pid)
			pg["posicao"] = _prender_coord((pg["posicao"] as Vector3) + delta)
			doc.definir_peca(pid, pg)
		return
	for id in alvo:
		var p := doc.peca(id)
		match campo:
			"tipo":
				# Só entre formas primitivas: modelo e terreno carregam dado próprio
				# (o id da loja, o relevo) que uma troca de forma não tem como inventar.
				if MapaArquivo.TIPOS_PRIMITIVOS.has(valor) and MapaArquivo.TIPOS_PRIMITIVOS.has(p["tipo"]):
					p["tipo"] = valor
					p["tamanho"] = DocumentoMapa.normalizar_tamanho(valor, p["tamanho"])
			"posicao":
				p["posicao"] = _prender_coord(valor)
			"rotacao_graus":
				p["rotacao_graus"] = DocumentoMapa.normalizar_rotacao(valor)
			"tamanho":
				p["tamanho"] = DocumentoMapa.normalizar_tamanho(p["tipo"], valor,
					_eixo_que_mudou(p["tamanho"], valor))
			"grade_celula":
				p["grade_celula"] = clampf(valor, MapaArquivo.GRADE_MIN, MapaArquivo.TAMANHO_MAX)
			"cor", "material", "colisao":
				p[campo] = valor
			"especie":
				if p["tipo"] == "area_animais":
					p["especie"] = String(valor)
			"quantidade":
				if p["tipo"] == "area_animais":
					p["quantidade"] = clampi(int(valor), 1, MapaArquivo.QUANTIDADE_MAX)
			# ----------------------------------------------------------- hitbox
			# A hitbox é um dicionário dentro da peça, e o painel manda campo
			# composto ("hitbox.tamanho"). Tudo passa por aqui, então desfazer e
			# refazer funcionam sem uma linha a mais de código.
			"hitbox.usar":
				if valor:
					p["hitbox"] = hitbox_de_partida(p)
				else:
					p.erase("hitbox")
			"hitbox.remover":
				p.erase("hitbox")
			"hitbox.forma":
				var h := hitbox_de_partida(p)
				h["forma"] = valor
				h["tamanho"] = DocumentoMapa.normalizar_tamanho(valor, h["tamanho"])
				p["hitbox"] = h
			"hitbox.deslocamento":
				var h := hitbox_de_partida(p)
				h["deslocamento"] = _prender_coord(valor)
				p["hitbox"] = h
			"hitbox.rotacao_graus":
				var h := hitbox_de_partida(p)
				h["rotacao_graus"] = DocumentoMapa.normalizar_rotacao(valor)
				p["hitbox"] = h
			"hitbox.tamanho":
				var h := hitbox_de_partida(p)
				h["tamanho"] = DocumentoMapa.normalizar_tamanho(h["forma"], valor,
					_eixo_que_mudou(h["tamanho"], valor))
				p["hitbox"] = h
			"hitbox.aplicar":
				# Copiar a hitbox de uma peça para as outras: o deslocamento e o giro
				# são LOCAIS, então valem igual em cada cópia. O tamanho passa pela
				# normalização da forma de destino por segurança.
				var origem: Dictionary = valor
				var h := (origem as Dictionary).duplicate(true)
				h["tamanho"] = DocumentoMapa.normalizar_tamanho(h["forma"], h["tamanho"])
				p["hitbox"] = h
			_:
				push_error("[Editor] campo desconhecido: %s" % campo)
				return
		doc.definir_peca(id, p)


## A hitbox de onde partir ao mexer num campo dela (o painel também lê daqui). Quem já tem, continua de onde
## está; quem não tem GANHA o volume que a física já usa hoje — começar do volume
## atual é o que faz o primeiro ajuste ser pequeno, e não recomeçar do zero.
static func hitbox_de_partida(p: Dictionary) -> Dictionary:
	if p.has("hitbox"):
		return (p["hitbox"] as Dictionary).duplicate(true)
	var v := MapaMontador.volume_de_colisao(p)
	if v.is_empty():
		# Colisão de malha do modelo: não há volume simples de onde partir, então a
		# caixa do tamanho da peça é o ponto de partida honesto.
		return {"forma": "caixa", "deslocamento": Vector3.ZERO,
			"tamanho": p["tamanho"], "rotacao_graus": Vector3.ZERO}
	var local: Transform3D = v["local"]
	return {"forma": v["forma"], "deslocamento": local.origin,
		"tamanho": v["tamanho"],
		"rotacao_graus": DocumentoMapa.normalizar_rotacao(local.basis.get_euler() * (180.0 / PI))}


## As peças IGUAIS à selecionada: mesmo tipo e, se for modelo, mesmo modelo. É o que
## faz a hitbox valer a pena num mapa real — ninguém ajusta trinta cópias da mesma
## árvore uma a uma. A peça de origem entra na conta.
static func iguais_a(doc: DocumentoMapa, id: String) -> Array[String]:
	var iguais: Array[String] = []
	if not doc.tem(id):
		return iguais
	var base := doc.peca(id)
	for outro in doc.ids():
		var p := doc.peca(outro)
		if p["tipo"] != base["tipo"]:
			continue
		if base["tipo"] == "modelo" and p.get("modelo", "") != base.get("modelo", ""):
			continue
		iguais.append(outro)
	return iguais


## Copia a hitbox da peça selecionada para todas as iguais, num passo só de
## histórico: vinte cópias voltam com um Ctrl+Z.
static func aplicar_hitbox_em_iguais(doc: DocumentoMapa, hist: HistoricoDeEdicao,
		id: String) -> int:
	if not doc.tem(id) or not doc.peca(id).has("hitbox"):
		return 0
	var h: Dictionary = (doc.peca(id)["hitbox"] as Dictionary).duplicate(true)
	var ids := iguais_a(doc, id)
	hist.executar("Aplicar hitbox em %d peças" % ids.size(), func():
		for outro in ids:
			var p := doc.peca(outro)
			p["hitbox"] = h.duplicate(true)
			doc.definir_peca(outro, p)
	)
	return ids.size()


## O estado de partida de um arraste: cada item selecionado como estava no clique.
## O arraste sempre recalcula A PARTIR DAQUI — somar incremento a cada movimento do
## mouse acumularia erro de arredondamento e a peça "escorregaria" da grade.
static func foto(doc: DocumentoMapa, sel: SelecaoDoEditor) -> Dictionary:
	var f := {}
	if sel.tem_spawn():
		f[SelecaoDoEditor.SPAWN] = doc.spawn
	for pid in pecas_da_selecao(doc, sel):
		f[pid] = doc.peca(pid)
	return f


## Aplica um arraste do gizmo. `info` é o que `GizmoDoEditor.comecar` devolveu;
## `valor` é metros (seta/face) ou radianos (anel); `passo` ≤ 0 = sem grade.
static func aplicar_arraste(doc: DocumentoMapa, foto_inicial: Dictionary, info: Dictionary,
		valor: float, passo: float) -> void:
	var eixo: Vector3 = info["eixo_mundo"]
	match info["tipo"]:
		"seta":
			var d := GizmoMatematica.grudar(valor, passo)
			for id: String in foto_inicial:
				if id == SelecaoDoEditor.SPAWN:
					doc.definir_spawn(_prender_coord(foto_inicial[id] + eixo * d))
				else:
					var p: Dictionary = foto_inicial[id].duplicate(true)
					p["posicao"] = _prender_coord(p["posicao"] + eixo * d)
					doc.definir_peca(id, p)
		"face":
			if foto_inicial.size() != 1 or foto_inicial.has(SelecaoDoEditor.SPAWN):
				return
			var id: String = foto_inicial.keys()[0]
			var p: Dictionary = foto_inicial[id].duplicate(true)
			var r := GizmoMatematica.esticar_face(p, info["eixo"], info["sinal"], GizmoMatematica.grudar(valor, passo))
			p["posicao"] = r[0]
			p["tamanho"] = r[1]
			doc.definir_peca(id, p)
		"anel":
			var graus := rad_to_deg(valor)
			if passo > 0.0:
				graus = snappedf(graus, PASSO_GIRAR_GRAUS)
			var pivo: Vector3 = info["centro"]
			for id: String in foto_inicial:
				if id == SelecaoDoEditor.SPAWN:
					doc.definir_spawn(pivo + Basis(eixo, deg_to_rad(graus)) * (foto_inicial[id] - pivo))
				else:
					var p: Dictionary = foto_inicial[id].duplicate(true)
					var g := GizmoMatematica.girar_em_torno(p["posicao"], p["rotacao_graus"], pivo, eixo, deg_to_rad(graus))
					p["posicao"] = g[0]
					p["rotacao_graus"] = g[1]
					doc.definir_peca(id, p)


## ARRASTAR A HITBOX (23/09/2026). Espelha `aplicar_arraste` acima, com a MESMA
## `GizmoMatematica` — a diferença é só onde o resultado é gravado: no volume, e não
## na peça. O gizmo trabalha em MUNDO e a hitbox mora em espaço LOCAL da peça, então
## cada resultado volta pela base da peça (`base.inverse()`); é o único ponto desta
## função onde um erro de sinal apareceria, e é por isso que o teste gira a peça 45°.
static func aplicar_arraste_hitbox(doc: DocumentoMapa, foto_inicial: Dictionary,
		info: Dictionary, valor: float, passo: float) -> void:
	if foto_inicial.size() != 1 or foto_inicial.has(SelecaoDoEditor.SPAWN):
		return
	var id: String = foto_inicial.keys()[0]
	var p: Dictionary = foto_inicial[id].duplicate(true)
	var h := hitbox_de_partida(p)
	var base := Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0))
	var centro_mundo: Vector3 = p["posicao"] + base * (h["deslocamento"] as Vector3)
	var giro_mundo := base * Basis.from_euler((h["rotacao_graus"] as Vector3) * (PI / 180.0))
	var eixo: Vector3 = info["eixo_mundo"]
	match info["tipo"]:
		"seta":
			var novo := centro_mundo + eixo * GizmoMatematica.grudar(valor, passo)
			h["deslocamento"] = _prender_coord(base.inverse() * (novo - p["posicao"]))
		"face":
			# O volume esticado pela face é o mesmo problema da peça esticada: monta o
			# dado que a matemática já sabe resolver, em MUNDO, e traz o centro de volta.
			var falsa := {"tipo": h["forma"], "tamanho": h["tamanho"],
				"posicao": centro_mundo, "rotacao_graus": giro_mundo.get_euler() * (180.0 / PI)}
			var r := GizmoMatematica.esticar_face(falsa, info["eixo"], info["sinal"],
				GizmoMatematica.grudar(valor, passo))
			h["deslocamento"] = _prender_coord(base.inverse() * ((r[0] as Vector3) - p["posicao"]))
			h["tamanho"] = r[1]
		"anel":
			# Gira em torno do CENTRO DO PRÓPRIO VOLUME: girar o volume não pode
			# arrastá-lo para longe da peça.
			var graus := rad_to_deg(valor)
			if passo > 0.0:
				graus = snappedf(graus, PASSO_GIRAR_GRAUS)
			var novo_mundo := Basis(eixo, deg_to_rad(graus)) * giro_mundo
			h["rotacao_graus"] = DocumentoMapa.normalizar_rotacao(
				(base.inverse() * novo_mundo).get_euler() * (180.0 / PI))
	p["hitbox"] = h
	doc.definir_peca(id, p)


## Onde as alças do gizmo ficam quando o alvo é a hitbox: centro em mundo, a base
## girada do volume e a meia-extensão dele.
static func pose_da_hitbox(doc: DocumentoMapa, id: String) -> Dictionary:
	if not doc.tem(id):
		return {}
	var p := doc.peca(id)
	var h := hitbox_de_partida(p)
	var base := Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0))
	return {
		"centro": p["posicao"] + base * (h["deslocamento"] as Vector3),
		"base": base * Basis.from_euler((h["rotacao_graus"] as Vector3) * (PI / 180.0)),
		"meio": (h["tamanho"] as Vector3) * 0.5,
	}


static func centro(doc: DocumentoMapa, sel: SelecaoDoEditor) -> Vector3:
	var soma := Vector3.ZERO
	var n := 0
	if sel.tem_spawn():
		soma += doc.spawn
		n += 1
	# Guarda contra id recém-apagado: `pecas_de` ignora o que já saiu do documento
	# (no meio de um desfazer a seleção pode apontar por um instante para ele).
	for pid in pecas_da_selecao(doc, sel):
		soma += doc.peca(pid)["posicao"] as Vector3
		n += 1
	return soma / n if n > 0 else Vector3.ZERO


## Raio que cobre a seleção — para o F enquadrar.
static func raio(doc: DocumentoMapa, sel: SelecaoDoEditor, centro_: Vector3) -> float:
	var r := 1.0
	for id in pecas_da_selecao(doc, sel):
		var p := doc.peca(id)
		r = maxf(r, (p["posicao"] as Vector3).distance_to(centro_) + (p["tamanho"] as Vector3).length() * 0.5)
	return r


static func _grudar_vetor(v: Vector3, passo: float) -> Vector3:
	if passo <= 0.0:
		return v
	return Vector3(snappedf(v.x, passo), snappedf(v.y, passo), snappedf(v.z, passo))


static func _prender_coord(v: Vector3) -> Vector3:
	var limite := Vector3.ONE * MapaArquivo.LIMITE_COORD
	return v.clamp(-limite, limite)


static func _eixo_que_mudou(antes: Vector3, depois: Vector3) -> int:
	for i in 3:
		if not is_equal_approx(antes[i], depois[i]):
			return i
	return -1
