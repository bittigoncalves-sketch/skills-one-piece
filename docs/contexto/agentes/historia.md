# Contexto (agentes) — Modo História

> 21/09/2026 · versão para pessoas: [`../pessoas/historia.md`](../pessoas/historia.md) · arquivos e ★:
> [`INDICE.md#historia`](../INDICE.md#historia) · donos do detalhe: [`MODO_HISTORIA.md`](../../MODO_HISTORIA.md)
> (guia-mestre; o PDF em `docs/references/modo_historia/` é a fonte dos números),
> [`combat/README.md`](../../combat/README.md) (combate direcional), [`PLANO_COMBATE_HISTORIA.md`](../../PLANO_COMBATE_HISTORIA.md)
> (decisões e registro fase a fase)

## Escopo

A campanha: cena e orquestração (`src/historia/ModoHistoria.gd`), progressão/status do PDF
(`progressao.gd`, tecla M), inimigos do mapa (`inimigo_do_mapa.gd`) e o **combate corpo a corpo
direcional** estilo Chivalry 2 (`src/combat/direcional/`). **Não** é daqui: o mapa e o editor
(`mundo`), a HUD em si (`interface`, mas `HistoriaHud`/`JanelaDeStatus`/`VidaEnergiaHud` servem a este modo).

## Arquivos que mais pesam

| arquivo | papel |
|---|---|
| `src/combat/direcional/executor_corpo_a_corpo.gd` (★5, ~760 linhas) | A REGRA: estados, relógio único, contato, defesa, aparo, riposte, finta |
| `src/combat/direcional/golpe_direcional.gd` | ficha de um golpe (fases, dano, contato, chaves de pose) |
| `src/combat/direcional/estilo_corpo_a_corpo.gd` + `src/combat/direcional/estilos/boxe.tres` | ficha do estilo; **os números moram no `.tres`** |
| `src/combat/direcional/resolucao_de_contato.gd` | acerto/bloqueio/aparo/quebra e o lado do impacto (pura) |
| `src/combat/direcional/ator_de_combate.gd` (+ `ator_jogador`, `ator_boneco`) | adaptador do corpo; `impedido(contar_atordoamento)` |
| `src/combat/direcional/entrada_corpo_a_corpo.gd` | clique e gesto do mouse → pedido (4 direções) |
| `src/combat/direcional/pose_de_combate.gd`, `chave_de_pose.gd`, `aplicador_de_pose.gd` | pose como dado, Hermite, IK próprio de 2 ossos |
| `src/historia/ModoHistoria.gd` | orquestra; `colocar_civil()` = nascimento ÚNICO (jogo e "Testar" do editor); `invocar_boneco` |
| `src/historia/progressao.gd` | XP, níveis (barreira no 7), pontos, skills, ouro; salvo em `user://historia/progresso.json` |

## Contratos

- **Jogador e IA pelo MESMO executor**: quem decide (entrada ou `CerebroDeTreino`) só chama
  `pedir_ataque` / `erguer_guarda` / `baixar_guarda`.
- **Um relógio**, fases derivadas; cancelar = trocar `id_acao`. Sem `SceneTreeTimer` nem
  `Engine.time_scale` (hitstop é por ator).
- **Defesa resolvida ANTES do dano**; só ACERTO chama `CombatResolver.aplicar`.
- **Acerto no ATIVO não interrompe** para nenhum corpo (correção de 21/09: o atordoamento do
  `take_damage` do Player cancelava só o golpe do jogador).
- O aplicador escreve só **rotação local** nos ossos (`_girar_global`), nunca escala: reescrever
  `global_basis` com a escala do global fez os pés do boneco crescerem sem parar (21/09, seção G).
- Instalação num ponto só (`instalar_combate_direcional`); ponte no `Player.gd` com 9 pontos —
  10º ponto ou desvio com mais de 3 linhas de lógica → extrair componente.
- **Mapa e progresso de teste FIXOS** (`ModoHistoria.mapa_forcado` / `progresso_forcado`): o mapa
  do dono é vivo e nunca é lido nem gravado por teste. O atalho da área de trabalho nunca vira
  lançador de teste (`./jogar_historia.sh`).

## Estado e pendências

- Fases 0–6 e 7a do combate prontas (boxe). Faltam: resto da Fase 7 (estilo liberado pela skill,
  "Testar" do editor), Fase 8 (validação final + `critico-de-combate`/`avaliador-de-animacao`),
  A espada foi entregue em 06/10/2026: item inicial, N → ARMAS; equipar concede Espada 1.
- Inimigos do mapa são `StaticBody3D`: não atacam nem defendem. Treino real: janela M → TESTE →
  boneco de duelo (Parado, Só guarda, Ataca, Apara e responde).
- **Akuma no Mi (22–23/09):** a Rocket é a primeira fruta do modo — ficha em
  `src/historia/frutas/rocket.tres` (custo, recarga, dano, regeneração de energia), comida pelo
  TESTE e guardada no progresso; Z, X, C e F prontos. A guarda segura técnica de fruta
  (`ResolucaoDeContato.resolver_tecnica`, 30% + postura, sem aparo). Em 23/09 entraram pose
  própria por golpe (`rocket_missil`/`_bombardeio`/`_mergulho` — antes caíam no soco genérico),
  a paleta medida do vídeo com estilhaços/manchas/retículo/pilar, o foguete com malha e o
  **indicador de mira** (segurar mostra, soltar apaga). Onde o golpe cai é conta ÚNICA em
  `src/combat/mira_de_rocket.gd`: controlador e indicador chamam a mesma função, senão o anel
  mostra um ponto e a explosão sai em outro. Página: `docs/frutas/rocket.md`.
- Hipóteses de feel para o playtest do dono: janela de aparo 0,20 s, overhand punível demais,
  ganchos fracos, gesto de direção × acompanhar alvo com a mira.

## Validar

`test_executor_corpo_a_corpo`, `test_pose_de_combate`, `test_resolucao_de_contato`,
`test_entrada_corpo_a_corpo`, `test_contato_historia`, `test_defesa_historia`, `test_aparo_historia`,
`test_combate_historia`, `test_modo_historia`, `test_inimigos_historia`, `test_vida_energia_historia`;
com tela: `test_combate_historia_tela`, `medir_leitura_combate.gd`, `capturar_pose_combate.gd`.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "aparo riposte finta" --area historia
python3 tools/contexto/indice.py buscar "progressao nivel barreira xp"
python3 tools/contexto/indice.py buscar "chivalry decisao aparo" --docs
```

## Pet caranguejo (30/09/2026)

Categoria pets da loja, comportamento `pet_caranguejo`; no modo história segue lateralmente, pula e emite bolhas pelas garras. M → PETS chama/recolhe. Fonte: `art_src/pets/`; código: `src/historia/pets/`; integração e limites: `docs/MODO_HISTORIA.md`, seção Pet caranguejo. Teste: `test_pet_caranguejo` (24 verificações).

## Espada inicial (06/10/2026 — substitui a pendência de espada acima)

Pedido do dono: item inicial no inventário, equipável, ataque por clique como o corpo
a corpo. Implementado em `src/historia/equipamentos/espada_da_historia.gd` +
`src/combat/direcional/estilos/espada.tres`.
N → ARMAS; barra existente; save/migração; equipar concede Espada 1. Quatro golpes,
contato base/ponta, defesa/aparo, interrupção com recuperação preservada. Não instala
Yoru nem técnicas da arena. Teste: `test_espada_historia.gd`; evidências/checkpoint:
`docs/ESPADA_HISTORIA_CHECKPOINT.md`.

Z da espada (06/10): `src/historia/equipamentos/giro_da_espada.gd` assume corpo e lâmina até atingir
inimigo ou cancelar com Z. Imunidade exclusiva `giro_espada_ativo`, limpa ao sair/trocar
item/rig/incapacitar; Player e contato direcional recusam dano/reação durante o giro.
HUD e input próprios da história, sem liberar técnicas da arena. Teste:
`test_giro_espada_historia.gd`. `InimigoDoMapa` agora aceita knockback com colisão
e restaura a posição original ao renascer.


## Bestas do mar (07/10/2026)

`src/historia/bestas_mar/populacao.gd` converte os quatro modelos colocados no editor
em criaturas somente no runtime de `src/historia/ModoHistoria.gd`. Serpente boss
hostil com bolhas; demais pacíficos até dano, perseguição limitada e retorno à
praia. Nove clipes por espécie; água/ondas, contato de mordida e projétil varrido.
Perfis: `src/historia/bestas_mar/perfis.json`. Não povoar o mapa automaticamente.
Fonte/edição: `art_src/bestas_mar/LEIA-ME.md`. Testes:
`tools/dev_tests/test_bestas_mar.gd` e `tools/dev_tests/test_comportamento_bestas_mar.gd`
(64/64 headless e com tela). Evidências e limites: `docs/BESTAS_MAR_CHECKPOINT.md`.


## Sequência de socos (07/10/2026)

No boxe, clique sem gesto percorre quatro golpes; 1,2 s após terminar reinicia.
`src/combat/direcional/entrada_corpo_a_corpo.gd` avança somente em golpe_iniciado;
buffer não pula índices e clique cedo não finta. Gestos, IA e espada preservados.
Dados em `src/combat/direcional/estilos/boxe.tres`. Contrato/documentação:
`docs/combat/ENTRADAS.md`; validação: `docs/SEQUENCIA_SOCOS_CHECKPOINT.md`.


Z da espada com duas mãos (07/10): pose em
`src/historia/equipamentos/giro_da_espada.gd`, encaixes das palmas usados para alvos
IK; direita junto à guarda, esquerda 15 cm abaixo. Pegada trazida à frente do corpo.
7/7 medições de pegada e 42/42 regressões do Z com tela. Evidências/limites:
`docs/ESPADA_HISTORIA_CHECKPOINT.md`.

## Sharkman, bicicleta Hie e mergulho (13/10/2026)

M → Raça salva Humano/Sharkman. Sharkman respira sem limite; nado normal = corrida,
Shift = 2× nado e consome energia. Bicicleta: Espaço pula, segundo toque gira 360°,
Ctrl empina e curvas inclinam. Luz local acompanha mergulho. Código em
`historia/agua/` e `historia/equipamentos/bicicleta_de_gelo.gd`.
39/39 verificações com tela; regressões e regra ainda pendente de Sharkman com
Akuma ativa em `docs/SHARKMAN_BICICLETA_CHECKPOINT.md`.

## Mar do Modo História (14/10/2026)

Tudo que vive no mar liga num ponto só: `src/historia/mar/mar.gd` (o `ModoHistoria` chama
`montar` com um dicionário de contexto). Recifes (`recifes.gd`, corais do
`tools/blender/corais.py`), naufrágios com esqueletos e baú de ouro (`naufragios.gd`; peças do
mapa na categoria `naufragios`, baú uma vez por save em `ProgressaoDoPersonagem.sistemas["mar"]`),
encontro com besta navegando (`encontros_no_mar.gd`: ataca o barco, troca para o jogador ao ser
acertada; barco a zero afunda e é perdido), cardumes (`cardumes.gd`) e visão submersa
(`visao_submersa.gd`: névoa, cáusticas, raios, grupo `so_submerso`). F8 › "Besta do mar no
barco". Testes: `test_recifes`, `test_naufragios`, `test_encontros_no_mar`, `test_cardumes`,
`test_visao_submersa`; GPU: `medir_mar.gd`, `capturar_{recifes,naufragios,encontro}.gd`.
Plano, decisões do dono e medições: [`MAR_HISTORIA_PLANO.md`](../../MAR_HISTORIA_PLANO.md).
