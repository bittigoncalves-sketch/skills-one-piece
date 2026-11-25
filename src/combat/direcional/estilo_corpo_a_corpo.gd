class_name EstiloCorpoACorpo
extends Resource
# ============================================================================
#  ESTILO DE CORPO A CORPO — o conjunto de golpes que o executor usa.
#
#  ⚠️ NÃO É o "estilo de luta" do menu M. Aquele (`FightingStyles`, Boxe, Karatê
#  Tritão…) é o conjunto de skills Z/X/C/V e continua intocado. Este é o que o
#  CLIQUE faz no combate direcional do Modo História. Os dois nomes parecidos
#  foram mantidos distintos de propósito — ver §4.8 do plano.
#
#  O executor é o mesmo para todo estilo; boxe e espada diferem só nestes dados
#  (e nas poses). Estilo novo = `.tres` novo, nenhum código.
# ============================================================================

## Folga da invariante da quebra: o contato cai DENTRO do ativo e o golpe seguinte
## precisa de uns quadros para chegar ao alvo. Regra de jogo, não número de estilo.
const FOLGA_DA_QUEBRA := 0.10

@export var id: StringName
@export var nome := ""
## Um golpe por direção, exatamente.
@export var golpes: Array[GolpeDirecional] = []

@export_group("Ritmo")
## Padrão NEUTRO (0 = sem buffer): o valor real mora no `.tres` — ver a nota
## sobre padrões em `golpe_direcional.gd`.
## Clique nos últimos N segundos da recuperação fica guardado e sai quando ela
## acaba. Só UM clique é guardado, e só nessa janela: clicar mais cedo ou mais
## vezes não rende golpe nenhum a mais.
@export_range(0.0, 0.5, 0.01, "suffix:s") var buffer := 0.0
## Clique sem gesto percorre estas direções. Vazio conserva o ataque direcional.
@export var sequencia_cliques: Array[int] = []
## Tempo após terminar um golpe para continuar a sequência com outro clique.
@export_range(0.0, 3.0, 0.05, "suffix:s") var janela_sequencia := 0.0

@export_group("Pose")
## A guarda do estilo: onde todo golpe começa e termina. Precisa definir as DUAS
## mãos e os PÉS (a base) — as chaves dos golpes herdam dela o que não escrevem.
@export var guarda: ChaveDePose
## Os dedos durante toda ação de combate (papel → graus): no boxe, o punho fechado; na
## espada, a pega. Fica no estilo, e não em cada chave, porque a mão não muda de forma
## no meio de um golpe — e 30 papéis a mais em toda chave seriam 30 curvas por quadro.
@export var maos: Dictionary = {}
## Punhos orientados no espaço do corpo após a IK (arma precisa apontar com o corte).
@export var orientar_punhos := false
## Arma empunhada conserva a postura de transporte mesmo sem atacar.
@export var manter_postura := false

@export_group("Pés de apoio")
## Tornozelo até esta altura (espaço do corpo, m) = pé NO CHÃO: fica travado no MUNDO
## onde pisou, e o corpo pode avançar ou girar sobre ele. Acima disso o pé segue a pose
## (é um passo). Precisa cobrir a base da guarda.
@export_range(0.0, 0.5, 0.005, "suffix:m") var altura_de_apoio := 0.0
## Pé travado a mais que isto do lugar que a pose pede dá um passo até lá.
@export_range(0.0, 1.0, 0.01, "suffix:m") var soltar_pe_a := 0.0
@export_range(0.0, 0.5, 0.01, "suffix:s") var duracao_do_passo := 0.0
@export_range(0.0, 0.3, 0.005, "suffix:m") var altura_do_passo := 0.0
## Tempo para a camada de combate assumir o corpo ao começar uma ação (dentro do
## preparo, onde a entrada lê como antecipação) e para devolvê-lo ao animador.
@export_range(0.0, 0.5, 0.01, "suffix:s") var transicao_entrada := 0.0
@export_range(0.0, 0.8, 0.01, "suffix:s") var transicao_saida := 0.0
## Por quanto tempo a GUARDA fica erguida depois de uma ação, antes de o corpo
## voltar ao animador. É o que faz o próximo golpe sair da guarda e não dos braços
## caídos — medido em 16/09: sem ela as mãos subiam 0,42 m em 60 ms, um estalo.
@export_range(0.0, 10.0, 0.1, "suffix:s") var guarda_apos_acao := 0.0

@export_group("Defesa")
## Largura da guarda, em graus, centrada na frente do corpo. Fora dela (flanco,
## costas) o golpe entra mesmo com a guarda erguida.
@export_range(0.0, 360.0, 1.0, "suffix:°") var cone_da_guarda := 0.0
## Resistência interna da guarda (sem barra na tela, por decisão do plano). Cada
## golpe bloqueado tira o `dano_de_postura` dele; zerada, a guarda QUEBRA.
@export_range(0.0, 1000.0, 1.0) var postura_maxima := 0.0
@export_range(0.0, 500.0, 1.0, "suffix:/s") var postura_regeneracao := 0.0
## Quanto tempo sem bloquear nada antes de a postura voltar a subir.
@export_range(0.0, 5.0, 0.05, "suffix:s") var postura_atraso := 0.0
## Com quanto de postura o corpo sai de uma quebra de guarda.
@export_range(0.0, 1000.0, 1.0) var postura_apos_quebra := 0.0
## Quanto dura a quebra de guarda: sem guarda, sem ataque. Quebrar a guarda tem de
## render um acerto COM QUALQUER golpe (§7.5): precisa cobrir o resto do golpe que
## quebrou (ativo + recuperação do mais longo) mais o preparo do mais rápido.
@export_range(0.0, 3.0, 0.05, "suffix:s") var duracao_da_quebra := 0.0
## Tempo para baixar a guarda depois de soltar. Enquanto dura, a guarda não volta —
## é o que impede alternar guarda a cada quadro sem custo (e, na Fase 5, o spam de aparo).
@export_range(0.0, 1.0, 0.01, "suffix:s") var baixar_guarda := 0.0
## Fração da RECUPERAÇÃO a partir da qual a guarda pode interromper o golpe.
## Antes disso o corpo está preso ao golpe que errou.
@export_range(0.0, 1.0, 0.01) var guarda_liberada_na_recuperacao := 0.0
@export_range(0.0, 1.0, 0.01) var fator_movimento_guarda := 0.0
@export_range(0.0, 1.0, 0.01) var fator_movimento_quebra := 0.0
## A guarda erguida (RMB segurado), o tranco de um golpe bloqueado e a quebra.
@export var pose_guarda_erguida: ChaveDePose
@export var pose_impacto_na_guarda: ChaveDePose
@export var pose_quebra_de_guarda: ChaveDePose

@export_group("Aparo, riposte e finta")
## Quanto tempo, a partir de ERGUER a guarda com um aperto novo, um golpe que chega é
## APARADO em vez de bloqueado. A guarda que volta sozinha (botão segurado) não abre janela.
@export_range(0.0, 1.0, 0.01, "suffix:s") var janela_de_aparo := 0.0
## Quanto o ATACANTE aparado fica rebatido, sem agir. Precisa ser MENOR que o preparo
## do riposte mais rápido — senão o riposte seria dano garantido (§7.5).
@export_range(0.0, 1.0, 0.01, "suffix:s") var duracao_rebatido := 0.0
## Depois de um aparo, por quanto tempo o próximo golpe sai como riposte.
@export_range(0.0, 2.0, 0.01, "suffix:s") var janela_de_riposte := 0.0
## Fração do preparo que o riposte usa (0,6 = preparo 40% mais rápido).
@export_range(0.0, 1.0, 0.01) var fator_de_riposte := 0.0
## Até que fração do PREPARO o golpe ainda pode ser fintado.
@export_range(0.0, 1.0, 0.01) var janela_de_finta := 0.0
## Nunca fintar com menos que isto de preparo pela frente (a leitura do adversário
## precisa ter chance de acontecer).
@export_range(0.0, 1.0, 0.01, "suffix:s") var finta_minimo_restante := 0.0
## Postura gasta por finta. Sem postura suficiente, não há finta.
@export_range(0.0, 200.0, 1.0) var custo_da_finta := 0.0
@export var pose_aparo: ChaveDePose
@export var pose_rebatido: ChaveDePose

@export_group("Reações (pose no pico do tranco)")
@export var reacao_frente: ChaveDePose
@export var reacao_esquerda: ChaveDePose   ## atingido PELO lado esquerdo
@export var reacao_direita: ChaveDePose    ## atingido PELO lado direito
@export var reacao_costas: ChaveDePose
@export var reacao_pesada: ChaveDePose


func golpe_para(direcao: GolpeDirecional.Direcao) -> GolpeDirecional:
	for g in golpes:
		if g != null and g.direcao == direcao:
			return g
	return null


## As direções que este estilo tem golpe (quem sorteia golpes precisa só destas:
## pedir uma direção sem golpe é recusado e travaria quem espera o aceite).
func direcoes_com_golpe() -> Array[int]:
	var existentes: Array[int] = []
	for d in GolpeDirecional.DIRECOES_BASE:          # só as do gesto: quem sorteia golpes (IA, boneco) não pede os encaixes extras
		if golpe_para(d) != null:
			existentes.append(d)
	return existentes


## Pose de reação para o lado do impacto (`ResolucaoDeContato.Lado`). Golpe pesado
## usa a própria reação, venha de onde vier.
func reacao_para(lado: int, pesado: bool) -> ChaveDePose:
	if pesado:
		return reacao_pesada
	match lado:
		ResolucaoDeContato.Lado.ESQUERDA:
			return reacao_esquerda
		ResolucaoDeContato.Lado.DIREITA:
			return reacao_direita
		ResolucaoDeContato.Lado.COSTAS:
			return reacao_costas
	return reacao_frente


func validar() -> PackedStringArray:
	var erros := PackedStringArray()
	for d in GolpeDirecional.Direcao.values():
		var quantos := 0
		for g in golpes:
			if g != null and g.direcao == d:
				quantos += 1
		if d < GolpeDirecional.DIRECOES_BASE and quantos != 1:
			erros.append("%s: direção %s tem %d golpe(s); precisa de exatamente 1"
				% [id, GolpeDirecional.Direcao.keys()[d], quantos])
		elif d >= GolpeDirecional.DIRECOES_BASE and quantos > 1:
			erros.append("%s: encaixe extra %s tem %d golpes; no máximo 1" % [id, GolpeDirecional.Direcao.keys()[d], quantos])
	for g in golpes:
		if g == null:
			erros.append("%s: há uma posição vazia na lista de golpes" % id)
		else:
			erros.append_array(g.validar())
	if buffer < 0.0:
		erros.append("%s: buffer negativo" % id)
	if not sequencia_cliques.is_empty() and janela_sequencia <= 0.0:
		erros.append("%s: sequência precisa de janela positiva" % id)
	for direcao in sequencia_cliques:
		if golpe_para(direcao as GolpeDirecional.Direcao) == null:
			erros.append("%s: sequência aponta para direção sem golpe: %d" % [id, direcao])
	if guarda == null or not (guarda.usa_mao_direita and guarda.usa_mao_esquerda and guarda.usa_pes):
		erros.append("%s: a guarda precisa existir e definir as duas mãos e os pés" % id)
	elif guarda != null:
		erros.append_array(guarda.validar("%s/guarda" % id))
	if altura_de_apoio <= 0.0 or soltar_pe_a <= 0.0 or duracao_do_passo <= 0.0 or altura_do_passo <= 0.0:
		erros.append("%s: pés de apoio sem altura, distância, duração ou altura de passo" % id)
	elif guarda != null and maxf(guarda.pe_direito.y, guarda.pe_esquerdo.y) > altura_de_apoio:
		erros.append("%s: a base da guarda (%.3f m) fica acima da altura de apoio (%.3f m) — os pés nunca travariam"
			% [id, maxf(guarda.pe_direito.y, guarda.pe_esquerdo.y), altura_de_apoio])
	if maos.is_empty():
		erros.append("%s: sem pose das mãos (os dedos ficariam com o animador)" % id)
	for papel in maos:
		if not (maos[papel] is Vector3):
			erros.append("%s: mão %s não é Vector3" % [id, papel])
	if transicao_entrada <= 0.0 or transicao_saida <= 0.0:
		erros.append("%s: transições de pose precisam durar mais que zero (evita estalo)" % id)
	for par in [["reação frente", reacao_frente], ["reação esquerda", reacao_esquerda],
			["reação direita", reacao_direita], ["reação costas", reacao_costas], ["reação pesada", reacao_pesada],
			["guarda erguida", pose_guarda_erguida], ["impacto na guarda", pose_impacto_na_guarda],
			["quebra de guarda", pose_quebra_de_guarda], ["aparo", pose_aparo], ["rebatido", pose_rebatido]]:
		if par[1] == null:
			erros.append("%s: falta a pose %s" % [id, par[0]])
		else:
			erros.append_array((par[1] as ChaveDePose).validar("%s/%s" % [id, par[0]]))
	if cone_da_guarda <= 0.0 or postura_maxima <= 0.0 or duracao_da_quebra <= 0.0 or baixar_guarda <= 0.0:
		erros.append("%s: defesa sem cone, postura, quebra ou tempo de baixar a guarda" % id)
	if postura_apos_quebra <= 0.0 or postura_apos_quebra > postura_maxima:
		erros.append("%s: postura após a quebra fora de (0, máxima]" % id)
	# Invariantes de jogo (§7.5 do plano), cobrados nos DADOS para que nenhum ajuste de
	# número os quebre em silêncio.
	var preparo_mais_rapido := INF
	var resto_mais_longo := 0.0   # ativo + recuperação: o que sobra do golpe que quebrou
	for g in golpes:
		if g != null:
			preparo_mais_rapido = minf(preparo_mais_rapido, g.preparo)
			resto_mais_longo = maxf(resto_mais_longo, g.ativo + g.recuperacao)
	var quebra_minima := resto_mais_longo + preparo_mais_rapido + FOLGA_DA_QUEBRA
	if duracao_da_quebra <= quebra_minima:
		erros.append("%s: quebra (%.2f s) precisa passar de %.2f s — o resto do golpe mais longo (%.2f) + o preparo mais rápido (%.2f) + folga (%.2f); senão a quebra feita por ele não rende golpe"
			% [id, duracao_da_quebra, quebra_minima, resto_mais_longo, preparo_mais_rapido, FOLGA_DA_QUEBRA])
	if janela_de_aparo <= 0.0 or duracao_rebatido <= 0.0 or janela_de_riposte <= 0.0 \
			or fator_de_riposte <= 0.0 or janela_de_finta <= 0.0 or custo_da_finta <= 0.0:
		erros.append("%s: aparo, rebote, riposte ou finta sem valor" % id)
	if duracao_rebatido >= preparo_mais_rapido * fator_de_riposte:
		erros.append("%s: rebote (%.2f s) precisa ser menor que o preparo do riposte mais rápido (%.2f s) — riposte não pode ser dano garantido"
			% [id, duracao_rebatido, preparo_mais_rapido * fator_de_riposte])
	for g in golpes:
		if g != null and g.hitstun >= g.recuperacao + preparo_mais_rapido:
			erros.append("%s: hitstun de %s (%.2f s) prende o alvo — precisa ser menor que recuperação + preparo mais rápido (%.2f s)"
				% [id, g.id, g.hitstun, g.recuperacao + preparo_mais_rapido])
	return erros
