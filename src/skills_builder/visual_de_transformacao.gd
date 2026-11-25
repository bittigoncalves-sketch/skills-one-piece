extends RefCounted
## Formas da transformação. Geometria visual pura, sem scripts/colisão do asset.
const Visual := preload("res://src/skills_builder/visual_de_skill.gd")
static var _fumaca: Texture2D


static func criar(p: Dictionary, tamanho: Vector3) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "FormaTransformada"
	var altura := maxf(tamanho.y, .3) * float(p.get("escala", 1.0))
	var cor := Color(str(p.get("cor", "#dce9ff")))
	var forma := str(p.get("visual", "Fumaça"))
	raiz.set_meta("forma", forma)
	raiz.set_meta("altura", altura)
	if forma == "Modelo da loja":
		var bib := MapaMontador.biblioteca_em_uso()
		var id := str(p.get("modelo", ""))
		if not bib.tem(id):
			raiz.free()
			return null
		var modelo := bib.instanciar(id)
		if modelo == null:
			raiz.free()
			return null
		var info := bib.info(id)
		var escala := altura / maxf((info.tamanho as Vector3).y, .01)
		modelo.scale = Vector3.ONE * escala
		modelo.position = -(info.centro as Vector3) * escala
		_somente_visual(modelo)
		raiz.add_child(modelo)
	elif forma == "Luz":
		raiz.add_child(Visual.esfera_de_brilho("Nucleo", Color(1, .98, .85), altura * .22, .9))
		raiz.add_child(Visual.esfera_de_brilho("Halo", cor, altura * .5, 2.0))
		for i in 12:
			var ponto := Visual.esfera_de_brilho("Foton%d" % i, cor, altura * .025, 1.0)
			raiz.add_child(ponto)
	else:
		# Nuvem de volumes suaves; tempo da timeline, inclusive ao buscar/pausar.
		for i in 14:
			var q := MeshInstance3D.new()
			q.name = "Vapor%d" % i
			var malha := QuadMesh.new()
			malha.size = Vector2.ONE * altura * .68
			q.mesh = malha
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _textura_fumaca()
			mat.albedo_color = Color(cor.darkened(float(i % 3) * .09), .88)
			q.material_override = mat
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			raiz.add_child(q)
	animar(raiz, 0.0)
	return raiz


static func animar(raiz: Node3D, tempo: float) -> void:
	var h := float(raiz.get_meta("altura", 1.0))
	var forma := str(raiz.get_meta("forma", ""))
	if forma == "Luz":
		for nome in ["Nucleo", "Halo"]:
			raiz.get_node(nome).scale = Vector3.ONE * (1.0 + .06 * sin(tempo * 8.0))
		for i in 12:
			var fase := tempo * .8 + i * 2.399
			raiz.get_node("Foton%d" % i).position = Vector3(cos(fase) * .34, sin(fase * .7) * .4, sin(fase) * .34) * h
	elif forma == "Fumaça":
		for i in 14:
			var fase := fposmod(tempo * .24 + float(i) / 14.0, 1.0)
			var angulo := i * 2.399 + tempo * .32
			var raio := (.14 + .12 * sin(i * 1.7)) * h
			var q := raiz.get_child(i) as MeshInstance3D
			q.position = Vector3(cos(angulo) * raio, (fase - .5) * h * .8, sin(angulo) * raio)
			q.scale = Vector3.ONE * (.6 + .6 * fase)
			(q.material_override as StandardMaterial3D).albedo_color.a = sin(fase * PI) * .85


static func _textura_fumaca() -> Texture2D:
	if _fumaca != null: return _fumaca
	var ruido := FastNoiseLite.new()
	ruido.seed = 741
	ruido.frequency = .065
	var imagem := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var r := Vector2(x - 47.5, y - 47.5).length() / 47.5
			var n := ruido.get_noise_2d(x, y) * .5 + .5
			var a := pow(maxf(0.0, 1.0 - r * r), 1.7) * (.5 + n * .5)
			imagem.set_pixel(x, y, Color(1, 1, 1, a))
	_fumaca = ImageTexture.create_from_image(imagem)
	return _fumaca


static func _somente_visual(no: Node) -> void:
	# Catálogo local é a única fonte; comportamento do GLB nunca toma o ator.
	no.set_script(null)
	no.process_mode = Node.PROCESS_MODE_DISABLED
	if no is CollisionObject3D:
		no.collision_layer = 0
		no.collision_mask = 0
	for filho in no.get_children():
		if filho is CollisionShape3D or filho is CollisionPolygon3D:
			no.remove_child(filho)
			filho.free()
		else:
			_somente_visual(filho)
