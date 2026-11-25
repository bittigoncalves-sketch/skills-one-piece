class_name ModeloDeItemEF
extends RefCounted
## MODELO VOXEL DE UM ITEM DO EPIC FIGHT, a partir da textura REAL do mod (12/11/2026).
## O mod desenha a arma na mão como o Minecraft desenha todo `item/generated`: o sprite (24×24 espada longa, 32×32 montante, 40×40 lança, 30×30 tachi,
## 16×16 adaga…) EXTRUDADO, com a lâmina na diagonal do sprite (cabo embaixo à esquerda, ponta em cima à direita) girada para ficar em pé na mão.
## Aqui é igual, em voxels: cada pixel opaco vira um cubo (cor do pixel), com espessura de 1 pixel. As faces entre pixels vizinhos são cortadas.
## O cabo e a ponta saem do sprite sozinhos (extremos da diagonal), então vale para qualquer item do mod sem tabela de medidas.
## Texturas ficam em `assets/epic_fight/itens/` (LOCAL, fora do git: All Rights Reserved; `tools/epic_fight/extrair_itens.py`).
## Contrato: o cabo termina em y = −`RECUO_DO_CABO` e a ponta fica em y = `base + comprimento` (a lâmina aponta para +Y, como o resto do jogo).

const PASTA := "res://assets/epic_fight/"
const RECUO_DO_CABO := 0.12
const ESPESSURA_EM_PIXELS := 1.0
static var _cache := {}


## `{cena: PackedScene, pixel: float, pontas: Vector2}` ou {} se a textura não existe. `total` = distância cabo→ponta em metros.
static func construir(textura: String, total: float) -> Dictionary:
	var chave := "%s|%.3f" % [textura, total]
	if _cache.has(chave):
		return _cache[chave]
	var caminho := ProjectSettings.globalize_path(PASTA + textura)
	if textura == "" or not FileAccess.file_exists(caminho):
		return {}
	var img := Image.load_from_file(caminho)
	if img == null or img.is_empty():
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var cabo := Vector2i(-1, -1)
	var ponta := Vector2i(-1, -1)
	var menor := 1 << 30
	var maior := -(1 << 30)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			var placar := x + (h - 1 - y)            # diagonal "para cima e para a direita"
			if placar < menor:
				menor = placar
				cabo = Vector2i(x, y)
			if placar > maior:
				maior = placar
				ponta = Vector2i(x, y)
	if cabo.x < 0:
		return {}
	var u := Vector2(ponta.x - cabo.x, -(ponta.y - cabo.y))      # em y para cima
	var comprimento_px := maxf(u.length(), 1.0)
	var pixel := total / comprimento_px
	var giro := deg_to_rad(90.0) - atan2(u.y, u.x)               # leva cabo→ponta para +Y
	var c := cos(giro)
	var sn := sin(giro)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meia := pixel * 0.5
	var prof := pixel * ESPESSURA_EM_PIXELS * 0.5
	for y in h:
		for x in w:
			var cor := img.get_pixel(x, y)
			if cor.a < 0.5:
				continue
			var local := Vector2(x - cabo.x, -(y - cabo.y)) * pixel          # centro do pixel relativo ao cabo (y para cima)
			var centro := Vector2(local.x * c - local.y * sn, local.x * sn + local.y * c)
			var vizinho_esq := x > 0 and img.get_pixel(x - 1, y).a >= 0.5
			var vizinho_dir := x < w - 1 and img.get_pixel(x + 1, y).a >= 0.5
			var vizinho_cima := y > 0 and img.get_pixel(x, y - 1).a >= 0.5
			var vizinho_baixo := y < h - 1 and img.get_pixel(x, y + 1).a >= 0.5
			_pixel(st, centro, meia, prof, c, sn, Color(cor.r, cor.g, cor.b, 1.0), [vizinho_esq, vizinho_dir, vizinho_cima, vizinho_baixo])
	var malha := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.15
	mat.roughness = 0.6
	malha.surface_set_material(0, mat)
	var raiz := Node3D.new()
	raiz.name = "ItemEpicFight"
	var mi := MeshInstance3D.new()
	mi.name = "Voxels"
	mi.mesh = malha
	mi.position = Vector3(0.0, -RECUO_DO_CABO, 0.0)
	raiz.add_child(mi)
	mi.owner = raiz
	var cena := PackedScene.new()
	cena.pack(raiz)
	raiz.free()
	var r := {"cena": cena, "pixel": pixel, "pontas": Vector2(-RECUO_DO_CABO, -RECUO_DO_CABO + total)}
	_cache[chave] = r
	return r


## Um pixel como cubo girado em Z (o sprite é plano em XY, a espessura vai em Z). `viz` = esquerda, direita, cima, baixo (sem face onde há vizinho).
static func _pixel(st: SurfaceTool, centro: Vector2, meia: float, prof: float, c: float, sn: float, cor: Color, viz: Array) -> void:
	var cantos := [Vector2(-meia, -meia), Vector2(meia, -meia), Vector2(meia, meia), Vector2(-meia, meia)]
	var p: Array[Vector2] = []
	for k in cantos:
		p.append(centro + Vector2(k.x * c - k.y * sn, k.x * sn + k.y * c))
	var frente := Vector3(0, 0, 1)
	var fundo := Vector3(0, 0, -1)
	_quad(st, [Vector3(p[0].x, p[0].y, prof), Vector3(p[1].x, p[1].y, prof), Vector3(p[2].x, p[2].y, prof), Vector3(p[3].x, p[3].y, prof)], frente, cor)
	_quad(st, [Vector3(p[1].x, p[1].y, -prof), Vector3(p[0].x, p[0].y, -prof), Vector3(p[3].x, p[3].y, -prof), Vector3(p[2].x, p[2].y, -prof)], fundo, cor)
	# laterais: esquerda (p3→p0), direita (p1→p2), cima (p2→p3), baixo (p0→p1)
	var lados := [[3, 0, Vector2(-1, 0)], [1, 2, Vector2(1, 0)], [2, 3, Vector2(0, 1)], [0, 1, Vector2(0, -1)]]
	for i in 4:
		if viz[i]:
			continue
		var a: Vector2 = p[lados[i][0]]
		var b: Vector2 = p[lados[i][1]]
		var n2: Vector2 = lados[i][2]
		var n := Vector3(n2.x * c - n2.y * sn, n2.x * sn + n2.y * c, 0)
		_quad(st, [Vector3(a.x, a.y, prof), Vector3(b.x, b.y, prof), Vector3(b.x, b.y, -prof), Vector3(a.x, a.y, -prof)], n, cor)


static func _quad(st: SurfaceTool, v: Array, normal: Vector3, cor: Color) -> void:
	# a ordem dos vértices é a da Godot para a face de frente (sentido horário visto de fora); corrige pela normal
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var d: Vector3 = v[2]
	if (b - a).cross(d - a).dot(normal) > 0.0:
		v = [v[0], v[3], v[2], v[1]]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(cor)
		st.set_normal(normal)
		st.add_vertex(v[idx])
