extends RefCounted
## LANÇADOR DE TESTE DE ILHA (18/10/2026). Pedido do dono: "trazer o jogador para a última
## ilha feita com a habilidade de pulo no ar e o dash, bem como a fruta da luz equipada e
## respawn nessa nova ilha, para testes". Decisão dele: lançador SEPARADO, save de teste
## próprio, fruta Pika Pika original (`pika_pika`).
##
##   ./jogar_teste_ilha.sh [--ilha=<id>] [--nivel=<n>]
##
## A ilha padrão é a ÚLTIMA do cadastro (`Ilhas.TABELA`): ilha nova entra no fim e o teste
## a segue sem mudar nada aqui. O progresso de teste é refeito a cada abertura — o save
## real (`ModoHistoria.PROGRESSO_PADRAO`) não é lido nem gravado.

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const MODO := "res://src/historia/ModoHistoria.gd"
const PROGRESSO := "user://teste_de_ilha/progresso.json"
const FRUTA := "pika_pika"


## Ilha escolhida pelos argumentos (`--ilha=<id>`) ou a última do cadastro.
static func ilha(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--ilha="):
			return a.trim_prefix("--ilha=")
	return str(Ilhas.TABELA.keys().back())


## Grava o progresso de teste e arma o Modo História. Devolve "" ou o erro.
static func preparar(args: PackedStringArray) -> String:
	var id := ilha(args)
	if not Ilhas.existe(id):
		return "ilha desconhecida: %s (há: %s)" % [id, ", ".join(Ilhas.TABELA.keys())]
	var prog := ProgressaoDoPersonagem.new()
	prog.desbloquear("dash")
	prog.desbloquear("pulo_duplo")
	prog.comer_fruta(FRUTA)
	prog.visitar(id)
	for a in args:
		if a.begins_with("--nivel=") and a.trim_prefix("--nivel=").is_valid_int():
			prog.nivel = clampi(a.trim_prefix("--nivel=").to_int(), 1, 1000000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROGRESSO.get_base_dir()))
	var erro := prog.salvar(PROGRESSO)
	if erro != OK:
		return "não salvou o progresso de teste: %s" % error_string(erro)
	var modo = load(MODO)
	modo.set("progresso_forcado", PROGRESSO)
	modo.set("ilha_de_teste", id)
	return ""
