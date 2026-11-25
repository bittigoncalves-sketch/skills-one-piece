# Contexto (agentes) — Mundo e editor de mapa

> 21/09/2026 · versão para pessoas: [`../pessoas/mundo.md`](../pessoas/mundo.md) · arquivos e ★:
> [`INDICE.md#mundo`](../INDICE.md#mundo) · donos do detalhe: [`MODO_HISTORIA.md`](../../MODO_HISTORIA.md)
> §3–4 e §6a (formato do mapa, editor, inimigos), [`PLANO_VISUAL.md`](../../PLANO_VISUAL.md) (luz e ar)

## Escopo

Dois mundos: a **arena** montada por código (`MapBuilder`, `TreeScatter`, `WorldEnv`,
`RosaDosVentos`, coletáveis de fruta em `src/world/*FruitPickup.gd`) e o **mapa em arquivo** do
Modo História (`mapas/historia/*.json`) com o **editor de mapa** (`src/editor_mapa/`). **Não** é
daqui: o que acontece no Modo História depois de o mapa montar (`historia`).

## Arquivos que mais pesam

| arquivo | papel |
|---|---|
| `src/world/mapa_arquivo.gd` (MapaArquivo) | ler, validar e gravar o formato; não cria nó. **Fonte única do formato** |
| `src/world/mapa_montador.gd` (MapaMontador) | mapa VALIDADO → nós; o mesmo para jogo e editor |
| `src/world/biblioteca_modelos.gd` | os `.glb` importados pela loja, com categorias (a categoria "inimigos" marca inimigo) |
| `src/editor_mapa/EditorDeMapa.gd` | orquestrador do editor (etapa 2 do Modo História) |
| `src/editor_mapa/documento_mapa.gd`, `operacoes.gd`, `historico.gd`, `selecao.gd` | documento em memória, tudo que o muda, desfazer/refazer, seleção — sem nó |
| `src/editor_mapa/gizmo.gd` + `gizmo_matematica.gd` | alças mover/escalar/girar; matemática pura testável |
| `src/editor_mapa/loja.gd`, `importador_glb.gd`, `miniaturas.gd` | loja de modelos, importação, fotos em SubViewport isolado |
| `src/world/MapBuilder.gd` | arena FIXA: grade de lajes de 10 m com 16 buracos + blocos |
| `src/world/WorldEnv.gd` | ar e luz (Fase 1 do plano visual); o Modo História também aplica |
| `src/world/RosaDosVentos.gd` | pontos invisíveis de direção (usados por medidas e câmera) |

## Contratos

- **Floresta da loja (08/10):** substituição pontual em
  `tools/mapa_ilha/floresta_da_loja.gd`, sem regenerar a ilha. Mapa atual com
  1240 peças; preservação e edição validadas. Detalhes e backup em
  [`FLORESTA_LOJA_CHECKPOINT.md`](../../FLORESTA_LOJA_CHECKPOINT.md).
- **O mapa do Modo História é o ARQUIVO** (`mapas/historia/baseplate.json`): nada de chão escrito
  em código; o editor edita esse mesmo arquivo. O dono edita ao vivo — teste usa
  `ModoHistoria.mapa_forcado` com fixture de `tools/dev_tests/fixtures/`.
- **Camadas sem nó** (documento, operações, histórico, seleção, matemática do gizmo) são puras e
  testáveis; a vista (`vista_mapa.gd`) desenha o documento.
- **"Testar" do editor = jogo de verdade**: nasce por `ModoHistoria.colocar_civil`. A HUD do
  editor é própria (as barras de vida/energia da `HistoriaHud` não aparecem lá).
- Inimigo = peça cujo modelo está na categoria "inimigos"; só o JOGO transforma a peça
  (`InimigoDoMapa.ligar_no_mapa`, por `set_script`), para o editor não perder o nó.
- Peça com "Colisão" desligada não toma golpe (aviso no log).
- **HITBOX própria (23/09):** campo `hitbox` OPCIONAL na peça (forma, deslocamento, tamanho,
  rotação; formas em `MapaArquivo.FORMAS_HITBOX`, que inclui `capsula` e NÃO é `TIPOS`).
  Ausente = automático, e o arquivo sai idêntico ao de antes. **`MapaMontador.volume_de_colisao`
  é a conta ÚNICA**: a física monta a forma a partir dela e o editor desenha a partir dela —
  não escreva uma segunda. Ela devolve `{}` quando a colisão é a malha do modelo (aí não há
  caixa honesta para desenhar). A forma de SELEÇÃO (camada 20) continua vindo do tamanho da
  peça: hitbox pequena não pode tornar a peça difícil de clicar. Teclas: **H** vê o mapa
  inteiro, **Ctrl+H** aponta o gizmo para o volume.

## Armadilhas

- `add_child` antes de `global_position` (três ocorrências custaram caro).
- Corpo criado sobreposto a outro vira plataforma; teleporte de dois corpos no mesmo quadro
  despenetra (registrado em `erros.md`, 16/09).
- `Engine.time_scale` escala o delta da física (armadilha 13): medições de física em câmera lenta
  mentem.

## Validar

`test_editor_mapa`, `test_grupos_editor`, `test_loja_modelos`, `test_modo_historia`,
`test_inimigos_historia`, `test_arena`, `test_enchente`; medidas `medir_grade`,
`medir_rosa_dos_ventos`, `medir_blocos_sumindo`.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "mapa arquivo validar peca" --area mundo
python3 tools/contexto/indice.py buscar "gizmo escalar girar"
python3 tools/contexto/indice.py buscar "editor desfazer historico" --docs
```

## Pet caranguejo (30/09/2026)

Categoria pets da loja, comportamento `pet_caranguejo`; no modo história segue lateralmente, pula e emite bolhas pelas garras. M → PETS chama/recolhe. Fonte: `art_src/pets/`; código: `src/historia/pets/`; integração e limites: `docs/MODO_HISTORIA.md`, seção Pet caranguejo. Teste: `test_pet_caranguejo` (24 verificações).

## Praia e oceano (30/09/2026)

`oceano_historia.gd`/`.gdshader`: superfície visual compartilhada por `ModoHistoria` e `VistaDoMapa`, costa derivada de caixas `baseplate`/`baseplate_*`, atualizada por sinais do documento. Areia GLB na categoria `praia_mapa`; fonte/escala/limites em `art_src/praia/LEIA-ME.md`. Teste `test_praia_oceano`, validador `python3 tools/validar_praia.py --capturar`. Não alterar mapa vivo em teste; capturas usam areia temporária.

## Mar: relevo marinho (14/10/2026)

`src/world/relevo_marinho.gd` (`RelevoMarinho`, puro, semente fixa) é a FONTE ÚNICA da altura
do fundo e das máscaras (rocha, recife, duna): plataforma 5–25 m, talude, mar aberto ~−64 m,
fossa ~−80 m entre ilhas; d < 60 m da placa = rampa antiga (porto e vagas do cais).
`FundoDoMar` só desenha/colide: grade global de 4 m em blocos de 128 m, nó por ilha no centro
dela, `AbismoDoMar` em volta. Material `fundo_do_mar.gdshader` + `src/fx/shaders/luz_cel.gdshaderinc`.
Teste `test_relevo_marinho`. Plano, decisões e números: [`MAR_HISTORIA_PLANO.md`](../../MAR_HISTORIA_PLANO.md).
