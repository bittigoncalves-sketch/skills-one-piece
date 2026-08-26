class_name Contorno
extends MeshInstance3D
# ============================================================================
#  O NÓ DO CONTORNO — Fase 2 de docs/PLANO_VISUAL.md
#
#  Um quad que cobre a tela e desenha a silhueta escura por cima de tudo. A
#  matemática mora em `src/fx/shaders/contorno.gdshader`; aqui ficam o ciclo de
#  vida, a escala por dispositivo e as duas armadilhas de montagem.
#
#  ⚠️ ARMADILHA 1 — CULLING. O `vertex()` do shader manda o quad para a tela
#  inteira sobrescrevendo `POSITION`, mas o Godot decide se DESENHA o nó pela
#  AABB dele, que continua sendo a de um quad de 2×2 na origem. Andando dez
#  metros para o lado, o quad sai do tronco de visão, é descartado e o contorno
#  SOME — sem erro nenhum. `custom_aabb` gigante resolve.
#
#  ⚠️ ARMADILHA 2 — ORDEM. Ele precisa ser desenhado depois da cena (para ler a
#  profundidade dela) e antes de mais nada: `render_priority` alto, e no shader
#  `depth_test_disabled` + `depth_draw_never`, senão ele se esconde atrás do
#  cenário ou entra no buffer e atrapalha quem vier depois.
# ============================================================================

const CAMINHO_SHADER := "res://src/fx/shaders/contorno.gdshader"

# Espessura em pixels por dispositivo. No celular a tela é menor em pixels
# físicos, e a mesma espessura lê mais grossa — daí ser MENOR, não maior.
const ESPESSURA := {"celular": 1.0, "tablet": 1.15, "pc": 1.3}


static func criar(parent: Node) -> Contorno:
	if not ResourceLoader.exists(CAMINHO_SHADER):
		push_warning("[Contorno] shader ausente: " + CAMINHO_SHADER)
		return null
	var c := Contorno.new()
	c.name = "Contorno"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	c.mesh = q

	var mat := ShaderMaterial.new()
	mat.shader = load(CAMINHO_SHADER)
	mat.render_priority = 90
	c.material_override = mat

	# Ver a armadilha 1 do cabeçalho.
	c.custom_aabb = AABB(Vector3(-100000, -100000, -100000), Vector3(200000, 200000, 200000))
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.extra_cull_margin = 16384.0

	parent.add_child(c)
	c._ajustar_ao_dispositivo()
	return c


func _ajustar_ao_dispositivo() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	var disp := "pc"
	if is_inside_tree():
		var gf := get_tree().root.get_node_or_null("GameFlow")
		if gf != null:
			disp = str(gf.get("device"))
	mat.set_shader_parameter("espessura", ESPESSURA.get(disp, 1.3))
	# No celular o contorno de vinco sai inteiro: é o que custa mais amostras e
	# o que menos se enxerga numa tela pequena.
	if disp == "celular":
		mat.set_shader_parameter("peso_normal", 0.0)


## Liga/desliga sem tirar da árvore — serve para a sonda de medição comparar
## o mesmo quadro com e sem linha.
func ligado(v: bool) -> void:
	visible = v
