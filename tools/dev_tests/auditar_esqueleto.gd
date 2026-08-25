extends SceneTree
# AUDITORIA DO ESQUELETO do jogador: hierarquia real vs. hierarquia DECLARADA
# (BodyScanner/SkeletonDriver.RIG_PARENT/bake_mixamo.MAP), proporções dos
# segmentos contra a referência humana, e simetria L/R.
#   godot --headless --path . -s tools/dev_tests/auditar_esqueleto.gd
const ROLES := ["Torso","Neck","Head","UpperArm_L","ForeArm_L","UpperArm_R","ForeArm_R",
	"Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R"]
# Cânone humano (fração da altura total). Fonte: proporções de 7,5 cabeças.
const CANON := {"coxa": 0.245, "canela": 0.246, "braco": 0.186, "antebraco": 0.146}

func _init() -> void: _run()

func _run() -> void:
	await process_frame
	for cid in ["base", "nami", "ace", "blackbeard", "crocodile", "buggy"]:
		print("\n========== ", cid.to_upper(), " ==========")
		var data := CharacterBuilder.build_character(cid)
		var modelo: Node3D = data["node"]
		get_root().add_child(modelo)
		var skin: bool = data.get("skinned", false)
		var ab := PlayerModelKit.skeleton_aabb(modelo) if skin else PlayerModelKit.model_aabb(modelo)
		var ky: float = 1.5 / maxf(ab.size.y, 0.01)
		modelo.scale = Vector3(ky, ky, ky)
		await process_frame
		var prof := BodyScanner.scan(modelo)
		var n: Dictionary = prof["nodes"]
		var m: Dictionary = prof["metrics"]
		var faltando := []
		for r in ROLES:
			if not n.has(r): faltando.append(r)
		print("papeis resolvidos: %d/13%s" % [n.size(), ("" if faltando.is_empty() else "  FALTA: " + ", ".join(faltando))])

		# --- hierarquia REAL (pai mais próximo que também é papel) ---
		if not skin:
			var DECL := {"Torso":"","Neck":"Torso","Head":"Torso","UpperArm_L":"Torso","ForeArm_L":"UpperArm_L",
				"UpperArm_R":"Torso","ForeArm_R":"UpperArm_R","Thigh_L":"Torso","Shin_L":"Thigh_L",
				"Foot_L":"Shin_L","Thigh_R":"Torso","Shin_R":"Thigh_R","Foot_R":"Shin_R"}
			for r in ROLES:
				if not n.has(r): continue
				var p: Node = (n[r] as Node3D).get_parent()
				var real := ""
				while p != null:
					if ROLES.has(String(p.name)): real = String(p.name); break
					p = p.get_parent()
				if real != DECL.get(r, "!"):
					print("  ⚠ HIERARQUIA: '%s' declarado filho de '%s' mas o pai REAL é '%s'" % [r, DECL.get(r,"?"), real if real != "" else "(raiz)"])

		# --- comprimentos e proporções ---
		var alt: float = ab.size.y * ky
		var d := func(a, b): return (n[a] as Node3D).global_position.distance_to((n[b] as Node3D).global_position) if (n.has(a) and n.has(b)) else 0.0
		var coxa: float = d.call("Thigh_L","Shin_L")
		var canela: float = d.call("Shin_L","Foot_L")
		var braco: float = d.call("UpperArm_L","ForeArm_L")
		print("altura %.2f m | coxa %.3f (%.1f%% h, canon %.1f%%) | canela %.3f (%.1f%%, canon %.1f%%) | canela/coxa %.0f%% (humano ~100%%)" % [
			alt, coxa, 100.0*coxa/alt, 100.0*CANON["coxa"], canela, 100.0*canela/alt, 100.0*CANON["canela"],
			100.0*canela/maxf(coxa,0.001)])
		print("braço %.3f (%.1f%% h, canon %.1f%%) | perna total %.3f (%.1f%% h, canon %.1f%%)" % [
			braco, 100.0*braco/alt, 100.0*CANON["braco"], coxa+canela, 100.0*(coxa+canela)/alt,
			100.0*(CANON["coxa"]+CANON["canela"])])
		# simetria
		var cL: float = d.call("Thigh_L","Shin_L"); var cR: float = d.call("Thigh_R","Shin_R")
		var bL: float = d.call("UpperArm_L","ForeArm_L"); var bR: float = d.call("UpperArm_R","ForeArm_R")
		var assim: float = maxf(absf(cL-cR)/maxf(cL,0.001), absf(bL-bR)/maxf(bL,0.001))
		print("simetria L/R: %.2f%% de diferença%s" % [100.0*assim, "  ⚠" if assim > 0.02 else ""])
		modelo.queue_free()
	quit()
