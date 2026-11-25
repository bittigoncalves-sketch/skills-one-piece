class_name KitDoBuilder
extends RefCounted
## O Kit do Builder: as skills publicadas do JOGADOR equipadas como uma fruta
## (decisão do dono, 06/10/2026). Ele entra pelo mesmo caminho das Akuma no Mi —
## `current_fruit_id`, `_fire_skill`, energia, recarga, menu de técnicas e rede —,
## mas os golpes saem das skills de `mapas/skills` (`SkillsPublicadas.kit()`), e quem
## os executa é o `ExecutorDeSkill`.
##
## Números:
##   • dano: o do Builder vale na ARENA; na história a ficha aplica a escala das
##     frutas (× 250/2048) — `perfil_da_historia`;
##   • energia: o custo do Builder é medido numa barra de 100 (a prévia tem 100); no
##     jogo é a mesma FRAÇÃO da energia máxima do corpo;
##   • recarga: os segundos do Builder, nos dois modos.

const ID := "kit_builder"
const NOME := "Kit do Builder"
const COMPORTAMENTO := "builder"
## A barra da prévia do Builder: custo 10 = 10 % da energia.
const BARRA_DA_PREVIA := 100.0
## Clipe do bloco de Animação → pose do animador procedural do jogador. Só poses que
## o animador aplica pelo `custom_pose` sozinho, sem estado de outra fruta.
## ⚠️ OBSOLETO desde 07/10/2026: o bloco Animação toca o CLIPE bakeado da lista
## (`clipes_de_skill.gd`), igual na prévia e no jogo. Só `capturar_kit_do_builder.gd` lê
## isto ainda. Gatilho para apagar: refazer aquela captura com os clipes.
const POSES := {
	"Preparar": "gura_x_charge",
	"Ataque": "bomu_z_strike",
	"Planar": "air_slam_dive",
	"Investida": "gura_rush",
	"Vendaval": "spin_kick",
}


## É fruta do Builder? O Kit ou uma fruta do catálogo (`SkillsPublicadas.frutas`).
## Decisão do dono (06/10/2026): o Builder faz frutas de verdade (a Noro Noro no Mi).
static func e_do_builder(fruta: String) -> bool:
	return fruta == ID or (not fruta.is_empty() and not SkillsPublicadas.fruta(fruta).is_empty()
		and not SkillsPublicadas.e_reconstruida(fruta))


## A tecla desta fruta sai pelo Builder? Fruta do Builder: todas. Fruta da arena
## RECONSTRUÍDA no Builder (a Pika, 06/10/2026): só as teclas com skill publicada; as
## outras (o V da Pika) seguem o código da fruta. Custo, recarga, autorização, disparo
## e HUD perguntam por TECLA, aqui.
static func pelo_builder(fruta: String, tecla: String) -> bool:
	return e_do_builder(fruta) or (SkillsPublicadas.e_reconstruida(fruta) and tem(tecla, fruta))


## Tecla → skill da fruta (o Kit lê `kit.json`; as outras, o catálogo).
static func _skills(fruta: String) -> Dictionary:
	return SkillsPublicadas.kit() if fruta == ID else SkillsPublicadas.skills_da_fruta(fruta)


static func disponivel(fruta: String = ID) -> bool:
	return not _skills(fruta).is_empty()


static func nome(fruta: String = ID) -> String:
	if fruta == ID:
		return NOME
	return str(SkillsPublicadas.fruta(fruta).get("nome", fruta))


static func cor(fruta: String = ID) -> Color:
	return Color(str(SkillsPublicadas.fruta(fruta).get("cor", "#ffd23f"))) if fruta != ID else Color("#ffd23f")


## A skill na tecla ({} se a tecla está vazia).
static func skill(tecla: String, fruta: String = ID) -> Dictionary:
	return _skills(fruta).get(tecla, {})


static func tem(tecla: String, fruta: String = ID) -> bool:
	return not skill(tecla, fruta).is_empty()


static func teclas(fruta: String = ID) -> Array[String]:
	var saida: Array[String] = []
	var k := _skills(fruta)
	for t: String in SkillsPublicadas.TECLAS:
		if k.has(t):
			saida.append(t)
	return saida


static func recarga(tecla: String, fruta: String = ID) -> float:
	var s := skill(tecla, fruta)
	return float(s.configuracoes.recarga) if not s.is_empty() else 0.0


## Quanto tempo depois desta skill outro golpe de fruta pode sair (07/10/2026; o campo
## é opcional: skill de antes usa o intervalo do jogo, 0,5 s).
static func intervalo_depois(tecla: String, fruta: String = ID) -> float:
	var s := skill(tecla, fruta)
	if s.is_empty():
		return 0.5
	return float(s.configuracoes.get("intervalo_depois", 0.5))


static func custo(tecla: String, energia_maxima: float, fruta: String = ID) -> float:
	var s := skill(tecla, fruta)
	if s.is_empty():
		return 0.0
	return float(s.configuracoes.custo) / BARRA_DA_PREVIA * energia_maxima


static func nome_da_tecla(tecla: String, fruta: String = ID) -> String:
	var s := skill(tecla, fruta)
	return str(s.identificacao.nome) if not s.is_empty() else tecla


## A ficha do Modo História: técnicas com nome e recarga (o menu de técnicas lê
## daqui), dano na escala da história e a regeneração das frutas da arena.
static func perfil_da_historia(fruta: String = ID) -> PerfilDeFrutas:
	var p := PerfilDeFrutas.new()
	p.fruta = fruta
	# O Builder já cobra numa barra de 100 (`custo()`): fica a regeneração de antes (1/s),
	# sem o ×10 das frutas da arena (23/10/2026).
	p.regen_de_energia = 1.0
	p.escala_de_dano = PerfilDeFrutas.ESCALA_DA_ARENA
	for t: String in teclas(fruta):
		var tec := TecnicaDeFruta.new()
		tec.slot = t
		tec.nome = nome_da_tecla(t, fruta)
		tec.comportamento = COMPORTAMENTO
		tec.recarga = recarga(t, fruta)
		# O custo absoluto depende da energia máxima de AGORA (o nível muda): quem
		# cobra é `Player.custo_de_energia_do_cast`, por `custo()`. Aqui fica a fração.
		tec.custo_de_energia = float(skill(t, fruta).configuracoes.custo)
		p.tecnicas.append(tec)
	return p


## As frutas do catálogo prontas para o jogo (com ao menos uma skill).
static func frutas_prontas() -> Array[String]:
	var saida: Array[String] = []
	for f in SkillsPublicadas.frutas():
		# A reconstruída (Pika) já é fruta do jogo: não entra de novo como fruta do Builder.
		if disponivel(str(f.id)) and not bool(f.get("reconstroi", false)) and not bool(f.get("estilo", false)):
			saida.append(str(f.id))
	return saida


## Por que a skill NÃO pode sair agora ("" = pode). As condições do Builder, na
## mesma ordem e com as mesmas mensagens da prévia (`arena_preview.rodar`). Energia e
## recarga ficam com quem cobra.
static func recusa(dono: Node3D, s: Dictionary) -> String:
	var c: Dictionary = s.get("condicoes", {})
	if int(dono.get_meta("nivel", 1)) < int(c.get("nivel_minimo", 1)):
		return "Nível insuficiente."
	var vida_max := float(dono.get("max_health")) if dono.get("max_health") != null else 0.0
	if vida_max > 0.0 and float(dono.get("health")) / vida_max * 100.0 < float(c.get("vida_minima", 0.0)):
		return "Vida insuficiente."
	if bool(c.get("exige_chao", false)) and dono is CharacterBody3D and not (dono as CharacterBody3D).is_on_floor():
		return "Precisa estar no chão."
	if bool(c.get("exige_alvo", false)):
		var limite := minf(float(c.get("distancia_maxima", 30.0)), float(s.configuracoes.alcance))
		if alvo_mais_perto(dono, limite) == null:
			return "Nenhum alvo ao alcance (%.0f m)." % limite
	return ""


## O alvo vivo mais perto até `limite` metros (o mesmo critério das frutas).
static func alvo_mais_perto(dono: Node3D, limite: float) -> Node3D:
	var melhor: Node3D = null
	var menor := limite
	for a in AlvosDeGolpe.todos(dono.get_tree()):
		if a == dono or not (a is Node3D) or not is_instance_valid(a):
			continue
		if "health" in a and float(a.get("health")) <= 0.0:
			continue
		var d := AlvosDeGolpe.centro(a as Node3D).distance_to(dono.global_position)
		if d <= menor:
			menor = d
			melhor = a as Node3D
	return melhor
