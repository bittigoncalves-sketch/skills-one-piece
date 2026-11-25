class_name McAliadoDoMod
extends RefCounted
## CRIATURAS INVOCADAS PELAS FRUTAS COM CORPO DE VERDADE (10/11/2026, pedido do dono: "a fruta do biscoito gera aliados e eles não
## estão interativos"). `EntityType.create` devolvia um `McCorpoDoMod` — corpo virtual, sem colisão, sem hurtbox, sem metas
## (MeleeAttackGoal / alvos): o guerreiro de biscoito nascia, ficava parado e nada o via nem ele via nada.
## Aqui a criatura invocada nasce como `PersonagemMinePiece` (cápsula, hurtbox, modelo do mod, `CerebroMinePiece` que persegue e
## ataca, `IaDoMod` com o `tick` dela), com ficha montada dos DADOS do mod (atributos de `entidades_do_mod.json` + dimensões
## `.sized(l, a)` de `MinepieceModEntities.java`, em blocos de 0,88 m). Quem manda nela é o dono do mod:
## `SetSummonedEntityProcedure` grava OWNER_UUID/Player; este módulo só liga o corpo ao dono (segue, é alvo dos inimigos).
##
## Só as invocações abaixo (as que as 40 frutas criam). GATILHO: ampliar a tabela quando outra entidade de `base` Monster/Pathfinder
## com `metas` for criada por procedure e ficar parada — medir com a sonda `tools/dev_tests/sonda_aliados_do_mod.gd`.

const GRUPO := "invocados_do_mod"            # toda criatura invocada
const GRUPO_DO_JOGADOR := "invocados_do_jogador"   # as que têm o jogador como dono (aliadas dele)
## Aliados que custam 1 BISCOITO cada (pedido do dono, 10/11/2026): o jogador cria biscoitos com a técnica Biscuit do Bisu Bisu e cada
## guerreiro invocado gasta um. Sem biscoito suficiente o guerreiro não nasce.
const CUSTO_EM_ITEM := {"biscuit_warrrior": ItensDoMod.BISCOITO}

## id → [largura, altura] em BLOCOS (`m_20699_` no registro Java).
const DIMENSOES := {
	"biscuit_warrrior": Vector2(1.8, 3.6),       # Bisu Bisu
	"entity_doppelman": Vector2(0.6, 1.8),       # Kage Kage
	"entity_mini_hollow": Vector2(0.6, 1.2),     # Horo Horo
	"entity_negative_hollow": Vector2(0.6, 1.6),
	"note_warrior_1": Vector2(0.6, 1.8),         # Uta Uta
	"note_warrior_2": Vector2(0.6, 1.8),
	"entity_muso_donatsu": Vector2(0.6, 1.8),    # Mochi Mochi
}


## As rosquinhas do Mochi Mochi (Muso Donatsu) são um anel de 4 caixas de textura cinza-clara; sob a luz azul do céu liam como blocos AZUIS. Creme de mochi com um
## leve brilho próprio para ler como a massa branca do anime em qualquer hora do dia. Só visual (15/11/2026).
static func _tingir_de_mochi(corpo: Node) -> void:
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(1.0, 0.93, 0.82)
	tinta.roughness = 0.85
	tinta.emission_enabled = true
	tinta.emission = Color(1.0, 0.9, 0.75)
	tinta.emission_energy_multiplier = 0.45
	for m in corpo.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = tinta


static func e_invocavel(id: String) -> bool:
	return DIMENSOES.has(id)


## Limite de guerreiros de biscoito vivos no mapa (pedido do dono, 10/11/2026): passando de 6, cada novo (C ou V) apaga o MAIS ANTIGO.
const MAXIMO_DE_GUERREIROS := 6
static var _sequencia := 0


## Abre vaga para UM guerreiro novo: enquanto houver `MAXIMO_DE_GUERREIROS` ou mais vivos, apaga o mais antigo.
static func abrir_vaga(id: String, arvore: SceneTree) -> void:
	if id != "biscuit_warrrior" or arvore == null:
		return
	while true:
		var vivos: Array = []
		for f in arvore.get_nodes_in_group(GRUPO):
			if is_instance_valid(f) and not f.is_queued_for_deletion() and id_de(f) == id and f.has_method("vivo") and f.vivo():
				vivos.append(f)
		if vivos.size() < MAXIMO_DE_GUERREIROS:
			return
		var velho: Node = vivos[0]
		for f in vivos:
			if int(f.get_meta("nascido_seq", 0)) < int(velho.get_meta("nascido_seq", 0)):
				velho = f
		velho.remove_from_group(GRUPO)
		velho.remove_from_group(GRUPO_DO_JOGADOR)
		velho.queue_free()


## Cobra o item do aliado (1 por criatura). false = faltou: o `create` devolve null e a procedure do mod não cria nada.
static func cobrar(id: String, arvore: SceneTree) -> bool:
	return not CUSTO_EM_ITEM.has(id) or ItensDoMod.gastar(arvore, CUSTO_EM_ITEM[id], 1)


## Quantos itens uma técnica vai gastar: Biscuit Warrior (C) cria 1 guerreiro, a técnica 24 (V) cria 4. Para recusar ANTES de gastar energia.
const GUERREIROS_POR_TECNICA := {23: 1, 24: 4}


## Cria o corpo e devolve a entidade da camada Minecraft; null se não der (o chamador cai no corpo virtual).
static func criar(id: String, mundo: McMundo, pos: McVec3) -> McEntidade:
	if mundo == null or mundo.arvore == null or mundo.arvore.current_scene == null:
		return null
	var mod := Mc.ficha_do_mod(id)
	var atr: Dictionary = mod.get("atributos", {})
	var dim: Vector2 = DIMENSOES[id]
	var m := MundoMinePiece.METROS_POR_BLOCO
	var ficha := {
		"id": id, "nome": McTexto.traduzir("entity.minepiece." + id), "zona": "invocacao", "modelo": "", "chefe": false,
		"faccao": "mod", "invocado": true,
		"vida": float(atr.get("max_health", 20.0)), "armadura": float(atr.get("armor", 0.0)),
		"velocidade": float(atr.get("movement_speed", 0.3)), "dano_corpo": float(atr.get("attack_damage", 1.0)),
		"resistencia_a_empurrao": float(atr.get("knockback_resistance", 0.0)),
		"alcance_de_perseguicao": float(atr.get("follow_range", 16.0)),
		"forca": -1.0, "resistencia": -1.0, "altura": dim.y * m, "largura": dim.x * m,
		"nada": false, "espada": false, "arma_de_fogo": false, "tecnicas": [], "comuns": [],
	}
	var p := PersonagemMinePiece.new()
	p.montar(ficha, "mpx_" + id)
	p.renasce = false
	p.position = pos.para_godot() if pos != null else Vector3.ZERO
	p.ponto_de_origem = p.position
	p.add_to_group(GRUPO)
	_sequencia += 1
	p.set_meta("nascido_seq", _sequencia)
	mundo.arvore.current_scene.add_child(p)
	if id == "entity_muso_donatsu":
		_tingir_de_mochi(p)
	# O dono só é gravado DEPOIS do `create` (SetSummonedEntity): ao fim do quadro o corpo se liga a ele.
	_ligar_ao_dono.bind(p).call_deferred()        # (não `process_frame.connect`: várias criações no mesmo quadro — a Assault Attack cria 4 — descartavam as seguintes)
	return McEntidade.de(p)


## Dono = jogador: a criatura é aliada dele (não é "enemy", o jogador não a golpeia, segue o dono, inimigos a escolhem como alvo).
static func _ligar_ao_dono(p: PersonagemMinePiece) -> void:
	if not is_instance_valid(p):
		return
	var dados := McEntidade.de(p).getPersistentData()
	var dono_id := str(dados.getString("OWNER_UUID"))
	var dono: Node = instance_from_id(int(dono_id)) if dono_id.is_valid_int() else null
	if dono == null or not is_instance_valid(dono):
		return
	p.set_meta("dono_no", dono)
	# Guerreiro de biscoito: o `tick` do mod o apagava após 3600 ticks (3 min) e, no modo ataque, ao fim do ataque — pedido do dono: não morrem.
	# Morrem se o dono morrer ou deixar de ser do Bisu Bisu (regra do mod).
	# Vale para os DOIS modos (C e Assault Attack): o dono quer o aliado vivo; o `kill @s` do mod é ignorado em `McComandos._matar` enquanto o dono vive.
	if id_de(p) == "biscuit_warrrior":
		p.set_meta("aliado_permanente", true)
		var ret := Permanente.new()
		ret.name = "Permanente"
		p.add_child(ret)
	if dono.is_in_group("player"):
		p.remove_from_group("enemy")
		p.remove_from_group(AlvosDeGolpe.GRUPO)
		p.add_to_group(GRUPO_DO_JOGADOR)


static func id_de(p: Node) -> String:
	return str(p.get("id_personagem")) if "id_personagem" in p else ""


## Zera o relógio de vida (`cnt_life`) do `tick` do mod a cada quadro: a criatura não expira por tempo.
class Permanente:
	extends Node
	func _physics_process(_d: float) -> void:
		var pai := get_parent()
		if is_instance_valid(pai):
			McEntidade.de(pai as Node3D).getPersistentData().putDouble("cnt_life", 0.0)
