# Contexto (agentes) — Ferramentas, testes e pipeline

> 21/09/2026 · versão para pessoas: [`../pessoas/ferramentas.md`](../pessoas/ferramentas.md) · arquivos e ★:
> [`INDICE.md#ferramentas`](../INDICE.md#ferramentas) · donos do detalhe: [`VALIDACAO.md`](../../VALIDACAO.md),
> [`AGENTES.md`](../../AGENTES.md), [`guia/COMO_TRABALHAR.md`](../../guia/COMO_TRABALHAR.md),
> [`NUMEROS_MEDIDOS.md`](../../NUMEROS_MEDIDOS.md)

## Escopo

Como se prova e se produz: a bateria (`tools/dev_tests/`, ~100 testes `test_*.gd` e sondas
`net_*`, `medir_*`, `captura_*`), os scripts de raiz (`validar.sh`, `checar_cache.sh`,
`setup.sh`, `jogar*.sh`, `servidor.sh`), o pipeline de arte (`tools/blender/`, bake/export
Mixamo, prévias com captura), o estúdio de animação em andamento (`tools/anim_editor/studio/`,
projeto Godot separado), o pipeline multimodal (`multimodal/`), os geradores de agentes
(`tools/agentes/`) e este índice (`tools/contexto/`).

## Peças

| peça | uso |
|---|---|
| `validar.sh` | bateria: `rapido` pula os lentos; filtro por nome; `mp` roda sondas de 2 processos; sai 0 só se tudo passou; logs em `/tmp/validar_*.log` |
| `tools/dev_tests/test_compila.gd` | **a única prova de que compila** (lista scripts que não instanciam) |
| `checar_cache.sh` / `setup.sh` | regenera o cache de `class_name` (tela cinza) / primeiro preparo |
| `tools/dev_tests/tracar_locomocao.gd` | traço de locomoção: única rede contra regressão de física (com tela) |
| `tools/<fruta>_preview.gd -- --capture` | arena real equipada, captura as fases em PNG |
| `tools/bake_mixamo.gd`, `export_rig.gd`, `export_anims.gd` | Mixamo → rig por nós; perfil do rig e clipes em JSON |
| `tools/anim_editor/studio/` | estúdio de animação (trabalho do dono, fora do git; 6 scripts não compilam — débito conhecido) |
| `multimodal/` (`.gdignore`) | vídeo/imagem de referência → evidência medida (skill `multimodal-dev`) |
| `tools/agentes/gerar_agentes_*.py` | gera os agentes `boss-*` e `yoru-*` em `~/.claude/agents/` |
| `tools/contexto/indice.py` | busca TF-IDF, mapa `docs/contexto/INDICE.md`, verificação dos contextos |
| `src/tests/` (`BaseTest.gd`) | testes de cena antigos (`test_fsm`, `test_anim`, `test_physics`) |
| `tools/dev_tests/test_transformacao_skill.gd`, `test_transformacao_builder_ui.gd`, `test_transformacao_historia.gd` | transformação visual: contrato e restauração, interface/salvamento, publicação → kit → corpos reais. Detalhes: [`TRANSFORMACAO_BUILDER_CHECKPOINT.md`](../../TRANSFORMACAO_BUILDER_CHECKPOINT.md) |

## Contratos

- **Teste sabe reprovar:** toda sonda tem controle positivo ou sabotagem; asserção que nunca
  falha é enfeite. Pré-condição impressa (ex.: "corpos no chão, 0 inválidos").
- **Porta 24565 é serial.** `validar.sh` roda em série; agentes em paralelo usam `SOP_PORTA`.
- **Headless não captura mouse** e não desenha: clique real e visual precisam de tela — e esses
  testes capturam o mouse do desktop real (peça antes).
- **Mapa/progresso fixos em teste** (fixtures em `tools/dev_tests/fixtures/`).
- Sonda solta na raiz (`test_peer.gd`, `test_singleplayer.gd`, `test_spawner.gd`) não afirma
  nada; fica fora do glob de propósito.
- Teste novo entra no glob automaticamente (`tools/dev_tests/test_*.gd`); teste com tela entra
  na lista de exclusão do `validar.sh` e no bloco com tela.

## Armadilhas

- Erro de runtime dentro de `await` vira TIMEOUT, não falha.
- `extends SceneTree` não tem `get_tree()`; use `get_root()`.
- `preload`/tipo de classe que cita `Player` num teste `-s` compila o Player antes dos autoloads:
  use `load()` em tempo de execução.
- Tempo do teste: `test_frutas` até 480 s, `test_gomu_leak` ~131 s (dê 240 s); o resto 120 s.
- Contagem "por proximidade de texto" não é contagem: meça no dado.

## Débito conhecido (21/09)

8 falhas estáveis na bateria headless — lista no `PROJECT_CONTEXT.md` §8. `test_sala_publica`
depende do roteador (UPnP); `test_lan_discovery` precisa de farol (o `validar.sh` sobe).

## Buscar

```bash
python3 tools/contexto/indice.py buscar "sabotagem controle reprovar" --docs
python3 tools/contexto/indice.py buscar "porta paralelo SOP_PORTA"
python3 tools/contexto/indice.py buscar "captura fase png" --area ferramentas
```
