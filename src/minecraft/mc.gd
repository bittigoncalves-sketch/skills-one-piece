class_name Mc
extends RefCounted
# ============================================================================
#  CAMADA MINECRAFT — a API do Minecraft que as procedures TRADUZIDAS do Mine Piece chamam
#  (docs/MINE_PIECE_COMPLETO_MEDICAO.md; decisão do dono, 23/10/2026: "camada Minecraft +
#  tradutor"). O tradutor (`tools/mine_piece/tradutor/traduzir.py`) preserva os nomes do
#  Minecraft (getX, hasEffect, getPersistentData...) e manda para cá o que é REGISTRO
#  (efeito, atributo, partícula...), CONSTRUÇÃO (`new Vec3`) e ESTÁTICO (`Mth.nextDouble`).
#
#  E1 (fatia 1): entidade (`McEntidade`), mundo (`McMundo`), NBT, efeitos, atributos, Vec3,
#  AABB, instanceof. O que ainda não existe é CONTADO em `pedidos_sem_implementacao` (a
#  lista da próxima fatia, medida rodando o jogo) e devolve null — nunca finge um resultado.
# ============================================================================

const PROCEDURES := "res://src/minecraft/gerado/procedures/"
const NOME_DO_MUNDO := "McMundo"

## "tipo:nome" → quantas vezes foi pedido sem implementação.
static var pedidos_sem_implementacao := {}
static var _procedures := {}
static var _efeitos := {}
static var _atributos := {}
static var _tipos := {}


## Diagnóstico (medidores): "o_que" → quantas vezes. Não muda comportamento.
static var contadores := {}


static func contar(o_que: String) -> void:
	contadores[o_que] = int(contadores.get(o_que, 0)) + 1


static func _falta(tipo: String, nome: String) -> Variant:
	var chave := tipo + ":" + nome
	pedidos_sem_implementacao[chave] = int(pedidos_sem_implementacao.get(chave, 0)) + 1
	return null


# ------------------------------------------------------------ mundo e procedures
## O `Level` desta cena (criado na primeira vez, filho da raiz da árvore).
static func mundo(tree: SceneTree) -> McMundo:
	if tree == null:
		return null
	if tree.root.has_meta(NOME_DO_MUNDO):
		var existente: Variant = tree.root.get_meta(NOME_DO_MUNDO)
		if is_instance_valid(existente):
			return existente
	var m := McMundo.new()
	m.name = NOME_DO_MUNDO
	m.arvore = tree
	tree.root.set_meta(NOME_DO_MUNDO, m)
	tree.root.add_child.call_deferred(m)          # a raiz pode estar montando filhos agora
	return m


## Chama `execute` de uma procedure montando os argumentos pelo NOME dos parâmetros traduzidos
## (world, x, y, z, entity, amplifier…): cada procedure do mod tem uma assinatura. `valores`: nome → valor.
static var _parametros := {}


static func chamar(nome: StringName, valores: Dictionary) -> Variant:
	var s := proc(nome)
	if s == null:
		return null
	if not _parametros.has(nome):
		_parametros[nome] = []
		for m in s.get_script_method_list():
			if m["name"] == "execute":
				_parametros[nome] = m["args"].map(func(a): return str(a["name"]))
				break
	return s.callv("execute", (_parametros[nome] as Array).map(func(n): return valores.get(n)))


## Valores de argumento para uma entidade (world, x, y, z, entity).
static func argumentos_de(e: McEntidade, extra := {}) -> Dictionary:
	var v := {"world": e.level(), "x": e.getX(), "y": e.getY(), "z": e.getZ(), "entity": e}
	v.merge(extra, true)
	return v


## Outra procedure traduzida (`XProcedure.execute(...)` no Java). Carrega sob demanda.
const AQUECIMENTO := "res://mapas/east_blue/aquecimento_de_procedures.json"
## Desligar só nas medições (A/B no mesmo build).
static var aquecimento_ligado := true


## Carrega de antemão as procedures que os handlers de evento podem chamar (lista de tools/mine_piece/gerar_aquecimento.py).
## Sem isto o `load()` de cada uma acontece no meio da partida: 12,4 + 3,7 ms num quadro só (medido 04/11/2026).
## Devolve quantas carregou agora; idempotente (quem já está em cache não custa nada).
static func aquecer() -> int:
	if not aquecimento_ligado or not FileAccess.file_exists(AQUECIMENTO):
		return 0
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(AQUECIMENTO))
	var novas := 0
	if d is Dictionary:
		for n in d.get("procedures", []):
			if not _procedures.has(StringName(n)):
				novas += 1
			proc(StringName(n))
	return novas


## Procedures AJUSTADAS de propósito (13/11/2026, HTCS): NÃO são equivalentes à gerada — mudam mecânica/leitura de um poder (cada arquivo diz o que mudou e por quê).
const AJUSTADAS := {
	&"FujitoraMeteorSmallProcedure": "res://src/minecraft/ajustadas/FujitoraMeteorSmallProcedure.gd",
	&"LogicRifleProcedure": "res://src/minecraft/ajustadas/LogicRifleProcedure.gd",       # atirador alcança 48 m (era 24) — decisão do dono, 15/11/2026
}


## Procedures TRADUZIDAS À MÃO a partir das geradas (mesma assinatura): gargalos medidos que o tradutor ainda não otimiza. Cada uma tem cabeçalho com a
## diferença para a original e teste de equivalência (`test_procedures_otimizadas`). GATILHO: ao regerar as procedures (tradutor), reconferir
## cada arquivo daqui contra a nova versão gerada antes de manter a substituição.
const OTIMIZADAS := {
	&"BlockDestroyAllDirectionProcedure": "res://src/minecraft/otimizadas/BlockDestroyAllDirectionProcedure.gd",
	&"BlockToGrassProcedure": "res://src/minecraft/otimizadas/BlockToGrassProcedure.gd",
	&"ChangeTechniqueTestProcedure": "res://src/minecraft/otimizadas/ChangeTechniqueTestProcedure.gd",
	&"ReturnDevilFruitEatenProcedure": "res://src/minecraft/otimizadas/ReturnDevilFruitEatenProcedure.gd",
	&"SelectedArmorEquipProcedure": "res://src/minecraft/otimizadas/SelectedArmorEquipProcedure.gd",
}


static func proc(nome: StringName) -> GDScript:
	if not _procedures.has(nome):
		var t_load := Cronometro.ini()
		_procedures[nome] = load(String(OTIMIZADAS.get(nome, AJUSTADAS.get(nome, PROCEDURES + String(nome) + ".gd"))))
		if Cronometro.ligado:
			Cronometro.fim(StringName("proc_load:" + String(nome)), t_load)
	return _procedures[nome]


# ------------------------------------------------------------ instanceof
## Classes do Minecraft → o que no jogo responde por elas.
## Mob = personagem do mod e inimigo do mapa; ANIMAL = bicho da ilha (vivo, sem ficha de
## personagem, não jogador). Domesticado (TamableAnimal) ainda não existe no sentido do Minecraft.
const MOBS := [&"Mob", &"PathfinderMob", &"Monster", &"FlyingMob", &"AbstractGolem"]
const ANIMAIS := [&"Animal", &"AgeableMob", &"WaterAnimal"]
const JOGADOR := [&"Player", &"ServerPlayer", &"AbstractClientPlayer", &"LocalPlayer"]
## Mobs do Minecraft que o mod testa (`instanceof Zombie`…): não existem no jogo.
const MOBS_VANILLA := [&"Zombie", &"ZombieVillager", &"ZombieHorse", &"Husk", &"Drowned", &"Skeleton",
	&"WitherSkeleton", &"Stray", &"Creeper", &"Spider", &"CaveSpider", &"Enderman", &"Witch", &"Slime",
	&"Villager", &"AbstractVillager", &"WanderingTrader", &"IronGolem", &"SnowGolem", &"Blaze", &"Ghast",
	&"Phantom", &"Piglin", &"ZombifiedPiglin", &"Hoglin", &"Pillager", &"Vindicator", &"Evoker", &"Ravager",
	&"EnderDragon", &"WitherBoss", &"Warden", &"Wolf", &"Cat", &"Horse", &"Squid", &"Dolphin", &"Bee"]
const MUNDO := [&"Level", &"ServerLevel", &"LevelAccessor", &"LevelReader", &"BlockGetter", &"CommonLevelAccessor"]


## `x instanceof T`, com a hierarquia do Minecraft. Classe do mod `FooBarEntity` → o personagem
## cuja ficha é `foo_bar`.
static func e(alvo: Variant, tipo: StringName) -> bool:
	if alvo == null:
		return false
	if alvo is McEntidade:
		var ent := alvo as McEntidade
		if not ent.valida():
			return false
		var cls: Array = _classe_do_tipo(tipo)
		var tipo_cls: int = cls[0]
		if tipo_cls == CLS_ENTITY:
			return true
		if tipo_cls == CLS_GEO:
			return ent.no.has_method("tocar_tecnica")        # só quem tem o modelo animado do mod
		if tipo_cls == CLS_MOD:
			var id := str(ent.no.get("id_personagem")) if "id_personagem" in ent.no else ""
			return not id.is_empty() and cls[1] == id
		var e_jogador := ent.no.is_in_group("player")
		if tipo_cls == CLS_JOGADOR:
			return e_jogador
		var vivo := "health" in ent.no
		if tipo_cls == CLS_LIVING:
			return vivo
		if tipo_cls == CLS_MOB:
			return vivo and not e_jogador
		if tipo_cls == CLS_ANIMAL:
			return vivo and not e_jogador and not ("id_personagem" in ent.no or ent.no.is_in_group("enemy"))
		if tipo_cls == CLS_NAO_CORPO:
			return false                       # corpos do jogo não são projéteis, itens soltos nem mobs vanilla
		_falta("instanceof", String(tipo))
		return false
	if alvo is McMundo:
		return tipo in MUNDO
	if alvo is McItem:
		return item_e(alvo as McItem, tipo)
	if alvo is McBloco:
		var b := String((alvo as McBloco).id)
		return tipo == &"Block" or (tipo == &"LiquidBlock" and (b == "minecraft:water" or b == "minecraft:lava"))
	if alvo is String or alvo is StringName:
		return tipo == &"String"
	if alvo is McVec3:
		return tipo in [&"Vec3", &"BlockPos", &"Vec3i"]
	_falta("instanceof", String(tipo))
	return false


## O que um NOME de classe significa para `e()`. Decidido UMA vez por nome (09/11/2026): antes, cada chamada varria 4–5 listas e refazia o
## `_snake` caractere por caractere — e `ReturnDevilFruitEaten`, que testa ~100 classes por consulta, é chamada centenas de vezes por tick
## pelas lâminas do X do Batto Batto (FPS caía de 60 para ~9). A ordem de prioridade é a mesma de antes.
const CLS_ENTITY := 0
const CLS_GEO := 1
const CLS_JOGADOR := 2
const CLS_LIVING := 3
const CLS_MOB := 4
const CLS_ANIMAL := 5
const CLS_NAO_CORPO := 6
const CLS_MOD := 7
const CLS_DESCONHECIDA := 8
static var _classes_de_tipo: Dictionary = {}


static func _classe_do_tipo(tipo: StringName) -> Array:
	var c: Variant = _classes_de_tipo.get(tipo)
	if c != null:
		return c
	var nome := String(tipo)
	var r: Array
	if tipo == &"Entity":
		r = [CLS_ENTITY, ""]
	elif tipo == &"GeoEntity":
		r = [CLS_GEO, ""]
	elif tipo in JOGADOR:
		r = [CLS_JOGADOR, ""]
	elif tipo == &"LivingEntity":
		r = [CLS_LIVING, ""]
	elif tipo in MOBS:
		r = [CLS_MOB, ""]
	elif tipo in ANIMAIS:
		r = [CLS_ANIMAL, ""]
	elif tipo in [&"TamableAnimal", &"Projectile", &"AbstractArrow", &"ThrowableItemProjectile", &"ItemEntity"] or tipo in MOBS_VANILLA:
		r = [CLS_NAO_CORPO, ""]
	elif nome.ends_with("Entity"):
		r = [CLS_MOD, _snake(nome.trim_suffix("Entity"))]
	else:
		r = [CLS_DESCONHECIDA, ""]
	_classes_de_tipo[tipo] = r
	return r


## `GolDRogerEntity` → `gol_d_roger` (o nome de registro do MCreator).
static func _snake(nome: String) -> String:
	var s := ""
	for i in nome.length():
		var c := nome[i]
		if c == c.to_upper() and c != c.to_lower() and i > 0:
			s += "_"
		s += c.to_lower()
	return s


# ------------------------------------------------------------ registros
## `MobEffects.X` / `MinepieceModMobEffects.X.get()`: um tipo por id.
static func efeito(id: StringName) -> McEfeito:
	# O tradutor manda o nome do CAMPO (`MobEffects.DAMAGE_BOOST`) e os comandos o do REGISTRO (`strength`): um tipo só.
	id = McEfeito.ALIAS.get(id, id)
	if not _efeitos.has(id):
		var ef := McEfeito.new()
		ef.id = id
		_efeitos[id] = ef
	return _efeitos[id]


## `Attributes.X` (o tradutor manda o nome do campo: minecraft:max_health) ou do mod.
static func atributo(id: StringName) -> McAtributo:
	var nome := String(id)
	if nome.begins_with("minecraft:") and McAtributo.DO_CAMPO.has(nome.trim_prefix("minecraft:")):
		id = McAtributo.DO_CAMPO[nome.trim_prefix("minecraft:")]
	if not _atributos.has(id):
		var a := McAtributo.new()
		a.id = id
		var faixa: Array = McAtributo.FAIXAS.get(id, [0.0, -INF, INF])
		a.padrao = faixa[0]
		a.minimo = faixa[1]
		a.maximo = faixa[2]
		_atributos[id] = a
	return _atributos[id]


static func tipo_entidade(id: StringName) -> McTipoEntidade:
	if not _tipos.has(id):
		var t := McTipoEntidade.new()
		t.id = id
		_tipos[id] = t
	return _tipos[id]


## A ficha do MOD de cada entidade (`mapas/east_blue/entidades_do_mod.json`,
## tools/mine_piece/extrair_entidades.py): IA do baseTick, atributos, imunidades, metas, escala.
const ENTIDADES := "res://mapas/east_blue/entidades_do_mod.json"
static var _entidades_do_mod := {}


static func ficha_do_mod(id: String) -> Dictionary:
	if _entidades_do_mod.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENTIDADES)) if FileAccess.file_exists(ENTIDADES) else null
		_entidades_do_mod = d["entidades"] if d is Dictionary else {"_": {}}
	return _entidades_do_mod.get(id, {})


## Itens do mod com a classe-base (`mapas/east_blue/itens_do_mod.json`, tools/mine_piece/extrair_itens.py).
const ITENS := "res://mapas/east_blue/itens_do_mod.json"
static var _itens_do_mod := {}
const BASES_DE_ITEM := {&"SwordItem": ["SwordItem"], &"TieredItem": ["TieredItem", "SwordItem"],
	&"ShieldItem": ["ShieldItem"], &"ArmorItem": ["ArmorItem"]}
const VANILLA_POR_NOME := {&"SwordItem": "_sword", &"AxeItem": "_axe", &"HoeItem": "_hoe",
	&"ShovelItem": "_shovel", &"PickaxeItem": "_pickaxe", &"TridentItem": "trident", &"BowItem": "bow",
	&"CrossbowItem": "crossbow", &"ShieldItem": "shield"}


## `item instanceof SwordItem` (a IA escolhe golpe de espada assim).
static func item_e(it: McItem, tipo: StringName) -> bool:
	if tipo == &"Item":
		return true
	var nome := String(it.id)
	if nome.begins_with("minepiece:"):
		if _itens_do_mod.is_empty():
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITENS)) if FileAccess.file_exists(ITENS) else null
			_itens_do_mod = d["itens"] if d is Dictionary else {"_": {}}
		var base := str(_itens_do_mod.get(nome.trim_prefix("minepiece:"), {}).get("base", "Item"))
		return base in BASES_DE_ITEM.get(tipo, [String(tipo)])
	return VANILLA_POR_NOME.has(tipo) and nome.contains(VANILLA_POR_NOME[tipo])


## Classe Java de entidade do mod (`ProjectileWaterBulletEntity`) → id de registro.
static var _id_da_classe := {}


static func id_da_classe(classe: String) -> String:
	if _id_da_classe.is_empty():
		ficha_do_mod("_")
		for ident in _entidades_do_mod:
			var f: Variant = _entidades_do_mod[ident]
			if f is Dictionary and f.has("classe"):
				_id_da_classe[str(f["classe"])] = str(ident)
	return _id_da_classe.get(classe, "")


## As tags de entidade do mod (`mapas/east_blue/tags_de_entidade.json`, tools/mine_piece/extrair_tags.py).
const TAGS := "res://mapas/east_blue/tags_de_entidade.json"
static var _tags := {}


const SEM_GUARDA_NA_HISTORIA := true


## `categoria`: "tags" (entidade), "tags_de_item", "tags_de_bloco" — o mesmo nome pode existir em duas.
static func tag_contem(tag: Variant, id: StringName, categoria := "tags") -> bool:
	# Decisão do dono (15/11/2026): inimigo NÃO se defende. A IA do mod só ergue a guarda se o tipo NÃO tem a tag `minepiece:no_guard`
	# (`AIActive2Procedure`): na história todo tipo é tratado como tendo-a. `SEM_GUARDA_NA_HISTORIA = false` devolve a defesa do mod.
	if SEM_GUARDA_NA_HISTORIA and categoria == "tags" and str(tag) == "minepiece:no_guard":
		return true
	if _tags.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TAGS)) if FileAccess.file_exists(TAGS) else null
		_tags = d if d is Dictionary else {"tags": {}}
	return String(id) in (_tags.get(categoria, {}) as Dictionary).get(str(tag), [])


## Existe uma tag com este nome na categoria? (diferencia `is(TagKey)` de `is(ResourceKey)`).
static func tem_tag(tag: Variant, categoria: String) -> bool:
	tag_contem(tag, &"", categoria)               # só para carregar o arquivo
	return (_tags.get(categoria, {}) as Dictionary).has(str(tag))


static func particula(id: StringName) -> Variant: return id          # nome; o desenho é da próxima fatia
static func som(id: StringName) -> Variant: return id
static func tipo_dano(id: StringName) -> Variant: return id
static var _blocos := {}


static func bloco(id: StringName) -> McBloco:
	if not _blocos.has(id):
		var b := McBloco.new()
		b.id = id
		_blocos[id] = b
	return _blocos[id]
static var _itens := {}


static func item(id: StringName) -> McItem:
	if not _itens.has(id):
		var it := McItem.new()
		it.id = id
		_itens[id] = it
	return _itens[id]
static func encantamento(id: StringName) -> StringName: return id
static func regra(id: StringName) -> StringName: return id
static func menu(id: StringName) -> Variant: return _falta("menu", id)


# ------------------------------------------------------------ construção (`new T(...)`)
static func novo(tipo: StringName, args: Array) -> Variant:
	match tipo:
		&"CompoundTag":
			return McNbt.new()
		&"DecimalFormat":
			return McFormatoDecimal.de(args[0] if not args.is_empty() else "#.##")
		&"Vec3", &"BlockPos", &"Vec3i":
			return McVec3.de(float(args[0]), float(args[1]), float(args[2])) if args.size() >= 3 else McVec3.new()
		&"AABB":
			if args.size() == 2:
				return McAabb.de(args[0], args[1])
			return McAabb.de(McVec3.de(args[0], args[1], args[2]), McVec3.de(args[3], args[4], args[5]))
		&"MobEffectInstance":
			return McEfeito.instancia(args[0], int(args[1]) if args.size() > 1 else 0, int(args[2]) if args.size() > 2 else 0,
				bool(args[3]) if args.size() > 3 else false, bool(args[4]) if args.size() > 4 else true,
				bool(args[5]) if args.size() > 5 else true)
		&"AttributeModifier":
			var m := McAtributo.Modificador.new()
			# (uuid, nome, valor, operação) ou (nome, valor, operação).
			var i := 1 if args.size() >= 4 else 0
			m.uuid = str(args[0]) if args.size() >= 4 else str(args[0])
			m.nome = str(args[i])
			m.valor = float(args[i + 1])
			m.operacao = StringName(str(args[i + 2]))
			return m
		&"AtomicReference":
			return Referencia.new()
		&"MinepieceModAnimationMessage":
			var m := McRede.Animacao.new()
			m.clipe = str(args[0])
			m.alvo = int(args[1])
			m.sobrescrever = bool(args[2])
			return m
		&"ClipContext":
			return McMundo.Raio.de(args)
		&"ResourceLocation":
			return str(args[0]) if args.size() == 1 else "%s:%s" % [args[0], args[1]]
		&"Builder":
			return McLoot.Contexto.new()               # LootParams.Builder (ver `McLoot`)
		&"ItemStack":
			if args.is_empty() or args[0] == null:
				return McItem.pilha(null, 0)
			return McItem.pilha(args[0] if args[0] is McItem else Mc.item(StringName(str(args[0]))), int(args[1]) if args.size() > 1 else 1)
		&"CommandSourceStack":
			return McComandos.fonte_de(args)
		&"PlayerVariables":
			return McVariaveisDoMod.PlayerVariables.new()
		&"HurtByTargetGoal", &"NearestAttackableTargetGoal", &"MeleeAttackGoal", &"RandomStrollGoal", \
				&"LookAtPlayerGoal", &"RandomLookAroundGoal", &"FloatGoal", &"WaterAvoidingRandomStrollGoal":
			return McEntidade.Meta.de(tipo, args)
		&"DamageSource":
			return McFonteDeDano.de(args[0], args[1] if args.size() > 1 else null, args[2] if args.size() > 2 else null)
	if String(tipo).ends_with("Entity") and not id_da_classe(String(tipo)).is_empty():
		# `new XEntity(tipo, level)` / `new XEntity(level)`: o corpo virtual da entidade do mod.
		for a in args:
			if a is McMundo:
				return tipo_entidade(StringName("minepiece:" + id_da_classe(String(tipo)))).create(a)
	return _falta("new", tipo)


# ------------------------------------------------------------ estáticos e campos
static func estatico(classe: StringName, metodo: StringName, args: Array) -> Variant:
	match String(classe) + "." + String(metodo):
		"Minecraft.getInstance":
			return McServidor.Cliente.new()
		# Argumentos de comando (Brigadier): a linha de texto já foi resolvida em `McComandos.Contexto`.
		"EntityArgument.getEntities", "EntityArgument.getPlayers":
			return (args[0] as McComandos.Contexto).alvos(str(args[1]))
		"EntityArgument.getEntity", "EntityArgument.getPlayer":
			var lista: Array = (args[0] as McComandos.Contexto).alvos(str(args[1]))
			return lista[0] if not lista.is_empty() else null
		"DoubleArgumentType.getDouble", "IntegerArgumentType.getInteger":
			return (args[0] as McComandos.Contexto).valor(str(args[1]))
		"StringArgumentType.getString":
			return str((args[0] as McComandos.Contexto).valor(str(args[1])))
		"NbtUtils.writeBlockState":
			var tag := McNbt.new()
			tag.dados["Name"] = str((args[0] as McBloco.Estado).bloco.id) if args[0] is McBloco.Estado else "minecraft:air"
			return tag
		"ItemHandlerHelper.giveItemToPlayer":
			# O item vai para os itens do mod do jogador (ver `ItensDoMod`): o biscoito da técnica Biscuit do Bisu Bisu etc.
			var quem: Variant = args[0]
			var pilha: Variant = args[1]
			if quem is McEntidade and (quem as McEntidade).valida() and (quem as McEntidade).no.is_in_group("player") \
					and pilha is McItem.Pilha and not (pilha as McItem.Pilha).isEmpty():
				ItensDoMod.dar((quem as McEntidade).no.get_tree(), String((pilha as McItem.Pilha).item.id), (pilha as McItem.Pilha).getCount())
			return null
		"Block.getId":
			# Índice numérico do estado (pacotes e `levelEvent`): estável pelo nome, sem tabela do registro.
			return absi(str((args[0] as McBloco.Estado).bloco.id).hash()) % 65536 if args[0] is McBloco.Estado else 0
		"MinepieceMod.queueServerWork":
			mundo(Engine.get_main_loop() as SceneTree).queueServerWork(int(args[0]), args[1] as Callable)
			return null
		"EquipmentSlot.byTypeAndIndex":
			# Type.ARMOR índice 0..3 = FEET, LEGS, CHEST, HEAD; Type.HAND 0 = MAINHAND, 1 = OFFHAND.
			var i := int(args[1])
			if str(args[0]) == "ARMOR":
				return [&"FEET", &"LEGS", &"CHEST", &"HEAD"][clampi(i, 0, 3)]
			return [&"MAINHAND", &"OFFHAND"][clampi(i, 0, 1)]
		"BlockPos.containing":
			return McVec3.de(floorf(float(args[0])), floorf(float(args[1])), floorf(float(args[2]))) if args.size() == 3 \
				else (args[0] as McVec3).containing()
		"Vec3.atBottomCenterOf", "Vec3.atCenterOf", "Vec3.atLowerCornerOf":
			# BlockPos → ponto: centro do bloco em x/z; atBottomCenterOf = base, atCenterOf = meio.
			var b: McVec3 = args[0]
			var metodo_ := String(metodo)
			var dy := 0.5 if metodo_ == "atCenterOf" else 0.0
			return McVec3.de(b.x + 0.5, b.y + dy, b.z + 0.5) if metodo_ != "atLowerCornerOf" else McVec3.de(b.x, b.y, b.z)
		"AABB.ofSize":
			return McAabb.de_tamanho(args[0], args[1], args[2], args[3])
		"Component.literal", "Component.translatable", "Component.nullToEmpty":
			return McTexto.de(args[0] if not args.is_empty() else "")
		"Comparator.comparingDouble", "Comparator.comparingInt", "Comparator.comparing":
			return McFluxo.comparando(args[0])
		"ItemTags.create", "BlockTags.create", "EntityTypeTags.create":
			return StringName(str(args[0]))
		"ModList.get":
			return ListaDeMods.new()
		"ResourceKey.create":
			return StringName(str(args[1]))
		"String.format":
			# `String.format(Locale.US, "%.1f", x)`: o Locale vem antes do formato.
			if args.size() > 1 and not str(args[0]).contains("%") and str(args[1]).contains("%"):
				return _formatar(str(args[1]), args.slice(2))
			return _formatar(str(args[0]), args.slice(1))
		"EnchantmentHelper.getItemEnchantmentLevel", "EnchantmentHelper.getEnchantmentLevel":
			return 0                                   # não há encantamentos no jogo
		"UUID.fromString", "UUID.nameUUIDFromBytes":
			return str(args[0])
		"TagKey.create":
			return StringName(str(args[1]))            # a tag é o próprio id (forge:ranged_ammo)
		"RandomSource.create":
			return McAleatorio.de()
		"Mth.nextDouble", "Mth.nextFloat":
			return (args[0] as McAleatorio).rng.randf_range(float(args[1]), float(args[2]))
		"Mth.nextInt":
			return (args[0] as McAleatorio).rng.randi_range(int(args[1]), int(args[2]))
		"Mth.clamp":
			return clamp(args[0], args[1], args[2])
		"Mth.sqrt": return sqrt(float(args[0]))
		"Mth.floor": return floori(float(args[0]))
		"Mth.ceil": return ceili(float(args[0]))
		"Mth.abs": return abs(args[0])
		"Mth.sin": return sin(float(args[0]))
		"Mth.cos": return cos(float(args[0]))
		"Mth.wrapDegrees": return wrapf(float(args[0]), -180.0, 180.0)
		"Mth.lerp": return lerpf(float(args[1]), float(args[2]), float(args[0]))
		"ResourceLocation.tryParse", "ResourceLocation.parse": return str(args[0])
		"String.valueOf": return str(args[0])
		"Integer.parseInt", "Long.parseLong": return int(str(args[0]))
		"Double.parseDouble", "Float.parseFloat": return float(str(args[0]))
	return _falta("estatico", String(classe) + "." + String(metodo))


## `ModList.get().isLoaded("outro_mod")`: o mod checa compatibilidades — aqui nenhum outro mod existe.
class ListaDeMods:
	extends RefCounted
	func isLoaded(_id: Variant) -> bool: return false


## `MinepieceModVariables.MapVariables.get(world)` (o tradutor manda para cá: um método `get`
## sombrearia o `Object.get` do Godot).
static func variaveis(tipo: StringName, w: Variant) -> Variant:
	return (w as McMundo).variaveis(String(tipo)) if w is McMundo else null


static func campo(classe: StringName, nome: StringName) -> Variant:
	# Chaves de dado sincronizado (`DATA_mode`, `TEXTURE`, `ANIMATION`, `SHOOT`): o nome basta; o valor mora na entidade.
	if String(nome).begins_with("DATA_") or nome in [&"TEXTURE", &"ANIMATION", &"SHOOT"]:
		return nome
	match String(classe) + "." + String(nome):
		"Vec3.ZERO", "BlockPos.ZERO", "Vec3i.ZERO": return McVec3.new()
		"Level.OVERWORLD": return &"minecraft:overworld"
		"Level.NETHER": return &"minecraft:the_nether"
		"Level.END": return &"minecraft:the_end"
		"CommandSource.NULL": return null
		"ItemStack.EMPTY": return McItem.pilha(null, 0)
		# Constantes numéricas do Java (`Integer.MAX_VALUE` é a duração dos efeitos permanentes do mod: antes caía na regra de
		# enum abaixo, virava o TEXTO "MAX_VALUE" = 0 e o efeito morria no primeiro tick).
		"Integer.MAX_VALUE": return 2147483647
		"Integer.MIN_VALUE": return -2147483648
		"Long.MAX_VALUE": return 9223372036854775807
		"Long.MIN_VALUE": return -9223372036854775808
		"Double.MAX_VALUE": return 1.7976931348623157e308
		"Float.MAX_VALUE": return 3.4028234663852886e38
		"Double.MIN_VALUE": return 4.9e-324
	# `MinepieceConfig` (09/11/2026): os 4 booleanos de configuração do mod, com os PADRÕES do `MinepieceConfig.java` (forceNoSkills, hideSeaLocation,
	# doVanillaMobSpawning = falso; automaticallyEquip = verdadeiro). `Mc.obter0(valor)` devolve o booleano. Antes devolvia nulo e o fluxo de escolha de estilo abortava.
	if classe == &"MinepieceConfig":
		return String(nome) == "automaticallyEquip"
	if classe == &"PacketDistributor" or String(classe) + "." + String(nome) in ["MinepieceMod.PACKET_HANDLER", "PacketHandler.INSTANCE"]:
		return McRede.instancia()                   # pacotes cliente↔servidor: contados, não enviados
	if classe == &"ForgeMod":                       # atributos do Forge (SWIM_SPEED, ENTITY_GRAVITY…)
		return atributo(StringName("forge:" + String(nome).to_lower()))
	if classe in [&"ForgeRegistries", &"BuiltInRegistries", &"Registries"]:
		return McRegistro.de(String(nome))
	# Constante de enum (Block.VISUAL, Operation.ADDITION, SoundSource.NEUTRAL…): o próprio nome —
	# comparar com `==` funciona, e quem consome (atributo, raycast) lê o nome.
	if String(nome) == String(nome).to_upper():
		return StringName(nome)
	return _falta("campo", String(classe) + "." + String(nome))


static func nao_traduzido(o_que: StringName) -> Variant: return _falta("nao_traduzido", o_que)


## `String.format("%.1f %s", …)` do Java: %s, %d, %.Nf (os que o mod usa).
static func _formatar(f: String, args: Array) -> String:
	var r := RegEx.create_from_string(r"%(\.\d+)?[sdf]")
	var saida := ""
	var i := 0
	var ultimo := 0
	for m in r.search_all(f):
		saida += f.substr(ultimo, m.get_start() - ultimo)
		var v: Variant = args[i] if i < args.size() else ""
		saida += (("%" + m.get_string(0).substr(1)) % float(v)) if m.get_string(0).ends_with("f") else (str(int(v)) if m.get_string(0) == "%d" else str(v))
		i += 1
		ultimo = m.get_end()
	return saida + f.substr(ultimo)


# ------------------------------------------------------------ coleções do Java (o tradutor manda para cá)
## O tipo só se sabe rodando: lista → Array, mapa/conjunto → Dictionary, Supplier/Function → Callable.
class Entrada:
	extends RefCounted
	var k: Variant
	var v: Variant
	func getKey() -> Variant: return k
	func getValue() -> Variant: return v


static func entradas(m: Variant) -> Array:
	var saida := []
	if m is Dictionary:
		for k in m:
			var e := Entrada.new()
			e.k = k
			e.v = m[k]
			saida.append(e)
	return saida


## `java.util.concurrent.atomic.AtomicReference`: o mod a usa para tirar um valor de dentro de uma lambda (`ifPresent(c -> ref.set(c))`).
class Referencia:
	extends RefCounted
	var valor: Variant = null
	func set_(v: Variant) -> void: valor = v          # `set` é nativo do Object: o tradutor emite `set_`
	func obter() -> Variant: return valor


static func obter0(x: Variant) -> Variant:
	if x is Callable:
		return (x as Callable).call()
	if x is McEntidade.Opcional:
		return x.valor
	if x is Object and x.has_method("obter"):
		return x.obter()
	if typeof(x) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return x                                     # `ConfigValue.get()` de um valor já resolvido (ex.: `MinepieceConfig.*`)
	return _falta("get()", type_string(typeof(x)))


static func obter(x: Variant, k: Variant) -> Variant:
	if x is Array:
		return x[int(k)] if int(k) >= 0 and int(k) < x.size() else null
	if x is Dictionary:
		return x.get(k)
	if x is Object and x.has_method("obter"):
		return x.obter(k)
	return _falta("get(k)", type_string(typeof(x)))


static func obter_ou(x: Variant, k: Variant, padrao: Variant) -> Variant:
	return x.get(k, padrao) if x is Dictionary else padrao


static func por(x: Variant, k: Variant, v: Variant) -> Variant:
	if x is Dictionary:
		var antes: Variant = x.get(k)
		x[k] = v
		return antes
	if x is McNbt:                                   # `tag.put("BlockState", …)`
		var antes_nbt: Variant = (x as McNbt).dados.get(str(k))
		(x as McNbt).dados[str(k)] = v
		return antes_nbt
	return _falta("put", type_string(typeof(x)))


static func por_se_ausente(x: Variant, k: Variant, v: Variant) -> Variant:
	if x is Dictionary and not x.has(k):
		x[k] = v
		return null
	return x.get(k) if x is Dictionary else null


static func tem_chave(x: Variant, k: Variant) -> bool: return x is Dictionary and x.has(k)
static func chaves(x: Variant) -> Array: return x.keys() if x is Dictionary else []
static func valores(x: Variant) -> Array: return x.values() if x is Dictionary else (x if x is Array else [])
## `coleção.iterator()` do descompilador: `while it.hasNext(): x = it.next()`.
class Iterador:
	extends RefCounted
	var itens: Array = []
	var i := 0
	func hasNext() -> bool: return i < itens.size()
	func next() -> Variant:
		i += 1
		return itens[i - 1]
static func iterador(x: Variant) -> Iterador:
	var it := Iterador.new()
	it.itens = valores(x).duplicate()
	return it
static func tamanho(x: Variant) -> int: return x.size() if x is Array or x is Dictionary else 0
static func limpar(x: Variant) -> void:
	if x is Array or x is Dictionary:
		x.clear()


## `add(x)`: lista → append; Vec3 e afins → o `add` deles.
static func adicionar(x: Variant, v: Variant) -> Variant:
	if x is Array:
		x.append(v)
		return true
	if x is Dictionary:                     # Set do Java
		var novo: bool = not x.has(v)
		x[v] = true
		return novo
	return x.add(v)


static func adicionar_todos(x: Variant, vs: Variant) -> bool:
	for v in valores(vs) if vs is Dictionary else vs:
		adicionar(x, v)
	return true


static func remover(x: Variant, v: Variant) -> Variant:
	if x is Array:
		var i: int = x.find(v)
		if i >= 0:
			x.remove_at(i)
		return i >= 0
	if x is Dictionary:
		var antes: Variant = x.get(v)
		x.erase(v)
		return antes
	return x.remove(v)


static func contem(x: Variant, v: Variant) -> bool:
	if x is Array or x is Dictionary:
		return x.has(v)
	if x is String or x is StringName:
		return str(x).contains(str(v))
	return x.contains(v)


static func para_cada(x: Variant, f: Callable) -> void:
	for v in valores(x):
		f.call(v)


static func definir(x: Variant, v: Variant) -> Variant: return x.definir(v) if x is Object else _falta("set", "?")
static func definir_em(x: Variant, i: Variant, v: Variant) -> Variant:
	if x is Object and x.has_method("definir_chave"):  # `entityData.set(chave, valor)`
		return x.definir_chave(i, v)
	if x is Object and x.has_method("definir"):        # `regra.set(valor, servidor)`
		return x.definir(i)
	if x is Array:
		var antes: Variant = x[int(i)]
		x[int(i)] = v
		return antes
	return _falta("set(i, v)", type_string(typeof(x)))
static func aceitar(f: Variant, v: Variant) -> void:
	if f is Callable:
		f.call(v)
static func aplicar(f: Variant, v: Variant) -> Variant: return f.call(v) if f is Callable else null
static func testar(f: Variant, v: Variant) -> bool: return bool(f.call(v)) if f is Callable else false


# ------------------------------------------------------------ matemática (Java)
## `a % b` do Java: resto com o sinal do dividendo, inteiro ou não.
static func resto(a: Variant, b: Variant) -> Variant:
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		return a % b
	return fmod(float(a), float(b))


## `Math.round`: meio para CIMA (−2,5 → −2), não para longe do zero como o `round` do Godot.
static func math_round(x: float) -> int:
	return int(floor(x + 0.5))


static func hypot(a: float, b: float) -> float: return sqrt(a * a + b * b)
static func cbrt(x: float) -> float: return signf(x) * pow(absf(x), 1.0 / 3.0)
static func log10(x: float) -> float: return log(x) / log(10.0)
static func floor_mod(a: int, b: int) -> int: return ((a % b) + b) % b
static func floor_div(a: int, b: int) -> int: return floori(float(a) / float(b))


# ------------------------------------------------------------ Object/String do Java
## `a.equals(b)`: valor para texto/número; identidade para o resto (como o `equals` padrão).
static func iguais(a: Variant, b: Variant) -> bool:
	if a is McTexto:
		a = a.texto
	if b is McTexto:
		b = b.texto
	if (a is String or a is StringName) and (b is String or b is StringName):
		return str(a) == str(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


static func iguais_sem_caixa(a: Variant, b: Variant) -> bool:
	return str(a).to_lower() == str(b).to_lower()


## `isEmpty()` de String, lista ou mapa do Java.
static func vazio(x: Variant) -> bool:
	if x == null:
		return true
	if x is String or x is StringName or x is Array or x is Dictionary:
		return x.is_empty()
	_falta("isEmpty", type_string(typeof(x)))
	return false


## `s.substring(a)` / `s.substring(a, b)` (fim exclusivo).
static func substring(s: Variant, a: int, b: int = -1) -> String:
	var t := str(s)
	return t.substr(a) if b < 0 else t.substr(a, b - a)
