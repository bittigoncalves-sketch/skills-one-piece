extends SceneTree
## Auditoria (30/10/2026): das entidades-projétil do Mine Piece, quais o jogo DESENHA (`McVisual.tem_corpo`)?
## E, dessas, quais procedimentos de IA da Marinha as criam. Só leitura, roda em headless.
func _init() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/east_blue/entidades_do_mod.json"))
	var ent: Dictionary = d.get("entidades", d)
	var vistas := []
	for id in ent:
		var f: Dictionary = ent[id]
		var base := str(f.get("base", ""))
		if base in ["AbstractArrow", "ThrowableItemProjectile", "ThrowableProjectile", "Projectile"] or "projectile" in str(id) or "bullet" in str(id) or "shot" in str(id):
			vistas.append(id)
	vistas.sort()
	var sem := 0
	print("%-34s %-22s %s" % ["entidade", "base", "desenhada?"])
	for id in vistas:
		var tem: bool = McVisual.tem_corpo(str(id))
		if not tem:
			sem += 1
		print("%-34s %-22s %s" % [id, str(ent[id].get("base", "")), "sim" if tem else "NÃO (invisível)"])
	print("\n%d projéteis, %d sem desenho" % [vistas.size(), sem])
	# Quem, da Marinha, cria cada projétil (procedimentos de IA e de ataque que citam a classe).
	var classes := {}
	for id in vistas:
		classes[str(ent[id].get("classe", ""))] = str(id)
	for arq in ["AttackRifleProcedure", "AIMobProcedure", "AIHelmeppoProcedure", "AICobyProcedure", "LogicRifleProcedure"]:
		var t := FileAccess.get_file_as_string("res://src/minecraft/gerado/procedures/%s.gd" % arq)
		var usa := []
		for c in classes:
			if c != "" and t.contains('"%s"' % c):
				usa.append(classes[c])
		print("procedimento %-24s cria: %s" % [arq, str(usa) if not usa.is_empty() else "(nenhum projétil direto)"])
	quit()
