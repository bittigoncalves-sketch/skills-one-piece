extends RefCounted
## Roupas autorais sobre o UV biped. Mantém rosto, mãos, chapéu, armas e animações.
## Cada textura/material é composto uma vez e compartilhado entre os NPCs iguais.

const ROUPAS := {
	"marinheiro": preload("res://assets/textures/uniformes_faccoes/marinheiro.svg"),
	"pirata": preload("res://assets/textures/uniformes_faccoes/pirata.svg"),
}
static var _materiais: Dictionary = {}
const COR_DA_CAUDA := {"mp_macaco_humanoide": Color(0.45, 0.30, 0.16), "mp_macaco_rei": Color(0.2, 0.14, 0.1)}
## MACACOS HUMANOIDES da Ilha dos Macacos (18/11/2026): o corpo biped de sempre com a PELE inteira trocada por uma skin própria (pelagem, rosto de macaco).
## Modelo → textura (gerada por `tools/mine_piece/gerar_skin_macaco.py`).
const PELES := {
	"mp_macaco_humanoide": preload("res://assets/textures/macacos/pelagem_macaco.png"),
	"mp_macaco_rei": preload("res://assets/textures/macacos/pelagem_macaco_rei.png"),
}


static func grupo_do_modelo(modelo_id: String) -> String:
	if modelo_id == "mp_marine":
		return "marinheiro"
	if modelo_id == "mp_pirate" or modelo_id.begins_with("mp_pirate_pirate") or modelo_id.begins_with("mp_pirate_fishman"):
		return "pirata"
	return ""


static func aplicar(modelo: Node3D, modelo_id: String) -> void:
	if PELES.has(modelo_id):
		_aplicar_pele(modelo, modelo_id)
		return
	var grupo := grupo_do_modelo(modelo_id)
	if grupo.is_empty():
		return
	for no: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for superficie in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(superficie) as StandardMaterial3D
			if base == null or base.albedo_texture == null:
				continue
			var armadura := grupo == "marinheiro" and base.resource_name == "uniform_marine_1_helmet"
			# O uniforme equipado cobre a camisa/calça do marinheiro e tem outro UV.
			if base.resource_name != "corpo" and not armadura:
				continue
			var chave := "%s:%d" % [grupo, base.get_instance_id()]
			if not _materiais.has(chave):
				var mat := _compor(base, grupo, armadura)
				if mat == null:
					continue
				_materiais[chave] = mat
			mi.set_surface_override_material(superficie, _materiais[chave])


static func _compor(base: StandardMaterial3D, grupo: String, armadura: bool) -> StandardMaterial3D:
	var pele := base.albedo_texture.get_image()
	if pele == null:
		return null
	# Texturas GLB podem devolver a mesma Image: nunca alterar a origem compartilhada.
	pele = pele.duplicate() as Image
	if pele.is_compressed() and pele.decompress() != OK:
		return null
	pele.convert(Image.FORMAT_RGBA8)
	var roupa: Image = ROUPAS[grupo].get_image().duplicate()
	roupa.convert(Image.FORMAT_RGBA8)
	var tamanho := roupa.get_width()
	pele.resize(tamanho, tamanho, Image.INTERPOLATE_NEAREST)
	var escala := tamanho / 64
	if armadura:
		# Remapeia a mesma criação para clothes_marine1.geo; mantém o boné original.
		pele.fill_rect(Rect2i(0, 18 * escala, 24 * escala, 14 * escala), Color("c4d2dc"))
		for par: Array in [
			[Rect2i(20, 20, 8, 12), Vector2i(2, 20)],
			[Rect2i(32, 20, 8, 12), Vector2i(12, 20)],
			[Rect2i(0, 16, 16, 16), Vector2i(16, 0)],
		]:
			var r: Rect2i = par[0]
			pele.blit_rect(roupa, Rect2i(r.position * escala, r.size * escala), par[1] * escala)
		# Mangas compartilham UV com a barra frontal: branco e vivo azul contínuos.
		pele.fill_rect(Rect2i(0, 29 * escala, 16 * escala, 3 * escala), Color("eef2ed"))
		pele.fill_rect(Rect2i(0, 31 * escala, 16 * escala, escala), Color("234f83"))
		# Lenço em geometria própria, costuras e botões.
		pele.fill_rect(Rect2i(24 * escala, 17 * escala, 8 * escala, 16 * escala), Color("234f83"))
		pele.fill_rect(Rect2i(20 * escala, 30 * escala, 4 * escala, 3 * escala), Color("d6af62"))
	else:
		# Limpa apenas a segunda camada antiga de roupa; cabeça e mãos ficam intactas.
		for r: Rect2i in [Rect2i(0, 32, 56, 16), Rect2i(0, 48, 16, 16), Rect2i(48, 48, 16, 16)]:
			pele.fill_rect(Rect2i(r.position * escala, r.size * escala), Color.TRANSPARENT)
		pele.blend_rect(roupa, Rect2i(Vector2i.ZERO, roupa.get_size()), Vector2i.ZERO)
	pele.generate_mipmaps()
	var mat := base.duplicate() as StandardMaterial3D
	mat.resource_name = "uniforme_" + grupo
	mat.albedo_texture = ImageTexture.create_from_image(pele)
	mat.albedo_color = Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.9
	return mat


## Troca a textura do material "corpo" pela pele do modelo (mesmo UV do biped); o resto (animação, esqueleto) fica.
static func _aplicar_pele(modelo: Node3D, modelo_id: String) -> void:
	var torso := modelo.find_child("torso", true, false) as Node3D
	if torso != null and torso.get_node_or_null("Cauda") == null:
		var cor: Color = COR_DA_CAUDA[modelo_id]       # um tom abaixo do pelo do corpo (`gerar_skin_macaco.py`)
		preload("res://src/historia/east_blue/cauda_de_macaco.gd").em(torso, cor)
	for no: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for superficie in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(superficie) as StandardMaterial3D
			if base != null and "cutlass" in base.resource_name:
				mi.visible = false                       # o biped de origem traz um sabre embutido: macaco não usa arma
				continue
			if base == null or base.resource_name != "corpo":
				continue
			var chave := "pele:%s:%d" % [modelo_id, base.get_instance_id()]
			if not _materiais.has(chave):
				var mat := base.duplicate() as StandardMaterial3D
				mat.albedo_texture = PELES[modelo_id]
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				# Sob as copas da floresta o macaco lia cinza-azulado (sombra); um brilho próprio com a mesma textura devolve a pelagem sem lavar o desenho.
				mat.emission_enabled = true
				mat.emission_texture = PELES[modelo_id]
				mat.emission_energy_multiplier = 0.5
				_materiais[chave] = mat
			mi.set_surface_override_material(superficie, _materiais[chave])
