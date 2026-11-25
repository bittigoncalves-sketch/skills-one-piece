# Arquitetura

## As camadas, e o que cada uma pode saber

```
       decide                    regra                      corpo
  ┌──────────────┐        ┌──────────────────┐        ┌────────────────┐
  │ EntradaCorpo │ pedido │ ExecutorCorpoA   │ pose   │ AtorDeCombate  │
  │ ACorpo (LMB/ ├───────►│ Corpo            ├───────►│ (jogador/boneco│
  │ RMB, gesto)  │        │ estados, relógio,│        │  /futuro chefe)│
  └──────────────┘        │ contato, defesa  │        └───────┬────────┘
  ┌──────────────┐        └───┬─────────┬────┘                │ escreve
  │ CerebroDe    │ pedido     │ sinais  │ lê                  ▼
  │ Treino (IA)  ├────────────┘         │            ┌────────────────┐
  └──────────────┘                      │            │AplicadorDePose │
                                        ▼            │ IK + pé de apoio│
                            ┌────────────────────┐   └────────────────┘
                            │ApresentacaoDeCombate│
                            │ som, tremor, impacto│
                            └────────────────────┘
```

- **Quem decide** (jogador ou IA) só chama `pedir_ataque`, `erguer_guarda`,
  `baixar_guarda`. Nada mais. É isso que faz o boneco de treino lutar com a mesma
  regra do jogador, sem um segundo caminho de código.
- **A regra** (`ExecutorCorpoACorpo`) não conhece `Player`, teclado nem câmera. Ela
  recebe um `AtorDeCombate` e um `EstiloCorpoACorpo`, e emite sinais.
- **O corpo** entra por um adaptador (`AtorJogador`, `AtorBoneco`): ele diz qual é o
  nó físico, qual é o modelo visível, se o corpo está preso (atordoado, derrubado) e
  aplica a pose. O que é comum a qualquer corpo com o rig `base_v2` mora na base.
  `impedido(contar_atordoamento)` separa o atordoamento do dano das travas duras: o
  golpe que trocou dano no ATIVO pergunta só pelas duras (REGRAS, §7.1).
- **A apresentação** só ouve sinais. Trocar um som ou uma faísca nunca muda quando o
  golpe acerta.

## O relógio: um só

Toda ação corre em `_t_acao`, avançado em `avancar(delta)` a partir do
`_physics_process` do corpo. A fase (PREPARO/ATIVO/RECUPERAÇÃO) é **derivada** desse
tempo pela ficha do golpe (`GolpeDirecional.fase_em`), nunca por `SceneTreeTimer`.
Cancelar é trocar a identidade (`id_acao`), então qualquer coisa agendada para a ação
antiga se torna inválida sozinha.

Consequência prática: hitstop é só parar esse relógio (`pausar`), por ator. Nunca se
usa `Engine.time_scale` — ele congelaria o mundo inteiro, inclusive quem não está na
briga (há teste cobrando isso).

## A pose entra DEPOIS do animador

O `ProceduralAnimator` continua fazendo a locomoção de sempre. A camada de combate
roda depois (o executor é filho do corpo, logo a ordem da árvore garante) e
SUBSTITUI, com peso, só os papéis que a pose escreve:

- **mãos e pés por ALVO** (posição no espaço do corpo) → IK de dois ossos;
- **coluna, quadril, cabeça, antepé e dedos por ROTAÇÃO** (graus somados ao repouso).

Com peso 1 a pose sai exata; entre 0 e 1 ela mistura com o animador — é a mistura que
evita estalo na entrada e na saída da ação. Andando, as PERNAS voltam para a marcha
do animador (pose de perna parada num corpo que se desloca faria o pé patinar); o
avanço do próprio golpe não conta como andar.

Ver [DADOS.md](DADOS.md) para o contrato das poses e o pé de apoio.

## Onde isto é ligado (e só ali)

`ModoHistoria.instalar_combate_direcional(jogador)` monta, como filhos do jogador:
executor + entrada + apresentação (+ painel de depuração na autoridade). É chamado ao
colocar o Civil no mapa. Nenhum outro modo chama essa função.

No `Player.gd` existe apenas uma PONTE — desvios posicionais, sem regra: campo
`combate_direcional`, consultas públicas (`esta_atacando`, `corpo_livre_para_golpe`),
o fator de movimento e o teto de giro por fase, o avanço somado à velocidade e a
entrada encaminhada. São 9 pontos; o gatilho para extrair um `PonteDeCombate` é um
desvio passar de 3 linhas de lógica ou aparecer o 10º ponto (§14 do plano).

## O que ficou intocado, de propósito

`DamageZone`, `CombatResolver`, `Melee`, `MeleeController`, `ProceduralAnimator`,
`FightingStyles` (o "estilo de luta" do menu M, que são as skills Z/X/C/V), inventário,
mundo e terreno. O dano final ainda passa pelo `CombatResolver.aplicar(...)`, com a
marca `corpo_a_corpo_de`, para o combate novo herdar tudo que já existe (placar, rede,
imunidades).
