class_name PerfilGrafico
extends Node
# ============================================================================
#  PERFIL GRÁFICO — modo ECONOMIA do Modo História (30/10/2026).
#
#  Pedido do dono: desenhar menos, para aparelhos fracos e PC em economia de bateria. A medição
#  (tools/dev_tests/medir_desempenho_historia.gd, meio-dia, mesma cena) mostrou que o motor já
#  corta o que está fora do cone da câmera, e que o custo está em outro lugar:
#    • a sombra do sol (4 cascatas) responde por 65–90 % das chamadas de desenho e ~65 % das primitivas;
#    • objetos que ocupam poucos pixels ainda geram uma chamada de desenho cada.
#  Perfil LEVE (escolhido pelo dono; nada disso vale no modo NORMAL, que fica como era):
#    1. sombra do sol e da lua com 2 cascatas (era 4);
#    2. objetos do mapa que ocupariam menos de `PIXELS_MINIMOS` pixels somem (alcance de visibilidade
#       pelo tamanho do objeto e pelo tamanho da janela; nunca mexe em quem já tem alcance próprio,
#       em malha com esqueleto, nem em MultiMesh que cobre uma ilha inteira — o tamanho dele é enorme).
#  Medido (RTX 3050, 960×540): chamadas de desenho −52 a −67 %, primitivas −30 %, CPU de render −32 a −44 %.
#
#  ATIVAÇÃO: AUTOMÁTICO (padrão) liga sozinho com o notebook na bateria e volta na tomada; NORMAL e
#  ECONOMIA forçam. A escolha é do APARELHO (user://perfil_grafico.cfg), não do personagem.
#  Bateria: o Godot 4 não tem API; no Linux lê /sys/class/power_supply. Em Windows/macOS o automático
#  fica em NORMAL (gatilho: se um dono jogar lá, ler a energia pelo sistema).
#  Em headless o automático nunca liga (testes não dependem de a máquina estar na bateria).
#
#  O que NÃO faz: descarregar da memória nem pausar simulação (decisão do dono: só deixar de desenhar).
#  Pop-in: objetos pequenos aparecem de repente ao chegar perto; o alcance usa folga de 5 m contra pisca.
# ============================================================================

enum Modo { AUTO, NORMAL, ECONOMIA }

const ARQUIVO := "user://perfil_grafico.cfg"
const GRUPO := &"perfil_grafico"
const PIXELS_MINIMOS := 2.5
const ALCANCE_MINIMO := 30.0
const FOLGA := 5.0
const INTERVALO := 2.0
const META_CORTADO := &"pg_cortado"
const FOV_PADRAO := 75.0

static var modo: int = Modo.AUTO
static var _lido := false

## Quem diz se o aparelho está na bateria. Troca-se nos testes.
var na_bateria: Callable = PerfilGrafico.bateria_do_sistema
## Em headless o automático nunca liga; só um teste do automático desliga esta guarda.
var respeitar_headless := true
## Onde moram as peças do mapa (o corte só olha aqui).
var raiz_do_mapa: Node
var economia := false
var _sombras_originais := {}      # DirectionalLight3D -> modo de sombra de antes
var _altura_usada := -1
var _tempo := 0.0


func _ready() -> void:
	add_to_group(GRUPO)
	carregar_uma_vez()
	reavaliar()


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= INTERVALO:
		_tempo = 0.0
		reavaliar()


# ------------------------------------------------------------- escolha do aparelho
static func carregar_uma_vez() -> void:
	if _lido:
		return
	_lido = true
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) == OK:
		modo = clampi(int(cfg.get_value("grafico", "modo", Modo.AUTO)), Modo.AUTO, Modo.ECONOMIA)


## O jogador escolheu: grava no aparelho e avisa quem está em jogo.
static func definir_modo(novo: int, arvore: SceneTree = null) -> void:
	modo = clampi(novo, Modo.AUTO, Modo.ECONOMIA)
	_lido = true
	var cfg := ConfigFile.new()
	cfg.set_value("grafico", "modo", modo)
	cfg.save(ARQUIVO)
	if arvore != null:
		for no in arvore.get_nodes_in_group(GRUPO):
			(no as PerfilGrafico).reavaliar()


## Linux: alguma bateria descarregando. Outros sistemas: falso (ver o cabeçalho).
static func bateria_do_sistema() -> bool:
	if OS.get_name() != "Linux":
		return false
	var base := "/sys/class/power_supply"
	for nome in DirAccess.get_directories_at(base):
		var pasta := "%s/%s" % [base, nome]
		if FileAccess.get_file_as_string(pasta + "/type").strip_edges() == "Battery" \
				and FileAccess.get_file_as_string(pasta + "/status").strip_edges() == "Discharging":
			return true
	return false


func deve_economizar() -> bool:
	match modo:
		Modo.ECONOMIA:
			return true
		Modo.NORMAL:
			return false
	return not (respeitar_headless and DisplayServer.get_name() == "headless") and bool(na_bateria.call())


# ---------------------------------------------------------------------- aplicar
## Compara o que deveria valer agora com o que está valendo e só mexe se mudou (ou se a janela mudou de altura).
func reavaliar() -> void:
	var quer := deve_economizar()
	if quer == economia and not (economia and _altura_usada != _altura_da_janela()):
		return
	economia = quer
	_sombras(economia)
	if economia:
		_altura_usada = _altura_da_janela()
		cobrir(raiz_do_mapa)
	else:
		_restaurar(raiz_do_mapa)
		_altura_usada = -1


## Chamado também quando uma ilha acaba de ser montada (as peças dela são novas).
func cobrir(raiz: Node) -> int:
	if not economia or raiz == null:
		return 0
	var k := _pixels_por_metro_unitario() / PIXELS_MINIMOS
	var n := 0
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if not (no is MeshInstance3D or no is MultiMeshInstance3D):
			continue
		var gi := no as GeometryInstance3D
		var ja_cortado := gi.has_meta(META_CORTADO)
		if gi.visibility_range_end > 0.0 and not ja_cortado:
			continue                                   # alcance próprio (fundo do mar, cardumes…): não é nosso
		if no is MeshInstance3D and ((no as MeshInstance3D).skin != null or no.get_parent() is Skeleton3D):
			continue                                   # malha com esqueleto: o AABB de repouso engana
		var diagonal := (gi.get_aabb().size * (gi.global_transform.basis.get_scale().abs())).length()
		gi.visibility_range_end = maxf(diagonal * k, ALCANCE_MINIMO)
		gi.visibility_range_end_margin = FOLGA
		gi.set_meta(META_CORTADO, true)
		n += 1
	return n


func _restaurar(raiz: Node) -> void:
	if raiz == null:
		return
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if no is GeometryInstance3D and no.has_meta(META_CORTADO):
			(no as GeometryInstance3D).visibility_range_end = 0.0
			(no as GeometryInstance3D).visibility_range_end_margin = 0.0
			no.remove_meta(META_CORTADO)


## Sol e lua (a lua é criada pelo ciclo dia/noite ao lado do sol). Guarda o modo original na primeira vez.
func _sombras(ligar: bool) -> void:
	var cena := get_tree().current_scene if is_inside_tree() else null
	if cena == null:
		return
	for nome in ["Sol", "Lua"]:
		var luz := cena.get_node_or_null(nome) as DirectionalLight3D
		if luz == null:
			continue
		if not _sombras_originais.has(luz):
			_sombras_originais[luz] = luz.directional_shadow_mode
		luz.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if ligar else _sombras_originais[luz]


## Pixels que 1 metro ocupa a 1 metro de distância, na altura da janela e no campo de visão da câmera.
func _pixels_por_metro_unitario() -> float:
	var fov := FOV_PADRAO
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		fov = cam.fov
	return float(_altura_da_janela()) / (2.0 * tan(deg_to_rad(fov) * 0.5))


func _altura_da_janela() -> int:
	return get_window().size.y if is_inside_tree() else 720
