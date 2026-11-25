# Contexto (agentes) — Interface e HUD

> 21/09/2026 · versão para pessoas: [`../pessoas/interface.md`](../pessoas/interface.md) · arquivos e ★:
> [`INDICE.md#interface`](../INDICE.md#interface) · donos do detalhe: [`MODO_CELULAR.md`](../../MODO_CELULAR.md)
> (toque), [`PLANO_VISUAL.md`](../../PLANO_VISUAL.md) Fase 6 (estilo do HUD), [`CUSTOMIZACAO.md`](../../CUSTOMIZACAO.md)

## Escopo

Tudo em `src/ui/`: HUD de cada modo, menus (principal, personagem, customização), janela de status
do Modo História, barras, placar da rodada, controles de toque. **Não** é daqui: o editor de mapa
(painéis próprios em `src/editor_mapa/`, estilo em `ui_estilo.gd`) e o painel F10 de depuração do
combate direcional (`src/combat/direcional/depuracao_de_combate.gd`).

## Arquivos

| arquivo | papel |
|---|---|
| `src/ui/Estilo.gd` (★4, 0 testes) | tokens do HUD (cores VIDA/ENERGIA/…, linha, inclinação); a aparência manda aqui |
| `src/ui/BarraHud.gd` | a barra paralelogramo por `_draw()` (um nó por barra) |
| `src/ui/Hud.gd` | HUD da ARENA: barra de técnicas, inventário, menus, `StatsHud` |
| `src/ui/StatsHud.gd` | vida/energia/dash/dano total da arena, lidos do corpo a cada quadro |
| `src/ui/HistoriaHud.gd` | HUD do MODO HISTÓRIA: ESC, toque, janela M, avisos, `VidaEnergiaHud` |
| `src/ui/VidaEnergiaHud.gd` | barras de vida/energia da história; `vida_exibida` é a regra do número (também da janela M) |
| `src/ui/JanelaDeStatus.gd` | tecla M: status do PDF; seção TESTE só em build de desenvolvimento (boneco de duelo e "Comer Rocket") |
| `src/ui/TecnicasHud.gd` | as técnicas da fruta no Modo História (tecla, nome, recarga, custo), lidas da ficha do modo |
| `src/ui/MainMenu.gd` | menu principal (mesmo menu na arena e na história) |
| `src/ui/ToqueHud.gd` | toque: joystick, câmera e botões que INJETAM os mesmos eventos do teclado/mouse |
| `src/ui/SkillBar.gd`, `MatchHud.gd`, `StatusEffectsHud.gd`, `AmmoHud.gd` | técnicas, rodada, status, munição |

## Contratos

- **O Player acha a HUD pelo grupo `"hud"` e chama SEMPRE com `has_method`**: `toggle_main_menu`,
  `is_menu_open` (com menu aberto o WASD para), `on_player_damaged`, `update_skills_for_fruit`…
  HUD nova de modo implementa só o que o modo tem.
- **HUD por modo**: a da arena mostraria botões de poderes que o Civil não tem — por isso existe a
  `HistoriaHud`. Não reaproveite a `Hud` da arena na história.
- **Janela só MOSTRA e PEDE**: regra mora em `ProgressaoDoPersonagem`; pontos só saem no Confirmar.
  Pedidos da seção TESTE saem por sinal (`pediu_boneco`), quem cria é o `ModoHistoria`.
- **Toque injeta, não duplica** (`MODO_CELULAR.md`): botões sintetizam `InputEventMouseButton`/
  teclas; o jogo não sabe que é toque. O botão manda press E release (`ToqueHud._definir`), que é
  o que faz a fruta do Modo História funcionar no celular: lá **soltar é que dispara**.
- **O KEY-UP atravessa menu aberto de propósito** (senão a técnica fica presa com a tecla
  "segurada"). Com a mira da fruta isso passou a importar: soltar com o menu aberto
  **cancela** em vez de atirar (`CastController._menu_aberto`).
- **Leiaute do topo da história (medido 21/09):** barras y 18–86, aviso de nível y 100–136, painel
  F10 a partir de y 150 (`test_vida_energia_historia` prova em 800/1024/1280 px).

## Armadilhas

- `CanvasLayer` não é `CanvasItem` (`docs/ESTADO_ATUAL.md` §5); a camada da HUD da história é 5
  (acima da mira do Player, camada 1).
- A `HistoriaHud` lê M e ESC em `_input`, não em `_unhandled_input`: o Player escuta o ESC mais
  fundo na árvore e abriria o menu principal por cima da janela.
- UI que engole o evento de soltar deixa estado preso: leia o ESTADO do botão quando importar.
- UI em script de teste `-s` que cita classe que cita `Player` envenena o cache — mantenha a HUD
  sem citar `Player` (a `VidaEnergiaHud` recebe o corpo da `HistoriaHud`).

## Validar

`test_vida_energia_historia`, `test_modo_historia` (janela M), `test_toque` (com tela),
`test_elenco_trancado`, `medir_menu_principal`, `medir_customizacao`. Visual de HUD sem captura é
só metade da prova: diga quando não houve captura.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "hud barra estilo" --area interface
python3 tools/contexto/indice.py buscar "toque joystick botao injeta"
python3 tools/contexto/indice.py buscar "janela status pontos confirmar"
```
