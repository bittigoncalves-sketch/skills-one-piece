class_name CorpoLogiaMinePiece
extends RefCounted
## O corpo das logias no controlador genérico: a transformação elemental (regra do
## dono, `TransformacaoElemental`) com o voo do mod (`VooLogiaMinePiece`) e a borda
## do elemento nas malhas do personagem. Mesma regra que a Goro aplica por conta
## própria (GATILHO: na próxima mudança na Goro, ela passa a usar este módulo).
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")

var c
var cor := Color(1, 1, 1)
## Partícula do elemento (tira de flipbook do mod) que o corpo solta transformado, como as
## faíscas da Goro: {"caminho", "quadros"}. Vazio = sem partícula.
var particula := {}
var elemental := TransformacaoElemental.new()
var voo := VooLogiaMinePiece.new()
var _velocidade_antes := 1.0
var _voo_tick := 0
var _voo_acumulado := 0.0
var _brilho: ShaderMaterial


## Um tick do servidor. Fora da fruta ou morto, desfaz e só acompanha a vida.
func observar(vivo: bool) -> void:
	var agora: float = c.tick * B.TICK
	if not vivo or not c.fruta_ativa():
		if elemental.ativa:
			desfazer()
		elemental.observar(float(c.ator.health), float(c.ator.max_health), agora)
		return
	if elemental.observar(float(c.ator.health), float(c.ator.max_health), agora):
		_velocidade_antes = c.ator.speed_multiplier
		c.ator.speed_multiplier = _velocidade_antes * TransformacaoElemental.BONUS_DE_VELOCIDADE
		voo.comecar(c.ator.velocity)
		_voo_tick = 0
		_corpo_do_elemento(true)
	if elemental.ativa and c.tick % 3 == 1 and not particula.is_empty():
		VfxFrutaMinePiece.particulas(c.ator, str(particula.caminho), int(particula.quadros),
			c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), 4,
			Vector3(B.m(B.LARGURA_JOGADOR), B.m(B.ALTURA_JOGADOR * 0.5), B.m(B.LARGURA_JOGADOR)), 0.6, 0.6, 0.35)


func desfazer() -> void:
	if not elemental.ativa:
		return
	elemental.desfazer()
	if is_instance_valid(c.ator):
		c.ator.speed_multiplier = _velocidade_antes
	_corpo_do_elemento(false)


func voando() -> bool:
	return elemental.ativa


## O voo forçado da transformação: W/S comandam, Espaço sobe, parado plana.
func velocidade(delta: float, q: MoveFrame) -> Vector3:
	var saida := voo.v * B.VELOCIDADE
	_voo_acumulado += delta
	while _voo_acumulado >= B.TICK:
		_voo_acumulado -= B.TICK
		_voo_tick += 1
		saida = voo.tick(_voo_tick, q.espaco_segurado, signf(q.f), c.olhar(),
			TransformacaoElemental.BONUS_DE_VELOCIDADE, c.ator.is_on_floor())
	return saida


func _corpo_do_elemento(ligar: bool) -> void:
	var modelo: Node3D = c.ator._char_model if is_instance_valid(c.ator) else null
	if modelo == null:
		return
	if _brilho == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 cor : source_color = vec4(1.0);
void fragment() {
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float tremor = 0.7 + 0.3 * sin(TIME * 11.0 + VERTEX.y * 7.0);
	ALBEDO = cor.rgb;
	ALPHA = clamp(borda * 2.2 * tremor + 0.2, 0.0, 1.0);
}"""
		_brilho = ShaderMaterial.new()
		_brilho.shader = sh
		_brilho.set_shader_parameter("cor", cor)
	for malha in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := malha as MeshInstance3D
		if ligar:
			mi.material_overlay = _brilho
		elif mi.material_overlay == _brilho:
			mi.material_overlay = null
