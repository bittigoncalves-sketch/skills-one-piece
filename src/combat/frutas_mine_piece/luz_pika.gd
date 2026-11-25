extends Node3D
## ProjectileLaserEntity (Mine Piece v14) — a flecha de luz do Yasakani no Magatama: sem
## gravidade, 8 blocos/tick, perfura 50 corpos; o dano é o da flecha do Minecraft
## (ceil(velocidade × dano base) = ceil(8 × 0,6 × DamageFix)); ao bater no chão/parede
## explode (ProjectileLaserProjectileHitsBlock: partículas, som, blocos → marca) e some.
## Adaptação: a flecha do Minecraft vive até bater; aqui some depois de 3 s no ar.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const PASTA := "res://assets/mine_piece/frutas/pika/"
const VIDA_MAXIMA := 60
const COMPRIMENTO_DO_RASTRO := 1.6      # o dardo de luz vira um traço com cauda (antes 0,6 m: lia como ponto amarelo a distância)

var c
var rumo := Vector3.FORWARD    # blocos/tick
var dano := 6.0                # unidades do mod
var cnt6 := 0.0
var _furou := 0
var _ticks := 0
var _tempo := 0.0
var _visual: MeshInstance3D


func _ready() -> void:
	_visual = BeamVisual3D.criar(self, global_position, global_position + rumo.normalized() * COMPRIMENTO_DO_RASTRO, 0.07)
	# O dardo de luz 3D (Blender, `pika_lanca_de_luz.glb`) à frente do traço: a flecha deixa de ser só uma linha (24/11/2026).
	var dardo := AssetsDeTecnica.instanciar("pika_lanca_de_luz", 0.7)
	if dardo != null:
		add_child(dardo)
		AssetsDeTecnica.orientar_y(dardo, rumo)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or not is_instance_valid(c.ator):
		queue_free()
		return
	_tempo += delta
	while _tempo >= B.TICK and not is_queued_for_deletion():
		_tempo -= B.TICK
		_passo()


func _passo() -> void:
	_ticks += 1
	var de := global_position
	var ate := de + rumo * B.METROS_POR_BLOCO
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(de, ate, B.MASCARA_MUNDO, [c.ator.get_rid()]))
	var fim: Vector3 = hit.position if not hit.is_empty() else ate
	# Corpos no caminho (perfura até 50): cada um leva o dano da flecha, com a imunidade.
	var passos := maxi(int(ceil(de.distance_to(fim) / B.METROS_POR_BLOCO)), 1)
	for i in passos:
		var ponto := de.lerp(fim, float(i + 1) / passos)
		if c.servidor():
			_furou += B.ataque_em_area(c.ator, de, ponto, B.Ataque.new(dano, 1.0, 0.0, false), c.tick,
				c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
		if _furou >= 50:
			queue_free()
			return
	global_position = fim
	BeamVisual3D.atualizar(_visual, fim - rumo.normalized() * COMPRIMENTO_DO_RASTRO, fim)
	if not hit.is_empty():
		_explodir(fim)
	elif _ticks > VIDA_MAXIMA:
		queue_free()


func _explodir(onde: Vector3) -> void:
	var k6 := 1.0 + cnt6 * 0.1
	VfxFrutaMinePiece.particulas(self, PASTA + "particle_light_large.png", 5, onde, int(round(k6)) + 1,
		Vector3.ONE * 0.1, 0.0, 0.4, 0.8, 4, true)
	VfxFrutaMinePiece.particulas(self, PASTA + "particle_light_small.png", 5, onde, int(round(4.0 * k6)),
		Vector3.ONE * 0.1, 2.0 * k6, 0.4, 0.3, 12, true)
	VfxFrutaMinePiece.placa(self, onde, B.m(1.0), Color(0.1, 0.08, 0.02, 0.35), 4.0)
	if randf() < 0.25:   # 8 flechas por tick: um som a cada quatro estouros basta
		VfxFrutaMinePiece.som(self, PASTA + "sons/pika_luz_estouro.wav", onde, 0.5 * k6, randf_range(0.85, 1.2))
	queue_free()
