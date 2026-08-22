class_name Knockback
extends RefCounted
# ============================================================================
#  KNOCKBACK — horizontal e vertical, num lugar só.
#
#  POR QUE ESTE ARQUIVO EXISTE
#  ---------------------------
#  O dono listou "knockback horizontal" e "knockback vertical" como DUAS
#  mecânicas. No código eram UMA linha, e o vertical nem era mecânica: era a
#  constante `0.35` escondida dentro da conta do horizontal, em
#  `DamageZone._on_body`:
#
#      kb = dir * knockback + Vector3.UP * knockback * 0.35
#                                                     ^^^^
#  Ninguém conseguia ajustar a componente vertical sem editar a fórmula, e
#  ninguém conseguia descobrir que ela existia sem ler a fórmula. Número mágico
#  escondido é a mesma classe de problema que gerou o furo de munição infinita
#  (item 14): regra que mora dentro de uma expressão em vez de num dado nomeado.
#
#  DECISÃO DECLARADA (as seis do dono):
#   • benefício imediato: os dois knockbacks viram dado ajustável e testável;
#   • impacto futuro: golpe novo pede o perfil que quer, sem tocar na fórmula;
#   • manutenção: uma fórmula, um arquivo, um teste;
#   • extensão: perfil novo é uma constante, não um `if` na DamageZone;
#   • custo: baixo — a conta é a mesma, só saiu de lugar;
#   • risco: mudar o VALOR mudaria o feel do jogo inteiro. Por isso o padrão é
#     EXATAMENTE 0.35, o número que já estava lá. Esta extração não muda nada em
#     tela, e é assim que ela pôde ser feita sem aprovação de design.
#
#  ⚠️ AUTORIDADE: quem chama isto é a `DamageZone`, que só aplica dano e
#  knockback NO SERVIDOR. Não chame daqui de um caminho de cliente — seria
#  empurrão que o servidor não conhece, e o corpo voltaria no quadro seguinte.
# ============================================================================

# Fração do knockback que vira impulso PARA CIMA.
#
# 0.35 é o valor histórico do projeto, preservado ao pé da letra. Ele existe
# porque o jogo mata pelo BURACO, não pelo dano: sem componente vertical o alvo
# desliza pelo chão e agarra na borda; com ela, ele sai do plano e cai.
#
# ⚠️ Este comentário citava um `DAMAGE_SCALE = 0.12` na `DamageZone`. Ele não
# existe mais desde 2026-08-21 — o dano agora vem final de `src/combat/Balance.gd`.
# A razão de ser do viés vertical não mudou; a referência é que estava velha.
const FRACAO_VERTICAL := 0.35

# Perfis nomeados. Cada golpe escolhe um em vez de repetir números.
#
# ⚠️ NÃO acrescente perfil "porque pode ser útil" — o dono cobra complexidade
# adequada. Três existem porque três casos REAIS aparecem no jogo hoje.
const PADRAO := "padrao"          # radial + 35% pra cima (o de sempre)
const SO_HORIZONTAL := "rasteiro" # empurra sem levantar: bom para parede/onda
const ARREMESSO := "arremesso"    # sobe mais que empurra
# ⚠️ `ARREMESSO` dizia "o V da Gura usa" — NÃO USA (verificado em 2026-08-21).
# A `DamageZone` chama sempre `Knockback.PADRAO`; o V da Gura fixa a DIREÇÃO
# (`override_kb_dir`), não o perfil. Nem `ARREMESSO` nem o ajudante `rasteiro()`
# (que usa `SO_HORIZONTAL`) têm um único chamador no projeto. Ficam como opção
# pronta — mas quem for cobrar "três casos REAIS" no aviso acima que saiba que
# hoje o número real é UM.

const PERFIS := {
	PADRAO:         {"vertical": FRACAO_VERTICAL, "horizontal": 1.0},
	SO_HORIZONTAL:  {"vertical": 0.0,             "horizontal": 1.0},
	ARREMESSO:      {"vertical": 0.85,            "horizontal": 0.7},
}

# Vetor de knockback para um corpo, dado o centro do golpe.
#
# `direcao_fixa` != ZERO ignora o radial e usa a direção dada. Isso NÃO é
# preciosismo: o radial é `alvo − centro`, e numa frente de onda de 200 m o
# "centro" fica longe do ponto de contato — o empurrão sairia de lado. É também
# o que evita o item 26 (projétil rápido empurrando o alvo PARA TRÁS, porque a
# varredura registra o acerto depois de a zona já ter passado do alvo).
static func calcular(centro: Vector3, alvo: Vector3, forca: float,
		perfil: String = PADRAO, direcao_fixa: Vector3 = Vector3.ZERO) -> Vector3:
	if forca <= 0.0:
		return Vector3.ZERO
	var p: Dictionary = PERFIS.get(perfil, PERFIS[PADRAO])

	if direcao_fixa != Vector3.ZERO:
		return direcao_fixa.normalized() * forca

	var dir: Vector3 = alvo - centro
	dir.y = 0.0
	# `FORWARD` como plano B: alvo exatamente em cima do centro não tem direção
	# radial, e sem isto o `normalized()` devolveria zero e o golpe não empurraria.
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	return dir * forca * float(p["horizontal"]) \
		+ Vector3.UP * forca * float(p["vertical"])

# Só a parte horizontal — a mecânica que o dono chamou de "knockback horizontal".
static func horizontal(centro: Vector3, alvo: Vector3, forca: float) -> Vector3:
	return calcular(centro, alvo, forca, SO_HORIZONTAL)

# Só a parte vertical — "knockback vertical", o que a Gura Gura faz.
# Vetor puro para cima: quem quiser os dois usa `calcular` com um perfil.
static func vertical(forca: float) -> Vector3:
	return Vector3.UP * forca * FRACAO_VERTICAL
