extends RefCounted
## API visual da Mera Mera. O jogo continua dono da hitbox, da autoridade e do
## tempo de vida dos golpes — aqui só se desenha.
##
## É o mesmo contrato do `OpeVfx`, e existe pelo mesmo motivo: enquanto o visual
## mora dentro do arquivo que também cria `DamageZone`, mexer na aparência é
## mexer em balanceamento. Com a fachada, dá para trocar todo o fogo sem tocar
## num número de dano.
##
## ⚠️ Toda função devolve o nó criado, e NENHUMA agenda destruição de hitbox.

const BURST := preload("res://src/effects/MeraFireBurst.gd")
const BODY := preload("res://src/effects/MeraEmberBody.gd")


## Pendura o efeito no pai, SEMPRE de forma adiada.
##
## ⚠️ POR QUE ADIADO, E NÃO `add_child` DIRETO. Vários efeitos da Mera nascem
## dentro de um `tree_exiting` — o Hiken cria a explosão quando a própria hitbox
## sai da árvore. Nesse instante o pai está "busy setting up children" e o
## Godot **recusa** o `add_child`, com erro no log e o efeito silenciosamente
## ausente. Medido em 2026-09-08 pelo `test_frutas`:
##   `Parent node is busy setting up children, add_child() failed.`
##
## Como o nó só entra na árvore no quadro seguinte, a posição global não pode
## ser escrita aqui — quem a aplica é o `_ready` do efeito, a partir de
## `spawn_global`. Um quadro de atraso é invisível num efeito de fogo.
## ⚠️ `efeito` fica SEM TIPO de propósito: `spawn_global` não existe em `Node3D`,
## e o GDScript recusa em tempo de compilação o acesso a propriedade não
## declarada numa variável tipada.
static func _anexar(parent: Node, efeito, at: Vector3, posicionar: bool) -> Node3D:
	if not is_instance_valid(parent):
		efeito.free()
		return null
	if posicionar:
		efeito.spawn_global = at
		efeito.usar_spawn_global = true
	# ⚠️ NÃO use `parent.add_child.call_deferred(efeito)` direto. Se o pai for
	# liberado entre esta chamada e o quadro seguinte — que é justamente o caso
	# quando o efeito nasce de um `tree_exiting` —, o Godot descarta a chamada
	# adiada e o nó fica órfão: nunca entra na árvore e nunca é liberado. Isso é
	# vazamento, e vazamento é o critério 6 do `docs/PLANO_FRUTAS.md`. A lambda
	# reconfere o pai no instante do anexo e, se ele já se foi, libera o efeito.
	# ⚠️ Captura o ID, não o objeto. Uma lambda que captura um nó já liberado
	# faz o Godot registrar `Lambda capture at index 0 was freed` no log — erro
	# de verdade no console, por um caso que é esperado aqui. Com o `ObjectID` a
	# checagem é a mesma e o log fica limpo.
	var id_pai := parent.get_instance_id()
	var anexar := func() -> void:
		var alvo := instance_from_id(id_pai) as Node
		if alvo != null and alvo.is_inside_tree() and not alvo.is_queued_for_deletion():
			alvo.add_child(efeito)
		elif is_instance_valid(efeito):
			efeito.free()
	anexar.call_deferred()
	return efeito


## Clarão curto na boca do cano — o Higan dispara 8 destes por rajada.
static func muzzle(parent: Node, at: Vector3, direction: Vector3, scale_factor: float = 1.0) -> Node3D:
	var efeito := BURST.new()
	efeito.mode = "muzzle"
	efeito.direction = direction
	efeito.scale_factor = scale_factor
	return _anexar(parent, efeito, at, true)


## Batida média: bala de fogo, vagalume, qualquer coisa que encosta e some.
static func impact(parent: Node, at: Vector3, scale_factor: float = 1.0) -> Node3D:
	var efeito := BURST.new()
	efeito.mode = "impact"
	efeito.scale_factor = scale_factor
	return _anexar(parent, efeito, at, true)


## Estouro grande: fim do Hiken, detonação do Entei.
static func explosion(parent: Node, at: Vector3, scale_factor: float = 1.0) -> Node3D:
	var efeito := BURST.new()
	efeito.mode = "explosion"
	efeito.scale_factor = scale_factor
	return _anexar(parent, efeito, at, true)


## Só a marca no chão, sem chama. Serve para deixar rastro onde o fogo passou.
static func scorch(parent: Node, at: Vector3, radius: float = 2.0) -> Node3D:
	var efeito := BURST.new()
	efeito.mode = "scorch"
	efeito.scale_factor = radius / 2.2
	return _anexar(parent, efeito, at, true)


## O punho do Hiken. Vira filho da hitbox, que é quem o move.
static func fist(parent: Node, direction: Vector3, radius: float = 1.0) -> Node3D:
	var corpo := BODY.new()
	corpo.mode = "fist"
	corpo.body_radius = radius
	corpo.direction = direction
	return _anexar(parent, corpo, Vector3.ZERO, false)


## Rastro de chama atrás de um projétil. `direction` é a direção em que a chama
## ESCORRE (normalmente o oposto do voo), em espaço local do pai.
static func trail(parent: Node, direction: Vector3, radius: float = 0.1) -> Node3D:
	var corpo := BODY.new()
	corpo.mode = "trail"
	corpo.body_radius = radius
	corpo.direction = direction
	return _anexar(parent, corpo, Vector3.ZERO, false)


## O sol do Entei. `set_heat(0..1)` acende o núcleo conforme a carga.
static func sun(parent: Node, radius: float = 1.0, faceted: bool = false) -> Node3D:
	var corpo := BODY.new()
	corpo.mode = "sun"
	corpo.body_radius = radius
	corpo.faceted = faceted
	return _anexar(parent, corpo, Vector3.ZERO, false)
