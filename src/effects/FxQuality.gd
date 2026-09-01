class_name FxQuality
extends RefCounted

## Orçamento visual por perfil. Não decide dano, hitbox nem telegraph essencial;
## apenas a riqueza secundária (densidade, persistência e luz de destaque).
const FATORES := {
	"pc":      {"essencial": 1.0, "padrao": 1.0,  "hero": 1.0},
	"tablet":  {"essencial": 0.9, "padrao": 0.72, "hero": 0.55},
	"celular": {"essencial": 0.8, "padrao": 0.45, "hero": 0.28},
}

static func perfil() -> String:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore and arvore.root:
		var fluxo := arvore.root.get_node_or_null("GameFlow")
		if fluxo:
			var p := str(fluxo.get("device"))
			if FATORES.has(p):
				return p
	return "pc"

static func fator(categoria: String = "padrao") -> float:
	var tabela: Dictionary = FATORES.get(perfil(), FATORES["pc"])
	return float(tabela.get(categoria, tabela["padrao"]))

static func quantidade(base: int, categoria: String = "padrao") -> int:
	return maxi(1, int(round(float(base) * fator(categoria))))

static func duracao(base: float, categoria: String = "padrao") -> float:
	# O elemento principal conserva sua duração; apenas camadas secundárias saem
	# mais cedo nos aparelhos menores para liberar overdraw e memória.
	return base if categoria == "essencial" else base * lerpf(0.72, 1.0, fator(categoria))

static func permite_luz(categoria: String = "padrao") -> bool:
	return categoria != "hero" or perfil() != "celular"
