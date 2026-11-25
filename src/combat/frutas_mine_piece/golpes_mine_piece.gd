class_name GolpesMinePiece
extends RefCounted
## Golpes do corpo que várias técnicas do Mine Piece v14 chamam no meio delas.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const IMPACTO := "res://assets/mine_piece/combate/mp_impacto.glb"   # EntityStrike (slash_white)
const SOM := "res://assets/mine_piece/combate/hit_strong.ogg"


## AttackStrongPunchProcedure, o tick do golpe (cnt2 = 1): cubo de 6 × alcance a 2,5 ×
## alcance na mira, à altura do peito; 11 × CNT6, empurrão 1,5 × CNT6. Mão vazia:
## GetWeaponSize = GetReach = 1, então alcance = tamanho². A EntityStrike (idle3) marca.
static func soco_forte(c, cnt6: float) -> void:
	var k6 := 1.0 + cnt6 * 0.1
	var tam := B.tamanho(B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)
	var alcance := tam * tam
	var olhar: Vector3 = c.olhar()
	var centro: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.75) + olhar * B.m(2.5 * alcance)
	var a := B.Ataque.new(11.0 * k6, 6.0 * alcance, 1.5 * k6, false)
	a.ao_ferir = func(_alvo: Node) -> void:
		VfxFrutaMinePiece.som(c.ator, SOM, centro, 0.6)
	B.ataque_em_area(c.ator, c.pe(), centro, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
	c.pose("punch_right")
	_marca(c.ator, centro, olhar, 2.0 * alcance)


static func _marca(de: Node3D, onde: Vector3, rumo: Vector3, tamanho: float) -> void:
	var raiz := VfxGoroMinePiece._raiz(de)
	if raiz == null or not ResourceLoader.exists(IMPACTO):
		return
	var v := (load(IMPACTO) as PackedScene).instantiate() as Node3D
	raiz.add_child(v)
	v.global_position = onde
	if rumo.length_squared() > 0.0001 and absf(rumo.normalized().y) < 0.99:
		v.look_at(onde + rumo, Vector3.UP)
	v.scale = Vector3.ONE * tamanho
	for malha in v.find_children("*", "MeshInstance3D", true, false):
		(malha as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var anim := v.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation("idle3"):
		anim.play("idle3")
	VfxGoroMinePiece._durar(v, 0.5)
