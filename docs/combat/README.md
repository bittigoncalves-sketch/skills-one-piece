# Combate direcional do Modo História

Combate corpo a corpo inspirado em Chivalry 2, **exclusivo do Modo História**: clique
esquerdo encadeia quatro socos no boxe (janela de 1,2 s após o golpe); gestos do mouse
escolhem a direção diretamente. Clique direito defende, com
aparo, riposte, finta e quebra de guarda. Jogador e IA usam o MESMO executor.

O que este combate **não** é: ele não substitui e não toca o M1 da arena
(`Melee`/`MeleeController`), as skills das frutas (Z/X/C/V), o Roll (Q) nem nenhum
outro modo. Nada aqui é instalado fora do Modo História.

## Por onde começar

| quero… | leia |
|---|---|
| entender as camadas e quem decide o quê | [ARQUITETURA.md](ARQUITETURA.md) |
| saber a regra (estados, ataque, defesa, aparo, riposte, finta) | [REGRAS.md](REGRAS.md) |
| criar/ajustar estilo, golpe ou pose | [DADOS.md](DADOS.md) |
| mexer no clique, no gesto do mouse ou no InputMap | [ENTRADAS.md](ENTRADAS.md) |
| a história da decisão, fase a fase, com as medições | [../PLANO_COMBATE_HISTORIA.md](../PLANO_COMBATE_HISTORIA.md) |
| erros já cometidos aqui (e o motivo) | [../erros.md](../erros.md) |

## Os arquivos

Tudo vive em `src/combat/direcional/`:

| arquivo | papel |
|---|---|
| `executor_corpo_a_corpo.gd` | **a regra**: máquina de estados, relógio, contato, defesa, aparo, riposte, finta |
| `golpe_direcional.gd` | ficha de UM golpe (fases, dano, contato, chaves de pose) |
| `estilo_corpo_a_corpo.gd` | ficha do ESTILO: os 4 golpes + defesa + aparo + poses comuns |
| `chave_de_pose.gd` | uma pose-chave: mãos e pés por ALVO, resto por rotação |
| `pose_de_combate.gd` | avaliação PURA da pose no tempo (Hermite entre chaves) |
| `aplicador_de_pose.gd` | escreve a pose no rig: IK de braços e pernas, quadril, pé de apoio, dedos |
| `resolucao_de_contato.gd` | acerto/bloqueio/aparo/quebra e o LADO do impacto, pela geometria |
| `ator_de_combate.gd` + `ator_jogador.gd` + `ator_boneco.gd` | o adaptador de cada corpo |
| `entrada_corpo_a_corpo.gd` | clique e gesto do mouse → pedido de ação |
| `apresentacao_de_combate.gd` + `impacto_de_combate.gd` | som, tremor de câmera e o impacto visual |
| `cor_dos_bracos.gd` | braços **azuis** com a guarda erguida e **vermelhos** no golpe inteiro (preparo, impacto e recuperação); tinta translúcida 75%, troca em 0,08 s; o flash de dano tem prioridade (30/09/2026, pedido do dono) |
| `depuracao_de_combate.gd` | painel F10 (estado, fase, postura, janelas) |
| `cerebro_de_treino.gd` + `boneco_de_duelo.gd` | parceiro de treino que usa o mesmo executor |
| `cerebro_de_inimigo.gd` | o boneco como INIMIGO do mapa: zona de 20 m, persegue, luta, volta e regenera (30/09/2026) |
| `estilos/boxe.tres` | **os números** do boxe (fonte canônica) |

## Testes e sondas

| o quê | como |
|---|---|
| regra, sem cena (rápido) | `godot --headless --path . --script tools/dev_tests/test_executor_corpo_a_corpo.gd` |
| pose pura (continuidade, herança, validação) | `… test_pose_de_combate.gd` |
| lado do impacto e defesa (tabela pura) | `… test_resolucao_de_contato.gd` |
| contato, defesa e aparo com DOIS corpos reais | `… test_contato_historia.gd`, `test_defesa_historia.gd`, `test_aparo_historia.gd` |
| clique e gesto | `… test_entrada_corpo_a_corpo.gd` e, com tela, `test_combate_historia_tela.gd` |
| cor dos braços (azul/vermelho) no jogador e no boneco | `… test_cor_dos_bracos.gd` |
| o boneco como inimigo do mapa | `… test_inimigo_lutador.gd` |
| medir pose no rig real (IK, alcance, pico de velocidade, pés) | `… medir_pose_combate.gd` |
| medir leitura na câmera do jogo (precisa de tela) | `godot --path . --resolution 1280x720 --script tools/dev_tests/medir_leitura_combate.gd` |
| fotos em 3ª pessoa e lateral (precisa de tela) | `… capturar_pose_combate.gd -- <pasta> [tudo\|guarda\|golpes\|defesa]` |

Jogar de verdade: `./jogar_historia.sh` (o atalho principal da área de trabalho NUNCA
vira lançador de teste). O painel de depuração abre no **F10** ou com
`SOP_COMBATE_DEBUG=1`.

**Contra quem treinar:** o "Boneco de duelo" da aba inimigos da loja luta de verdade no mapa
(30/09/2026). No painel **F8** (só em build de desenvolvimento, antes a janela M → TESTE),
"Boneco de duelo" invoca um parceiro com o mesmo executor, à
frente do jogador: **Parado** (reação), **Só guarda** (postura, quebra, finta), **Ataca**
(golpes em direções sorteadas a cada 1,5 s — defesa e aparo), **Apara e responde**
(riposte do boneco). Pedir de novo troca o modo e o traz de volta; **Remover boneco** o
tira. Não dá XP. Código: `ModoHistoria.invocar_boneco`.

## Espada da história (06/10/2026)

`estilos/espada.tres` usa o mesmo executor do boxe: quatro direções e as mesmas
regras defensivas. N → ARMAS equipa o item inicial; a barra alterna arma/mãos livres.
`GolpeDirecional.efetor_base` opcional habilita varredura entre base e ponta da arma;
sem ele o contato do boxe é preservado. `orientar_punhos` interpreta as rotações
`Wrist_R/L` no espaço do corpo após a IK; `manter_postura` conserva a arma erguida no
neutro. A instalação/visual é exclusiva do jogador da história. Detalhes e controles
em [MODO_HISTORIA.md](../MODO_HISTORIA.md#espada-inicial--06102026).

As orientações de `Wrist_R/L` são interpoladas por quaternion (SLERP); o resto da
pose conserva Hermite/lerp. Isso permite inverter o fio entre cortes laterais e
girar o plano no corte vertical sem voltas artificiais de Euler. Regressão geométrica:
`test_fio_espada_historia.gd` mede fio × movimento e sentido do gesto em yaw 0°/90°.
