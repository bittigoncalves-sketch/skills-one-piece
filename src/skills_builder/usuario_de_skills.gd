class_name UsuarioDeSkills
extends Node
## Um INIMIGO que usa as skills do Builder atribuídas a ele (06/10/2026).
##
## Decisão do dono: a atribuição mora na skill (Usuário Inimigo + "Quem usa" = id do
## modelo da loja). Este nó, filho do inimigo, faz o papel de "torre":
##   • com um jogador vivo dentro do alcance da skill (e das condições dela), vira
##     para ele e lança a skill pelo `ExecutorDeSkill`, respeitando a recarga;
##   • uma skill de cada vez: espera a anterior acabar;
##   • o boneco de duelo só usa skill com o corpo a corpo NEUTRO — intercala entre
##     os golpes dele, não por cima;
##   • dano: a mesma FRAÇÃO de vida do alvo que a skill tiraria na arena;
##   • decide no SERVIDOR (no Modo História, a máquina local).
## Inimigo não tem barra de energia: o custo do Builder não se aplica a ele.

const PERIODO := 0.2      # de quanto em quanto tempo ele procura alvo
const SEGURAR_DA_IA := 0.6

var ator: Node3D = null
var skills: Array[Dictionary] = []
var _recargas := {}       # id da skill → segundos
var _ocupado := 0.0       # até a skill em curso acabar
var _relogio := 0.0


## Liga em `quem` as skills do Usuário Inimigo atribuídas ao modelo `modelo`.
## Devolve o nó (null se não há skill para ele).
static func ligar(quem: Node3D, modelo: String) -> UsuarioDeSkills:
	if quem == null or modelo.is_empty():
		return null
	var lista := SkillsPublicadas.atribuidas("Inimigo", modelo)
	if lista.is_empty():
		return null
	var u := UsuarioDeSkills.new()
	u.name = "UsuarioDeSkills"
	u.ator = quem
	u.skills = lista
	quem.add_child(u)
	print("🛠 Inimigo '%s' (%s) usa %d skill(s) do Builder" % [quem.name, modelo, lista.size()])
	return u


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	delta *= Lentidao.fator(ator)          # inimigo lento: recarga e decisão devagar
	for id in _recargas.keys():
		_recargas[id] = maxf(0.0, float(_recargas[id]) - delta)
	_ocupado = maxf(0.0, _ocupado - delta)
	_relogio -= delta
	if _ocupado > 0.0 or _relogio > 0.0 or not _pode_agir():
		return
	_relogio = PERIODO
	for s in skills:
		if float(_recargas.get(str(s.identificacao.id), 0.0)) > 0.0:
			continue
		var alvo := _alvo_para(s)
		if alvo == null:
			continue
		_lancar(s, alvo)
		return


func _pode_agir() -> bool:
	if not is_instance_valid(ator) or not ator.is_inside_tree() or not ator.visible:
		return false
	if ator.has_method("vivo") and not ator.call("vivo"):
		return false
	if "health" in ator and float(ator.get("health")) <= 0.0:
		return false
	# Boneco de duelo: só com o corpo a corpo neutro (intercala, não sobrepõe).
	var cc: Variant = ator.get("combate_direcional")
	if cc != null and is_instance_valid(cc) and (cc as Object).has_method("ocupado") and (cc as Object).call("ocupado"):
		return false
	return true


## O jogador vivo mais perto que esta skill pode alcançar agora (null = nenhum).
func _alvo_para(s: Dictionary) -> Node3D:
	var c: Dictionary = s.condicoes
	var alcance := float(s.configuracoes.alcance)
	if bool(c.get("exige_alvo", false)):
		alcance = minf(alcance, float(c.get("distancia_maxima", alcance)))
	var vida_max: Variant = ator.get("max_health")
	if vida_max != null and float(vida_max) > 0.0 \
			and float(ator.get("health")) / float(vida_max) * 100.0 < float(c.get("vida_minima", 0.0)):
		return null
	if bool(c.get("exige_chao", false)) and ator is CharacterBody3D and not (ator as CharacterBody3D).is_on_floor():
		return null
	var melhor: Node3D = null
	var menor := alcance
	for j in ator.get_tree().get_nodes_in_group("player"):
		if not (j is Node3D) or not is_instance_valid(j):
			continue
		if "health" in j and float(j.get("health")) <= 0.0:
			continue
		var d := (j as Node3D).global_position.distance_to(ator.global_position)
		if d <= menor:
			menor = d
			melhor = j as Node3D
	return melhor


func _lancar(s: Dictionary, alvo: Node3D) -> void:
	var meio := AlvosDeGolpe.centro(alvo)
	var rumo := meio - ator.global_position
	rumo.y = 0.0
	if ator.has_method("encarar"):
		ator.call("encarar", meio)
	elif rumo.length_squared() > 0.0001:
		ator.global_rotation.y = atan2(-rumo.x, -rumo.z)
	var pai: Node = ator.get_tree().current_scene if ator.get_tree().current_scene != null else ator.get_parent()
	var e := ExecutorDeSkill.lancar(pai, ator, s, rumo, 1.0, meio)
	e.escala_pela_vida_do_alvo = true
	e.segurar_auto = SEGURAR_DA_IA          # "Carregar e soltar": a IA segura um instante e solta
	_recargas[str(s.identificacao.id)] = float(s.configuracoes.recarga)
	_ocupado = float(s.configuracoes.duracao) + (SEGURAR_DA_IA if e.segurando else 0.0)
