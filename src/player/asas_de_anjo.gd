class_name AsasDeAnjo
extends RefCounted
# ============================================================================
#  ASAS DE ANJO — o golpe exclusivo do Skypean.
#
#  Pedido do dono (2026-09-01): "quando Skypean e o segundo pulo acionado +
#  clique do mouse, um script roda buscando se há jogadores próximos; se houver,
#  o jogador direciona uma voadora na direção do alvo, podendo ser acima, abaixo
#  ou um pouco afastado do usuário do golpe. Caso não acerte, não entra em
#  recarga."
#
#  ------------------------------------------------- AS TRÊS REGRAS QUE O DEFINEM
#  1. SÓ DO SKYPEAN. É identidade de raça, não uma habilidade geral — quem não
#     é Skypean nem chega a testar as outras condições.
#  2. SÓ NO SEGUNDO PULO. Exige o geppo já gasto: é o que amarra o golpe às asas
#     e o separa da Aú, que sai com Espaço no primeiro salto.
#  3. SÓ COM ALVO. Sem alguém por perto o golpe não sai, e o clique segue para a
#     Aú ou para o combo. Uma voadora no vazio seria mobilidade grátis.
#
#  ⚠️ ERRAR NÃO COBRA RECARGA. É o pedido explícito do dono, e muda o caráter do
#  golpe: ele é uma APOSTA de leitura, não um recurso a ser gerido. Quem erra
#  perde o tempo do voo e a posição — punição suficiente — e pode tentar de novo.
#  A recarga só começa quando a hitbox conecta.
#
#  ⚠️ A DIREÇÃO É EM TRÊS DIMENSÕES. "acima, abaixo ou um pouco afastado" quer
#  dizer que o vetor até o alvo NÃO é achatado no plano: perseguir só em X/Z
#  faria o Skypean passar por cima de quem está no chão, que é justamente a
#  situação em que ele estará ao usar isto.
# ============================================================================

## Até onde procurar alguém. Generoso porque o golpe atravessa a distância —
## curto demais, o jogador teria de estar praticamente em cima do alvo, e aí a
## voadora não teria o que fazer.
const ALCANCE_BUSCA := 24.0
## Quão rápido o corpo viaja durante o golpe.
const VELOCIDADE := 27.0
## Quanto tempo o voo dura antes de o corpo voltar ao controle normal.
const DURACAO := 0.58
## Dano. Abaixo do finalizador M1 (112) porque o valor do golpe é alcançar quem
## está fora de alcance, não bater mais forte.
const DANO := 88.0
const KNOCKBACK := 24.0
const HITSTUN := 0.70
const RAIO_HITBOX := 1.9
## Recarga — cobrada SÓ no acerto.
const RECARGA := 11.0
## A raça dona do golpe.
const RACA := "skypiean"


## O golpe cabe agora? Responde sem efeito colateral: quem chama decide.
static func disponivel(dono: Node, recarga_restante: float) -> bool:
	if dono == null or not is_instance_valid(dono):
		return false
	if recarga_restante > 0.0:
		return false
	if String(dono.get("equipped_weapon")) != "":
		return false
	if dono.has_method("is_on_floor") and dono.call("is_on_floor"):
		return false
	if raca_de(dono) != RACA:
		return false
	if geppos_de(dono) < 1:
		return false
	return alvo_de(dono) != null


static func raca_de(dono: Node) -> String:
	var modelo = dono.get("_char_model")
	if modelo is Node3D and (modelo as Node3D).has_meta("raca_id"):
		return String((modelo as Node3D).get_meta("raca_id"))
	return ""


static func geppos_de(dono: Node) -> int:
	var pk = dono.get("_parkour")
	if pk == null or not pk.has_method("geppos"):
		return 0
	return int(pk.call("geppos"))


## O corpo mais PRÓXIMO dentro do alcance, em três dimensões.
##
## ⚠️ Procura em "player" E em "enemy": num treino contra bonecos o golpe tem de
## funcionar igual, senão a única forma de experimentá-lo é numa partida cheia.
static func alvo_de(dono: Node) -> Node3D:
	if not (dono is Node3D):
		return null
	var origem: Vector3 = (dono as Node3D).global_position
	var arvore := dono.get_tree()
	if arvore == null:
		return null
	var melhor: Node3D = null
	var menor := ALCANCE_BUSCA
	for grupo in ["player", "enemy"]:
		for n in arvore.get_nodes_in_group(grupo):
			if n == dono or not (n is Node3D) or not is_instance_valid(n):
				continue
			if n.has_method("esta_morto") and bool(n.call("esta_morto")):
				continue
			var d: float = origem.distance_to((n as Node3D).global_position)
			if d < menor:
				menor = d
				melhor = n
	return melhor


## A direção do voo: do peito de quem ataca ao peito do alvo, sem achatar.
static func rumo(dono: Node3D, alvo: Node3D) -> Vector3:
	var v: Vector3 = alvo.global_position - dono.global_position
	if v.length_squared() < 0.001:
		return Vector3.FORWARD
	return v.normalized()
