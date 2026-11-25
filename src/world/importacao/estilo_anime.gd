@tool
extends EditorScenePostImport
# ============================================================================
#  ESTILO ANIME NA IMPORTAÇÃO — sombreamento em faixas + contorno (02/10/2026).
#
#  Pedido do dono: a besta do mar serpente no estilo do anime (referência
#  ~/Downloads/seaserpent.webp), "anime completo": contorno preto, linhas pintadas e
#  sombreamento toon. O glTF não carrega toon nem contorno; este script, ligado no
#  `.import` de um modelo (`import_script/path`), converte na importação:
#    • cada StandardMaterial3D vira toon (luz e brilho em degrau, sem metal);
#    • ganha um segundo passe de CONTORNO: a malha inflada pelas normais (`grow`), só as
#      faces de trás (`CULL_FRONT`), sem luz — a casca escura aparece na silhueta;
#    • olhos (material com "Olho" no nome) brilham um pouco, como no desenho.
#  Vale para o jogo e para o editor de mapa (os dois usam a cena importada). Hoje só a
#  serpente usa (`mapas/modelos/besta_mar_serpente.glb.import`).
# ============================================================================

## Espessura do contorno no tamanho NATIVO do modelo (a serpente tem ~18 m; ~0,4 %).
const CONTORNO := 0.07
const COR_CONTORNO := Color(0.07, 0.05, 0.045)


func _post_import(scene: Node) -> Object:
	var contorno := StandardMaterial3D.new()
	contorno.resource_name = "Contorno_anime"
	contorno.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	contorno.albedo_color = COR_CONTORNO
	contorno.cull_mode = BaseMaterial3D.CULL_FRONT
	contorno.grow = true
	contorno.grow_amount = CONTORNO
	var feitos := {}
	for no in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var original := mi.mesh.surface_get_material(i)
			if not (original is StandardMaterial3D):
				continue
			if not feitos.has(original):
				feitos[original] = _toon(original as StandardMaterial3D, contorno)
			mi.mesh.surface_set_material(i, feitos[original])
	return scene


func _toon(original: StandardMaterial3D, contorno: Material) -> StandardMaterial3D:
	var m := original.duplicate() as StandardMaterial3D
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.metallic = 0.0
	m.roughness = maxf(m.roughness, 0.85)
	if original.resource_name.contains("Olho"):
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.6
	# Linha de tinta já é a própria linha: contorno nela dobraria a espessura (sujava a testa).
	if not original.resource_name.contains("Tinta"):
		m.next_pass = contorno
	return m
