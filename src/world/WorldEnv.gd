class_name WorldEnv
extends RefCounted
# ============================================================================
#  O AR E A LUZ — Fase 1 de docs/PLANO_VISUAL.md
#
#  ⚠️ ISTO É A LUZ QUE UM CEL-SHADER VAI CONSUMIR, e por isso três ajustes vão
#  na direção CONTRÁRIA do que se faria num jogo realista. Não é engano:
#
#    SSAO      apertado, quase um risco de contato, em vez de um degradê largo
#    tonemap   REINHARD em vez de FILMIC — filmic dessatura o alto da curva
#    ambiente  BAIXO em vez de alto — ambiente alto achata a diferença entre
#              luz e sombra, e no cel essa diferença É o desenho
#
#  Ajustar o ar para o render de hoje e depois trocar o render seria pagar duas
#  vezes. Ver o §3 do plano.
#
#  ------------------------------------------------------- O QUE FOI MEDIDO
#  Antes desta passada, as cinco cenas de `tools/dev_tests/captura_visual.gd`
#  diziam:
#
#      cena         brilho médio   estourado   PRETO
#      1_mundo         0,666         0,0%       0,0%
#      3_perto         0,714         0,0%       0,1%
#
#  **Zero por cento de preto em toda a tela.** Não havia um tom escuro na
#  imagem inteira — tudo vivia numa faixa estreita, clara. É o "chapado"
#  virado número, e é o alvo desta fase.
#
#  ⚠️ E o chão NÃO estava estourado (0,0% acima de 0,9), ao contrário do que
#  eu tinha afirmado olhando a captura. Ele é CLARO E SEM CONTRASTE, que é
#  outro problema e pede outro remédio: contraste, não corte de exposição.
# ============================================================================

# Escala tudo que custa caro. `GameFlow.device` já existe e o ScreenFX já o
# respeita — a Fase 1 nasce escalada, não adaptada depois.
const PESO := {"celular": 0.45, "tablet": 0.7, "pc": 1.0}


static func apply(parent: Node) -> void:
	var peso := _peso(parent)

	# ------------------------------------------------------------------ SOL
	# Quente e mais forte. A dupla "sol quente + sombra fria" é o par que dá o
	# ensolarado de anime; sol neutro sobre ambiente neutro dá dia nublado.
	var sun := DirectionalLight3D.new()
	sun.name = "Sol"
	sun.rotation_degrees = Vector3(-52, -130, 0)
	sun.light_energy = 1.75
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0 * peso
	# Sombra mais OPACA e menos borrada: no cel a sombra é uma FORMA, não uma
	# mancha suave. `shadow_blur` alto é o que faz sombra de anime parecer de
	# jogo realista mal iluminado.
	sun.shadow_blur = 0.6
	sun.shadow_opacity = 1.0
	parent.add_child(sun)

	# ------------------------------------------------- LUZ DE APOIO (contra)
	# Aproximação barata da luz de contorno (§7.1b do plano) enquanto o
	# cel-shader não existe: uma direcional fria, vinda de trás, SEM sombra.
	# Ela separa o personagem do fundo — que numa arena PvP é função, não
	# enfeite. Some quando a rim light de verdade entrar na Fase 3.
	var contra := DirectionalLight3D.new()
	contra.name = "LuzDeContra"
	contra.rotation_degrees = Vector3(-24, 58, 0)
	contra.light_energy = 0.55
	contra.light_color = Color(0.62, 0.78, 1.0)
	contra.shadow_enabled = false
	parent.add_child(contra)

	var env := Environment.new()

	# ------------------------------------------------------------------ CÉU
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.13, 0.45, 0.90)
	sky_mat.sky_horizon_color = Color(0.66, 0.86, 0.99)
	sky_mat.sky_energy_multiplier = 1.0
	# ⚠️ O "CHÃO" DO CÉU FICOU ESCURO — e isto é conserto de JOGABILIDADE.
	#
	# Ele era verde (0.15, 0.32, 0.22). O mapa é uma grade COM BURACOS e cair
	# é a principal forma de morrer; olhando por um buraco, o jogador via essa
	# cor e o poço lia como GRAMA LÁ EMBAIXO. Um abismo que parece chão
	# convida exatamente o erro que mata.
	sky_mat.ground_bottom_color = Color(0.03, 0.04, 0.07)
	sky_mat.ground_horizon_color = Color(0.20, 0.28, 0.38)
	sky_mat.ground_curve = 0.04
	sky.sky_material = sky_mat
	env.sky = sky

	# -------------------------------------------------------------- AMBIENTE
	# Fonte COR, não CÉU, e energia baixa. Com fonte céu a 1,1 o ambiente
	# preenchia a sombra inteira e não sobrava contraste — os 0,0% de preto da
	# medição. Azul frio de propósito: é a sombra que responde ao sol quente.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.55, 0.78)
	env.ambient_light_energy = 0.55

	# -------------------------------------------------------------- TONEMAP
	# REINHARDT no lugar de FILMIC (o Godot escreve com T no fim). Filmic rola o brilho e DESSATURA o topo da
	# curva, que é o oposto de "cor chapada e saturada". `white` alto deixa o
	# emissivo passar de 1.0 sem virar branco — é o que alimenta o glow.
	env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
	env.tonemap_white = 3.0
	env.tonemap_exposure = 0.92

	# --------------------------------------------------------------- AJUSTES
	# Um pouco mais de contraste e saturação, que é o que a medição pedia.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.18
	env.adjustment_brightness = 1.0

	# ------------------------------------------------------------------ GLOW
	# ⚠️ NÃO EXISTIA GLOW NENHUM NO PROJETO. Agora existe, e está conferido:
	# uma esfera EMISSIVA E SOMBREADA passa a espalhar halo (+0,036 medidos no
	# anel em volta) e o núcleo estoura para branco.
	#
	# ⚠️⚠️ MAS OS VFX DAS FRUTAS *NÃO* MELHORAM DE GRAÇA — eu afirmei isso duas
	# vezes e estava ERRADO. Medido:
	#
	#     esfera unshaded + emissão 4.0   ->  glow on/off IDÊNTICO (+0,0000)
	#     esfera unshaded SÓ albedo       ->  IGUAL à de cima, ao dígito
	#
	# As duas últimas serem idênticas é a prova: `SHADING_MODE_UNSHADED`
	# DESCARTA a emissão inteira. O material devolve só o albedo, que é limitado
	# a 1,0 e nunca cruza o limiar. E `unshaded + emissivo` é exatamente como os
	# efeitos deste jogo são feitos — 32 combinações em 16 arquivos.
	#
	# A correção mínima (medida) é ALBEDO ACIMA DE 1,0, não emissão:
	#
	#     unshaded, albedo 2.5  ->  +0,0586 de halo, mais que o caminho sombreado
	#
	# Ela preserva o motivo de o efeito ser unshaded (não escurecer na sombra da
	# cena). É trabalho da Fase 5 do plano, arquivo por arquivo — não cabe aqui.
	#
	# Limiar ACIMA de 1.0 de propósito (risco 2 do plano): o chão é claro, e
	# limiar baixo transformaria a tela em leite.
	# ⭐ A OUTRA ALAVANCA: `glow_intensity` é o TAMANHO/FORÇA DO HALO, enquanto
	# `FxUtil.ESCALA` é a força do efeito em si. Se o brilho incomodar, mexa
	# primeiro na de lá (o núcleo), depois nesta (a auréola).
	#
	# ⚠️ BAIXADO EM 2026-08-25 a pedido do dono ("o brilho das skills está muito
	# alto"). Estava intensidade 0,9, limiar 1,05 e quatro níveis ligados —
	# medido, isso dava 3,0% da tela estourada numa cena com UM golpe. O limiar
	# subiu junto: 1,15 deixa passar só o núcleo de verdade, e não a borda
	# meio-clara de tudo que é emissivo.
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.15
	env.glow_hdr_scale = 1.6
	env.glow_intensity = 0.5 if peso >= 1.0 else 0.38
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# Níveis: os baixos dão o halo colado, os altos dão o brilho largo. No
	# celular ficam só os colados, que é o que cabe no orçamento.
	#
	# ⚠️ `set_glow_level()` É BASE ZERO (índices 0..6) — os nomes que aparecem
	# no inspetor (`glow_levels/1` .. `/7`) são base UM. Escrevi 1..7 e o Godot
	# respondeu `Index p_level = 7 is out of bounds`: o último nível estourava e
	# o primeiro nunca era zerado, ou seja o glow saía mal configurado, com um
	# erro que passa no meio do log.
	# ⚠️ NÍVEL ALTO = HALO LARGO, e é o que mais incomodava. O nível 4 (auréola
	# bem aberta) saiu, e o 3 caiu pela metade: o brilho ficou COLADO no efeito
	# em vez de virar uma mancha em volta.
	for i in 7:
		env.set_glow_level(i, 0.0)
	env.set_glow_level(1, 1.0)      # halo colado
	env.set_glow_level(2, 0.5)
	if peso >= 1.0:
		env.set_glow_level(3, 0.25)

	# ------------------------------------------------------------------ AR
	# Névoa só para PERSPECTIVA AÉREA. A profundidade do poço é do FUNDO, não
	# do ar — ver `_fundo_do_poco()` embaixo.
	#
	# ⚠️ ERRO COMETIDO E CORRIGIDO NA MESMA SESSÃO, registrado porque a causa é
	# de conceito e volta fácil:
	#
	# A primeira versão tentou fazer a névoa cumprir DUAS funções opostas —
	# clarear ao longe (perspectiva aérea) e escurecer para baixo (o poço) —
	# ligando `fog_height_density = 0.16`. O `Environment` tem UMA cor de
	# névoa só. Como ela precisa ser clara para a perspectiva aérea, o poço
	# encheu de névoa opaca e CLARA: o buraco deixou de parecer grama (a cor
	# verde do "chão" do céu) e passou a parecer ÁGUA. E a névoa opaca ainda
	# escondeu o plano escuro do fundo, que era quem deveria resolver.
	#
	# Uma cor não faz dois trabalhos contrários. O ar clareia; o fundo escurece.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.62, 0.78, 0.94)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = 0.0020
	env.fog_sky_affect = 0.22
	env.fog_aerial_perspective = 0.42
	# ⚠️ QUEDA POR ALTURA EM ZERO — medido, não estimado.
	#
	# Isolei a causa capturando o mesmo poço em três condições e lendo a cor no
	# meio dele:
	#
	#     como estava (névoa on, fundo on)   (0,263  0,369  0,467)   azul lavado
	#     SEM NÉVOA,  fundo on               (0,000  0,000  0,000)   preto
	#     SEM NÉVOA,  fundo off              (0,000  0,000  0,016)   preto
	#
	# Duas conclusões, e as duas mudaram o desenho:
	#  1. quem lavava o poço era a NÉVOA sozinha — mesmo com a densidade de
	#     altura já reduzida a 0,012. Ela vai a zero;
	#  2. o "chão" escuro do céu já entrega preto SEM plano de fundo nenhum.
	#     O plano que eu tinha criado era redundante e foi removido.
	#
	# A névoa de base (0,0020) ainda dá ~10% de lavagem em 55 m, que é o
	# gradiente suficiente para o poço ter profundidade sem virar chapa preta.
	env.fog_height = 0.0
	env.fog_height_density = 0.0

	# ------------------------------------------------------------------ SSAO
	# ⚠️ APERTADO, não desligado — e isto é adaptação, não o que o plano dizia.
	#
	# O plano pedia "SSAO fora, sombra de contato no lugar". O Godot 4 NÃO tem
	# sombra de contato (era coisa do 3.x, `shadow_contact`). O que chega
	# perto é um SSAO de raio pequeno e queda dura: ele escurece o encontro de
	# duas superfícies como uma LINHA, em vez do degradê largo que briga com
	# faixa chapada. Raio era 1,2; agora é 0,3.
	env.ssao_enabled = peso >= 0.7
	env.ssao_radius = 0.3
	env.ssao_intensity = 3.2
	env.ssao_power = 2.4
	env.ssao_detail = 1.0
	env.ssao_horizon = 0.2

	var we := WorldEnvironment.new()
	we.name = "Ambiente"
	we.environment = env
	parent.add_child(we)

	# CONTORNO (Fase 2). Entra aqui e não junto da câmera de propósito: o quad
	# vai para a tela inteira pelo `vertex()` do shader, então não depende de
	# onde está no mundo — e a câmera do jogo nasce dentro do `CameraRig` de
	# cada jogador, que é lugar ruim para pendurar estilo de render.
	Contorno.criar(parent)

# ⚠️ NÃO EXISTE PLANO DE FUNDO NO POÇO, e a ausência é uma decisão medida.
#
# Cheguei a criar um: um `PlaneMesh` de 600×600 escuro em y = −46, para o
# buraco ter fundo visual sem ter fundo físico. A medição mostrou que ele era
# REDUNDANTE — só com o "chão" escuro do céu (`ground_bottom_color`) a cor no
# meio do poço já era (0,000 0,000 0,016), praticamente o mesmo preto que o
# plano dava.
#
# E ele nunca seria visto de perto: o jogador morre em `Scoreboard.VOID_Y`
# (−40), seis metros ACIMA de onde o plano estava. Malha de 600×600 para
# reproduzir o que o céu já faz é peso sem função.


static func _peso(parent: Node) -> float:
	var arv := parent.get_tree() if parent.is_inside_tree() else null
	if arv == null:
		return 1.0
	var gf := arv.root.get_node_or_null("GameFlow")
	if gf == null:
		return 1.0
	return float(PESO.get(str(gf.get("device")), 1.0))
