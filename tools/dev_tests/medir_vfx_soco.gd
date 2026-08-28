extends SceneTree
# ============================================================================
#  O ANEL DO SOCO ACOMPANHA A DIREÇÃO DO GOLPE?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_vfx_soco.gd
#
#  Relato do dono: "o efeito visual que o clique libera aponta sempre para a
#  mesma direção".
#
#  Era verdade e a causa era literal: `Melee._impacto` fazia
#  `m.rotation.x = PI * 0.5` — uma rotação FIXA NO MUNDO. A POSIÇÃO do anel
#  acompanhava o soco; a ORIENTAÇÃO, não. Socar para o norte e para o sul
#  desenhava o mesmo anel virado para o mesmo lado.
#
#  ⚠️ A sonda chama `Melee.golpear` DIRETO, e não simula o clique. Reproduzir o
#  clique testaria a encanação de entrada (buffer, FSM, recaptura do cursor) —
#  e o defeito não está lá. Sonda deve medir o que se quer saber.
#
#  ⚠️ A MEDIDA É O EIXO DO TORO — o `+Y` LOCAL dele. A primeira versão desta
#  sonda media o `−Z` do nó e dava 0,000 em tudo: com a rotação FIXA antiga o −Z
#  também apontava para cima, então ela não distinguia o defeito do conserto.
#  Sonda que dá o mesmo número nos dois casos não está medindo o que interessa.
#
#  E usa |dot|, não dot: um anel é simétrico em torno do eixo, então eixo = +dir
#  e eixo = −dir desenham exatamente a mesma coisa na tela.
# ============================================================================

var _ok_n := 0
var _falhas := 0
var _eixos: Array = []

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)

	var cena: Node = get_root().get_tree().current_scene
	print("=== eixo do anel × direção do golpe ===")
	print("rumo | direção pedida        | eixo do anel          | dot")
	for graus in [0, 45, 90, 135, 180, 225, 270, 315]:
		var yaw := deg_to_rad(float(graus))
		var dir := RosaDosVentos.frente(yaw)
		var antes := _aneis(cena, p.global_position)
		Melee.golpear(cena, p, 0, p.global_position + Vector3.UP, dir)
		# a janela do golpe é derivada do frame data; 40 quadros cobrem com folga
		var eixo := Vector3.ZERO
		for i in 40:
			await process_frame
			for m in _aneis(cena, p.global_position):
				if antes.has(m.get_instance_id()):
					continue
				# o suporte APONTA na direção do golpe: o −Z dele é o eixo do anel
				eixo = -m.global_transform.basis.z
				break
			if eixo != Vector3.ZERO:
				break
		# ⚠️ ESPERA LONGA ENTRE CASOS. O anel do impacto nasce com RETARDO (a janela
		# vem do frame data), e com 25 quadros o anel do golpe anterior ainda não
		# tinha aparecido quando o instantâneo do caso seguinte era tirado — cada
		# célula media o golpe ANTERIOR, com atraso de exatamente um passo. É o
		# mesmo defeito que a sonda das direções das skills já teve.
		for i in 70:
			await process_frame
		if eixo == Vector3.ZERO:
			print("%4d | (nenhum anel criado)" % graus)
			_ok("rumo %d°: o anel existe" % graus, false)
			continue
		var dot: float = absf(eixo.normalized().dot(dir.normalized()))
		print("%4d | (%+.2f,%+.2f,%+.2f) | (%+.2f,%+.2f,%+.2f) | %+.3f" % [
			graus, dir.x, dir.y, dir.z, eixo.x, eixo.y, eixo.z, dot])
		_ok("rumo %d°: o anel aponta para onde o soco foi" % graus, dot > 0.95)
		_eixos.append(eixo.normalized())

	# ⚠️ O SINTOMA RELATADO ERA "aponta SEMPRE para a mesma direção". Então não
	# basta cada anel bater com o seu rumo: os eixos entre rumos diferentes têm
	# de SER diferentes. Sem esta conferência, um anel travado num eixo que por
	# acaso batesse com um dos rumos passaria.
	var iguais := 0
	for i in range(1, _eixos.size()):
		if absf((_eixos[i] as Vector3).dot(_eixos[0])) > 0.99:
			iguais += 1
	print("\neixos iguais ao primeiro: %d de %d" % [iguais, maxi(_eixos.size() - 1, 1)])
	_ok("os anéis NÃO ficam todos no mesmo eixo", iguais < _eixos.size() - 1)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Os anéis do impacto. O toro é filho de um SUPORTE que aponta na direção do
## golpe (ver `Melee._impacto`), então o que interessa medir é o suporte.
## ⚠️ SÓ OS ANÉIS PERTO DO JOGADOR. Os bonecos de treino socam sozinhos e criam
## os MESMOS anéis — a primeira versão pegava os deles e media as direções em que
## ELES batiam, o que produziu um resultado errado e convincente (variava por
## rumo, só que sem relação nenhuma com o golpe medido). Congelar os bonecos não
## basta: o que atrapalha é o anel que já estava a caminho.
func _aneis(cena: Node, perto_de: Vector3) -> Array:
	var out: Array = []
	for f in cena.get_children():
		if not (f is Node3D) or (f as Node3D).global_position.distance_to(perto_de) > 6.0:
			continue
		for g in f.get_children():
			if g is MeshInstance3D and (g as MeshInstance3D).mesh is TorusMesh:
				out.append(f)
				break
	return out


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
