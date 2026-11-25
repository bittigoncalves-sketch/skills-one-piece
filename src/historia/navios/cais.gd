extends RefCounted
## Vaga no cais (10/10/2026): onde um barco comprado atraca, perto do vendedor de barcos.
##
## Pedido do dono: o barco comprado "fica seu", nasce na água do porto ao lado do
## vendedor e, ao abrir o jogo, volta atracado ao cais. A vaga NÃO é um ponto gravado no
## mapa: é procurada em anéis crescentes em volta do vendedor — se o dono mudar o NPC de
## lugar no editor, os barcos acompanham. Uma vaga serve quando:
##   • há água sob o casco inteiro (popa, proa, bordos e meio), funda o bastante para o
##     calado com folga;
##   • o volume do casco, da quilha até 4 m acima da água, não toca cenário (píer, pedra,
##     outro barco já assentado no mundo);
##   • não sobrepõe outro barco da frota (círculo pela meia diagonal: o barco recém-posto
##     ainda pode não estar na física do quadro).
## A proa fica virada para longe do vendedor: W leva para o mar aberto.

const RAIO_MIN := 6.0
const RAIO_MAX := 90.0
const PASSO_RAIO := 3.0
const PASSO_ANGULO := 12.0          # graus
const FOLGA_FUNDO := 0.6            # m de água abaixo da quilha
const ALTURA_LIVRE := 4.0           # m acima da linha d'água que o casco precisa livres
const FOLGA_LATERAL := 0.8          # m em volta do casco


## Transform da vaga mais perto de `origem` para `barco` (já configurado) ou `null`.
## `outros`: [{centro: Vector3, raio: float}] dos barcos da frota que não são este.
static func vaga(espaco: PhysicsDirectSpaceState3D, origem: Vector3, barco: CharacterBody3D,
		outros: Array[Dictionary], excluir: Array[RID] = []) -> Variant:
	var casco: Vector3 = barco.get("tamanho_casco")
	var calado := float((barco.get("perfil") as Dictionary).get("calado", 0.5))
	var raio_barco := Vector2(casco.x, casco.z).length() * 0.5 + FOLGA_LATERAL
	var r := RAIO_MIN
	# Navio grande (Moby Dick, 85 m) precisa de anéis além dos 90 m do porto pequeno.
	var limite := maxf(RAIO_MAX, raio_barco * 2.5)
	while r <= limite:
		var passos := int(360.0 / PASSO_ANGULO)
		for i in passos:
			var ang := deg_to_rad(i * PASSO_ANGULO)
			var p := origem + Vector3(cos(ang), 0.0, sin(ang)) * r
			var nivel := AguaDoMundo.nivel_em(p.x, p.z)
			if is_nan(nivel):
				continue
			var fora := Vector3(p.x - origem.x, 0.0, p.z - origem.z).normalized()
			var giro := atan2(-fora.x, -fora.z)             # −Z (proa) para longe do vendedor
			var t := Transform3D(Basis(Vector3.UP, giro), Vector3(p.x, nivel, p.z))
			if _sobrepoe(t.origin, raio_barco, outros):
				continue
			if not _fundo_livre(espaco, t, casco, calado, nivel, excluir):
				continue
			if not _volume_livre(espaco, t, casco, calado, excluir):
				continue
			return t
		r += PASSO_RAIO
	return null


static func raio_de(barco: CharacterBody3D) -> float:
	var casco: Vector3 = barco.get("tamanho_casco")
	return Vector2(casco.x, casco.z).length() * 0.5 + FOLGA_LATERAL


static func _sobrepoe(centro: Vector3, raio: float, outros: Array[Dictionary]) -> bool:
	for o in outros:
		var c: Vector3 = o["centro"]
		if Vector2(c.x - centro.x, c.z - centro.z).length() < raio + float(o["raio"]):
			return true
	return false


## Água em todo o casco e fundo abaixo da quilha (raios em 9 pontos do casco).
static func _fundo_livre(espaco: PhysicsDirectSpaceState3D, t: Transform3D, casco: Vector3, calado: float,
		nivel: float, excluir: Array[RID]) -> bool:
	for fx in [-0.5, 0.0, 0.5]:
		for fz in [-0.5, 0.0, 0.5]:
			var q := t * Vector3(fx * (casco.x + FOLGA_LATERAL), 0.0, fz * (casco.z + FOLGA_LATERAL))
			var aqui := AguaDoMundo.nivel_em(q.x, q.z)
			if is_nan(aqui) or absf(aqui - nivel) > 0.05:
				return false
			var raio := PhysicsRayQueryParameters3D.create(Vector3(q.x, nivel + 0.5, q.z),
				Vector3(q.x, nivel - calado - FOLGA_FUNDO, q.z), 1)
			raio.exclude = excluir
			if not espaco.intersect_ray(raio).is_empty():
				return false
	return true


## O volume do casco (com folga) não toca cenário nem outro corpo.
static func _volume_livre(espaco: PhysicsDirectSpaceState3D, t: Transform3D, casco: Vector3, calado: float,
		excluir: Array[RID]) -> bool:
	var caixa := BoxShape3D.new()
	var altura := calado + ALTURA_LIVRE
	caixa.size = Vector3(casco.x + FOLGA_LATERAL * 2.0, altura, casco.z + FOLGA_LATERAL * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = caixa
	q.transform = Transform3D(t.basis, t.origin + Vector3.UP * (altura * 0.5 - calado))
	q.collision_mask = 1
	q.exclude = excluir
	return espaco.intersect_shape(q, 1).is_empty()
