extends SceneTree
# ============================================================================
#  TESTE DA TABELA DE DANO — roda sem abrir o jogo.
#
#      godot --headless --path . --script tools/dev_tests/test_balance.gd
#
#  Ele não mede o jogo rodando (isso é o `test_frutas.gd`); ele confere que a
#  TABELA é internamente coerente, que é a única coisa que dá para garantir sem
#  um alvo vivo — e é justamente o que faltava antes: os números moravam em três
#  lugares que não se falavam, e nada checava se batiam.
#
#  O que ele recusa:
#    1. skill fora da faixa de dano do seu slot;
#    2. multi-hit que não chega perto do próprio teto — seria um golpe que
#       promete mais do que entrega, e um teto que é decoração;
#    3. carregado com máximo menor que o mínimo, ou sem tempo de carga;
#    4. teto de skill acima do teto do slot;
#    5. orçamento que não corta (o `DamageBudget` deixando passar do teto);
#    6. as tabelas espelhadas (`FightingStyles.STYLES`, `Melee.COMBO`) fora de
#       sincronia com o `Balance`.
# ============================================================================

var _falhas: int = 0
var _checagens: int = 0

func _init() -> void:
	print("=== TESTE DA TABELA DE DANO (Balance) ===")
	print("Vida de referência: %.0f\n" % Balance.HP_BASE)

	_faixas_por_slot()
	_multi_alcanca_o_teto()
	_carregados()
	_tetos()
	_orcamento_corta()
	_tabelas_espelhadas()

	print("\n%d checagens, %d falha(s)." % [_checagens, _falhas])
	if _falhas == 0:
		print("✅ TABELA COERENTE.")
	else:
		print("❌ TABELA INCOERENTE — ver acima.")
	quit(1 if _falhas > 0 else 0)

func _ok(cond: bool, msg: String) -> void:
	_checagens += 1
	if not cond:
		_falhas += 1
		print("  ❌ " + msg)

# ---------------------------------------------------------------------------
# 1. Toda skill cabe na faixa do seu slot.
#
# MULTI é medido pelo TOTAL (hits x dano), não pelo dano de um acerto: 16 balas
# de 12 não caberiam na faixa "único 80-96" e nem deveriam — o que precisa caber
# é a rajada inteira.
func _faixas_por_slot() -> void:
	print("[1] faixa de dano por slot")
	for fruta in Balance.FRUTAS:
		for slot in Balance.FRUTAS[fruta]:
			var s := Balance.spec(fruta, slot)
			var ref: Dictionary = Balance.SLOT[slot]
			var nome := "%s/%s" % [fruta, slot]
			match s.tipo:
				DamageSpec.Tipo.UNICO:
					var f: Array = ref["unico"]
					# A pistola da Yami é a exceção declarada: é um TOGGLE sem pente,
					# então o que cabe na faixa do slot é a rajada de tiros, não um.
					if s.teto <= 0.0:
						_ok(s.dano > 0.0, "%s: toggle com dano zero" % nome)
					else:
						_ok(s.dano >= f[0] and s.dano <= f[1],
							"%s: dano %.0f fora da faixa [%.0f, %.0f]" % [nome, s.dano, f[0], f[1]])
				DamageSpec.Tipo.MULTI:
					# O golpe tem de conseguir chegar PERTO do próprio teto, senão o
					# teto é decoração e o multi-hit é, na prática, mais fraco que um
					# golpe único do mesmo slot.
					#
					# Não se exige chegar EXATAMENTE ao teto: nas armas da Buki o dano
					# por bala sai de `teto / nº de balas` arredondado para baixo, então
					# o pente cheio fica alguns pontos abaixo de propósito. 85% é a
					# folga que acomoda esse arredondamento sem deixar passar um golpe
					# que entrega metade do que promete.
					var total := _total_alcancavel(s)
					_ok(total >= s.teto * 0.85,
						"%s: total alcançável %.0f, menos de 85%% do teto %.0f" % [
							nome, total, s.teto])
				DamageSpec.Tipo.CARREGADO:
					var c: Array = ref.get("carregado", ref["unico"])
					_ok(s.dano >= c[0] and s.dano_max <= c[1],
						"%s: carga %.0f->%.0f fora da faixa [%.0f, %.0f]" % [
							nome, s.dano, s.dano_max, c[0], c[1]])

# ---------------------------------------------------------------------------
# O máximo que um golpe consegue entregar se TUDO acertar: os `hits` que valem
# `dano` mais cada parte nomeada, que é um acerto adicional de valor próprio.
func _total_alcancavel(s: DamageSpec) -> float:
	var total := s.dano * float(s.hits)
	for chave in s.partes:
		total += float(s.partes[chave])
	return total

# 2. Um MULTI tem de ser mesmo múltiplo e ter valor por acerto.
func _multi_alcanca_o_teto() -> void:
	print("[2] multi-hit é múltiplo de verdade")
	for fruta in Balance.FRUTAS:
		for slot in Balance.FRUTAS[fruta]:
			var s := Balance.spec(fruta, slot)
			if s.tipo != DamageSpec.Tipo.MULTI:
				continue
			# "Vários acertos" conta as PARTES nomeadas: o Kurouzu tem 1 acerto de
			# `dano` (o vórtice) e 1 parte (o arremesso) — dois acertos, valores
			# diferentes. Um MULTI de um acerto só seria um UNICO mal declarado.
			_ok(s.hits + s.partes.size() > 1,
				"%s/%s: MULTI com um acerto só (%d hits, %d partes)" % [
					fruta, slot, s.hits, s.partes.size()])
			_ok(s.dano > 0.0, "%s/%s: MULTI com dano zero" % [fruta, slot])

func _carregados() -> void:
	print("[3] skills carregáveis")
	for fruta in Balance.FRUTAS:
		for slot in Balance.FRUTAS[fruta]:
			var s := Balance.spec(fruta, slot)
			if s.tipo != DamageSpec.Tipo.CARREGADO:
				continue
			var nome := "%s/%s" % [fruta, slot]
			_ok(s.dano_max > s.dano, "%s: máximo %.0f não supera o mínimo %.0f" % [nome, s.dano_max, s.dano])
			_ok(s.tempo_de_carga > 0.0, "%s: tempo de carga zero" % nome)
			# A curva tem de ser contínua nas duas pontas.
			_ok(is_equal_approx(s.valor_do_hit(0.0), s.dano), "%s: carga 0 não dá o mínimo" % nome)
			_ok(is_equal_approx(s.valor_do_hit(s.tempo_de_carga), s.dano_max), "%s: carga cheia não dá o máximo" % nome)
			_ok(is_equal_approx(s.valor_do_hit(999.0), s.dano_max), "%s: carga além do tempo não grampeia" % nome)

func _tetos() -> void:
	print("[4] teto de skill <= teto de slot")
	for fruta in Balance.FRUTAS:
		for slot in Balance.FRUTAS[fruta]:
			var s := Balance.spec(fruta, slot)
			var teto_slot := Balance.teto_do_slot(slot)
			_ok(s.teto <= teto_slot,
				"%s/%s: teto %.0f acima do teto do slot %.0f" % [fruta, slot, s.teto, teto_slot])

# ---------------------------------------------------------------------------
# 5. O orçamento realmente corta. Este é o teste da mecânica que não existia:
#    antes, 25 escombros do Liberation somavam 1800 numa vida de 2048.
func _orcamento_corta() -> void:
	print("[5] o orçamento corta o excedente")
	var alvo := Node.new()          # basta um id de instância; nada é aplicado
	var cast_id := CombatResolver.novo_cast()
	var teto := 768.0
	var somado := 0.0
	for i in 40:                    # 40 acertos de 96 = 3840 pedidos
		somado += CombatResolver._cobrar(cast_id, alvo, 96.0, teto)
	_ok(is_equal_approx(somado, teto),
		"40 acertos de 96 com teto 768 somaram %.1f (esperado %.1f)" % [somado, teto])

	# Conjuração NOVA tem orçamento cheio: é o que impede o segundo Gatling de
	# nascer sem dano por causa do primeiro.
	var outro := CombatResolver.novo_cast()
	var s2: float = CombatResolver._cobrar(outro, alvo, 96.0, teto)
	_ok(is_equal_approx(s2, 96.0), "conjuração nova nasceu com o orçamento gasto (%.1f)" % s2)

	CombatResolver.limpar_tudo()
	alvo.free()

# ---------------------------------------------------------------------------
# 6. As tabelas que REPETEM números do Balance continuam batendo com ele.
#    `Melee.COMBO` e `FightingStyles.STYLES` guardam o dano ao lado do frame
#    data / da cor porque separar só essa coluna tornaria a leitura pior — mas
#    então alguém tem de conferir que não divergiram, e é aqui.
func _tabelas_espelhadas() -> void:
	print("[6] tabelas espelhadas em sincronia")
	var combo: Array = Balance.MELEE["combo"]
	_ok(Melee.COMBO.size() == combo.size(),
		"Melee.COMBO tem %d passos, Balance.MELEE tem %d" % [Melee.COMBO.size(), combo.size()])
	for i in mini(Melee.COMBO.size(), combo.size()):
		var d := float(Melee.COMBO[i]["dano"])
		_ok(is_equal_approx(d, float(combo[i])),
			"Melee.COMBO[%d].dano = %.0f, Balance diz %.0f" % [i, d, float(combo[i])])

	var espada: Array = Balance.MELEE["espada"]
	for i in mini(Melee.COMBO_SWORD.size(), espada.size()):
		var d := float(Melee.COMBO_SWORD[i]["dano"])
		_ok(is_equal_approx(d, float(espada[i])),
			"Melee.COMBO_SWORD[%d].dano = %.0f, Balance diz %.0f" % [i, d, float(espada[i])])

	for estilo in Balance.ESTILOS:
		if not FightingStyles.STYLES.has(estilo):
			continue
		var skills: Dictionary = FightingStyles.STYLES[estilo]["skills"]
		for slot in Balance.ESTILOS[estilo]:
			if not skills.has(slot):
				continue
			var d := float(skills[slot]["dano"])
			var b := float(Balance.ESTILOS[estilo][slot])
			_ok(is_equal_approx(d, b),
				"FightingStyles %s/%s = %.0f, Balance diz %.0f" % [estilo, slot, d, b])
