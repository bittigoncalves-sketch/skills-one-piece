extends RefCounted
## Contrato de dados do Skills Builder. JSON contém valores, nunca recursos/código.
const FORMATO := "skills-one-piece/skill"
const VERSAO := 1
const PASTA := "user://skills_builder"
const MAX_BYTES := 1024 * 1024
const MAX_EVENTOS := 64
const TIPOS := ["hitbox", "movimento", "projetil", "animacao", "vfx", "audio", "camera", "transformacao"]
const Catalogo = preload("res://src/skills_builder/catalogo_de_projeteis.gd")
const Clipes = preload("res://src/skills_builder/clipes_de_skill.gd")
const ANCORAS := ["Jogador", "Osso do jogador", "Alvo", "Projétil", "Ponto mirado", "Mundo"]
## Osso da âncora → nó do rig (a mão direita é o `Hand_R`; a esquerda, a ponta do antebraço).
const OSSOS := ["Mão direita", "Mão esquerda", "Cabeça", "Tronco", "Pé direito", "Pé esquerdo"]
const SONS := ["Vento", "Impacto", "Disparo", "Luz: carga", "Luz: disparo", "Luz: fragmento", "Luz: impacto",
	"Luz: viagem", "Luz: explosão", "Luz: teleporte", "Luz: barragem", "Gelo: disparo", "Gelo: rajada"]

static func _campo(id: String, nome: String, tipo: String, padrao: Variant, minimo: float = 0.0, maximo: float = 0.0, opcoes: Array = []) -> Dictionary:
	return {"id": id, "nome": nome, "tipo": tipo, "padrao": padrao, "min": minimo, "max": maximo, "opcoes": opcoes}

## Campo que pode faltar no arquivo (acréscimo compatível com a versão 1).
static func _campo_opcional(id: String, nome: String, tipo: String, padrao: Variant, minimo: float = 0.0, maximo: float = 0.0, opcoes: Array = []) -> Dictionary:
	var c := _campo(id, nome, tipo, padrao, minimo, maximo, opcoes)
	c["opcional"] = true
	return c

static func secoes() -> Array[Dictionary]:
	return [
		{"id": "identificacao", "nome": "Identificação da skill", "campos": [
			_campo("id", "Identificador", "texto", "nova_skill", 1, 64),
			_campo("nome", "Nome", "texto", "Nova skill", 1, 80),
			_campo("descricao", "Descrição", "longo", "", 0, 2000),
			_campo("dono", "Usuário", "enum", "Jogador", 0, 0, ["Jogador", "Inimigo", "Chefe", "Animal"]),
			# Quem, dentro do Usuário, usa a skill (06/10/2026, decisão do dono): o id do
			# modelo de inimigo da loja, do chefe ou da espécie. Jogador: a tecla da
			# ativação. OPCIONAL para os arquivos de antes continuarem válidos.
			_campo_opcional("atribuida_a", "Quem usa", "texto", "", 0, 64),
			# Fruta do Builder (06/10/2026): a skill de Jogador vai para a tecla desta fruta
			# (id do catálogo `mapas/skills/frutas.json`); vazio = Kit do Builder.
			_campo_opcional("fruta", "Fruta", "texto", "", 0, 64),
			_campo("modelo", "Modelo da prévia", "enum", "Base", 0, 0, ["Base", "Harpia"])]},
		{"id": "configuracoes", "nome": "Configurações principais", "campos": [
			_campo("duracao", "Duração (s)", "numero", 1.5, 0.1, 30),
			_campo("recarga", "Recarga (s)", "numero", 2.0, 0, 600),
			_campo("custo", "Custo de energia", "numero", 10.0, 0, 10000),
			_campo("alcance", "Alcance (m)", "numero", 8.0, 0, 100),
			# Pika refeita no editor (06/10/2026): sem gravidade do começo ao fim da skill
			# (golpe no ar), e o rumo travado no alvo mais perto (até o Alcance) ao sair.
			_campo_opcional("flutuar", "Flutuar durante a skill", "bool", false),
			_campo_opcional("mirar_no_alvo", "Mirar no alvo mais perto", "bool", false),
			# Intervalo entre golpes (07/10/2026, pedido do dono): depois desta skill, outro
			# golpe de fruta só sai passado este tempo (o jogo usa 0,5 s nas frutas em código).
			_campo_opcional("intervalo_depois", "Intervalo até o próximo golpe (s)", "numero", 0.5, 0, 10),
			# Viagem que acaba antes (07/10/2026, X da Pika): nos Movimentos no plano, um
			# inimigo até este raio (m; 0 = desligado), perto ou embaixo, leva o ator para
			# cima dele; "Parar antes do vazio" não deixa a viagem sair de cima do chão. Nos
			# dois, a timeline pula para "Início do fim" (s; −1 = só pára a viagem).
			_campo_opcional("fim_sobre_alvo", "Terminar sobre o inimigo (raio, m)", "numero", 0.0, 0, 30),
			_campo_opcional("parar_no_vazio", "Parar antes do vazio", "bool", false),
			_campo_opcional("inicio_do_fim", "Início do fim (s)", "numero", -1.0, -1, 30),
			# Custo enquanto a tecla está segurando (07/10/2026, F da Pika): % da energia
			# máxima por segundo; acabou a energia, a skill solta sozinha.
			_campo_opcional("custo_por_segundo", "Custo por segundo segurando (%)", "numero", 0.0, 0, 100)]},
		{"id": "ativacao", "nome": "Sistema de ativação", "campos": [
			# "Sustentar" (06/10/2026, C da Pika): a timeline anda enquanto a tecla está
			# apertada; soltar ENCERRA a skill ali (o que faltava não sai).
			_campo("modo", "Modo", "enum", "Pressionar", 0, 0, ["Pressionar", "Segurar", "Automática", "Carregar e soltar", "Sustentar"]),
			_campo("tecla", "Tecla", "enum", "Z", 0, 0, ["Z", "X", "C", "V", "F"]),
			_campo("carga", "Tempo de carga (s)", "numero", 0.5, 0, 30),
			_campo("repetir", "Repetir enquanto ativo", "bool", false),
			# "Carregar e soltar" (06/10/2026): a timeline PÁRA em `ponto_segurar` enquanto
			# a tecla está apertada (até `segurar_max`); soltar continua; soltar antes do
			# ponto cancela e devolve a energia.
			_campo_opcional("ponto_segurar", "Ponto de segurar (s)", "numero", 0.5, 0, 30),
			_campo_opcional("segurar_max", "Segurar no máximo (s)", "numero", 5.0, 0.1, 30),
			# Z da Pika (07/10/2026): em "Carregar e soltar", o Impulso cresce com o tempo
			# segurado até este multiplicador, com a carga cheia no Tempo de carga.
			_campo_opcional("empurrao_carga_max", "Impulso com carga cheia (×)", "numero", 1.0, 1, 5),
			# Segurando a tecla (Carregar e soltar, Sustentar, carga do Segurar) o jogador
			# NÃO anda, não pula nem esquiva (pedido do dono, 07/10/2026) — salvo esta opção
			# (voo, golpe que se move enquanto segura).
			_campo_opcional("andar_segurando", "Pode andar enquanto segura", "bool", false),
			# Z da Pika (10/10/2026, pedido do dono): segurando, o jogador fica PARADO onde
			# está, inclusive no ar (sem cair). Só no Modo História ("todas as alterações no
			# modo história"); na arena o campo não muda nada.
			_campo_opcional("paralisar_segurando", "Paralisa segurando, até no ar (Modo História)", "bool", false)]},
		{"id": "hitboxes", "nome": "Hitboxes", "campos": [
			_campo("forma", "Forma", "enum", "Esfera", 0, 0, ["Esfera", "Caixa", "Cápsula"]),
			_campo("raio", "Raio (m)", "numero", 1.5, 0.05, 30),
			_campo("largura", "Largura (m)", "numero", 3.0, 0.1, 60),
			_campo("altura", "Altura (m)", "numero", 3.0, 0.1, 60),
			_campo("profundidade", "Profundidade (m)", "numero", 3.0, 0.1, 60),
			_campo("x", "Posição X (m)", "numero", 0.0, -100, 100),
			_campo("y", "Posição Y (m)", "numero", 1.0, -100, 100),
			_campo("z", "Posição Z (m)", "numero", -2.0, -100, 100),
			_campo("unicos", "Um acerto por alvo", "bool", true),
			# Segue a MIRA (com a inclinação) a partir de X/Y e pára na primeira parede: o
			# comprimento é a Profundidade (feixe da Z da Pika, 06/10/2026).
			_campo_opcional("mirar", "Seguir a mira", "bool", false),
			# Nasce na MÃO direita do ator (07/10/2026, Z da Pika calibrado): o feixe sai da
			# mão e continua indo ao ponto do retículo.
			_campo_opcional("na_mao", "Nasce na mão", "bool", false)]},
		{"id": "dano", "nome": "Dano e efeitos", "campos": [
			_campo("valor", "Dano", "numero", 25.0, 0, 100000),
			_campo("tipo", "Tipo", "enum", "Físico", 0, 0, ["Físico", "Vento", "Fogo", "Gelo"]),
			_campo("critico", "Chance crítica (%)", "numero", 0.0, 0, 100),
			_campo("multiplicador", "Multiplicador crítico", "numero", 2.0, 1, 10),
			_campo("empurrao", "Impulso (m/s)", "numero", 1.5, 0, 50),
			_campo("atordoamento", "Atordoamento (s)", "numero", 0.2, 0, 30),
			_campo("lentidao", "Lentidão (%)", "numero", 0.0, 0, 100),
			_campo("duracao_efeito", "Duração do efeito (s)", "numero", 1.0, 0, 30),
			# Congelar (07/10/2026, Hie refeita: "todos os golpes congelam 0,7 s"): o bloco
			# de gelo do jogo prende quem leva; depois, 0,5 s de imunidade ao gelo.
			_campo_opcional("congelar", "Congelar (s)", "numero", 0.0, 0, 10),
			# Cura pelo dano (Nikyu Nikyu C, 14/10/2026): o usuário recupera esta % do dano
			# que o acerto causa (limitada à vida máxima).
			_campo_opcional("cura_do_dano", "Cura do dano causado (%)", "numero", 0.0, 0, 500)]},
		{"id": "movimento", "nome": "Movimento", "campos": [
			# "Mira" (07/10/2026, voo do F da Pika): anda para onde a câmera aponta AGORA, na
			# Velocidade, enquanto o bloco dura (sem destino fixo).
			_campo("direcao", "Direção", "enum", "Frente", 0, 0, ["Frente", "Trás", "Acima", "Mira"]),
			_campo("velocidade", "Velocidade (m/s)", "numero", 6.0, 0, 100),
			_campo("distancia", "Distância máxima (m)", "numero", 2.0, 0, 100),
			_campo("curva", "Curva", "enum", "Suave", 0, 0, ["Linear", "Suave"]),
			# Zigue-zague e subida da Pika (06/10/2026): desvio da Direção (graus; + para a
			# direita, + para cima) e Teleporte = chega ao fim na hora (pára na parede).
			_campo_opcional("angulo", "Ângulo lateral (graus)", "numero", 0.0, -180, 180),
			_campo_opcional("inclinacao", "Inclinação (graus)", "numero", 0.0, -90, 90),
			_campo_opcional("teleporte", "Teleporte", "bool", false),
			# Só se começar no chão (o X da Pika sobe do chão; no ar, começa de onde está).
			_campo_opcional("so_do_chao", "Só se estiver no chão", "bool", false)]},
		{"id": "projeteis", "nome": "Projéteis", "campos": [
			_campo("velocidade", "Velocidade (m/s)", "numero", 12.0, 0, 100),
			_campo("raio", "Raio (m)", "numero", 0.4, 0.05, 10),
			_campo("quantidade", "Quantidade", "inteiro", 1, 1, 16),
			_campo("abertura", "Abertura (graus)", "numero", 20.0, 0, 180),
			_campo("gravidade", "Gravidade (m/s²)", "numero", 0.0, -50, 50),
			_campo("vida", "Vida (s)", "numero", 2.0, 0.1, 10),
			_campo("perfurar", "Atravessar alvos", "bool", false),
			# Esfera do X da Pika (06/10/2026): para onde sai, explosão ao tocar (raio; 0 =
			# não explode; quem fere é a explosão) e projétil só de efeito (sem dano).
			# "Chuva" (07/10/2026, C da Pika): sobem em arco e caem espalhados num círculo
			# ("Área da chuva", raio em m) em volta do chão mirado.
			_campo_opcional("direcao_disparo", "Sai para", "enum", "Mira", 0, 0, ["Mira", "Frente", "Abaixo", "Chuva", "Anel"]),
			# "Anel" (Nikyu Nikyu, 14/10/2026): os projéteis nascem em volta do jogador (a
			# esta distância, em alturas variadas) e saem todos para a mira.
			# Projétil grande que voa rente ao chão (Nikyu Nikyu, 14/10/2026): o desenho usa o
			# Raio; o ACERTO usa este (0 = igual ao Raio), para a pata de 3 m não raspar o piso.
			_campo_opcional("raio_de_acerto", "Raio do acerto (m; 0 = o Raio)", "numero", 0.0, 0, 10),
			_campo_opcional("raio_do_anel", "Raio do anel (m)", "numero", 2.5, 0.5, 20),
			_campo_opcional("area_chuva", "Área da chuva (raio, m)", "numero", 8.0, 1, 40),
			# De onde sai (07/10/2026, Z da Hie: as estacas saem das mãos estendidas).
			_campo_opcional("sai_de", "Sai de", "enum", "Corpo", 0, 0, ["Corpo", "Mão direita", "Mão esquerda", "Entre as mãos"]),
			_campo_opcional("explosao", "Explosão ao tocar (m)", "numero", 0.0, 0, 20),
			# Z da Hie (10/10/2026, pedido do dono: "só concede imunidade ao gelo no terceiro
			# disparo e caso acerte"): desligado, o acerto congela SEM deixar a imunidade —
			# e estica o gelo de quem já está preso. Só no Modo História; na arena todo
			# acerto dá a imunidade de sempre.
			_campo_opcional("imunidade_gelo", "Dá imunidade ao gelo ao acertar (Modo História)", "bool", true),
			_campo_opcional("sem_dano", "Só efeito (sem dano)", "bool", false),
			_campo_opcional("som_explosao", "Som da explosão", "enum", "Impacto", 0, 0, SONS),
			# Loja de projéteis (06/10/2026): a forma do catálogo ou um modelo da loja do
			# editor, o giro (graus/s) e o rastro. Só desenho: o acerto segue o Raio.
			_campo_opcional("visual", "Forma", "enum", Catalogo.PADRAO, 0, 0, Catalogo.FORMAS),
			_campo_opcional("modelo", "Modelo da loja", "texto", "", 0, 64),
			_campo_opcional("giro", "Giro (graus/s)", "numero", 0.0, 0, 3600),
			_campo_opcional("rastro", "Rastro", "enum", "Nenhum", 0, 0, Catalogo.RASTROS)]},
		{"id": "animacao", "nome": "Animação", "campos": [
			# Clipes do jogo (07/10/2026): combate, rolamentos, movimento e posturas; os 5
			# nomes antigos viram atalhos. Prévia e jogo tocam o MESMO clipe (`clipes_de_skill`).
			_campo("clipe", "Clipe", "enum", "Ataque", 0, 0, Clipes.opcoes()).merged({"aceita": Clipes.RENOMEADOS, "rotulos": Clipes.rotulos()}),
			_campo("velocidade", "Velocidade", "numero", 1.0, 0.1, 4),
			# Quanto do clipe vale sobre o corpo (0..1; acima de 1 conta como 1).
			_campo("intensidade", "Intensidade", "numero", 1.0, 0, 3),
			# Poses próprias da skill (06/10/2026): com Pose escolhida, o bloco segura a
			# pose em vez do clipe; Transição = tempo para chegar nela; Pulso = vibração.
			_campo_opcional("pose", "Pose", "texto", "", 0, 64),
			_campo_opcional("transicao", "Transição (s)", "numero", 0.15, 0, 2),
			_campo_opcional("pulso", "Pulso", "numero", 0.0, 0, 1)]},
		{"id": "vfx", "nome": "VFX", "campos": [
			# Cometa (06/10/2026): o corpo VIRA luz durante o bloco (some e vira um cometa).
			# Explosão: clarão que cresce e some.
			# Estrela (07/10/2026): estrela de quatro pontas que cresce com a carga.
			# Rachadura (14/10/2026): fenda no chão que se abre e some (Escala = diâmetro ~1,6 m x Escala).
			_campo("estilo", "Estilo", "enum", "Impacto", 0, 0, ["Impacto", "Anel", "Vento", "Tornado", "Carga", "Feixe", "Fótons", "Cometa", "Explosão", "Estrela", "Rachadura"]),
			_campo("cor", "Cor", "cor", "#66e6ff"),
			_campo("escala", "Escala", "numero", 1.0, 0.1, 10),
			# Fótons cintilantes (Noro Noro, 06/10/2026): onde o efeito nasce (metros a partir
			# do pé e da frente do ator) e o comprimento do Feixe.
			_campo_opcional("altura", "Altura (m)", "numero", 1.0, 0, 5),
			_campo_opcional("frente", "À frente (m)", "numero", 1.0, -5, 10),
			_campo_opcional("comprimento", "Comprimento do feixe (m)", "numero", 8.0, 0.5, 60),
			_campo_opcional("mirar", "Seguir a mira", "bool", false),
			# Segunda cor dos efeitos de luz (cintilas, véu do feixe). Vazia = lilás (Noro).
			_campo_opcional("cor_2", "Cor secundária", "texto", "", 0, 7),
			_campo_opcional("na_mao", "Nasce na mão", "bool", false),
			# Âncora (07/10/2026, pedido do dono): onde o efeito nasce e fica — no jogador
			# (Altura/À frente valem só aqui), num osso dele, no alvo (inimigo mais perto),
			# num projétil de um bloco (segue a bolinha; id do bloco), no ponto mirado ou
			# parado no mundo onde nasceu.
			_campo_opcional("ancora", "Âncora", "enum", "Jogador", 0, 0, ANCORAS),
			_campo_opcional("osso", "Osso da âncora", "enum", "Mão direita", 0, 0, OSSOS),
			_campo_opcional("projetil_de", "Projétil do bloco (id)", "texto", "", 0, 64)]},
		{"id": "transformacao", "nome": "Transformação", "opcional": true, "campos": [
			_campo("alvo", "Transformar", "enum", "Usuário", 0, 0, ["Usuário", "Inimigo mais próximo", "Inimigos ao redor", "Assets ao redor", "Inimigos e assets ao redor"]),
			_campo("raio", "Alcance / raio (m)", "numero", 8.0, 0.1, 50),
			_campo("visual", "Asset", "enum", "Fumaça", 0, 0, ["Fumaça", "Luz", "Modelo da loja"]),
			_campo("modelo", "Modelo da loja", "texto", "", 0, 64),
			_campo("escala", "Escala visual", "numero", 1.0, 0.1, 5),
			_campo("cor", "Cor da fumaça / luz", "cor", "#dce9ff")]},
		{"id": "audio", "nome": "Áudio", "campos": [
			# Sons de luz (06/10/2026): as vozes da Pika (`PikaAudio`), para a fruta refeita
			# no editor soar como ela.
			_campo("som", "Som", "enum", "Impacto", 0, 0, SONS),
			_campo("volume", "Volume (dB)", "numero", -12.0, -60, 0),
			_campo("tom", "Tom", "numero", 1.0, 0.25, 3)]},
		{"id": "camera", "nome": "Câmera", "campos": [
			_campo("tremor", "Tremor", "numero", 0.2, 0, 2),
			_campo("zoom", "Campo de visão (graus)", "numero", 40.0, 25, 100)]},
		{"id": "condicoes", "nome": "Condições", "campos": [
			_campo("nivel_minimo", "Nível mínimo", "inteiro", 1, 1, 1000),
			_campo("vida_minima", "Vida mínima (%)", "numero", 0.0, 0, 100),
			_campo("exige_chao", "Exige chão", "bool", false),
			_campo("exige_alvo", "Exige alvo", "bool", true),
			_campo("distancia_maxima", "Distância máxima do alvo (m)", "numero", 30.0, 0, 100)]}
	]

static func novo() -> Dictionary:
	var skill := {"formato": FORMATO, "versao": VERSAO, "eventos": [], "poses": []}
	for secao in secoes():
		var dados := {}
		for campo in secao.campos:
			dados[campo.id] = campo.padrao
		skill[secao.id] = dados
	var padroes := [["animacao", 0.0, 0.9], ["movimento", 0.2, 0.2], ["hitbox", 0.35, 0.25], ["vfx", 0.35, 0.4], ["audio", 0.35, 0.2], ["camera", 0.35, 0.3]]
	for item in padroes:
		skill.eventos.append({"id": item[0] + "_1", "tipo": item[0], "inicio": item[1], "duracao": item[2], "habilitado": true, "parametros": {}})
	return skill

static func secao_evento(tipo: String) -> String:
	return {"hitbox": "hitboxes", "projetil": "projeteis"}.get(tipo, tipo)

static func parametros(skill: Dictionary, evento: Dictionary) -> Dictionary:
	var secao := secao_evento(str(evento.get("tipo", "")))
	var resultado: Dictionary = skill.get(secao, {}).duplicate(true)
	# Seções adicionadas na versão 1 podem não existir em skills já publicadas.
	if secao == "transformacao":
		for s in secoes():
			if s.id == secao:
				for c in s.campos:
					if not resultado.has(c.id): resultado[c.id] = c.padrao
	resultado.merge(evento.get("parametros", {}), true)
	return resultado

static func _id_de_modelo(valor: Variant) -> bool:
	return not valor is String or valor.is_empty() or _regex(valor, "^[A-Za-z0-9_-]{1,64}$")

static func _numero(valor: Variant) -> bool:
	return (valor is int or valor is float) and is_finite(float(valor))

static func _regex(valor: String, expressao: String) -> bool:
	var regex := RegEx.new()
	regex.compile(expressao)
	return regex.search(valor) != null

static func _campos(dados: Variant, campos: Array, local: String, parcial: bool, erros: Array[String]) -> void:
	if not dados is Dictionary:
		erros.append(local + " precisa ser um objeto.")
		return
	var permitidos: Array = []
	for campo in campos:
		permitidos.append(campo.id)
		var chave: String = campo.id
		if not dados.has(chave):
			if not parcial and not campo.get("opcional", false):
				erros.append(local + "." + chave + " é obrigatório.")
			continue
		var valor: Variant = dados[chave]
		var valido := false
		match campo.tipo:
			"texto", "longo":
				valido = valor is String and valor.length() >= campo.min and valor.length() <= campo.max
			"numero", "inteiro":
				valido = _numero(valor) and float(valor) >= campo.min and float(valor) <= campo.max
				if valido and campo.tipo == "inteiro":
					valido = float(valor) == floor(float(valor))
			"bool": valido = valor is bool
			"objeto": valido = valor is Dictionary
			# `aceita`: nomes antigos que saíram da lista e ainda valem ({antigo: atual}).
			"enum": valido = valor is String and (valor in campo.opcoes or valor in campo.get("aceita", {}))
			"cor": valido = valor is String and _regex(valor, "^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$")
		if not valido:
			erros.append(local + "." + chave + ": valor inválido (" + campo.tipo + ").")
	for chave in dados:
		if not chave in permitidos:
			erros.append(local + ": campo desconhecido " + str(chave) + ".")

static func validar(raw: Variant) -> Dictionary:
	var erros: Array[String] = []
	if not raw is Dictionary:
		return {"ok": false, "erros": ["A skill precisa ser um objeto JSON."], "skill": {}}
	if raw.get("formato") != FORMATO:
		erros.append("Formato de skill inválido.")
	if not _numero(raw.get("versao")) or raw.get("versao") != VERSAO:
		erros.append("Versão de skill não suportada.")
	var permitidos := ["formato", "versao", "eventos", "poses"]
	var metadados := {}
	for secao in secoes():
		permitidos.append(secao.id)
		metadados[secao.id] = secao.campos
		if secao.get("opcional", false) and not raw.has(secao.id):
			continue
		_campos(raw.get(secao.id), secao.campos, secao.id, false, erros)
	for chave in raw:
		if not chave in permitidos:
			erros.append("Campo desconhecido: " + str(chave))
	var identificacao: Variant = raw.get("identificacao")
	if identificacao is Dictionary and identificacao.get("id") is String:
		if not _regex(identificacao.id, "^[A-Za-z0-9_-]{1,64}$"):
			erros.append("Identificador: use 1–64 letras ASCII, números, _ ou -.")
		var fr: Variant = identificacao.get("fruta", "")
		if fr is String and not fr.is_empty() and not _regex(fr, "^[a-z0-9_]{1,64}$"):
			erros.append("Fruta: id inválido (minúsculas, números e _).")
		var quem: Variant = identificacao.get("atribuida_a", "")
		if quem is String and not quem.is_empty() and not _regex(quem, "^[A-Za-z0-9_-]{1,64}$"):
			erros.append("Quem usa: id inválido (letras ASCII, números, _ ou -).")
	var eventos: Variant = raw.get("eventos")
	if not eventos is Array or eventos.size() > MAX_EVENTOS:
		erros.append("A timeline precisa de uma lista de até 64 eventos.")
	else:
		var ids := {}
		var total := 0.0
		if raw.get("configuracoes") is Dictionary and _numero(raw.configuracoes.get("duracao")):
			total = float(raw.configuracoes.duracao)
		for i in eventos.size():
			var evento: Variant = eventos[i]
			var local := "eventos[%d]" % i
			if not evento is Dictionary:
				erros.append(local + " precisa ser um objeto.")
				continue
			_campos(evento, [_campo("id", "", "texto", "", 1, 64), _campo("tipo", "", "enum", "", 0, 0, TIPOS), _campo("inicio", "", "numero", 0, 0, 30), _campo("duracao", "", "numero", 0, 0.01, 30), _campo("habilitado", "", "bool", true), {"id": "parametros", "tipo": "objeto"}], local, false, erros)
			# O validador genérico trata campos escalares; parâmetros são validados abaixo.
			if evento.get("id") is String:
				if not _regex(evento.id, "^[A-Za-z0-9_-]{1,64}$") or ids.has(evento.id):
					erros.append(local + ": ID inválido ou repetido.")
				ids[evento.id] = true
			if _numero(evento.get("inicio")) and _numero(evento.get("duracao")) and float(evento.inicio) + float(evento.duracao) > total + 0.000001:
				erros.append(local + ": o evento ultrapassa a duração da skill.")
			if evento.get("tipo") is String and evento.tipo in TIPOS:
				_campos(evento.get("parametros"), metadados[secao_evento(evento.tipo)], local + ".parametros", true, erros)
	# Modelo da loja como projétil: o id vira caminho de arquivo na loja, então só o
	# formato de id (nada de "../").
	var proj: Variant = raw.get("projeteis")
	var trans: Variant = raw.get("transformacao", {})
	if trans is Dictionary and not _id_de_modelo(trans.get("modelo", "")):
		erros.append("Transformação: modelo da loja com id inválido.")
	if proj is Dictionary and not _id_de_modelo(proj.get("modelo", "")):
		erros.append("Projéteis: modelo da loja com id inválido.")
	if eventos is Array:
		for evento in eventos:
			if evento is Dictionary and evento.get("parametros") is Dictionary and not _id_de_modelo(evento.parametros.get("modelo", "")):
				erros.append("Evento %s: modelo da loja com id inválido." % str(evento.get("id", "?")))
	# Poses (opcionais): a lista e, nos blocos de Animação, a pose citada tem de existir.
	erros.append_array(PosesDeSkill.erros(raw.get("poses")))
	if eventos is Array:
		var existentes := PosesDeSkill.ids(raw)
		for evento in eventos:
			if evento is Dictionary and evento.get("parametros") is Dictionary:
				var citada: Variant = evento.parametros.get("pose", "")
				if citada is String and not citada.is_empty() and not citada in existentes:
					erros.append("Evento %s: a pose \"%s\" não existe." % [str(evento.get("id", "?")), citada])
	if erros.is_empty() and JSON.stringify(raw).to_utf8_buffer().size() > MAX_BYTES:
		erros.append("A skill excede o limite de 1 MiB.")
	var documento: Dictionary = raw.duplicate(true) if erros.is_empty() else {}
	if erros.is_empty() and not documento.has("transformacao"):
		documento.transformacao = parametros(documento, {"tipo": "transformacao"})
	return {"ok": erros.is_empty(), "erros": erros, "skill": documento}

static func carregar(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {"ok": false, "erros": ["Não foi possível abrir a skill: " + error_string(FileAccess.get_open_error())], "skill": {}}
	if arquivo.get_length() > MAX_BYTES:
		return {"ok": false, "erros": ["A skill excede o limite de 1 MiB."], "skill": {}}
	var json := JSON.new()
	if json.parse(arquivo.get_as_text()) != OK:
		return {"ok": false, "erros": ["JSON inválido na linha %d: %s" % [json.get_error_line(), json.get_error_message()]], "skill": {}}
	return validar(json.data)

static func salvar(skill: Dictionary, pasta: String = PASTA) -> Dictionary:
	# Validar o ID antes de compor qualquer caminho.
	var resultado := validar(skill)
	if not resultado.ok:
		return {"ok": false, "erros": resultado.erros, "caminho": ""}
	return salvar_em(skill, pasta.path_join(str(skill.identificacao.id) + ".json"))

static func salvar_em(skill: Dictionary, caminho: String) -> Dictionary:
	var resultado := validar(skill)
	if not resultado.ok:
		return {"ok": false, "erros": resultado.erros, "caminho": ""}
	var absoluto := ProjectSettings.globalize_path(caminho)
	var erro := DirAccess.make_dir_recursive_absolute(absoluto.get_base_dir())
	if erro != OK:
		return {"ok": false, "erros": ["Não foi possível criar a pasta: " + error_string(erro)], "caminho": ""}
	var temporario := absoluto + ".%d.tmp" % Time.get_ticks_usec()
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return {"ok": false, "erros": ["Não foi possível gravar: " + error_string(FileAccess.get_open_error())], "caminho": ""}
	arquivo.store_string(JSON.stringify(resultado.skill, "\t") + "\n")
	arquivo.flush()
	erro = arquivo.get_error()
	arquivo.close()
	if erro == OK:
		erro = DirAccess.rename_absolute(temporario, absoluto)
	if erro != OK:
		DirAccess.remove_absolute(temporario)
		return {"ok": false, "erros": ["Não foi possível salvar: " + error_string(erro)], "caminho": ""}
	return {"ok": true, "erros": [], "caminho": caminho}

static func listar(pasta: String = PASTA) -> Array[String]:
	var caminhos: Array[String] = []
	var dir := DirAccess.open(pasta)
	if dir == null:
		return caminhos
	for nome in dir.get_files():
		if nome.ends_with(".json"):
			caminhos.append(pasta.path_join(nome))
	caminhos.sort()
	return caminhos
