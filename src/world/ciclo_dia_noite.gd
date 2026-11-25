class_name CicloDiaNoite
extends Node
signal tempo_passou(dias: float)
# ============================================================================
#  CICLO DE DIA E NOITE DO MODO HISTÓRIA (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#  Pedido do dono: "adição de ciclo de dia e noite, lembrando que à noite o jogador deve
#  ver normalmente — não escureça demais o mapa a ponto de impedir a visão". Escolha
#  dele: dia completo = 24 min reais (1 min = 1 h do jogo).
#
#  O QUE MUDA COM A HORA (tudo a partir do que o `WorldEnv` montou, que é o MEIO-DIA):
#    • o SOL anda de leste a oeste (nasce às 6 h, se põe às 18 h); de noite a LUA
#      (uma segunda luz direcional, fria) faz o papel dele — só um dos dois projeta
#      sombra por vez;
#    • o CÉU: azul de dia, laranja/rosa no amanhecer e no entardecer, azul-marinho com
#      ESTRELAS à noite; o disco do céu vira a lua;
#    • ambiente, névoa, luz de contorno e exposição acompanham.
#  NOITE LEGÍVEL (o pedido): a noite é AZUL, não preta — o ambiente fica até mais forte
#  que de dia (0,7 contra 0,55), a lua ilumina e a exposição sobe. Medido em
#  `test_ciclo_dia_noite`: a cena à meia-noite tem que guardar ≥ 45 % da luz do meio-dia.
#
#  Começa às 8 h em cada sessão (a hora não vai para o save). F8 › "Avançar 3 h".
# ============================================================================

## Segundos reais de um dia inteiro.
const DURACAO_DO_DIA := 24.0 * 60.0
const HORA_INICIAL := 8.0
const ELEVACAO_SOL := 52.0          # graus ao meio-dia (a do WorldEnv)
const AZIMUTE_SOL := -130.0         # graus ao meio-dia (a do WorldEnv)
const ELEVACAO_LUA := 44.0

## Paletas-chave por hora. Entre duas chaves, interpolação suave.
const DIA := {
	"topo": Color(0.13, 0.45, 0.90), "horizonte": Color(0.66, 0.86, 0.99), "chao": Color(0.20, 0.28, 0.38),
	"nuvem_luz": Color(1.0, 0.99, 0.95), "nuvem_sombra": Color(0.60, 0.69, 0.85),
	"sol": Color(1.0, 0.93, 0.78), "sol_energia": 1.75, "lua_energia": 0.0,
	"ambiente": Color(0.42, 0.55, 0.78), "ambiente_energia": 0.55,
	"nevoa": Color(0.62, 0.78, 0.94), "contra": Color(0.62, 0.78, 1.0), "contra_energia": 0.55,
	"exposicao": 0.92, "estrelas": 0.0,
}
const CREPUSCULO := {
	"topo": Color(0.22, 0.30, 0.62), "horizonte": Color(1.0, 0.64, 0.42), "chao": Color(0.26, 0.22, 0.30),
	"nuvem_luz": Color(1.0, 0.76, 0.58), "nuvem_sombra": Color(0.52, 0.42, 0.60),
	"sol": Color(1.0, 0.62, 0.38), "sol_energia": 1.15, "lua_energia": 0.0,
	"ambiente": Color(0.56, 0.52, 0.66), "ambiente_energia": 0.6,
	"nevoa": Color(0.86, 0.66, 0.56), "contra": Color(0.55, 0.62, 0.98), "contra_energia": 0.5,
	"exposicao": 0.98, "estrelas": 0.15,
}
const NOITE := {
	"topo": Color(0.035, 0.07, 0.19), "horizonte": Color(0.14, 0.23, 0.42), "chao": Color(0.07, 0.09, 0.15),
	"nuvem_luz": Color(0.46, 0.54, 0.74), "nuvem_sombra": Color(0.17, 0.22, 0.36),
	"sol": Color(0.70, 0.79, 1.0), "sol_energia": 0.0, "lua_energia": 0.75,
	"ambiente": Color(0.42, 0.52, 0.86), "ambiente_energia": 0.7,
	"nevoa": Color(0.2, 0.29, 0.46), "contra": Color(0.52, 0.64, 1.0), "contra_energia": 0.45,
	"exposicao": 1.15, "estrelas": 1.0,
}
## [hora, paleta] em ordem; 0 h e 24 h iguais.
var _chaves := [[0.0, NOITE], [4.8, NOITE], [6.0, CREPUSCULO], [7.4, DIA], [16.8, DIA],
	[18.2, CREPUSCULO], [19.6, NOITE], [24.0, NOITE]]

## Hora do jogo, 0–24.
var hora := HORA_INICIAL
## Parado (testes e fotos): a hora só muda por `definir_hora`/`avancar`.
var pausado := false
var hud_de_pausa: Node = null

var _sol: DirectionalLight3D
var _lua: DirectionalLight3D
var _contra: DirectionalLight3D
var _ambiente: Environment
var _ceu: ShaderMaterial


func _ready() -> void:
	name = "CicloDiaNoite"
	add_to_group("ciclo_dia_noite")


## Acha o que o `WorldEnv.apply(cena)` montou e cria a lua. Chamar logo depois dele.
func ligar(cena: Node) -> void:
	_sol = cena.get_node_or_null("Sol") as DirectionalLight3D
	_contra = cena.get_node_or_null("LuzDeContra") as DirectionalLight3D
	var we := cena.get_node_or_null("Ambiente") as WorldEnvironment
	_ambiente = we.environment if we != null else null
	if _ambiente != null and _ambiente.sky != null:
		_ceu = _ambiente.sky.sky_material as ShaderMaterial
	if _sol != null:
		_lua = DirectionalLight3D.new()
		_lua.name = "Lua"
		_lua.light_color = NOITE["sol"]
		_lua.light_energy = 0.0
		_lua.shadow_enabled = false
		_lua.shadow_blur = _sol.shadow_blur
		_lua.shadow_opacity = 0.85
		_lua.directional_shadow_max_distance = _sol.directional_shadow_max_distance
		_sol.get_parent().add_child(_lua)
	aplicar()


func _process(delta: float) -> void:
	if pausado or (is_instance_valid(hud_de_pausa) and hud_de_pausa.is_menu_open()):
		return
	tempo_passou.emit(delta / DURACAO_DO_DIA)
	hora = fposmod(hora + delta * 24.0 / DURACAO_DO_DIA, 24.0)
	aplicar()


func definir_hora(h: float) -> void:
	hora = fposmod(h, 24.0)
	aplicar()


func avancar(horas: float) -> void:
	tempo_passou.emit(maxf(horas, 0.0) / 24.0)
	definir_hora(hora + horas)


## "06:30"
func texto_da_hora() -> String:
	return "%02d:%02d" % [int(hora), int(fmod(hora, 1.0) * 60.0)]


## É noite (lua manda)?
func noite() -> bool:
	return paleta()["lua_energia"] > paleta()["sol_energia"]


## A paleta de agora (interpolada entre as chaves).
func paleta() -> Dictionary:
	for i in _chaves.size() - 1:
		var a: Array = _chaves[i]
		var b: Array = _chaves[i + 1]
		if hora >= float(a[0]) and hora <= float(b[0]):
			var t := smoothstep(float(a[0]), float(b[0]), hora)
			return _misturar(a[1], b[1], t)
	return NOITE


static func _misturar(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var saida := {}
	for k in a:
		var va: Variant = a[k]
		var vb: Variant = b[k]
		saida[k] = (va as Color).lerp(vb, t) if va is Color else lerpf(float(va), float(vb), t)
	return saida


## Direção PARA o astro (o +Z da luz) e o giro da luz, por elevação/azimute em graus.
static func _giro(elevacao: float, azimute: float) -> Vector3:
	return Vector3(deg_to_rad(-elevacao), deg_to_rad(azimute), 0.0)


func aplicar() -> void:
	var p := paleta()
	# Sol: arco das 6 h às 18 h; abaixo do horizonte não ilumina.
	var arco := (hora - 6.0) / 12.0
	var elev_sol := ELEVACAO_SOL * sin(PI * arco)
	var az_sol := AZIMUTE_SOL + (hora - 12.0) * 12.0
	var elev_lua := ELEVACAO_LUA * sin(PI * ((fposmod(hora + 12.0, 24.0) - 6.0) / 12.0))
	var az_lua := AZIMUTE_SOL + 180.0 + (fposmod(hora + 12.0, 24.0) - 12.0) * 12.0
	if _sol != null:
		_sol.rotation = _giro(maxf(elev_sol, 4.0), az_sol)
		_sol.light_color = p["sol"] if p["sol_energia"] > 0.0 else DIA["sol"]
		_sol.light_energy = float(p["sol_energia"]) * smoothstep(-2.0, 6.0, elev_sol)
		_sol.visible = _sol.light_energy > 0.005
	if _lua != null:
		_lua.rotation = _giro(maxf(elev_lua, 8.0), az_lua)
		_lua.light_energy = float(p["lua_energia"]) * smoothstep(-2.0, 8.0, elev_lua)
		_lua.visible = _lua.light_energy > 0.005
		# Uma sombra por vez: quem ilumina mais.
		var sol_manda := _sol == null or _sol.light_energy >= _lua.light_energy
		if _sol != null:
			_sol.shadow_enabled = sol_manda
		_lua.shadow_enabled = not sol_manda
	if _contra != null:
		_contra.light_color = p["contra"]
		_contra.light_energy = p["contra_energia"]
	if _ambiente != null:
		_ambiente.ambient_light_color = p["ambiente"]
		_ambiente.ambient_light_energy = p["ambiente_energia"]
		_ambiente.fog_light_color = p["nevoa"]
		_ambiente.tonemap_exposure = p["exposicao"]
	if _ceu != null:
		_ceu.set_shader_parameter("cor_topo", p["topo"])
		_ceu.set_shader_parameter("cor_horizonte", p["horizonte"])
		_ceu.set_shader_parameter("cor_chao_horizonte", p["chao"])
		_ceu.set_shader_parameter("cor_nuvem_luz", p["nuvem_luz"])
		_ceu.set_shader_parameter("cor_nuvem_sombra", p["nuvem_sombra"])
		_ceu.set_shader_parameter("estrelas", p["estrelas"])
		# O disco do céu: o sol de dia, a lua (menor, pálida, halo curto) de noite.
		var de_noite := noite()
		var astro: DirectionalLight3D = _lua if de_noite and _lua != null else _sol
		if astro != null:
			_ceu.set_shader_parameter("dir_sol", astro.global_transform.basis.z.normalized()
				if astro.is_inside_tree() else Basis.from_euler(astro.rotation).z.normalized())
		_ceu.set_shader_parameter("cor_sol", Color(0.85, 0.9, 1.0) if de_noite else p["sol"])
		_ceu.set_shader_parameter("raio_sol", 1.9 if de_noite else 2.6)
		_ceu.set_shader_parameter("forca_halo", 0.22 if de_noite else 0.55)
