extends SceneTree
# ============================================================================
#  FICHAS DE ANIMAL + TAMANHO REAL dos animais da loja (01/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/aplicar_fichas_de_animais.gd
#
#  A TABELA aprovada pelo dono (comportamento de cada animal) e o tamanho em que cada
#  um vive na ilha. Idempotente. Grava no catálogo: `animal` (FichaDeAnimal) e
#  `tamanho_padrao`.
#
#  Medida do tamanho: nos modelos com ESQUELETO a caixa da malha é a da pose de
#  montagem (asas/braços abertos — a águia "mede" 6,2 m de envergadura, o gorila fica
#  de braços abertos); a altura é medida pelos OSSOS na pose de parado. Nos estáticos,
#  pela caixa da malha. Todos olham para +Z (conferido em vista lateral, 01/10).
# ============================================================================

## id -> [comportamento, corpo, medida ("altura" | "maior"), metros, extras da ficha]
## Metros revistos em 01/10/2026 (tabela aprovada pelo dono): o personagem mede 1,51 m
## (modelo, não a cápsula) e os tamanhos tinham sido pensados para ~1,75 m; os
## minúsculos (pintinho, sapo, lagarto, pássaros) ampliados de leve para serem vistos e
## acertados. Fotos: art_src/validation/escala_animais/ (capturar_escala_animais.gd).
const TABELA := {
	# ---- doméstico / fazenda
	"beagle": ["domestico", "quadrupede", "altura", 0.50, {}],
	"corgi": ["domestico", "quadrupede", "altura", 0.45, {}],
	"dog": ["domestico", "quadrupede", "altura", 0.60, {}],
	"dog-9bqpcxoyrk": ["domestico", "quadrupede", "altura", 0.75, {}],
	"dog_final_": ["domestico", "quadrupede", "altura", 0.65, {}],
	"cat": ["domestico", "quadrupede", "altura", 0.35, {"vida": 20}],
	"chicken": ["domestico", "ave_chao", "altura", 0.45, {"vida": 12}],
	"chick": ["domestico", "ave_chao", "altura", 0.20, {"vida": 5, "passeio": 0.7}],
	"duck": ["domestico", "ave_chao", "altura", 0.42, {"vida": 12}],
	"cow": ["domestico", "quadrupede", "altura", 1.30, {"vida": 120, "passeio": 0.8}],
	"horse": ["domestico", "quadrupede", "altura", 1.55, {"vida": 120, "corrida": 7.0}],
	"sheep": ["domestico", "quadrupede", "altura", 0.80, {"vida": 50, "passeio": 0.8}],
	"sheep_-_animated_low_poly": ["domestico", "quadrupede", "altura", 0.80, {"vida": 50, "passeio": 0.8}],
	"pelican_-_animated_low_poly": ["domestico", "ave_chao", "altura", 0.95, {"vida": 40}],
	# ---- presa que foge
	"rabbit": ["presa", "saltador", "altura", 0.35, {"vida": 12, "corrida": 7.0, "alerta": 8.0}],
	"deer": ["presa", "quadrupede", "altura", 1.40, {"vida": 50, "corrida": 8.5, "alerta": 13.0}],
	"deer-blt2gjhppt": ["presa", "quadrupede", "altura", 1.65, {"vida": 60, "corrida": 8.5, "alerta": 14.0}],
	"fox": ["presa", "quadrupede", "altura", 0.55, {"vida": 30, "corrida": 7.5, "alerta": 10.0}],
	"frog": ["presa", "saltador", "altura", 0.20, {"vida": 6, "passeio": 0.8, "corrida": 3.0, "alerta": 4.0}],
	"lizard": ["presa", "rastejante", "maior", 0.80, {"vida": 8, "corrida": 5.0, "alerta": 5.0}],
	"bird_2": ["presa", "voador", "maior", 0.60, {"vida": 6, "passeio": 4.0, "corrida": 9.0, "alerta": 10.0, "altura_voo": 7.0}],
	"bird-h5izaudltz": ["presa", "voador", "maior", 0.60, {"vida": 6, "passeio": 4.0, "corrida": 9.0, "alerta": 10.0, "altura_voo": 8.0}],
	# ---- territorial
	"bufalo": ["territorial", "quadrupede", "altura", 1.55, {"vida": 200, "dano": 4, "alerta": 7.0}],
	"bizon": ["territorial", "quadrupede", "altura", 1.60, {"vida": 200, "dano": 4, "alerta": 7.0}],
	"caranguejo_grande": ["territorial", "caranguejo", "altura", 1.1, {"vida": 120, "dano": 3, "alerta": 5.0, "corrida": 4.0, "passeio": 0.9}],
	"monkey_-_animated_low_poly": ["territorial", "quadrupede", "altura", 0.8, {"vida": 60, "dano": 2, "alerta": 6.0, "corrida": 6.0}],
	# ---- predador
	"bear": ["predador", "quadrupede", "altura", 1.25, {"vida": 220, "dano": 5, "corrida": 6.2}],
	"eagle_-_animated_low_poly": ["predador", "voador", "maior", 2.0, {"vida": 70, "dano": 3, "alerta": 16.0, "passeio": 5.0, "corrida": 11.0, "altura_voo": 14.0}],
	# ---- chefes (presos à área deles nos morros)
	"gorilla_-_animated_low_poly": ["predador", "quadrupede", "altura", 3.2, {"vida": 900, "dano": 7, "alerta": 18.0, "corrida": 5.5, "boss": true}],
	"harpia_-_animated_low_poly": ["predador", "voador", "maior", 7.0, {"vida": 700, "dano": 6, "alerta": 22.0, "corrida": 12.0, "passeio": 6.0, "altura_voo": 12.0, "boss": true}],
}

## Herbívoros que a fruta do pomar doma (decisão do dono, 01/10/2026): pasto grande,
## caça da floresta, ovelhas, macaco e aves de fazenda.
const DOMAVEIS := ["cow", "horse", "bufalo", "bizon", "rabbit", "deer", "deer-blt2gjhppt", "sheep",
	"sheep_-_animated_low_poly", "monkey_-_animated_low_poly", "chicken", "chick", "duck"]

## Como o animal aparece para o jogador (HUD) e no editor.
const NOMES := {
	"beagle": "Beagle", "corgi": "Corgi", "dog": "Cão", "dog-9bqpcxoyrk": "Cão de guarda",
	"dog_final_": "Vira-lata", "cat": "Gato", "chicken": "Galinha", "chick": "Pintinho",
	"duck": "Pato", "cow": "Vaca", "horse": "Cavalo", "sheep": "Ovelha",
	"sheep_-_animated_low_poly": "Carneiro", "pelican_-_animated_low_poly": "Pelicano",
	"rabbit": "Coelho", "deer": "Cervo", "deer-blt2gjhppt": "Alce", "fox": "Raposa",
	"frog": "Sapo", "lizard": "Lagarto", "bird_2": "Pardal", "bird-h5izaudltz": "Andorinha",
	"bufalo": "Búfalo", "bizon": "Bisão", "caranguejo_grande": "Caranguejo gigante",
	"monkey_-_animated_low_poly": "Macaco", "bear": "Urso", "eagle_-_animated_low_poly": "Águia",
	"gorilla_-_animated_low_poly": "Gorila Rei", "harpia_-_animated_low_poly": "Harpia",
}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var erros := 0
	for id: String in TABELA:
		if not bib.tem(id):
			push_error("fora da loja: " + id)
			erros += 1
			continue
		var linha: Array = TABELA[id]
		var extra: Dictionary = (linha[4] as Dictionary).duplicate()
		extra["nome"] = NOMES.get(id, "")
		extra["domavel"] = DOMAVEIS.has(id)
		var ficha := FichaDeAnimal.nova(linha[0], linha[1], extra)
		erros += int(bib.definir_ficha_de_animal(id, ficha) != OK)
		var t: Vector3 = bib.info(id)["tamanho"]
		var real := await _medida_real(bib, id, linha[2])
		var fator: float = float(linha[3]) / real
		erros += int(bib.definir_tamanho_padrao(id, t * fator) != OK)
		var p := bib.tamanho_padrao(id)
		print("ANIMAL %-28s %-11s %-10s alvo %.2f m (%s) -> caixa %.2f × %.2f × %.2f" % [id, linha[0], linha[1],
			linha[3], linha[2], p.x, p.y, p.z])
	print("FICHAS_ANIMAIS %d erros=%d" % [TABELA.size(), erros])
	quit(1 if erros else 0)


## A medida do modelo EM UNIDADES DO CATÁLOGO, na pose em que ele vive:
## ossos na pose de parado (rigados) ou caixa da malha (estáticos).
func _medida_real(bib: BibliotecaDeModelos, id: String, medida: String) -> float:
	var t: Vector3 = bib.info(id)["tamanho"]
	var m := bib.instanciar(id)
	root.add_child(m)
	var sks := m.find_children("*", "Skeleton3D", true, false)
	var resultado := t.y if medida == "altura" else maxf(t.x, maxf(t.y, t.z))
	if not sks.is_empty() and medida == "altura":
		for ap in m.find_children("*", "AnimationPlayer", true, false):
			for nome in (ap as AnimationPlayer).get_animation_list():
				if String(nome).to_lower().contains("idle"):
					(ap as AnimationPlayer).play(nome)
					break
		for i in 3:
			await process_frame
		var sk := sks[0] as Skeleton3D
		var lo := INF
		var hi := -INF
		for b in sk.get_bone_count():
			var y := (sk.global_transform * sk.get_bone_global_pose(b).origin).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		# Ossos param no meio da cabeça e no tornozelo: +12 % cobre crânio e casco.
		resultado = (hi - lo) * 1.12
	m.free()
	return maxf(resultado, 0.01)
