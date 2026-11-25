extends SceneTree
# ============================================================================
#  O PLANO DA LÂMINA — o que o `test_corte_horizontal` NÃO mede
#
#  godot --headless --path . --script tools/dev_tests/medir_fio_yoru.gd
#
#  Relato do dono (09/09/2026, com vídeo): "no golpe vertical está sendo
#  executado com a lâmina na horizontal, o que é um erro".
#
#  ⚠️ O INSTRUMENTO QUE EXISTIA NÃO ENXERGA ISSO. O `test_corte_horizontal` mede
#  o ângulo do EIXO da lâmina (guarda->ponta) com a vertical. Uma espada pode ter
#  o eixo perfeitamente correto e ainda assim estar ROLADA 90° sobre si mesma —
#  cortando de chapa. Eixo e rolamento são dois graus de liberdade diferentes, e
#  só um deles estava sob medição.
#
#  ------------------------------------------- A GEOMETRIA (medida, não suposta)
#  `tools/dev_tests/medir_lamina_yoru.gd` sobre `yoru_v2.glb`, por seção
#  transversal ao longo do comprimento:
#     +X local = FIO    -> a espessura afina até 0,0000 m (a aresta)
#     -X local = DORSO  -> chanfro de 0,006·(1-t) m
#     +Y local = comprimento (guarda 0,39 -> ponta 1,77)
#     ±Z local = as duas FACES
#  Bate com `tools/blender/yoru_master.py` e com o nó autoral `edge_direction`.
#
#  ------------------------------------------------------------- AS TRÊS CONTAS
#  Tudo em espaço LOCAL do personagem, para não depender da câmera.
#
#  1. CORTA OU BATE DE CHAPA — ângulo entre o deslocamento da ponta e o PLANO da
#     lâmina.  0° = viaja dentro do próprio plano (corta); 90° = perpendicular.
#  2. O FIO LIDERA? — dot(deslocamento, fio). +1 = corta de fio; -1 = de DORSO.
#  3. O PLANO ESTÁ EM PÉ? — ângulo da normal da chapa com a VERTICAL.
#     90° = plano da lâmina VERTICAL (o que o corte vertical exige);
#      0° = plano DEITADO (o defeito relatado).
#
#  ⚠️ Mede pelo caminho VIVO (`YoruRig.pose`), não pelo `WeaponPoses` antigo. A
#  primeira versão deste medidor disparava `_net_play_melee`, que é o caminho
#  legado: o `YoruController` fixa `sword.global_basis` todo quadro, então a
#  espada ficava presa na pose de GUARDA e as três contas saíam constantes
#  (0, 0.6, 0.8 — que é exatamente `Basis(RIGHT,-0.644)·z`). Medir o sistema
#  errado dá número estável e sem sentido.
# ============================================================================
const PASSOS := 60

# ⚠️ FIXTURE COM O CAMPO DECLARADO. Um `Node3D` cru não tem `_char_model`, e
# `set()` em propriedade inexistente falha EM SILÊNCIO: o `YoruRig.setup` recebia
# `null`, caía no rig legado (`detailed = false`) e todas as contas saíam vazias.
# Mesmo padrão do `tools/dev_tests/test_yoru_rig.gd`.
class Fixture extends Node3D:
	var _char_model: Node3D
	var _proc_anim: Node

func _init() -> void:
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var p := Fixture.new()
	mundo.add_child(p)
	var modelo := CharacterBuilder.build_character("base").node as Node3D
	p._char_model = modelo
	p.add_child(modelo)
	var caixa := PlayerModelKit.model_aabb(modelo)
	modelo.scale = Vector3.ONE * (1.5 / caixa.size.y)
	var mao: Node3D = modelo.find_child("Weapon_R", true, false)
	mao.rotation.x = PI
	var espada := YoruSword.ligar_na_mao(mao)
	var rig := YoruRig.new()
	rig.setup(p, espada)
	print("rig detalhado: %s" % rig.detailed)
	for id in ["M1_1", "M1_2", "Z", "X", "V", "C"]:
		_medir(rig, espada, modelo, id)
	quit()

func _medir(rig: YoruRig, espada: Node3D, modelo: Node3D, id: String) -> void:
	var dur: float = YoruMoves.duration(id)
	var m := YoruMoves.get_move(id)
	var ini: float = float(m.startup) / dur
	var fim: float = (float(m.startup) + float(m.active)) / dur
	var ant := Vector3.ZERO
	var tem := false
	var pior := 0.0
	var soma_fio := 0.0
	var soma_plano := 0.0
	var dorso := 0
	var n := 0
	for i in PASSOS + 1:
		var t: float = dur * float(i) / float(PASSOS)
		rig.pose(id, t, Vector3.FORWARD)
		var ponta: Vector3 = (espada.get("ponta") as Node3D).global_position
		if not tem:
			ant = ponta
			tem = true
			continue
		var desloc := ponta - ant
		ant = ponta
		if desloc.length() < 1e-5:
			continue
		var frac: float = t / dur
		if frac < ini or frac > fim:
			continue                      # só a janela de dano
		var inv := modelo.global_basis.orthonormalized().inverse()
		var b: Basis = (espada as Node3D).global_basis.orthonormalized()
		var fio := (inv * b.x).normalized()
		var chapa := (inv * b.z).normalized()
		var v := (inv * desloc).normalized()
		var desal := rad_to_deg(asin(clampf(absf(v.dot(chapa)), 0.0, 1.0)))
		pior = maxf(pior, desal)
		soma_fio += v.dot(fio)
		soma_plano += rad_to_deg(acos(clampf(absf(chapa.dot(Vector3.UP)), 0.0, 1.0)))
		if v.dot(fio) < 0.0:
			dorso += 1
		n += 1
	if n == 0:
		print("  %-5s (parado: sem deslocamento na janela)" % id)
		return
	print("  %-5s desalinho máx %5.1f° [0=corta 90=chapa] | fio·v %+5.2f | dorso %2d/%d | plano x vertical %5.1f° [90=em pé]"
		% [id, pior, soma_fio / float(n), dorso, n, soma_plano / float(n)])
