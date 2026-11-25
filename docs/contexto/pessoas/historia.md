# Modo História — para quem chega

> Versão para agentes: [`../agentes/historia.md`](../agentes/historia.md) · arquivos: [`../INDICE.md#historia`](../INDICE.md#historia)

## O que é

A campanha do jogo. Você nasce como **Civil** (nível 1, vida 20, energia 10, sem poderes) e evolui:
ganha XP, sobe de nível, distribui pontos em atributos e libera habilidades. As regras e os números
vêm de um documento de planejamento do dono (um PDF em `docs/references/modo_historia/`).

O corpo a corpo aqui é **inspirado em Chivalry 2**:

- **clique esquerdo** ataca, e a direção do golpe vem do movimento do mouse: para o lado vira
  gancho, para cima vira golpe de cima, parado sai um jab;
- **clique direito** segurado levanta a guarda; apertado bem na hora do golpe vira **aparo**, que
  abre um **contra-ataque rápido (riposte)**;
- dá para **fintar** (trocar de golpe no começo) e a guarda **quebra** se apanhar demais.

## Onde as coisas estão

| assunto | arquivo |
|---|---|
| a cena do modo, o nascimento do jogador, o boneco de treino | `src/historia/ModoHistoria.gd` |
| nível, XP, pontos, ouro (e onde é salvo) | `src/historia/progressao.gd` |
| inimigos do mapa | `src/historia/inimigo_do_mapa.gd` |
| a regra do combate (ataque, defesa, aparo, finta) | `src/combat/direcional/executor_corpo_a_corpo.gd` |
| os números do boxe (tempos, dano, janelas) | `src/combat/direcional/estilos/boxe.tres` |
| como o mouse vira direção | `src/combat/direcional/entrada_corpo_a_corpo.gd` |

## Como testar jogando

1. `./jogar_historia.sh`
2. Aperte **M** → seção **TESTE** (só aparece em desenvolvimento) → **Combate +1** (sem essa skill
   o Civil não ataca) → escolha um **boneco de duelo**: Parado, Só guarda, Ataca ou Apara e responde.
3. **F10** mostra um painel com o estado do combate (fase, postura, janelas).
4. Na mesma seção TESTE, **Comer Rocket** dá a primeira fruta do modo: **Z** míssil, **X**
   bombardeio em linha, **C** mergulho explosivo e **F** voo curto. Segurar a tecla mostra onde
   o golpe vai cair; soltar apaga. O clique continua sendo o boxe — a fruta não troca de modo.

Os inimigos que já estão no mapa ainda não lutam de volta: para treinar defesa, use o boneco.
Contra o boneco em "Só guarda" dá para ver a guarda segurar a fruta (passa 30% e gasta postura).

## Cuidado com

- **O mapa do Modo História é editado pelo dono.** Testes usam um mapa e um progresso de teste
  fixos; nunca grave no mapa de verdade.
- **Números do combate ficam no `.tres`**, não no código: é lá que se calibra.
- **Jogador e inimigo usam a mesma regra de combate.** Se algo vale para um e não para o outro, é
  defeito (foi assim com a troca de golpes, corrigida em 21/09).

## Para saber mais

- [`../../MODO_HISTORIA.md`](../../MODO_HISTORIA.md) — guia-mestre do modo
- [`../../combat/README.md`](../../combat/README.md) — o combate direcional, peça por peça
- [`../../PLANO_COMBATE_HISTORIA.md`](../../PLANO_COMBATE_HISTORIA.md) — as decisões, fase a fase
