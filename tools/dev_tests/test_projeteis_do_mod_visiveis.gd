extends SceneTree
## Os projéteis do mod que o jogo não desenhava agora têm corpo (30/10/2026): bullet, heart_bullet, booger (sprito do item,
## como o `ThrownItemRenderer`) e missile (modelo de 9 caixas + 5 peças). E o fuzil do marinheiro cria justamente esses.
## Roda em headless. Não conferi a aparência: só que o corpo existe, tem malha, textura e tamanho coerentes.
var _falhas := 0
func _init() -> void:
	call_deferred("_r")
func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _falhas += 1
func _r() -> void:
	await process_frame
	for id in ["bullet", "heart_bullet", "booger", "missile"]:
		_ok(McVisual.tem_corpo(id), "%s tem corpo desenhado" % id)
	_ok(McVisual.tem_corpo("projectile_slash") and McVisual.tem_corpo("projectile_water_bullet"), "os que já tinham continuam")
	for id in ["entity_wolf_projectile", "vasco_shot"]:
		_ok(not McVisual.tem_corpo(id), "%s ainda NÃO tem (fora do escopo; são mobs, não balas)" % id)

	var sprite := McVisual.corpo("bullet")
	var mat := sprite.material_override as StandardMaterial3D
	_ok(sprite.mesh is QuadMesh and mat != null and mat.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED, "bullet é um quadrado de frente para a câmera")
	_ok(mat.albedo_texture != null and mat.albedo_texture.get_width() == 32 and FileAccess.file_exists("res://assets/mine_piece/visual/entidades/bullet.png"),
		"com a textura item/bullet.png do mod (32×32)")
	_ok(absf((sprite.mesh as QuadMesh).size.x - 0.5 * MundoMinePiece.METROS_POR_BLOCO) < 0.001, "tamanho = meio bloco (%.2f m)" % (sprite.mesh as QuadMesh).size.x)
	_ok(sprite.has_meta(McVisual.META_FIXO), "marcado como textura fixa (o `setTexture` do mod não a troca)")

	var missil := McVisual.corpo("missile")
	var caixa: AABB = missil.mesh.get_aabb()
	_ok((missil.mesh as ArrayMesh).get_surface_count() == 1, "míssil: uma malha")
	# 9 + 1 + 1 + 1 + 1 + 2 caixas × 24 vértices
	var vertices := ((missil.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_ok(vertices == 15 * 24, "míssil: 15 caixas (9 do corpo + 6 das aletas) = %d vértices" % vertices)
	var comprimento := caixa.size.y / MundoMinePiece.METROS_POR_BLOCO
	_ok(comprimento > 2.7 and comprimento < 3.1, "míssil tem ~2,9 blocos de ponta a ponta (y −22 → +24: %.2f)" % comprimento)
	_ok(absf(caixa.get_center().y) < 0.01 and absf(caixa.get_center().x) < 0.05, "a malha está centrada (gira pelo meio, não pelo bico)")
	var mat2 := missil.material_override as StandardMaterial3D
	_ok(mat2.albedo_texture != null and FileAccess.file_exists("res://assets/mine_piece/visual/entidades/missile.png"), "com a textura missile.png do mod")
	_ok(missil.has_meta(&"mc_alinhar_y"), "o corpo alinha o +Y do míssil com a velocidade")
	# UV dentro de [0, 1]
	var uv_ok := true
	for uv: Vector2 in (missil.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
		uv_ok = uv_ok and uv.x >= -0.001 and uv.x <= 1.001 and uv.y >= -0.001 and uv.y <= 1.001
	_ok(uv_ok, "todas as coordenadas de textura caem na imagem")
	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas else 0)
