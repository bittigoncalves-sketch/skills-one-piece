extends SceneTree
## API física das ondas e orçamento/vida da espuma usada pelos barcos reais.
const Oceano := preload("res://src/world/oceano_historia.gd")
const Esteira := preload("res://src/historia/navios/esteira.gd")
var falhas := 0

func _initialize() -> void:
	_executar.call_deferred()

func verificar(condicao: bool, mensagem: String) -> void:
	print(("PASS " if condicao else "FAIL ") + mensagem)
	if not condicao:
		falhas += 1

func _executar() -> void:
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	var oceano := Oceano.new()
	root.add_child(oceano)
	oceano.configurar(mapa)
	oceano.set_physics_process(false)
	AguaDoMundo.registrar(mapa, oceano)
	oceano.material.set_shader_parameter("tempo_fixo", 2.0)
	var media := AguaDoMundo.nivel_em(300, 0)
	var h := AguaDoMundo.superficie_em(300, 0)
	verificar(not is_equal_approx(h, media), "superfície de barco inclui onda acima/abaixo da linha média")
	verificar(is_nan(AguaDoMundo.superficie_em(0, 0)), "ilha não vira superfície navegável")
	verificar(AguaDoMundo.normal_em(300, 0).is_normalized(), "normal unitária para orientação do casco")
	oceano._physics_process(10.0)
	verificar(is_equal_approx(h, AguaDoMundo.superficie_em(300, 0)), "tempo_fixo mantém captura e flutuação sincronizadas")
	verificar(is_equal_approx(float(oceano.material.get_shader_parameter("tempo_simulado")), 10.0), "shader recebe o mesmo relógio da física")
	oceano.material.set_shader_parameter("tempo_fixo", -1.0)
	verificar(not is_equal_approx(h, AguaDoMundo.superficie_em(300, 0)), "relógio simulado movimenta as ondas")
	oceano.material.set_shader_parameter("velocidade", 0.0)
	h = AguaDoMundo.superficie_em(300, 0)
	oceano._physics_process(7.0)
	verificar(is_equal_approx(h, AguaDoMundo.superficie_em(300, 0)), "velocidade zero congela ondas físicas e visuais")
	oceano.material.set_shader_parameter("altura_ondas", 0.0)
	verificar(is_equal_approx(media, AguaDoMundo.superficie_em(300, 0)) and AguaDoMundo.normal_em(300, 0).is_equal_approx(Vector3.UP), "mar sem onda mantém linha média e normal vertical")
	verificar(is_equal_approx(AguaDoMundo.nivel_em(300, 0), media), "nado/animais preservam contrato do nível plano")
	var esteira := Esteira.new()
	root.add_child(esteira)
	esteira.configurar(3.0, 8.0)
	var nos := esteira.get_child_count()
	for i in 600:
		esteira.atualizar(Vector3(300, media, -float(i) / 10.0), Vector3.FORWARD, 6.0, 1.0 / 60.0, true)
	verificar(esteira._marcas.size() <= Esteira.MAX_MARCAS and esteira._marcas.size() > 20, "10 s de navegação mantém orçamento fixo de espuma")
	verificar(esteira.get_child_count() == nos and nos == 1, "rastro reusa uma malha sem criar nós por frame")
	verificar(esteira._vertices.size() > 0 and esteira._vertices.size() <= 1200, "espuma gera geometria limitada (máximo 400 triângulos)")
	for i in 300:
		esteira.atualizar(Vector3(300, media, -60), Vector3.FORWARD, 0.0, 1.0 / 60.0, true)
	verificar(esteira._marcas.is_empty() and esteira._malha.get_surface_count() == 0, "parado dissipa espuma em até 5 s")
	for i in 120:
		esteira.atualizar(Vector3(0, 2, 0), Vector3.FORWARD, 6.0, 1.0 / 60.0, false)
	verificar(esteira._marcas.is_empty() and esteira._malha.get_surface_count() == 0, "barco seco não emite espuma")
	esteira.free()
	AguaDoMundo.esquecer()
	oceano.free()
	print("ONDAS_BARCOS_RESULTADO falhas=", falhas)
	quit(1 if falhas else 0)
