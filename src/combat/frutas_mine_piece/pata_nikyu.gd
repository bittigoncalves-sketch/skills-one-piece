extends MunicaoMinePiece
## PadEntity (Mine Piece v14) com a AIPadProcedure, modo 0: o tapa do Pad Ho e as palmadas do Tsuppari.
## A textura-base é "clear", mas o `PadLayer` do mod redesenha o modelo `pad.geo` com tex_white em RenderType.eyes: a pata é uma
## pata BRANCA LUMINOSA, visível (corrigido: antes o port a tratava como invisível — só som e partículas). Adaptação declarada: o
## mod sorteia o yaw da entidade (0–360°); aqui a palma aponta para onde ela anda.
## A cada tick anda `|power|` blocos (8 no Pad Ho, 6 no Tsuppari), UM bloco por passo, feria em cada passo (15 × CNT6,
## empurrão 0,5, cubo de 3 × tamanho) e NÃO para no primeiro alvo nem na parede: atravessa tudo (teleportTo) até cnt1 > 10.
## Parede: na primeira vez que o centro entra num bloco sólido, explosão de potência 0 e fumaça (o mod também quebra blocos com
## BlockDestroyAllDirection; o mapa do jogo não tem a grade de blocos, então só o efeito entra — adaptação declarada).
const Mundo := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")

## O `power` do mod (x/y/z_power): módulo = blocos por tick.
var potencia := 8.0
## DATA_mode: 0 = tapa (Pad Ho / Tsuppari); 1 = segue o dono (Ursus Shock, enquanto ele segura); 2 = solta (voa a 3 blocos/tick
## e detona em onda de choque); 3 = a explosão no fim da Assault (nasce já "morta": onda com CNT6 negativo, some com cnt1 > 14).
var modo := 0
## O executor da Nikyu que criou esta pata no modo 1 (dele vêm a âncora e o fim da técnica).
var dono_exec: Node
var _na_parede := false
var _onda := false              # "morreu": a onda de choque (NoAI)
var _forca_voo := Vector3.ZERO  # x/y/z_power copiado do dono: blocos por tick


func _configurar() -> void:
	if modo == 3:
		_onda = true
	largura_base = 1.0          # EntityType.sized(1, 1)
	altura_base = 1.0
	velocidade = potencia
	fator_alcance = 1.25        # AIPad: entity_size = ReturnEntitySize × 1,25
	dano_base = 15.0
	empurrao = 0.5
	extra_pela_carga = false
	mede_do_meio = true
	limite_cnt1 = 10
	grupo = "pata_nikyu_mine_piece"
	modelo = "res://assets/mine_piece/frutas/nikyu/mp_pata.glb"
	brilho = true


## Invulnerable:1b no `data merge` do mod.
func take_damage(_dano: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
	pass


func _passo() -> void:
	if modo == 1:
		_seguir()
		return
	if modo == 2 or modo == 3:
		_solta()
		return
	_cnt1 += 1
	var t := Mundo.tamanho_municao(altura_b(), largura_b()) * fator_alcance
	var k6 := 1.0 + cnt6 * 0.1
	var passo_b := rumo.normalized()
	for i in maxi(int(round(maxf(potencia, 1.0))), 1):
		var a := B.Ataque.new(dano_base * k6, 3.0 * t, empurrao, false)
		a.ignora_guarda = true       # "ignore": true
		B.ataque_em_area(c.ator, global_position, _ponto(), a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
		if _dentro_de_parede():
			if not _na_parede:
				_na_parede = true
				_batida(t)
		else:
			_na_parede = false
		global_position += passo_b * B.METROS_POR_BLOCO
	if _cnt1 > limite_cnt1:
		queue_free()


## InsideSolid no centro do corpo (a pata é um cubo de 1 × tamanho).
func _dentro_de_parede() -> bool:
	return B.solido(get_world_3d(), centro_do_corpo() - Vector3.UP * B.m(altura_b() * 0.5), altura_b(), largura_b() * 0.8)


## Explosão de potência 0 + `particle explosion` e `particle cloud` do comando do mod.
func _batida(t: float) -> void:
	var onde := _ponto()
	var lado := B.m(t)
	VfxGoroMinePiece.clarao(c.ator, onde, lado)
	VfxFrutaMinePiece.onda_de_choque(c.ator, onde, lado * 1.2, Color(1.0, 0.75, 0.45), 0.6)
	VfxGoroMinePiece.fumaca(c.ator, onde, int(round(maxf(4.0 * t, 1.0))), lado, 0.5)
	McVisual.som(c.get_tree(), "entity.generic.explode", McVec3.de_godot(onde), 1.0, 1.0)


# ------------------------------------------------------------------ Ursus Shock (AIPadExplodeProcedure)
## Modo 1: encolhe 1 bloco por tick (até 0,5), cola na âncora do dono, copia a mira e a força dele. Quando a técnica acaba (ou o
## dono passa de cnt1 > 20) vira modo 2 com o som da flecha.
func _seguir() -> void:
	var seguindo: bool = is_instance_valid(dono_exec) and c.ativo and int(dono_exec.tecnica) == 22
	if tamanho > 0.5:
		tamanho = maxf(tamanho - 1.0, 0.5)
	if seguindo:
		rumo = dono_exec.rumo_ancora
		_forca_voo = rumo * 3.0
		global_position = dono_exec.ancora
		if int(dono_exec.cnt1) > 20:
			seguindo = false
	if not seguindo:
		modo = 2
		_cnt1 = 0
		McVisual.som(c.get_tree(), "entity.arrow.shoot", McVec3.de_godot(_ponto()), 1.0, 1.0)


## Modo 2: voa `_forca_voo` blocos por tick; qualquer alvo a menos de 24 blocos apressa o fim (cnt1 ≥ 15); com cnt1 > 20
## "kill @s" + "NoAI:1b" e começa a onda.
func _solta() -> void:
	if _onda:
		_onda_de_choque()
		return
	_cnt1 += 1
	var centro := _ponto()
	for alvo in AlvosDeGolpe.todos(c.get_tree()):
		if B.atacavel(c.ator, alvo) and B.no_cubo(alvo, centro, 48.0):
			_cnt1 = maxi(_cnt1, 15)
			break
	if _cnt1 > 20:
		_cnt1 = 0
		_onda = true
		return
	var passo := _forca_voo * B.METROS_POR_BLOCO
	if not B.solido(get_world_3d(), global_position + passo, altura_b(), largura_b() * 0.8):
		global_position += passo


## A explosão: cubo de (tamanho + 4) blocos, 30 × CNT6 (empurrão 1) e empurrão de área 1; o tamanho cresce size/7 por tick até
## 42 × CNT6³ (5 se CNT6 < 1) e o centro vertical fica parado. Dura os 20 ticks da morte da entidade.
func _onda_de_choque() -> void:
	_cnt1 += 1
	var k6 := 1.0 + cnt6 * 0.1
	var centro := _ponto()
	if _cnt1 == 1:
		McVisual.som(c.get_tree(), "minepiece:flame_explode", McVec3.de_godot(centro), 2.0 * k6, 2.0)
	var lado := tamanho + 4.0
	var a := B.Ataque.new(30.0 * k6, lado, 1.0, false)
	B.ataque_em_area(c.ator, centro, centro, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
	if _cnt1 % 4 == 1:
		# BlockDestroyAllDirection (0,75 do alcance, dano 8): sem a grade de blocos, só a poeira.
		VfxGoroMinePiece.fumaca(c.ator, centro, mini(int(round(lado)), 16), B.m(lado) * 0.35, 1.0)
	B.empurrar_area(c.ator, centro, centro, lado, 1.0)
	var alvo_tam := 42.0 * k6 * k6 * k6 if k6 >= 1.0 else 5.0
	if tamanho < alvo_tam:
		var antes := altura_b()
		tamanho = minf(tamanho + alvo_tam / 7.0, alvo_tam)
		global_position.y += B.m((antes - altura_b()) * 0.5)      # o centro não sobe (old_height do mod)
		VfxGoroMinePiece.fumaca(c.ator, centro, mini(int(2.0 * lado), 24), B.m(lado) * 0.5, 1.0)
	if _cnt1 > (14 if cnt6 < 0.0 else 20):
		queue_free()
