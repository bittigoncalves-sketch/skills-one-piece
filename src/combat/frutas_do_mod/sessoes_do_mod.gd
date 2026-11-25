class_name SessoesDoMod
extends RefCounted
## Técnicas em PARALELO para as logias do FLUXO DO MOD (Mera, Magu, Suna, Yami, Mori), 24/11/2026.
##
## O problema: o mod guarda UMA técnica por entidade (`PersistentData`: `skill`, `cnt1…cnt10`, `PRESS_Z`, `x/y/z_pos`…) e o
## efeito `minepiece:skill` a dirige a cada tick; `LogicStart` recusa começar outra enquanto `skill % 50 != 0`. Por isso uma
## técnica travava as outras.
##
## A solução (troca de contexto, sem mexer em procedure gerada): o estado PRIVADO de cada técnica (as chaves de `PRIVADAS`)
## vive num dicionário próprio.
##   • a técnica VIVA tem o estado no NBT do mod e é dirigida pelo efeito nativo, como sempre;
##   • ao começar outra, a viva é ESTACIONADA (captura das chaves privadas), o NBT é limpo e a nova passa a ser a viva;
##   • a cada tick (0,05 s) cada estacionada é DIRIGIDA à mão: troca o estado dela para o NBT, roda o MESMO gancho do efeito
##     (`CursedTechniqueOnPotionActiveTick`), captura de volta e restaura a viva — tudo síncrono, no mesmo quadro;
##   • quando a viva acaba (`skill` = 0), a primeira estacionada é promovida a viva.
## Chaves compartilhadas (OWNER_UUID, PlayerName, guard, PRESS_S, cnt_x…) ficam no NBT real, fora da troca.
## Limite conhecido: entidades que a técnica lança e que leem o NBT do DONO depois (ex.: `cnt6` de carga) veem o estado da
## técnica que estiver viva — igual ao mod original, que zera os contadores a cada técnica nova.
## GATILHO: se uma logia do fluxo do mod mostrar chave privada nova (técnica que se confunde com outra), acrescentar em `PRIVADAS`.
const PRIVADAS := ["skill", "cnt1", "cnt2", "cnt3", "cnt4", "cnt5", "cnt6", "cnt7", "cnt8", "cnt9", "cnt10", "Damage", "COOLDOWN_TICKS",
	"PRESS_Z", "x_power", "y_power", "z_power", "attack", "knockback", "x_knockback", "y_knockback", "z_knockback", "BlockRange",
	"BlockDamage", "effect", "effectConfirm", "Range", "pitch", "yaw", "x_pos", "y_pos", "z_pos", "noParticle", "canFly",
	"projectile_type", "old_x_position", "old_y_position", "old_z_position", "old_barrier", "old_block", "ignore", "size",
	"delay_time", "KnockbackFix", "noEffect", "Stop", "ExtinctionBlock", "betrayal", "PASSIVE_POWERFIX"]
## As frutas que usam isto (as que rodam só pelas procedures do mod, sem controlador autoral).
const FRUTAS := ["mera_mera", "magu_magu", "suna_suna", "yami_yami", "mori_mori"]
const TICK := 0.05

var c                          # ControladorFrutaDoMod
var vivo := 0                  # número da técnica cujo estado está no NBT do mod (0 = nenhuma)
var executando := 0            # a estacionada que está em tick manual agora (0 = nenhuma): diz de quem é o projétil criado neste instante
var estacionadas := {}         # número → {chave privada: valor}
var _acumulado := 0.0


static func contem(fruta_id: String) -> bool:
	return FRUTAS.has(fruta_id)


func _dados() -> Dictionary:
	return c._mc.getPersistentData().dados


func _skill() -> float:
	return float(_dados().get("skill", 0.0))


func capturar() -> Dictionary:
	var saida := {}
	var d := _dados()
	for k: String in PRIVADAS:
		if d.has(k):
			saida[k] = d[k]
	return saida


func aplicar(estado: Dictionary) -> void:
	var d := _dados()
	for k: String in PRIVADAS:
		d.erase(k)
	for k: String in estado:
		d[k] = estado[k]


func tem() -> bool:
	return vivo != 0 or not estacionadas.is_empty()


func total() -> int:
	return (1 if vivo != 0 else 0) + estacionadas.size()


## A técnica `numero` já está em curso (viva ou estacionada)?
func em_curso(numero: int) -> bool:
	return numero == vivo or estacionadas.has(numero)


## Antes de o mod começar uma técnica nova: a viva (se ainda corre) vai para o lado e o NBT fica limpo para `LogicStart`.
func antes_de_comecar() -> void:
	if vivo != 0 and _skill() != 0.0:
		estacionadas[vivo] = capturar()
		vivo = 0
	aplicar({})


func depois_de_comecar(numero: int) -> void:
	vivo = numero if _skill() != 0.0 else 0


## Soltou a tecla da técnica `numero`. Devolve verdadeiro se era a viva (quem chama roda o fluxo normal de soltar).
func soltar(numero: int) -> bool:
	if numero == vivo:
		return true
	if estacionadas.has(numero):
		estacionadas[numero]["PRESS_Z"] = false
	return false


func cancelar_tudo() -> void:
	estacionadas.clear()
	vivo = 0


## Chamado a cada quadro, depois do tick do mundo.
func passo(delta: float) -> void:
	if not tem():
		return
	if not c.fruta_ativa() or float(c.ator.health) <= 0.0 or not c.ator.corpo_livre_para_golpe():
		estacionadas.clear()
		if vivo != 0 and _skill() == 0.0:
			vivo = 0
		return
	# a viva acabou → promove a primeira estacionada
	if vivo != 0 and _skill() == 0.0:
		vivo = 0
	if vivo == 0 and not estacionadas.is_empty():
		_promover()
	_acumulado += delta
	while _acumulado >= TICK:
		_acumulado -= TICK
		_dirigir_estacionadas()


func _promover() -> void:
	var numero: int = estacionadas.keys()[0]
	var estado: Dictionary = estacionadas[numero]
	estacionadas.erase(numero)
	if float(estado.get("skill", 0.0)) == 0.0:
		return
	aplicar(estado)
	vivo = numero
	_garantir_efeito()


func _garantir_efeito() -> void:
	if vivo != 0 and not c._mc.hasEffect(Mc.efeito("minepiece:skill")):
		c._mc.addEffect(Mc.novo(&"MobEffectInstance", [Mc.efeito(&"minepiece:skill"), Mc.campo(&"Integer", &"MAX_VALUE"), 0, false, false]))


func _dirigir_estacionadas() -> void:
	var efeito := Mc.efeito("minepiece:skill")
	for numero: int in estacionadas.keys():
		var estado: Dictionary = estacionadas[numero]
		if float(estado.get("skill", 0.0)) == 0.0:
			estacionadas.erase(numero)
			continue
		var guardado := capturar()
		var tecnica_antes: int = c._tecnica_em_uso
		aplicar(estado)
		c._tecnica_em_uso = numero
		executando = numero
		c._mc._gancho(efeito, "tick", 0)
		executando = 0
		estacionadas[numero] = capturar()
		aplicar(guardado)
		c._atualizar_recargas(0.0)            # o recarregamento que ESTA técnica renovou fica com ela
		c._tecnica_em_uso = tecnica_antes
	_garantir_efeito()
