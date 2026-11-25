class_name GizmoMatematica
extends RefCounted
# ============================================================================
#  MATEMÁTICA DO GIZMO — funções puras, sem nó, para poderem ser testadas.
#
#  O gizmo só diz "o mouse andou tanto ao longo deste eixo / girou tanto neste
#  anel". Transformar isso em nova posição, tamanho ou rotação da peça mora aqui,
#  e é por isso que o teste consegue provar "arrastar 3 m no X move 3 m no X" sem
#  simular mouse nenhum.
#
#  Convenção: rotação de peça é `rotacao_graus` em EULER YXZ, a mesma ordem que o
#  `Node3D.rotation_degrees` usa por padrão. Trocar a ordem aqui sem trocar lá
#  faria toda peça girada em dois eixos voltar torta do arquivo.
# ============================================================================

const QUASE_PARALELO := 1e-4


## Parâmetro `t` do ponto do EIXO mais próximo do RAIO do mouse (retas infinitas).
## Devolve NAN quando raio e eixo são quase paralelos: olhando de ponta para um
## eixo, qualquer movimento do mouse viraria um salto enorme — melhor ignorar.
static func parametro_no_eixo(raio_origem: Vector3, raio_dir: Vector3,
		eixo_origem: Vector3, eixo_dir: Vector3) -> float:
	var w0 := eixo_origem - raio_origem
	var a := eixo_dir.dot(eixo_dir)
	var b := eixo_dir.dot(raio_dir)
	var c := raio_dir.dot(raio_dir)
	var d := eixo_dir.dot(w0)
	var e := raio_dir.dot(w0)
	var denominador := a * c - b * b
	if absf(denominador) < QUASE_PARALELO:
		return NAN
	return (b * e - c * d) / denominador


## Ângulo (radianos, −π..π) do ponto onde o raio fura o plano do anel, medido a
## partir de uma referência fixa do plano. NAN se o raio não fura o plano.
static func angulo_no_plano(raio_origem: Vector3, raio_dir: Vector3,
		centro: Vector3, normal: Vector3) -> float:
	var plano := Plane(normal, centro)
	var ponto: Variant = plano.intersects_ray(raio_origem, raio_dir)
	if ponto == null:
		return NAN
	var referencia := _perpendicular(normal)
	var outra := normal.cross(referencia)
	var v: Vector3 = ponto - centro
	return atan2(v.dot(outra), v.dot(referencia))


## Diferença entre dois ângulos, sempre pelo caminho curto (−π..π).
static func diferenca_angular(de: float, para: float) -> float:
	return wrapf(para - de, -PI, PI)


## Arredonda ao passo; passo ≤ 0 é "livre".
static func grudar(valor: float, passo: float) -> float:
	return valor if passo <= 0.0 else snappedf(valor, passo)


static func distancia_ao_segmento_2d(ponto: Vector2, a: Vector2, b: Vector2) -> float:
	return ponto.distance_to(Geometry2D.get_closest_point_to_segment(ponto, a, b))


## Gira uma peça em torno de `centro` por `angulo` (radianos) no `eixo` do MUNDO.
## Devolve [nova_posicao, nova_rotacao_graus].
static func girar_em_torno(posicao: Vector3, rotacao_graus: Vector3, centro: Vector3,
		eixo: Vector3, angulo: float) -> Array:
	var giro := Basis(eixo.normalized(), angulo)
	var base := Basis.from_euler(rotacao_graus * (PI / 180.0))
	var nova_base := (giro * base).orthonormalized()
	var nova_posicao := centro + giro * (posicao - centro)
	var graus := nova_base.get_euler() * (180.0 / PI)
	return [nova_posicao, DocumentoMapa.normalizar_rotacao(graus)]


## Estica a peça pela FACE (`eixo_local` 0/1/2, `sinal` ±1) mantendo a face oposta
## parada, como no Roblox Studio. Devolve [nova_posicao, novo_tamanho].
static func esticar_face(p: Dictionary, eixo_local: int, sinal: int, delta: float) -> Array:
	var tamanho: Vector3 = p["tamanho"]
	var pedido := tamanho
	pedido[eixo_local] = tamanho[eixo_local] + delta
	var novo := DocumentoMapa.normalizar_tamanho(p["tipo"], pedido, eixo_local)
	var real: float = novo[eixo_local] - tamanho[eixo_local]
	var base := Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0))
	var nova_posicao: Vector3 = p["posicao"] + base[eixo_local].normalized() * (sinal * real * 0.5)
	return [nova_posicao, novo]


static func _perpendicular(normal: Vector3) -> Vector3:
	var candidato := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	return normal.cross(candidato).normalized()
