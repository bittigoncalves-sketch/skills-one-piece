class_name McVisual
extends RefCounted
## O VISUAL e o SOM que as procedures do Mine Piece pedem POR NOME (`sendParticles`, `playSound`).
##
## Sons e partículas do próprio mod vêm do jar (`tools/mine_piece/extrair_visual.py` → `assets/mine_piece/visual/`
## e `mapas/east_blue/visual_do_mod.json`). Os nomes do Minecraft puro (`entity.wither.shoot`, `minecraft:crit`)
## NÃO estão no jar. Os SONS vanilla vêm do Minecraft 1.20.1 local (`tools/mine_piece/extrair_sons_minecraft.py`: as
## variantes, volume e tom do próprio `sounds.json`); a PARTÍCULA vanilla ganha uma procedural (ESTILO, provisória:
## as texturas de partícula do Minecraft ainda não foram extraídas). O que não tem nem um nem outro continua
## CONTADO em `Mc.pedidos_sem_implementacao`.

const VISUAL := "res://mapas/east_blue/visual_do_mod.json"
const PASTA := "res://assets/mine_piece/visual/"
const MAX_SONS := 24
const MAX_EMISSORES := 48

## Partícula do Minecraft puro: cor, tamanho (blocos), vida (s), gravidade (blocos/s²), aditiva.
const ESTILO := {
	"minecraft:crit": {"cor": Color(1.0, 0.92, 0.55), "tam": 0.12, "vida": 0.35, "grav": 6.0, "add": true},
	"minecraft:enchanted_hit": {"cor": Color(0.55, 0.9, 1.0), "tam": 0.12, "vida": 0.4, "grav": 2.0, "add": true},
	"minecraft:cloud": {"cor": Color(0.95, 0.95, 0.95, 0.8), "tam": 0.3, "vida": 0.7, "grav": -0.4, "add": false},
	"minecraft:flash": {"cor": Color(1, 1, 1), "tam": 1.4, "vida": 0.15, "grav": 0.0, "add": true},
	"minecraft:explosion": {"cor": Color(0.55, 0.55, 0.55, 0.9), "tam": 1.2, "vida": 0.5, "grav": 0.0, "add": false},
	"minecraft:flame": {"cor": Color(1.0, 0.55, 0.15), "tam": 0.2, "vida": 0.45, "grav": -2.0, "add": true},
	"minecraft:small_flame": {"cor": Color(1.0, 0.6, 0.2), "tam": 0.12, "vida": 0.4, "grav": -2.0, "add": true},
	"minecraft:soul_fire_flame": {"cor": Color(0.3, 0.85, 1.0), "tam": 0.2, "vida": 0.45, "grav": -2.0, "add": true},
	"minecraft:firework": {"cor": Color(1.0, 0.85, 0.4), "tam": 0.12, "vida": 0.6, "grav": 3.0, "add": true},
	"minecraft:squid_ink": {"cor": Color(0.08, 0.08, 0.1, 0.9), "tam": 0.25, "vida": 0.9, "grav": 1.0, "add": false},
	"minecraft:end_rod": {"cor": Color(1, 1, 0.95), "tam": 0.12, "vida": 0.8, "grav": 0.0, "add": true},
	"minecraft:lava": {"cor": Color(1.0, 0.45, 0.1), "tam": 0.14, "vida": 0.7, "grav": 8.0, "add": true},
	"minecraft:portal": {"cor": Color(0.65, 0.3, 1.0), "tam": 0.14, "vida": 0.8, "grav": 0.0, "add": true},
	"minecraft:dragon_breath": {"cor": Color(0.9, 0.3, 0.9), "tam": 0.2, "vida": 0.9, "grav": -0.3, "add": true},
	"minecraft:large_smoke": {"cor": Color(0.55, 0.55, 0.55, 0.85), "tam": 0.45, "vida": 1.0, "grav": -0.15, "add": false},
	"minecraft:instant_effect": {"cor": Color(1.0, 0.6, 0.7), "tam": 0.15, "vida": 0.5, "grav": 0.0, "add": true},
	"minecraft:angry_villager": {"cor": Color(1, 1, 1), "tam": 0.3, "vida": 0.6, "grav": -0.3, "add": false},
	# Estilhaço de bloco quebrando: o Minecraft usa a textura do bloco; aqui, grãos cinza que caem.
	"minecraft:block": {"cor": Color(0.55, 0.55, 0.52), "tam": 0.12, "vida": 0.6, "grav": 14.0, "add": false},
	"minecraft:soul": {"cor": Color(1, 1, 1), "tam": 0.2, "vida": 1.0, "grav": -0.5, "add": false},
	# `particle dust r g b tamanho`: o grão colorido de redstone; a cor vem do comando (`cor_dust`).
	"minecraft:dust": {"cor": Color(1.0, 0.0, 0.0), "tam": 0.15, "vida": 0.8, "grav": 0.0, "add": false},
}
## As partículas vanilla cujo sprite é CINZA (a textura `generic`/`spell`): o Minecraft as tinge; as outras têm cor própria.
const TINGIR: Array[String] = ["minecraft:squid_ink", "minecraft:portal", "minecraft:dragon_breath",
	"minecraft:instant_effect", "minecraft:firework", "minecraft:large_smoke"]

static var _dados: Dictionary
static var _sons: Dictionary = {}          # arquivo → AudioStream
static var _texturas: Dictionary = {}      # chave → Texture2D
static var _sons_vivos := 0
static var _emissores_vivos := 0


static func _carregar() -> void:
	if not _dados.is_empty():
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(VISUAL)) if FileAccess.file_exists(VISUAL) else null
	_dados = d if d is Dictionary else {"sons": {}, "particulas": {}}


# ------------------------------------------------------------------ som
## `id`: "minepiece:x" ou nome do Minecraft. Devolve true se tocou (senão o chamador conta a falta).
static func som(arvore: SceneTree, id: String, pos_blocos: McVec3, volume := 1.0, tom := 1.0) -> bool:
	_carregar()
	var evento := id if ":" in id else "minecraft:" + id
	var arquivos: Array = (_dados.sons as Dictionary).get(evento, [])
	if arquivos.is_empty() or arvore == null or _sons_vivos >= MAX_SONS:
		return not arquivos.is_empty()            # tem som, só não coube agora: não é falta
	var escolhido := _variante(arquivos)
	var arq := String(escolhido["n"])
	volume *= float(escolhido["v"])
	tom *= float(escolhido["p"])
	var stream := _stream(arq)
	if stream == null:
		return false
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = clampf(tom, 0.25, 4.0)
	p.volume_db = linear_to_db(clampf(volume, 0.05, 2.0))
	p.unit_size = 12.0
	p.max_distance = 140.0
	p.position = pos_blocos.para_godot() if pos_blocos != null else Vector3.ZERO
	_sons_vivos += 1
	p.finished.connect(func() -> void:
		_sons_vivos -= 1
		p.queue_free())
	arvore.root.add_child.call_deferred(p)
	p.play.call_deferred()
	return true


## Uma variante do evento, com o PESO do `sounds.json` (padrão 1): item "arquivo" ou {n, v, p, w}.
static func _variante(itens: Array) -> Dictionary:
	var soma := 0.0
	for i: Variant in itens:
		soma += float((i as Dictionary).get("w", 1.0)) if i is Dictionary else 1.0
	var sorteio := randf() * soma
	var escolhido: Variant = itens[0]
	for i: Variant in itens:
		sorteio -= float((i as Dictionary).get("w", 1.0)) if i is Dictionary else 1.0
		escolhido = i
		if sorteio <= 0.0:
			break
	if escolhido is Dictionary:
		var d := escolhido as Dictionary
		return {"n": d["n"], "v": d.get("v", 1.0), "p": d.get("p", 1.0)}
	return {"n": escolhido, "v": 1.0, "p": 1.0}


static func _stream(arq: String) -> AudioStream:
	if not _sons.has(arq):
		var caminho := PASTA + "sons/" + arq + ".ogg"
		_sons[arq] = AudioStreamOggVorbis.load_from_file(caminho) if FileAccess.file_exists(caminho) else null
	return _sons[arq]


# ------------------------------------------------------------------ corpo de entidade de golpe/projétil
## Entidades do mod que são um PLANO DUPLO cruzado (o `geo` de `entity_strike`/`entity_sweep`: dois planos de
## 32 px = 2 m a 90°) com a textura `slash_*`/`projectile_*` escolhida por `setTexture`.
const PLANOS := ["entity_strike", "entity_sweep", "entity_slash", "projectile_slash", "projectile_sweep"]


## Projéteis desenhados como o `ThrownItemRenderer` do mod: o SPRITO do item, sempre de frente para a câmera. `lado` em blocos (o
## sprito de item no chão do Minecraft ocupa ~0,5 bloco). `bullet` = item_bullet, `heart_bullet` = item_heart, `booger` = o botão
## de blackstone polido do Java (`Blocks.POLISHED_BLACKSTONE_BUTTON`). Texturas: tools/mine_piece/extrair_projeteis.py.
const SPRITES := {
	"bullet": {"textura": "bullet", "lado": 0.5},
	"heart_bullet": {"textura": "heart", "lado": 0.5},
	"booger": {"textura": "booger", "lado": 0.3},
}
const MISSIL := "missile"
## `minecraft:lightning_bolt` (Goro, Mamaragan, Abyss…): entidade do Minecraft puro, desenhada aqui (ver `raio`).
const RAIO := "minecraft:lightning_bolt"
const META_FIXO := &"mc_desenho_fixo"       # corpo cuja textura NÃO vem de `setTexture` (sprito, míssil)


## O renderer do mod NUNCA desenha esta entidade (`isBodyVisible = false`, textura `clear`): ela só existe pela IA
## (partículas, som, dano em área). Não é falta de modelo — é o que o original faz. `extrair_invisiveis.py`.
static func e_invisivel(id: String) -> bool:
	_carregar()
	return id in (_dados.get("invisiveis", []) as Array)


static func tem_corpo(id: String) -> bool:
	return id == RAIO or modelo_java_de(id) != {} or id in PLANOS or id.begins_with("projectile_") or SPRITES.has(id) or id == MISSIL or modelo_de(id) != ""


## Modelo GeckoLib convertido (`extrair_modelos_de_efeito.py` → `modelos/mpx_<id>.glb`), ou "" se a entidade não tem.
## Os planos e os desenhos próprios acima têm precedência: são fiéis ao `geo` deles e já testados.
static func modelo_de(id: String) -> String:
	if id in PLANOS or id.begins_with("projectile_") or SPRITES.has(id) or id == MISSIL:
		return ""
	_carregar()
	var m: Variant = (_dados.get("modelos", {}) as Dictionary).get(id)
	if m is Dictionary:
		var caminho := PASTA + "modelos/" + str(m["glb"])
		return caminho if ResourceLoader.exists(caminho) else ""
	# Personagem com ficha criado por uma procedure (ex.: Kumacy): já tem o modelo da loja (com roupa e arma), sem duplicar arquivo.
	var da_loja := "res://mapas/modelos/mp_%s.glb" % id
	return da_loja if ResourceLoader.exists(da_loja) else ""


## Corpo vindo de um modelo GeckoLib: a cena do .glb, com a textura inicial do mod. O nó traz o `AnimationPlayer`.
static func _modelo(id: String) -> Node3D:
	var cena := load(modelo_de(id)) as PackedScene
	var no := cena.instantiate() as Node3D
	no.name = "Desenho"
	no.set_meta(META_FIXO, true)                    # a textura vem do .glb; `texturizar_modelo` troca por `setTexture`
	no.set_meta(&"mc_modelo", true)
	return no


## `setTexture(nome)` num modelo: troca o albedo de todas as malhas pela `entidades/<nome>.png`. Nome sem arquivo: fica como está.
static func texturizar_modelo(no: Node, nome: String) -> void:
	var rel := "entidades/" + nome
	if nome == "" or not FileAccess.file_exists(PASTA + rel + ".png"):
		return
	var tex := _textura_arquivo(rel)
	for m: Node in no.find_children("*", "MeshInstance3D", true, false):
		var malha := (m as MeshInstance3D).mesh
		for i in malha.get_surface_count():
			var base := malha.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var mat := base.duplicate() as StandardMaterial3D
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			(m as MeshInstance3D).set_surface_override_material(i, mat)


## Toca o clipe `nome` (GeckoLib `triggerAnim`); o converter põe o sufixo `_loop` nos que se repetem. "empty"/desconhecido: ciclo base.
static func tocar(no: Node, nome: String) -> bool:
	var ap := no.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return false
	for a in ap.get_animation_list():
		if a == nome or a == nome + "_loop" or a.ends_with("." + nome) or a.ends_with("." + nome + "_loop"):
			ap.play(a)
			return true
	return false


## Ciclo base do modelo: o primeiro clipe `*idle*` (ou o primeiro em loop), se houver.
static func ciclo_base(no: Node) -> void:
	var ap := no.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	var lista := ap.get_animation_list()
	for a in lista:
		if "idle" in a.to_lower():
			ap.play(a)
			return
	for a in lista:
		if a.ends_with("_loop"):
			ap.play(a)
			return


## Malha do corpo (sem textura ainda: `texturizar` põe quando `setTexture` roda). Escala em METROS = tamanho × 2.
static func corpo(id: String) -> Node3D:
	if modelo_de(id) != "":
		return _modelo(id)
	if SPRITES.has(id):
		return _sprite(SPRITES[id])
	if id == MISSIL:
		return _missil()
	if id == RAIO:
		return raio()
	if modelo_java_de(id) != {}:
		return _modelo_java(id)
	var m := MeshInstance3D.new()
	m.name = "Desenho"
	var mesh := ArrayMesh.new()
	var h := 1.0 * MundoMinePiece.METROS_POR_BLOCO
	for ang in [0.0, PI * 0.5]:
		var a := _plano(h, ang)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## `ThrownItemRenderer`: um quadrado com a textura do item, sempre de frente para a câmera, recorte duro (pixel art).
static func _sprite(d: Dictionary) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "Desenho"
	var quadrado := QuadMesh.new()
	quadrado.size = Vector2.ONE * float(d["lado"]) * MundoMinePiece.METROS_POR_BLOCO
	m.mesh = quadrado
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _textura_arquivo("entidades/" + str(d["textura"]))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.set_meta(META_FIXO, true)
	return m


## `Modelmissile` (client/model do mod): o `bone` com 9 caixas e 5 peças de aletas, textura de 48 × 48 (`missile.png`). Cada
## peça: [x, y, z, rx, ry, rz] (translação em 1/16 de bloco, rotação em rad; Y do Minecraft é PARA BAIXO) e suas caixas
## [u, v, x, y, z, w, h, d, inflar]. A ponta (y = −22) vira +Y aqui: o corpo alinha o +Y com a velocidade.
const MISSIL_TEXTURA := Vector2(48.0, 48.0)
const MISSIL_PECAS := [
	[[0.0, 24.0, 0.0, 0.0, 0.0, 0.0], [
		[1, 0, -4.0, -16.0, -4.0, 8, 8, 8, 0.0], [0, 0, -3.5, -8.0, -3.5, 7, 16, 7, 0.0], [0, 0, -4.0, 8.0, -4.0, 8, 8, 8, 0.5],
		[0, 31, -4.0, -8.0, -4.0, 8, 1, 8, 0.25], [0, 31, -4.0, 6.5, -4.0, 8, 1, 8, 0.25],
		[4, 0, 2.0, 16.0, -3.0, 2, 8, 6, 0.0], [4, 0, -4.0, 16.0, -3.0, 2, 8, 6, 0.0],
		[7, 4, -2.0, -22.0, -2.0, 4, 2, 4, 0.0], [4, 2, -3.0, -20.0, -3.0, 6, 4, 6, 0.0]]],
	[[0.0, 43.7071, 0.0, 3.1416, 0.0, -2.3562], [[5, 39, 4.0355, 0.0355, -0.5, 1, 8, 1, 0.0]]],
	[[0.0, 43.7071, 0.0, 0.0, 0.0, -0.7854], [[5, 39, 4.0355, 0.0355, -0.5, 1, 8, 1, 0.0]]],
	[[0.5, 43.0, 5.0, 1.5708, -0.7854, -1.5708], [[5, 39, 0.0, -3.0, 0.0, 1, 8, 1, 0.0]]],
	[[0.5, 43.0, -5.0, -1.5708, 0.7854, -1.5708], [[5, 39, 0.0, -3.0, -1.0, 1, 8, 1, 0.0]]],
	[[0.0, 44.0, 0.0, 0.0, 1.5708, 0.0], [[4, 0, 2.0, -4.0, -3.0, 2, 8, 6, 0.0], [4, 0, -4.0, -4.0, -3.0, 2, 8, 6, 0.0]]],
]


static func _missil() -> MeshInstance3D:
	var vs := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var k := MundoMinePiece.METROS_POR_BLOCO / 16.0
	for peca: Array in MISSIL_PECAS:
		var p: Array = peca[0]
		# Ordem do Minecraft: translada, depois gira Z, Y, X.
		var rot := Basis.from_euler(Vector3(p[3], p[4], p[5]), EULER_ORDER_ZYX)
		for c: Array in peca[1]:
			_caixa_mc(vs, uvs, idx, c, Vector3(p[0], p[1], p[2]), rot, k)
	# O osso do modelo fica a 24 do chão: centra a malha, para o míssil girar pelo meio e não pelo bico.
	var minimo := vs[0]
	var maximo := vs[0]
	for q in vs:
		minimo = minimo.min(q)
		maximo = maximo.max(q)
	var centro := (minimo + maximo) * 0.5
	for i in vs.size():
		vs[i] -= centro
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := MeshInstance3D.new()
	m.name = "Desenho"
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _textura_arquivo("entidades/missile")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.set_meta(META_FIXO, true)
	m.set_meta(&"mc_alinhar_y", true)
	return m


## Uma caixa do `CubeListBuilder.addBox(x, y, z, w, h, d, inflar)` com `texOffs(u, v)`: 6 faces no mapa de UV do Minecraft
## (cima e baixo em cima, depois direita/frente/esquerda/trás). O Minecraft tem Y para baixo e Z para o espectador:
## (x, −y, −z) é uma rotação de 180° em X, sem espelhar.
static func _caixa_mc(vs: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, c: Array,
		translacao: Vector3, rot: Basis, k: float, tex := MISSIL_TEXTURA) -> void:
	var u: float = c[0]
	var v: float = c[1]
	var inf: float = c[8]
	var x0: float = c[2] - inf
	var y0: float = c[3] - inf
	var z0: float = c[4] - inf
	var w: float = c[5]
	var h: float = c[6]
	var d: float = c[7]
	var x1: float = x0 + w + 2.0 * inf
	var y1: float = y0 + h + 2.0 * inf
	var z1: float = z0 + d + 2.0 * inf
	# Cantos no espaço do Minecraft, depois pose (rotação e translação) e conversão para o Godot.
	var cantos: Array[Vector3] = []
	for xi in [x0, x1]:
		for yi in [y0, y1]:
			for zi in [z0, z1]:
				var q := rot * Vector3(xi, yi, zi) + translacao
				cantos.append(Vector3(q.x, -q.y, -q.z) * k)
	# índice = xi*4 + yi*2 + zi (0 = mínimo, 1 = máximo)
	var faces := [
		[[1, 0, 4, 5], Vector2(u + d, v), Vector2(w, d)],                                   # cima (y mínimo)
		[[2, 3, 7, 6], Vector2(u + d + w, v), Vector2(w, d)],                                # baixo
		[[0, 1, 3, 2], Vector2(u, v + d), Vector2(d, h)],                                    # direita (x mínimo)
		[[6, 2, 0, 4], Vector2(u + d, v + d), Vector2(w, h)],                                # frente (z mínimo)
		[[6, 7, 5, 4], Vector2(u + d + w, v + d), Vector2(d, h)],                            # esquerda (x máximo)
		[[3, 7, 5, 1], Vector2(u + 2.0 * d + w, v + d), Vector2(w, h)],                      # trás (z máximo)
	]
	# 10º item (opcional) = `CubeListBuilder.mirror(true)`: o Minecraft espelha o U de cada face e troca a direita com a esquerda.
	var espelho: bool = c.size() > 9 and bool(c[9])
	if espelho:
		var tmp: Array = faces[2]
		faces[2] = [faces[2][0], faces[4][1], faces[4][2]]
		faces[4] = [faces[4][0], tmp[1], tmp[2]]
	for f in faces:
		var qd: Array = f[0]
		var o: Vector2 = f[1]
		var t: Vector2 = f[2]
		var a := vs.size()
		for i in 4:
			vs.append(cantos[qd[i]])
		var u0 := o.x + t.x if espelho else o.x
		var u1 := o.x if espelho else o.x + t.x
		uvs.append(Vector2(u0, o.y + t.y) / tex)
		uvs.append(Vector2(u1, o.y + t.y) / tex)
		uvs.append(Vector2(u1, o.y) / tex)
		uvs.append(Vector2(u0, o.y) / tex)
		idx.append_array(PackedInt32Array([a, a + 1, a + 2, a, a + 2, a + 3]))


static func _plano(h: float, ang: float) -> Array:
	var r := Basis(Vector3.UP, ang)
	var v := PackedVector3Array([r * Vector3(-h, -h, 0), r * Vector3(h, -h, 0), r * Vector3(h, h, 0), r * Vector3(-h, h, 0)])
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	return a


## Troca a textura (`slash_blue`…); sem arquivo, cor lisa pelo sufixo — nunca fica invisível.
static func texturizar(m: MeshInstance3D, nome: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var rel := "entidades/" + nome
	if nome != "" and FileAccess.file_exists(PASTA + rel + ".png"):
		mat.albedo_texture = _textura_arquivo(rel)
	else:
		mat.albedo_texture = _textura_suave()
		mat.albedo_color = Color(0.8, 0.9, 1.0)
	m.material_override = mat


## Registro de partículas do Minecraft 1.20.1 (`ParticleTypes`, lido do jar): nome fora dele é erro do comando
## ("Unknown particle") no jogo original — não é falta do nosso desenho.
const PARTICULAS_VANILLA: PackedStringArray = [
	"ambient_entity_effect", "angry_villager", "ash", "block", "bubble", "bubble_column_up", "bubble_pop",
	"campfire_cosy_smoke", "campfire_signal_smoke", "cherry_leaves", "cloud", "composter", "crimson_spore",
	"crit", "current_down", "damage_indicator", "dolphin", "dragon_breath", "dripping_dripstone_lava",
	"dripping_dripstone_water", "dripping_honey", "dripping_lava", "dripping_obsidian_tear",
	"dripping_water", "dust", "effect", "egg_crack", "elder_guardian", "electric_spark", "enchant",
	"enchanted_hit", "end_rod", "entity_effect", "explosion", "explosion_emitter", "falling_dripstone_lava",
	"falling_dripstone_water", "falling_honey", "falling_lava", "falling_nectar", "falling_obsidian_tear",
	"falling_spore_blossom", "falling_water", "firework", "fishing", "flame", "flash", "glow",
	"glow_squid_ink", "happy_villager", "heart", "instant_effect", "item", "item_slime", "item_snowball",
	"landing_honey", "landing_lava", "landing_obsidian_tear", "large_smoke", "lava", "mycelium", "nautilus",
	"note", "poof", "portal", "rain", "reverse_portal", "scrape", "sculk_charge_pop", "sculk_soul",
	"small_flame", "smoke", "sneeze", "snowflake", "sonic_boom", "soul", "soul_fire_flame", "spit", "splash",
	"spore_blossom_air", "squid_ink", "sweep_attack", "totem_of_undying", "underwater", "warped_spore",
	"wax_off", "wax_on", "white_ash", "witch"
]


## O jogo original conheceria esta partícula? (vanilla: registro acima; do mod: as extraídas do jar dele).
static func particula_existe(id: String) -> bool:
	_carregar()
	if id.begins_with("minecraft:"):
		return id.trim_prefix("minecraft:") in PARTICULAS_VANILLA
	return (_dados.particulas as Dictionary).has(id)


# ------------------------------------------------------------------ partícula
## `sendParticles`: n > 0 → n partículas com deslocamento ~ (dx,dy,dz) e velocidade `vel`; n == 0 → UMA que
## anda na direção (dx,dy,dz) × vel. Posições e deslocamentos em BLOCOS. true se há desenho para o nome.
static func particula(arvore: SceneTree, id: String, pos_blocos: McVec3, n: int, dx: float, dy: float, dz: float,
		vel: float, cor_propria := Color(0, 0, 0, 0)) -> bool:
	_carregar()
	var mod: Dictionary = (_dados.particulas as Dictionary).get(id, {})
	var estilo: Dictionary = ESTILO.get(id, {})
	if mod.is_empty() and estilo.is_empty():
		return false
	if arvore == null or _emissores_vivos >= MAX_EMISSORES:
		return true
	var m := MundoMinePiece.METROS_POR_BLOCO
	var e := CPUParticles3D.new()
	e.one_shot = true
	e.explosiveness = 0.9
	e.emitting = false
	e.local_coords = false
	# Presença (15/11/2026, medido: 45 de 105 técnicas do mod mudavam <8% da imagem): +50% de partículas e teto 40 → 64. O custo continua limitado por MAX_EMISSORES.
	e.amount = clampi(int(ceil(float(n) * 1.5)) if n > 0 else 1, 1, 64)
	e.position = pos_blocos.para_godot() if pos_blocos != null else Vector3.ZERO
	if n > 0:
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		e.emission_box_extents = Vector3(maxf(dx, 0.05), maxf(dy, 0.05), maxf(dz, 0.05)) * m
		e.direction = Vector3.UP
		e.spread = 180.0
		e.initial_velocity_min = 0.0
		e.initial_velocity_max = clampf(vel, 0.05, 3.0) * m * 3.0
	else:
		var dir := Vector3(dx, dy, dz)
		e.direction = dir.normalized() if dir.length() > 0.0001 else Vector3.UP
		e.spread = 4.0
		e.initial_velocity_min = clampf(vel, 0.05, 3.0) * m * 3.0
		e.initial_velocity_max = e.initial_velocity_min
	var tam := 0.25 * m
	var vida := 0.6
	var aditiva := true
	var cor := Color.WHITE
	var tex: Texture2D
	var frames := 1
	if not mod.is_empty():
		var q := int(mod.quadros)
		var vanilla := id.begins_with("minecraft:")
		# Sprite REAL do Minecraft 1.20.1 (tira extraída do jar por `extrair_particulas_minecraft.py`); a física
		# (tamanho, vida, gravidade, aditiva) segue o `ESTILO`, e só o sprite cinza é tingido.
		tex = _textura_arquivo("particulas/" + ("mc_" + id.trim_prefix("minecraft:") if vanilla else id.trim_prefix("minepiece:")))
		frames = q
		if vanilla and not estilo.is_empty():
			tam = float(estilo.tam) * m
			vida = float(estilo.vida)
			aditiva = bool(estilo.add)
			e.gravity = Vector3(0, -float(estilo.grav) * m, 0)
			cor = estilo.cor if id in TINGIR else Color(1, 1, 1, estilo.cor.a)
		else:
			tam = 0.5 * m * (float(mod.w) / 16.0 if float(mod.w) > 0.0 else 1.0)
			aditiva = true
		# `anim_speed` 1 = a tira inteira passa UMA vez durante a vida da partícula (Godot 4). Multiplicar por
		# quadros ÷ vida (como estava) a levava ao último quadro — transparente na explosão — em poucos ms.
		e.anim_speed_min = 1.0
		e.anim_speed_max = 1.0
	else:
		tex = _textura_suave()
		cor = estilo.cor if cor_propria.a == 0.0 else cor_propria
		tam = float(estilo.tam) * m
		vida = float(estilo.vida)
		aditiva = bool(estilo.add)
		e.gravity = Vector3(0, -float(estilo.grav) * m, 0)
	e.lifetime = vida
	e.scale_amount_min = 0.8
	e.scale_amount_max = 1.2
	# Estoura, murcha e some (13/11/2026): antes a partícula tinha tamanho fixo, girava nada e sumia de repente; nas capturas das 34 frutas do mod
	# o fogo/fumaça/faísca saíam como quadradinhos duros e pequenos. A curva e o fade são de apresentação; o sprite, a vida e a cor seguem o mod.
	e.scale_amount_curve = _curva_de_tamanho()
	e.color_ramp = _rampa_de_fade()
	e.angle_min = -180.0
	e.angle_max = 180.0
	tam *= 1.75      # era 1.3: as partículas do mod (0,25 bloco) liam como pontinhos a 8 m; o sprite, a vida e a cor seguem o mod
	var malha := QuadMesh.new()
	malha.size = Vector2(tam, tam)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditiva else BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_texture = tex
	mat.albedo_color = cor
	mat.vertex_color_use_as_albedo = true
	mat.particles_anim_h_frames = frames
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.no_depth_test = false
	if mod.is_empty():
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	else:
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	malha.material = mat
	e.mesh = malha
	_emissores_vivos += 1
	arvore.root.add_child.call_deferred(e)
	e.set_deferred("emitting", true)
	arvore.create_timer(vida + 0.3).timeout.connect(func() -> void:
		_emissores_vivos -= 1
		if is_instance_valid(e):
			e.queue_free())
	return true


static var _curva: Curve
static var _rampa: Gradient


static func _curva_de_tamanho() -> Curve:
	if _curva == null:
		_curva = Curve.new()
		_curva.add_point(Vector2(0.0, 0.6))
		_curva.add_point(Vector2(0.2, 1.0))
		_curva.add_point(Vector2(1.0, 0.45))
	return _curva


static func _rampa_de_fade() -> Gradient:
	if _rampa == null:
		_rampa = Gradient.new()
		_rampa.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		_rampa.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	return _rampa


static func _textura_arquivo(rel: String) -> Texture2D:
	if not _texturas.has(rel):
		var caminho := PASTA + rel + ".png"
		# Textura IMPORTADA primeiro: `Image.load_from_file` em `res://` não funciona em build exportado (o .png some do pacote;
		# só o .ctex fica) e o Godot avisa a cada carga. O arquivo cru fica de reserva para o que ainda não foi importado.
		if ResourceLoader.exists(caminho):
			_texturas[rel] = load(caminho) as Texture2D
		else:
			var img := Image.load_from_file(caminho) if FileAccess.file_exists(caminho) else null
			_texturas[rel] = ImageTexture.create_from_image(img) if img != null else _textura_suave()
	return _texturas[rel]


## Círculo suave 32 px (as partículas do Minecraft puro não têm arquivo no jar).
static func _textura_suave() -> Texture2D:
	if not _texturas.has("suave"):
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
		_texturas["suave"] = ImageTexture.create_from_image(img)
	return _texturas["suave"]


## O relâmpago: uma coluna recortada (passeio aleatório de ~0,5 m a cada ~1,5 m) do céu até o ponto de impacto, em dois
## planos cruzados sem sombra e com brilho próprio, mais uma luz de clarão. `reforma()` sorteia outro traçado (cada
## reclarão do Minecraft tem a sua forma). Altura ~40 m: o do Minecraft vai até o teto do mundo e some na névoa.
static func raio() -> Node3D:
	var no := Node3D.new()
	no.name = "Desenho"
	no.set_meta(META_FIXO, true)                        # a textura não vem de `setTexture`
	var m := MeshInstance3D.new()
	m.name = "Coluna"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(m)
	var luz := OmniLight3D.new()
	luz.name = "Clarao"
	luz.light_color = Color(0.8, 0.86, 1.0)
	luz.light_energy = 6.0
	luz.omni_range = 18.0
	luz.position = Vector3(0, 3.0, 0)
	no.add_child(luz)
	raio_reforma(no)
	return no


static func raio_reforma(no: Node3D) -> void:
	var m := no.get_node("Coluna") as MeshInstance3D
	var vs := PackedVector3Array()
	var idx := PackedInt32Array()
	var largura := 0.32
	var altura := 40.0
	var passo := 1.5
	var x := 0.0
	var z := 0.0
	var y := altura
	var ponta := Vector3(0, y, 0)
	while y > 0.0:
		var y2 := maxf(0.0, y - passo)
		var alvo := Vector3(x + randf_range(-0.5, 0.5), y2, z + randf_range(-0.5, 0.5))
		if y2 == 0.0:
			alvo.x *= 0.3                               # a ponta acaba perto do ponto de impacto
			alvo.z *= 0.3
		for ang in [0.0, PI * 0.5]:
			var lado := Basis(Vector3.UP, ang) * Vector3(largura, 0, 0)
			var base := vs.size()
			vs.append_array([ponta - lado, ponta + lado, alvo + lado, alvo - lado])
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		ponta = alvo
		x = alvo.x
		z = alvo.z
		y = y2
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.mesh = mesh


# ------------------------------------------------------------------ modelos Java escritos à mão (`CubeListBuilder`)
## `tools/mine_piece/extrair_modelos_java.py` → `visual_do_mod.json: modelos_java` (`tree_root`, `entity_ball`). Vazio = não tem.
static func modelo_java_de(id: String) -> Dictionary:
	_carregar()
	var m: Variant = (_dados.get("modelos_java", {}) as Dictionary).get(id)
	return m if m is Dictionary else {}


## Peças aninhadas: cada uma é "translada, depois gira Z, Y, X" (ordem do Minecraft) relativa ao pai; as caixas vão para
## o espaço do modelo já com a pose acumulada. A textura base é a do renderer (`textura`); camadas extras (gelo sobre a
## raiz) não são desenhadas — ver `camadas_extras`. O tamanho vem do atributo SIZE (o renderer do mod escala por ele).
static func _modelo_java(id: String) -> MeshInstance3D:
	var d := modelo_java_de(id)
	var vs := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var k := MundoMinePiece.METROS_POR_BLOCO / 16.0
	var tex := Vector2(float(d.tex_w), float(d.tex_h))
	var mundo := {"": Transform3D.IDENTITY}                         # nome da peça → pose acumulada (espaço do Minecraft)
	for p: Dictionary in d.partes:
		var pos: Array = p.pos
		var rot: Array = p.rot
		var local := Transform3D(Basis.from_euler(Vector3(rot[0], rot[1], rot[2]), EULER_ORDER_ZYX), Vector3(pos[0], pos[1], pos[2]))
		var acumulada: Transform3D = (mundo.get(p.pai, Transform3D.IDENTITY) as Transform3D) * local
		mundo[p.nome] = acumulada
		for c: Array in p.caixas:
			_caixa_mc(vs, uvs, idx, c, acumulada.origin, acumulada.basis, k, tex)
	# O pivô do modelo fica a 24 do chão (Y para baixo): apoia a base no chão e centra em x/z.
	var minimo := vs[0]
	var maximo := vs[0]
	for q in vs:
		minimo = minimo.min(q)
		maximo = maximo.max(q)
	var deslocamento := Vector3((minimo.x + maximo.x) * 0.5, minimo.y, (minimo.z + maximo.z) * 0.5)
	for i in vs.size():
		vs[i] -= deslocamento
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := MeshInstance3D.new()
	m.name = "Desenho"
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _textura_arquivo("entidades/" + str(d.textura))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.set_meta(META_FIXO, true)
	m.set_meta(&"mc_escala_size", true)
	return m
