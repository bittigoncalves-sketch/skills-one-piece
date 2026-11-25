class_name AnimacaoDeCaptura
extends Node3D
## ANIMAÇÃO DE CAPTURA (10/11/2026, pedido do dono): a pokébola acerta, a criatura some para dentro dela, a bola cai no chão e CHACOALHA de um
## lado para o outro (`chacoalhadas` vezes, 0..4 pelo sorteio da conta Pokémon). Sucesso: clique e TRÊS ESTRELAS sobem da bola (no lugar do texto
## "capturado"). Falha: a bola abre num clarão e a criatura volta. Só apresenta: quem decide (sorteio) e quem captura é o `Recrutamento`,
## chamado por `ao_terminar(capturou)` — no sucesso, no instante do clique (as estrelas sobem depois).
## Linha do tempo (s): CAIR 0,45 → [chacoalhada 0,55 + pausa 0,30] × n → (sucesso) CLIQUE 0,25 → ESTRELAS 1,0 | (falha) ABRIR 0,3.
signal terminou(capturou: bool)

const CAIR := 0.45
const CHACOALHADA := 0.55
const PAUSA := 0.30
const CLIQUE := 0.25
const ESTRELAS := 3
const VIDA_DAS_ESTRELAS := 1.0
const ABRIR := 0.3
const ARCO := 0.5                    # rad de cada lado na chacoalhada

var chacoalhadas := 0
var capturou := false
var ao_terminar: Callable
var altura_inicial := 0.8            # onde a bola "nasce" (centro da criatura), acima do chão
var chacoalhadas_feitas := 0
var estrelas_criadas := 0
var fase := "cair"

var _t := 0.0
var _bola: Node3D
var _entregue := false
var _som_do_clique := false


func _ready() -> void:
	name = "AnimacaoDeCaptura"
	_bola = _montar_bola()
	add_child(_bola)
	_bola.position.y = altura_inicial


static func _material(cor: Color, brilho := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = brilho
	return m


## A bola: cubo vermelho (a mesma cor da bola em voo) com a faixa branca e o botão — estética voxel do jogo.
func _montar_bola() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Bola"
	var topo := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.24, 0.12, 0.24)
	topo.mesh = b
	topo.position.y = 0.06
	topo.material_override = _material(Color(0.9, 0.3, 0.25), 0.4)
	raiz.add_child(topo)
	var base := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(0.24, 0.12, 0.24)
	base.mesh = b2
	base.position.y = -0.06
	base.material_override = _material(Color(0.95, 0.95, 0.95), 0.15)
	raiz.add_child(base)
	var botao := MeshInstance3D.new()
	var b3 := BoxMesh.new()
	b3.size = Vector3(0.07, 0.07, 0.26)
	botao.mesh = b3
	botao.material_override = _material(Color(0.15, 0.15, 0.15), 0.0)
	raiz.add_child(botao)
	return raiz


func _physics_process(delta: float) -> void:
	_t += delta
	_avancar()


func _avancar() -> void:
	if not is_instance_valid(_bola):
		return
	var t := _t
	if t < CAIR:
		fase = "cair"
		var k := t / CAIR
		_bola.position.y = lerpf(altura_inicial, 0.12, k * k)          # cai acelerando
		_bola.rotation = Vector3(0.0, t * 8.0, 0.0)
		return
	t -= CAIR
	_bola.position.y = 0.12
	_bola.rotation = Vector3.ZERO
	# chacoalhadas: o balanço lateral decai a cada uma
	var ciclo := CHACOALHADA + PAUSA
	var n_feitas := mini(int(t / ciclo), chacoalhadas)
	if n_feitas < chacoalhadas or t < chacoalhadas * ciclo:
		fase = "chacoalhar"
		var i := int(t / ciclo)
		var dentro := t - float(i) * ciclo
		chacoalhadas_feitas = maxi(chacoalhadas_feitas, i + (1 if dentro >= CHACOALHADA else 0))
		if dentro < CHACOALHADA:
			var amp := ARCO * (1.0 - 0.1 * float(i))
			_bola.rotation.z = sin(dentro / CHACOALHADA * TAU) * amp          # de um lado para o outro
		return
	chacoalhadas_feitas = chacoalhadas
	t -= chacoalhadas * ciclo
	if capturou:
		if t < CLIQUE:
			fase = "clique"
			return
		if not _entregue:
			_entregue = true
			_soltar_estrelas()
			if ao_terminar.is_valid():
				ao_terminar.call(true)                 # a criatura sai do mundo agora; as estrelas sobem
			terminou.emit(true)
		fase = "estrelas"
		if t - CLIQUE >= VIDA_DAS_ESTRELAS:
			queue_free()
	else:
		fase = "abrir"
		if not _entregue:
			_entregue = true
			_bola.scale = Vector3.ONE * 1.6                # clarão: a bola abre
			McVisual.particula(get_tree(), "minecraft:cloud", McVec3.de_godot(global_position + Vector3.UP * 0.2), 12, 0.2, 0.2, 0.2, 0.05)
			if ao_terminar.is_valid():
				ao_terminar.call(false)
			terminou.emit(false)
		if t >= ABRIR:
			queue_free()


## TRÊS estrelas douradas que sobem em leque e somem.
func _soltar_estrelas() -> void:
	McVisual.som(get_tree(), "entity.experience_orb.pickup", McVec3.de_godot(global_position), 1.0, 1.3)
	for i in ESTRELAS:
		var estrela := Label3D.new()
		estrela.name = "Estrela%d" % i
		estrela.text = "★"
		estrela.font_size = 96
		estrela.pixel_size = 0.004
		estrela.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		estrela.modulate = Color(1.0, 0.85, 0.2)
		estrela.outline_modulate = Color(1.0, 0.6, 0.1)
		estrela.outline_size = 8
		estrela.no_depth_test = true
		estrela.position = Vector3(0.0, 0.3, 0.0)
		add_child(estrela)
		var ang := TAU * float(i) / float(ESTRELAS) + PI * 0.5
		var destino := Vector3(cos(ang) * 0.55, 1.3 + 0.15 * float(i), sin(ang) * 0.55)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(estrela, "position", destino, VIDA_DAS_ESTRELAS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(estrela, "modulate:a", 0.0, VIDA_DAS_ESTRELAS * 0.6).set_delay(VIDA_DAS_ESTRELAS * 0.4)
		tw.tween_property(estrela, "scale", Vector3.ONE * 1.4, VIDA_DAS_ESTRELAS)
		estrelas_criadas += 1
