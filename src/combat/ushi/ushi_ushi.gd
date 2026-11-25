extends Node
## USHI USHI NO MI, MODELO GIRAFA — kit autoral (21/11/2026, pedido do dono). Plano e referências: `docs/frutas/ushi_ushi/PLANO.md` (Codex).
## TRÊS FORMAS: 0 humano · 1 girafa humanoide (a do mod) · 2 girafa quadrúpede (`FormaGirafa`). O J percorre 0→1→2→0 (Shift volta). A forma 2 é
## estado DESTE módulo; o atributo `minepiece:form` do mod fica em 1 nela (mantém tamanho, resistência e passo da girafa).
## HUMANO e HUMANOIDE:  Z Investida do Pescoço · X Corte no Ar · C Rajada de Cortes (+ V Sky Slicer, do mod).
## QUADRÚPEDE:          Z Pescoçada · X Martelada (nariz) · C não existe.
## Mesmo ciclo de vida da Flor de Buda/Zushi: entrada e dano no servidor, recarga por técnica no `controlador`, sem skill builder.

const ID := "ushi_ushi_giraffe"
const ID_GIRAFA := "ushi_ushi_girafa"        # chave da tabela do `Balance` para a forma quadrúpede
const PRIMEIRO := 1101
const NUMEROS := {"Z": 1101, "X": 1102, "C": 1103}
const NUMEROS_GIRAFA := {"Z": 1111, "X": 1112}
const RESISTENCIA_TRANSFORMADO := 1.5          # pedido do dono (21/11/2026): transformado (forma 1 ou 2) recebe 1,5× menos dano (meta `resistencia_de_forma`, lida em `Player.take_damage`)
const SKY_SLICER := 25                        # o V do mod, que continua nas formas 0 e 1
const LutaBasica = preload("res://src/combat/frutas_mine_piece/luta.gd")

enum Fase { LIVRE, PREPARO, ATIVO, RECUPERA }

## Dados por golpe. `p`/`a`/`r` = preparo/ativo/recuperação (s). Alcance do pescoço em metros (já com a escala da forma).
const DADOS := {
	"Z": {"nome": "Investida do Pescoço", "custo": 60.0, "recarga": 3.0, "p": 0.22, "a": 0.26, "r": 0.36, "alcance": 5.5, "raio": 0.85, "passo": 6.0, "empurrao": 13.0},
	"X": {"nome": "Corte no Ar", "custo": 100.0, "recarga": 4.0, "p": 0.34, "a": 0.06, "r": 0.34, "larg": 2.6, "vel": 45.0, "alc": 40.0, "incl": 0.2},      # bicuda lateral: a lâmina sai quase deitada, varrida pelo arco da perna
	"C": {"nome": "Rajada de Cortes", "custo": 150.0, "recarga": 7.0, "p": 0.16, "a": 1.26, "r": 0.4, "cortes": 9, "larg": 1.9, "vel": 42.0, "alc": 32.0},
}
const DADOS_GIRAFA := {
	"Z": {"nome": "Pescoçada", "custo": 60.0, "recarga": 3.0, "p": 0.36, "a": 0.16, "r": 0.42, "alcance": 6.5, "raio": 1.0, "passo": 3.0, "empurrao": 18.0},
	"X": {"nome": "Martelada", "custo": 110.0, "recarga": 4.5, "p": 0.38, "a": 0.24, "r": 0.46, "alcance": 4.4, "raio": 1.15, "empurrao": 14.0, "giro_ini": 1.0, "giro_fim": -0.75},
}
const ORDEM_DE_INCLINACAO := [0.1, 0.4, -0.2, 0.7, 0.0, -0.4, 0.5, -0.1, 0.3]       # bicudas laterais: lâminas quase deitadas, cada uma com um leve desvio

var controlador: Node
var forma := 0                 # 0 humano · 1 humanoide · 2 girafa
var ativo := false
var fase: Fase = Fase.LIVRE
var tecla := ""
var numero := 0
var tempo := 0.0
var spec: DamageSpec
var acertos := 0               # alvos feridos pelo golpe em curso/último (teste e HUD)
var mov := 0.0                 # 0..1 — velocidade horizontal suavizada (animação de corrida)
var fase_corrida := 0.0
var bloqueio_de_forma := 0.0   # s de troca de forma (corpo parado, fumaça)

var _dados: Dictionary
var _dir := Vector3.FORWARD    # direção da mira travada no início do ATIVO
var _feridos := {}
var _ancora: Node3D            # segue a junta do pescoço (formas 0 e 1)
var _pescoco: UshiPescoco      # pescoço do humano/humanoide
var _ponta_ant := Vector3.ZERO
var _raiz_ant := Vector3.ZERO
var _cortes_soltos := 0
var _pos_base := {}
var _forma_zoan: FormaZoan
var _mod_visto := 0
var _cabeca_oculta: Node3D
var _camadas_ocultas: Array[Node3D] = []
var _girafa: FormaGirafa
var cortes_lancados := 0       # contador cumulativo (teste)


func ator() -> Player:
	return controlador.ator


# ------------------------------------------------------------------ formas

## J: 0→1→2→0 (para trás: o inverso). O mod só conhece 0↔1: a forma 2 é a girafa por cima da 1.
func ciclar(para_tras := false) -> void:
	if ativo or bloqueio_de_forma > 0.0 or not controlador.servidor():
		return
	var alvo := posmod(forma + (-1 if para_tras else 1), 3)
	var mod_quer := 0 if alvo == 0 else 1
	if controlador.forma_atual() != mod_quer:
		controlador._passo_do_mod(mod_quer > controlador.forma_atual())
	forma = alvo
	bloqueio_de_forma = 0.6 if alvo == 2 or forma == 2 else 0.0
	_ao_mudar_forma()
	if alvo == 2 or alvo == 1:
		PoderVfx.impacto(ator(), ator().global_position + Vector3.UP * 0.9, UshiMateriais.CLARO, 2.2, PoderVfx.Forma.CIRCULO)


## Chamado pelo controlador quando o mod muda a forma por conta própria (nascimento, morte, retirar a fruta).
func sincronizar_com_o_mod() -> void:
	var m: int = controlador.forma_atual()
	if m == _mod_visto:
		return                                           # só reage a MUDANÇA do mod (a dele demora ~2 s depois do J)
	_mod_visto = m
	if m == 0 and forma != 0:
		forma = 0
		_ao_mudar_forma()
	elif m > 0 and forma == 0:
		forma = 1
		_ao_mudar_forma()


func forma_visual() -> int:
	return forma


func _ao_mudar_forma() -> void:
	cancelar()
	var a := ator()
	if not is_instance_valid(a):
		return
	if forma >= 1:
		a.set_meta("resistencia_de_forma", RESISTENCIA_TRANSFORMADO)
	elif a.has_meta("resistencia_de_forma"):
		a.remove_meta("resistencia_de_forma")
	FormaZoan.aplicar(a, ID, 1 if forma == 1 else 0)
	_forma_zoan = a.get_node_or_null("FormaZoan") as FormaZoan
	_pos_base.clear()
	if is_instance_valid(_forma_zoan):
		_forma_zoan.pos_seguir = _pose_humanoide
	_girafa = FormaGirafa.aplicar(a, forma == 2)
	if forma == 2:
		a.set_meta(FormaZoan.META_ATIVA, true)
		if a.has_method("_atualizar_visibilidade_corpo"):
			a._atualizar_visibilidade_corpo()
	_retirar_pescoco()


func limpar() -> void:
	cancelar()
	if is_instance_valid(ator()) and ator().has_meta("resistencia_de_forma"):
		ator().remove_meta("resistencia_de_forma")
	if is_inside_tree():
		UshiCorte.limpar_do_dono(ator(), get_tree())
	_retirar_pescoco()
	if is_instance_valid(ator()):
		FormaGirafa.aplicar(ator(), false)
	_girafa = null


# ------------------------------------------------------------------ golpes

func dados_de(t: String) -> Dictionary:
	return (DADOS_GIRAFA if forma == 2 else DADOS).get(t, {})


func numero_de(t: String) -> int:
	return int((NUMEROS_GIRAFA if forma == 2 else NUMEROS).get(t, 0))


func iniciar(t: String) -> bool:
	var a := ator()
	var d := dados_de(t)
	if d.is_empty() or ativo or controlador.ativo or not controlador.servidor() or not controlador.fruta_ativa():
		return false
	if a.morrendo or not a.corpo_livre_para_golpe() or bloqueio_de_forma > 0.0:
		return false
	var n := numero_de(t)
	if controlador.recarga_da_tecnica(n) > 0.0 or a.energy + 0.001 < float(d.custo):
		return false
	a.gastar_energia(float(d.custo))
	controlador._sincronizar_para_o_mod()
	ativo = true
	controlador.ativo = true
	controlador.selecao = n
	a.set_meta(ControladorFrutaMinePiece.META, controlador.get_instance_id())
	controlador.iniciar_recarga(n, float(d.recarga))
	tecla = t
	numero = n
	_dados = d
	tempo = 0.0
	fase = Fase.PREPARO
	acertos = 0
	_feridos.clear()
	_cortes_soltos = 0
	spec = _spec_do_golpe(t)
	_mirar()
	if _usa_pescoco():
		_garantir_pescoco()
	PoderDaFruta.ativacao(a, ID, float(d.custo))
	return true


## Os golpes próprios usam a tabela da arena, não as unidades das procedures do mod.
## A Luta recebe Força em cada contato: a rajada completa tem até 20 socos e um
## final, então distribuímos esse bônus pelos nove cortes para manter a vantagem
## da fruta também em níveis altos, sem abrir mão do teto por conjuração.
func _spec_do_golpe(t: String) -> DamageSpec:
	var a := ator()
	var perfil: PerfilDeFrutas = a.perfil_de_frutas
	var historia := perfil != null and perfil.fruta == ID and perfil.fiel_ao_mod
	var escala := PerfilDeFrutas.ESCALA_DA_ARENA * Balance.HISTORIA_TECNICAS if historia else a.escala_de_dano_da_fruta(ID)
	var resultado := Balance.novo(ID_GIRAFA if forma == 2 else ID, t, escala)
	if historia and resultado != null:
		var bonus := maxf(0.0, float(a.get_meta("bonus_fisico_historia", 0.0)))
		if t == "C":
			var socos_maximos := ceili(float(LutaBasica.MAXIMO_RAJADA - LutaBasica.INICIO_RAJADA) / float(LutaBasica.INTERVALO_RAJADA)) + 1
			bonus *= float(socos_maximos) / float(resultado.hits)
		resultado.dano += bonus
		resultado.teto += bonus * float(resultado.hits)
	return resultado


func _usa_pescoco() -> bool:
	return tecla == "Z" or (forma == 2 and tecla == "X")


var _dir_reta := Vector3.FORWARD       # a mira EXATA (sem limite de elevação): o X e a C voam RETO nela (pedido do dono: "não sobe, vai reto para onde a mira aponta")
var _ponto_mira := Vector3.INF         # o ponto que o retículo marca (para os cortes que saem do PÉ mirarem nele, não em paralelo à câmera)


func _mirar() -> void:
	var d: Vector3 = controlador.olhar()
	_dir_reta = d.normalized() if d.length() > 0.01 else -ator().global_basis.z
	var cam: Camera3D = ator().get_viewport().get_camera_3d()
	var origem_mira: Vector3 = cam.global_position if cam != null else ator().global_position + Vector3.UP * 1.6
	_ponto_mira = origem_mira + (d.normalized() if d.length() > 0.01 else -ator().global_basis.z) * 14.0      # ponto da LINHA do retículo a 14 m (sem colisão: mirar no chão não pode enterrar o corte)
	_dir = d.normalized() if d.length() > 0.01 else -ator().global_basis.z
	_dir.y = clampf(_dir.y, -0.45, 0.6)
	_dir = _dir.normalized()


func _physics_process(delta: float) -> void:
	var a := ator()
	if not is_instance_valid(a):
		return
	bloqueio_de_forma = maxf(0.0, bloqueio_de_forma - delta)
	_medir_movimento(delta)
	if is_instance_valid(_ancora):
		_seguir_ancora()
	if not ativo:
		return
	if not controlador.fruta_ativa() or a.morrendo or not a.corpo_livre_para_golpe():
		cancelar()
		return
	tempo += delta
	var d := _dados
	var p := float(d.p)
	var at := float(d.a)
	var r := float(d.r)
	if tempo < p:
		fase = Fase.PREPARO
		_pose_do_golpe(tempo / p, 0.0, 0.0)
	elif tempo < p + at:
		if fase != Fase.ATIVO:
			fase = Fase.ATIVO
			_mirar()                                      # a mira vale no instante em que o golpe sai
			_ao_comecar_ativo()
		_pose_do_golpe(1.0, (tempo - p) / at, 0.0)
		_durante_ativo(delta, (tempo - p) / at)
	elif tempo < p + at + r:
		fase = Fase.RECUPERA
		if tecla == "C":
			while _cortes_soltos < int(d.cortes):          # quadro lento: nenhum corte da rajada se perde na virada de fase
				_soltar_corte(_cortes_soltos, int(d.cortes))
				_cortes_soltos += 1
		_pose_do_golpe(1.0, 1.0, (tempo - p - at) / r)
	else:
		cancelar()


func _ao_comecar_ativo() -> void:
	_ponta_ant = _ponta()
	_raiz_ant = _raiz()
	# Um som por ataque (UshiAudio). O C toca um talho por corte (ver `_soltar_corte`).
	if tecla == "Z":
		UshiAudio.tocar(ator(), "z_pescocada" if forma == 2 else "z_investida")
	elif tecla == "X":
		UshiAudio.tocar(ator(), "martelada" if forma == 2 else "x_corte")
	if tecla == "X" and forma != 2:
		_soltar_corte(0, 1)



func _durante_ativo(_delta: float, u: float) -> void:
	if tecla == "C":
		_emitir_cortes_devidos()
		return
	if tecla == "X" and forma != 2:
		return
	_ferir_com_o_pescoco()


## C: um corte no PICO de cada chute (0,084 s depois do início de cada ciclo de 0,14 s), do pé que chuta — nunca no início do ciclo.
## Em quadro lento vários picos podem vencer no mesmo tick: todos saem, nenhum se perde.
func _emitir_cortes_devidos() -> void:
	var total := int(_dados.cortes)
	var rel := tempo - float(_dados.p)
	while _cortes_soltos < total and rel >= UshiChute.C_PICO + float(_cortes_soltos) * UshiChute.C_CICLO:
		_soltar_corte(_cortes_soltos, total)
		_cortes_soltos += 1


## Corte no ar (X humano/humanoide) e cada corte da rajada (C).
func _soltar_corte(i: int, total: int) -> void:
	var a := ator()
	var d := _dados
	# RETO na mira: a lâmina voa exatamente na direção apontada (sem convergir para um ponto, que a fazia subir). Sai do lado do pé que chuta, na altura
	# do quadril, para a linha ficar perto da do retículo.
	var pe := _pe_que_chuta(i % 2 == 0 or tecla == "X")
	var plano := Vector3(_dir_reta.x, 0.0, _dir_reta.z).normalized()
	var base_xz := (pe if pe != Vector3.INF else a.global_position)
	var de := Vector3(base_xz.x, a.global_position.y + 0.95, base_xz.z) + plano * 0.4
	var rumo := _dir_reta
	if tecla == "C":
		# Leque determinístico: cada corte desvia um pouco (yaw e pitch) em sequência fixa — a rajada cobre uma faixa, não uma linha.
		var desvio := Basis(Vector3.UP, sin(float(i) * 2.399) * 0.06) * Basis(Vector3.RIGHT, cos(float(i) * 1.7) * 0.03)
		rumo = (desvio * rumo).normalized()
	var incl: float = float(d.get("incl", 0.0)) if tecla == "X" else float(ORDEM_DE_INCLINACAO[i % ORDEM_DE_INCLINACAO.size()])
	var c := UshiCorte.criar(get_tree().current_scene, de, rumo, a, spec, float(d.larg), incl, float(d.vel), float(d.alc))
	c.empurrao = 7.0 if tecla == "X" else 3.5
	c.atordoar = 0.3 if tecla == "X" else 0.12
	cortes_lancados += 1
	if tecla == "C":
		UshiAudio.tocar(a, "c_corte", i, -9.0)
	if tecla == "X":
		PoderVfx.tremor(a, 0.12)


func _pe_que_chuta(direito: bool) -> Vector3:
	var raiz := ator().get("_char_model") as Node3D
	if raiz == null:
		return Vector3.INF
	var pe := raiz.find_child("Foot_R" if direito else "Foot_L", true, false) as Node3D
	return pe.global_position if pe != null else Vector3.INF


func _ferir_com_o_pescoco() -> void:
	var a := ator()
	var raiz := _raiz()
	var ponta := _ponta()
	var d := _dados
	var raio := float(d.raio)
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if _feridos.has(alvo) or not MundoMinePiece.atacavel(a, alvo) or CombatResolver.e_fogo_amigo(alvo, a):
			continue
		var c := AlvosDeGolpe.centro(alvo)
		# O que o pescoço varreu neste passo: da raiz até a ponta (Z) / só o terço do nariz (martelada), contra o corpo do alvo.
		var de := raiz if tecla == "Z" else raiz.lerp(ponta, 0.55)
		var perto := Geometry3D.get_closest_point_to_segment(c, de, ponta)
		var perto_ant := Geometry3D.get_closest_point_to_segment(c, de if tecla == "Z" else _raiz_ant.lerp(_ponta_ant, 0.55), _ponta_ant)
		var dist := minf(AlvosDeGolpe.distancia_ao_corpo(alvo, perto), AlvosDeGolpe.distancia_ao_corpo(alvo, perto_ant))
		if dist > raio:
			continue
		if _parede_entre(raiz, perto, a):
			continue                                     # o pescoço não fere através de parede
		_feridos[alvo] = true
		acertos += 1
		var empurra: Vector3
		if tecla == "Z":
			empurra = (_dir * float(d.empurrao)) + Vector3.UP * 3.0
		else:
			var varrido := (ponta - _ponta_ant)
			varrido.y = 0.0
			empurra = (varrido.normalized() if varrido.length() > 0.001 else _dir) * float(d.empurrao) + Vector3.UP * 4.5
		CombatResolver.aplicar(alvo, spec.dano, spec.cast_id, spec.teto, raiz, empurra, 0.7 if tecla == "X" else 0.45, 0.0, false, null, a)
		PoderVfx.impacto(a, perto, UshiMateriais.CLARO, 2.4, PoderVfx.Forma.CIRCULO)
		PoderVfx.tremor(a, 0.22)
		UshiAudio.tocar(a, "impacto", 0, -3.0 if (tecla == "X" and forma == 2) else -6.0)
	_ponta_ant = ponta
	_raiz_ant = raiz


func _parede_entre(de: Vector3, para: Vector3, a: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, para, 1, [a.get_rid()])
	return not a.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ pose do golpe (pescoço e corpo)

func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


## Pose do pescoço pelas três fases (`pr` 0..1 do preparo, `at` do ativo, `re` da recuperação).
func _pose_do_golpe(pr: float, at: float, re: float) -> void:
	var pesc := _pescoco_ativo()
	if pesc == null:
		_pose_de_chute(pr, at, re)
		return
	var base := _dados
	var rest_pitch := 0.42 if forma == 2 else 0.0
	var comp := pesc.comprimento_base * _escala_do_corpo()
	var ext_max := maxf(1.0, float(base.alcance) / maxf(comp, 0.1))
	var parent := pesc.get_parent() as Node3D
	var local := parent.global_basis.orthonormalized().inverse() * _dir
	var yaw_aim := atan2(-local.x, -local.z)
	var pitch_aim := acos(clampf(local.y, -1.0, 1.0))
	var ext := 1.0
	var pitch := rest_pitch
	var yaw := 0.0
	var peso := 0.0
	if tecla == "Z":
		if re > 0.0:
			var k := _ease_out(re)
			ext = lerpf(ext_max, 1.0, k)
			pitch = lerpf(pitch_aim, rest_pitch, k)
			yaw = lerpf(yaw_aim, 0.0, k)
			peso = 1.0 - k
		elif at > 0.0:
			ext = lerpf(0.5, ext_max, _ease_out(at))                 # estica com tudo
			pitch = pitch_aim
			yaw = yaw_aim
			peso = 1.0
		else:
			var k := pr * pr
			ext = lerpf(1.0, 0.5, k)                                 # retrai o pescoço
			pitch = lerpf(rest_pitch, 0.1, k)                        # e o puxa para trás/para cima
			yaw = 0.0
			peso = k
	else:   # Martelada: enrola o pescoço de lado, depois varre com o nariz
		var giro_ini := float(base.giro_ini)
		var giro_fim := float(base.giro_fim)
		var chao := 2.0                                         # ~27° ABAIXO da horizontal: o nariz desce até a altura de quem está no chão
		if re > 0.0:
			var k := _ease_out(re)
			ext = lerpf(ext_max, 1.0, k)
			pitch = lerpf(chao, rest_pitch, k)
			yaw = lerpf(yaw_aim + giro_fim, 0.0, k)
			peso = 1.0 - k
		elif at > 0.0:
			var u := _ease_out(at)
			ext = lerpf(0.85, ext_max, minf(1.0, u * 1.4))
			pitch = chao
			yaw = yaw_aim + lerpf(giro_ini, giro_fim, u)
			peso = 1.0
		else:
			var k := pr * pr
			ext = lerpf(1.0, 0.85, k)
			pitch = lerpf(rest_pitch, chao, minf(1.0, k * 1.5))
			yaw = yaw_aim + giro_ini * k
			peso = k
	pesc.extensao = ext
	pesc.pitch = pitch
	pesc.yaw = yaw
	pesc.roll = 0.0
	if is_instance_valid(_girafa):
		_girafa.coice_t = tempo if (tecla == "X" and tempo < float(base.p)) else -1.0     # coice visual na preparação da Martelada (sem dano)
		_girafa.peso_do_golpe = peso
		_girafa.inclinacao_do_tronco = -0.12 * peso if tecla == "Z" else 0.0


## Chute do X e da C (humano e humanoide): publica a pose no rig (meta `pose_externa`) e faz o salto visual do X. A forma 2 não usa.
var _y_base := INF


func _pose_de_chute(_pr: float, _at: float, _re: float) -> void:
	if forma == 2:
		return
	var d := _dados
	var pose: Dictionary
	var total := float(d.p) + float(d.a) + float(d.r)
	if tecla == "X":
		pose = UshiChute.pose_x(tempo + UshiChute.ATRASO_DO_RIG)
		_saltar(UshiChute.salto_x(tempo))
	else:
		var rel := tempo - float(d.p)
		if rel < 0.0:
			pose = UshiChute.pose_c(0.0, 1.0, 0)                  # preparo: já em posição de chutar (chuta com a direita primeiro)
			for papel: String in pose:
				pose[papel] = (pose[papel] as Vector3) * smoothstep(0.0, 1.0, tempo / maxf(float(d.p), 0.01))
		elif rel < float(d.a):
			var k := mini(int(rel / UshiChute.C_CICLO), int(d.cortes) - 1)
			pose = UshiChute.pose_c(fposmod(rel, UshiChute.C_CICLO) / UshiChute.C_CICLO, 1.0 if k % 2 == 0 else -1.0, k)
		else:
			pose = UshiChute.pose_c(1.0, 1.0 if int(d.cortes) % 2 == 1 else -1.0, int(d.cortes))
			var f := 1.0 - smoothstep(0.0, 1.0, (tempo - float(d.p) - float(d.a)) / maxf(float(d.r), 0.01))
			for papel: String in pose:
				pose[papel] = (pose[papel] as Vector3) * f
	# Recuperação do X: a pose já volta a zero no fim da linha do tempo; fecha suave nos últimos 0,08 s.
	if tecla == "X":
		var f := smoothstep(0.0, 1.0, (total - tempo) / 0.08)
		for papel: String in pose:
			pose[papel] = (pose[papel] as Vector3) * f
	ator().set_meta("pose_externa", pose)


func _saltar(altura: float) -> void:
	var m := ator().get("_char_model") as Node3D
	if m == null:
		return
	if _y_base == INF:
		_y_base = m.position.y
	m.position.y = _y_base + altura


func _fim_do_chute() -> void:
	if is_instance_valid(ator()) and ator().has_meta("pose_externa"):
		ator().remove_meta("pose_externa")
	if _y_base != INF:
		var m := ator().get("_char_model") as Node3D if is_instance_valid(ator()) else null
		if m != null:
			m.position.y = _y_base
		_y_base = INF


# ------------------------------------------------------------------ movimento

func controla_movimento() -> bool:
	return ativo or bloqueio_de_forma > 0.0


func velocidade(atual: Vector3, q: MoveFrame) -> Vector3:
	if bloqueio_de_forma > 0.0:
		return Vector3(0, minf(atual.y, 0.0), 0)
	var a := ator()
	var base := Player.SPEED * a.speed_multiplier
	if tecla == "Z" and fase == Fase.ATIVO:
		var h := Vector3(_dir.x, 0.0, _dir.z).normalized()
		return Vector3(h.x * float(_dados.passo), atual.y, h.z * float(_dados.passo))
	if tecla == "C":
		return Vector3(q.dir.x * base * 0.4, atual.y, q.dir.z * base * 0.4)
	var f := 0.0 if fase != Fase.RECUPERA else 0.3
	return Vector3(q.dir.x * base * f, atual.y, q.dir.z * base * f)


func _medir_movimento(delta: float) -> void:
	var a := ator()
	var v := Vector2(a.velocity.x, a.velocity.z).length() if a.is_on_floor() else 0.0
	mov = lerpf(mov, clampf(v / (Player.SPEED * 1.3), 0.0, 1.0), clampf(delta * 9.0, 0.0, 1.0))
	fase_corrida += v * delta * 2.2


# ------------------------------------------------------------------ pescoço dos corpos humano/humanoide

func _escala_do_corpo() -> float:
	if forma == 2 and is_instance_valid(_girafa):
		return _girafa.global_basis.get_scale().x
	return float(McEntidade.de(ator()).escala(&"height"))


func _pescoco_ativo() -> UshiPescoco:
	if forma == 2:
		return _girafa.pescoco if is_instance_valid(_girafa) else null
	return _pescoco if tecla == "Z" else null


func _garantir_pescoco() -> void:
	if forma == 2 or is_instance_valid(_pescoco):
		return
	_ancora = Node3D.new()
	_ancora.name = "AncoraDoPescocoUshi"
	ator().add_child(_ancora)
	_pescoco = UshiPescoco.new(1.1 if forma == 1 else 0.9, 0.2)
	_ancora.add_child(_pescoco)
	_seguir_ancora()
	var cab: Node3D = null
	if is_instance_valid(_forma_zoan):
		cab = _forma_zoan._topo.get("Head") as Node3D
	elif forma == 0:
		cab = (ator().get("_char_model") as Node3D).find_child("Head", true, false) as Node3D
	if cab != null:
		cab.visible = false              # a cabeça do corpo sai: a do pescoço ocupa o lugar
		_cabeca_oculta = cab
	if is_instance_valid(_forma_zoan):
		var camada2 := _forma_zoan._topo.get("Head#1") as Node3D      # 2ª camada do modelo (overlay da cabeça): sai junto
		if camada2 != null:
			camada2.visible = false
			_camadas_ocultas.append(camada2)


func _seguir_ancora() -> void:
	var a := ator()
	var raiz := a.get("_char_model") as Node3D
	if raiz == null:
		return
	var junta := raiz.find_child("Neck", true, false) as Node3D
	var esc := float(McEntidade.de(a).escala(&"height"))
	var origem := junta.global_position if junta != null else raiz.global_position + Vector3.UP * 1.5 * esc
	# Girafa humanoide: o pescoço nasce no PIVÔ da peça Head do modelo do mod (a altura dos ombros dela), não na junta do pescoço humano (mais alta).
	if is_instance_valid(_forma_zoan):
		var cab := _forma_zoan._topo.get("Head") as Node3D
		if cab != null:
			origem = cab.global_position
	_ancora.global_transform = Transform3D(raiz.global_basis.orthonormalized() * Basis.from_scale(Vector3.ONE * esc), origem)


func _retirar_pescoco() -> void:
	if is_instance_valid(_ancora):
		_ancora.queue_free()
	_ancora = null
	_pescoco = null
	if is_instance_valid(_cabeca_oculta):
		_cabeca_oculta.visible = true
	_cabeca_oculta = null
	for n in _camadas_ocultas:
		if is_instance_valid(n):
			n.visible = true
	_camadas_ocultas.clear()


func _ponta() -> Vector3:
	var p := _pescoco_ativo()
	return p.ponta() if p != null else ator().global_position


func _raiz() -> Vector3:
	var p := _pescoco_ativo()
	return p.raiz() if p != null else ator().global_position


## Fim do golpe (ou cancelamento): pescoço volta, recarga já corre no controlador.
func cancelar() -> void:
	if is_instance_valid(_girafa):
		_girafa.peso_do_golpe = 0.0
		_girafa.coice_t = -1.0
		_girafa.inclinacao_do_tronco = 0.0
	if tecla == "Z" or tecla == "X":
		if is_instance_valid(_pescoco) and forma != 2:
			_retirar_pescoco()
	_fim_do_chute()
	spec = null          # o orçamento (cast_id) NÃO é encerrado aqui: cortes já lançados seguem em voo e o varredor de vencidos o recolhe
	if ativo and is_instance_valid(controlador):
		controlador.ativo = false
		var a := ator()
		if is_instance_valid(a) and int(a.get_meta(ControladorFrutaMinePiece.META, 0)) == controlador.get_instance_id():
			a.remove_meta(ControladorFrutaMinePiece.META)
	ativo = false
	fase = Fase.LIVRE
	tecla = ""


func _exit_tree() -> void:
	limpar()


# ------------------------------------------------------------------ corrida do humanoide (forma 1)

## Corrida REFEITA (pedido do dono): em vez da corrida genérica do rig, a girafa humanoide inclina o tronco para a frente, balança o pescoço
## contra a passada, abre as pernas longas e leva os braços soltos em contrafase. A pose entra por mistura proporcional à velocidade; parado
## ou andando devagar vale a pose do rig. Aplicada por cima do que o `FormaZoan._seguir` acabou de copiar das juntas.
func _pose_humanoide(f: FormaZoan) -> void:
	var topo: Dictionary = f._topo
	if topo.is_empty():
		return
	if _pos_base.is_empty():
		for nome: String in topo:
			_pos_base[nome] = (topo[nome] as Node3D).position
	for nome: String in topo:
		(topo[nome] as Node3D).position = _pos_base[nome]
	var w := smoothstep(0.12, 0.45, mov) * (0.0 if ativo else 1.0)
	var sw := sin(fase_corrida)
	var quique := absf(sin(fase_corrida)) * 0.05 * w
	var lean := 0.26 * w
	var quadril := Vector3(0, -12.0 * f._k, 0)               # pivô do tronco: o quadril (no espaço do modelo, Y para cima)
	var giro_tronco := Basis(Vector3.RIGHT, lean)
	var pose := {
		"RightLeg": Basis(Vector3.RIGHT, -sw * 1.0 * w), "LeftLeg": Basis(Vector3.RIGHT, sw * 1.0 * w),
		"RightArm": Basis(Vector3.RIGHT, sw * 0.7 * w + 0.15 * w), "LeftArm": Basis(Vector3.RIGHT, -sw * 0.7 * w + 0.15 * w),
		"Body": giro_tronco,
		"Head": Basis(Vector3.RIGHT, lean * 0.6 + sin(fase_corrida + 1.0) * 0.12 * w),
	}
	# TODAS as camadas do modelo (a 2ª camada se chama "Head#1", "Body#1"…): recebem a MESMA pose da peça-base. Antes só a 1ª camada era movida e a
	# 2ª da cabeça ficava parada na pose do rig, flutuando fora do lugar durante a corrida (relato do dono, 21/11/2026).
	for nome: String in topo:
		var base_nome := nome.get_slice("#", 0)
		if not pose.has(base_nome):
			continue
		var peca := topo[nome] as Node3D
		var alvo: Basis = (pose[base_nome] as Basis) * (f._base[nome] as Basis)
		peca.basis = peca.basis.slerp(alvo, w) if w > 0.0 else peca.basis
		if w > 0.0 and ["Body", "Head", "RightArm", "LeftArm"].has(base_nome):
			var p0: Vector3 = _pos_base[nome]
			peca.position = (quadril + giro_tronco * (p0 - quadril)).lerp(p0, 1.0 - w) + Vector3(0, quique, 0)


# ------------------------------------------------------------------ HUD

func estados() -> Array:
	var saida := []
	var a := ator()
	var tabela := DADOS_GIRAFA if forma == 2 else DADOS
	for t: String in ["Z", "X", "C"]:
		if not tabela.has(t):
			continue
		var d: Dictionary = tabela[t]
		var n := numero_de(t)
		saida.append({"nome": d.nome, "tecla": t, "selecionada": ativo and tecla == t, "custo": float(d.custo),
			"recarga": controlador.recarga_da_tecnica(n), "recarga_total": float(d.recarga),
			"sem_energia": a.energy + 0.001 < float(d.custo), "bloqueada": a.max_energy + 0.001 < float(d.custo)})
	return saida
