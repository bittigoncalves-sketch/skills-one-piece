class_name AssetsDeTecnica
extends RefCounted
## O ASSET 3D de cada técnica das logias do fluxo do mod (24/11/2026, pedido do dono): em vez do plano cruzado genérico do mod, o projétil
## nasce com o modelo feito no Blender (`tools/blender/logias_assets.py` → `assets/mine_piece/frutas/logias_mod/modelos/*.glb`), com a textura do
## elemento (areia, madeira, magma…), e voa/dispara como o projétil de sempre: o dano, a hitbox e o movimento continuam sendo do mod — só o desenho muda.
## Ex.: Suna Suna · Desert Dagger = uma adaga de areia que é disparada.
##
## Como liga: `McTipoEntidade.create` chama `aplicar` logo depois de criar o corpo; a chave é `fruta|técnica em execução|entidade`. A técnica em execução
## vem do controlador (`tecnica_em_execucao`, que enxerga a sessão paralela que está rodando). Sem entrada na tabela, nada muda.
## ORIENTAÇÃO: o +Y do corpo vai para a velocidade (`mc_alinhar_y`); os .glb têm a PONTA em +Y do Godot. ESCALA: 1 unidade do asset = 1 bloco.
const PASTA := "res://assets/mine_piece/frutas/logias_mod/modelos/"
## "fruta|numero|entidade" → {"glb", "escala" (multiplica o asset), "tamanho_do_mod" (segue o atributo SIZE do mod)}
const TABELA := {
	"suna_suna|21|projectile_slash": {"glb": "suna_adaga", "escala": 0.8, "tamanho_do_mod": false},
	"suna_suna|24|projectile_slash": {"glb": "suna_adaga", "escala": 1.6, "tamanho_do_mod": false},
	"suna_suna|22|entity_slash": {"glb": "suna_cimitarra", "escala": 1.4, "tamanho_do_mod": false},
	"mera_mera|25|projectile_flame": {"glb": "mera_bola_de_fogo", "escala": 0.8, "tamanho_do_mod": false},
	"mera_mera|22|fist": {"glb": "mera_punho", "escala": 1.2, "tamanho_do_mod": false},
	"mera_mera|26|entity_flame_ball": {"glb": "mera_sol", "escala": 2.0, "tamanho_do_mod": false},
	"magu_magu|22|entity_dog_head": {"glb": "magu_cao", "escala": 1.6, "tamanho_do_mod": false},
	"yami_yami|28|entity_dark_ball": {"glb": "yami_esfera", "escala": 2.4, "tamanho_do_mod": false},
	"magu_magu|21|entity_dai_funka": {"glb": "magu_rocha", "escala": 1.2, "tamanho_do_mod": false},
	"magu_magu|24|entity_dai_funka": {"glb": "magu_rocha", "escala": 1.8, "tamanho_do_mod": false},
	"yami_yami|23|entity_ball": {"glb": "yami_esfera", "escala": 1.0, "tamanho_do_mod": false},
	"mori_mori|22|tree_root": {"glb": "mori_estaca", "escala": 1.4, "tamanho_do_mod": false},
	"mori_mori|24|tree_root": {"glb": "mori_estaca", "escala": 1.0, "tamanho_do_mod": false},
}
static var _cenas := {}


## Põe a PONTA (+Y) do `no` na direção `para` (ignora direção nula).
static func orientar_y(no: Node3D, para: Vector3) -> void:
	if para.length_squared() < 0.0001:
		return
	para = para.normalized()
	var eixo := Vector3.UP.cross(para)
	no.basis = Basis(eixo.normalized(), Vector3.UP.angle_to(para)) if eixo.length_squared() > 0.000001 \
		else (Basis.IDENTITY if para.y > 0.0 else Basis(Vector3.RIGHT, PI))


## Instancia um asset por nome (sem aplicar em corpo nenhum): quem tem executor próprio (a flecha de luz da Pika) o usa direto. Escala em blocos.
static func instanciar(nome: String, escala := 1.0) -> Node3D:
	var caminho := PASTA + nome + ".glb"
	if not ResourceLoader.exists(caminho):
		return null
	if not _cenas.has(caminho):
		_cenas[caminho] = load(caminho)
	var asset := (_cenas[caminho] as PackedScene).instantiate() as Node3D
	asset.name = "Asset"
	asset.scale = Vector3.ONE * MundoMinePiece.METROS_POR_BLOCO * escala
	return asset


static func chave(fruta_id: String, numero: int, entidade: String) -> String:
	return "%s|%d|%s" % [fruta_id, numero, entidade]


static func existe(fruta_id: String, numero: int, entidade: String) -> bool:
	var f: Dictionary = TABELA.get(chave(fruta_id, numero, entidade), {})
	return not f.is_empty() and ResourceLoader.exists(PASTA + str(f.glb) + ".glb")


## Troca o desenho do corpo `corpo` (um `McCorpoDoMod`) pelo asset da técnica que o jogador `jogador` está executando. Devolve se trocou.
static func aplicar(corpo: Node, entidade: String, jogador: Node) -> bool:
	if not is_instance_valid(corpo) or not is_instance_valid(jogador) or not corpo.has_method("trocar_desenho"):
		return false
	var ctl := jogador.get_node_or_null("FrutaMinePiece")
	if ctl == null or not ctl.has_method("tecnica_em_execucao"):
		return false
	var fruta := str(jogador.get("current_fruit_id"))
	var numero: int = ctl.tecnica_em_execucao()
	var f: Dictionary = TABELA.get(chave(fruta, numero, entidade), {})
	if f.is_empty():
		return false
	var caminho := PASTA + str(f.glb) + ".glb"
	if not ResourceLoader.exists(caminho):
		return false
	if not _cenas.has(caminho):
		_cenas[caminho] = load(caminho)
	var asset := (_cenas[caminho] as PackedScene).instantiate() as Node3D
	asset.name = "Asset"
	asset.scale = Vector3.ONE * MundoMinePiece.METROS_POR_BLOCO * float(f.escala)
	var envoltorio := Node3D.new()
	envoltorio.name = "Desenho"
	envoltorio.set_meta(McVisual.META_FIXO, true)        # a textura é a do asset, não a de `setTexture`
	envoltorio.set_meta(&"mc_alinhar_y", true)            # a ponta (+Y) acompanha a velocidade
	if bool(f.get("tamanho_do_mod", false)):
		envoltorio.set_meta(&"mc_escala_size", true)
	envoltorio.add_child(asset)
	# Antes da primeira velocidade o projétil parado apontava o +Y para o céu (a adaga nascia em pé sobre a cabeça): já nasce apontando para a mira.
	orientar_y(envoltorio, ctl.olhar() if ctl.has_method("olhar") else Vector3.ZERO)
	corpo.trocar_desenho(envoltorio)
	return true
