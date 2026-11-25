extends Node
## Uma tecla do Kit do Builder apertada (06/10/2026). A semântica de ativação é a da
## prévia do Builder (`arena_preview.rodar/soltar/_process`):
##   • ao apertar: condições → recarga → energia; cobra a energia e liga a recarga;
##   • Pressionar: o golpe sai já; Segurar: carrega `ativacao.carga` s e sai sozinho
##     ao completar — soltar antes CANCELA e devolve a energia (e a recarga);
##   • Automática, ou "repetir enquanto ativo": com a tecla apertada, sai de novo
##     quando o golpe termina e a recarga zera, até faltar energia ou condição.
## Quem decide o dano é o servidor: o golpe sai por `pedir_cast_no_servidor`.

var dono: Node3D = null
var slot := ""
var skill: Dictionary = {}

var _carga := 0.0          # segundos que ainda faltam de carga (Segurar)
var _segurando := true
var _repetir := false
var _cobrado := 0.0
var _espera := 0.0         # até o golpe atual terminar (para repetir)
# "Carregar e soltar": o golpe já saiu no aperto e espera no ponto de segurar; soltar a
# tecla avisa todos (continuar, ou cancelar se ainda não chegou ao ponto).
var _segura_e_solta := false
var _lancado_ms := 0


## Começa. Devolve "" se saiu (ou começou a carregar), ou o motivo da recusa.
func iniciar() -> String:
	_repetir = bool(skill.ativacao.repetir) or str(skill.ativacao.modo) == "Automática"
	var motivo := _ativar()
	if not motivo.is_empty():
		queue_free()
	return motivo


func carregando() -> bool:
	return _carga > 0.0


## A tecla está segurando a skill e ela não deixa andar (07/10/2026, pedido do dono):
## o Player trava W/A/S/D, o pulo e a esquiva enquanto isto for verdade.
func prende_o_andar() -> bool:
	return (_segura_e_solta or _carga > 0.0) and not bool(skill.ativacao.get("andar_segurando", false))


## Segurando, o corpo fica PARADO, inclusive no ar (10/10/2026, Z da Pika): campo
## "Paralisa segurando" da skill, e só no Modo História (o dono com perfil de frutas).
func paralisa() -> bool:
	return prende_o_andar() and bool(skill.ativacao.get("paralisar_segurando", false)) \
		and dono.get("perfil_de_frutas") != null


func soltar() -> void:
	_segurando = false
	if _segura_e_solta:
		_segura_e_solta = false
		var ponto := float(skill.ativacao.get("ponto_segurar", 0.5))
		var cancelar := str(skill.ativacao.modo) == "Carregar e soltar" and (Time.get_ticks_msec() - _lancado_ms) / 1000.0 < ponto
		if cancelar:
			dono.energy = minf(float(dono.max_energy), float(dono.energy) + _cobrado)
			(dono.get("_fruit_cooldowns") as Dictionary)[slot] = 0.0
			print("⚡ %s: soltou antes de carregar — energia devolvida." % KitDoBuilder.nome_da_tecla(slot, str(dono.get("current_fruit_id"))))
		var mira := {"aim": Vector3.ZERO, "origem": Vector3.ZERO}
		if not cancelar and str(skill.ativacao.modo) == "Carregar e soltar":
			# O golpe sai AGORA (07/10/2026): a recarga e o intervalo entre golpes contam
			# daqui (armados no aperto, recomeçam cheios), e a mira é a de agora.
			dono.trigger_skill_cooldown(slot)
			mira = dono.mira_do_cast()
		dono.pedir_soltar_do_kit(slot, cancelar, mira["aim"], mira["origem"])
		queue_free()
		return
	if _carga > 0.0:
		# Carga incompleta: nada sai, a energia volta e a recarga também.
		_carga = 0.0
		dono.energy = minf(float(dono.max_energy), float(dono.energy) + _cobrado)
		(dono.get("_fruit_cooldowns") as Dictionary)[slot] = 0.0
		print("⚡ %s: carga cancelada — energia devolvida." % KitDoBuilder.nome_da_tecla(slot, str(dono.get("current_fruit_id"))))
	queue_free()


func _ativar() -> String:
	var recusa := KitDoBuilder.recusa(dono, skill)
	if not recusa.is_empty():
		return recusa
	if float((dono.get("_fruit_cooldowns") as Dictionary).get(slot, 0.0)) > 0.0:
		return "A habilidade está em recarga."
	var custo: float = dono.custo_de_energia_do_cast(slot)
	if float(dono.energy) + 0.001 < custo:
		return "Energia insuficiente."
	dono.gastar_energia(custo)
	_cobrado = custo
	dono.trigger_skill_cooldown(slot)
	if str(skill.ativacao.modo) in ["Carregar e soltar", "Sustentar"]:
		# "Sustentar" (C da Pika, 06/10/2026): o golpe sai já e soltar a tecla o ENCERRA.
		_segura_e_solta = true
		_repetir = false
		_lancado_ms = Time.get_ticks_msec()
		_disparar()
		return ""
	if str(skill.ativacao.modo) == "Segurar" and float(skill.ativacao.carga) > 0.0:
		_carga = float(skill.ativacao.carga)
		return ""
	_disparar()
	return ""


## Quanto o dono regenera de energia por segundo agora (a do modo, ou a da arena).
func _regen_do_dono() -> float:
	var vida: Variant = dono.get("_vida")
	if vida == null:
		return 0.0
	var do_modo := float(vida.get("regen_energia_do_modo"))
	return do_modo if do_modo > 0.0 else HealthController.regen_energia_por_s(float(dono.max_energy), false)


func _disparar() -> void:
	var mira: Dictionary = dono.mira_do_cast()
	dono.pedir_cast_no_servidor(slot, mira["aim"], mira["origem"], 0.0)
	_espera = float(skill.configuracoes.duracao)


func _process(delta: float) -> void:
	if not is_instance_valid(dono):
		queue_free()
		return
	if _segura_e_solta:
		# Custo por segundo segurando (07/10/2026, F da Pika): acabou a energia, solta.
		var por_segundo := float(skill.configuracoes.get("custo_por_segundo", 0.0))
		if por_segundo > 0.0:
			# LÍQUIDO, como o dreno da invisibilidade da Suke: a regeneração segue correndo,
			# e na história (1/s numa barra de 10) ela pagava o voo inteiro (medido: 0 gasto).
			var barra := KitDoBuilder.BARRA_DA_PREVIA if dono.get("perfil_de_frutas") != null else float(dono.max_energy)
			var gasto := (por_segundo / KitDoBuilder.BARRA_DA_PREVIA * barra + _regen_do_dono()) * delta
			if float(dono.energy) < gasto:
				print("⚡ %s: acabou a energia." % KitDoBuilder.nome_da_tecla(slot, str(dono.get("current_fruit_id"))))
				soltar()
				return
			dono.gastar_energia(gasto)
		# Espera a tecla subir. Folga de segurança: depois do máximo + a timeline, some.
		var limite := float(skill.ativacao.get("ponto_segurar", 0.5)) + float(skill.ativacao.get("segurar_max", 5.0)) \
			+ float(skill.configuracoes.duracao) + 1.0
		if (Time.get_ticks_msec() - _lancado_ms) / 1000.0 > limite:
			queue_free()
		return
	if _carga > 0.0:
		_carga -= delta
		if _carga <= 0.0:
			_carga = 0.0
			_disparar()
			if not _repetir or not _segurando:
				queue_free()
		return
	if not (_repetir and _segurando):
		queue_free()
		return
	_espera -= delta
	if _espera > 0.0 or float((dono.get("_fruit_cooldowns") as Dictionary).get(slot, 0.0)) > 0.0:
		return
	var motivo := _ativar()
	if not motivo.is_empty():
		print("⏹ %s: repetição parou — %s" % [KitDoBuilder.nome_da_tecla(slot, str(dono.get("current_fruit_id"))), motivo])
		queue_free()
