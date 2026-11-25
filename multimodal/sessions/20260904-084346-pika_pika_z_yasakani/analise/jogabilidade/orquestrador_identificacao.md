# Jogabilidade — identificação da fonte (Claude, orquestrador)

## O vídeo NÃO é referência externa: é o próprio jogo

`OBSERVED` — a HUD do `skills-one-piece` está visível em todos os 15 quadros:
placar `01:19`, barras verde/azul, `FRUTA: SUKE SUKE [R Alternar]`, e o rótulo do
estilo **`Kingki 3.0 Omni`**.

`OBSERVED` — o golpe do vídeo é o **PX Laser Beam, o Z do estilo Pacifista**, já
implementado e documentado no projeto:

| evidência | onde |
|---|---|
| spec escrita pelo dono | `docs/ESTILO_PACIFISTA.md` (não commitado) |
| implementação | `src/combat/laser_px.gd:1` — *"o Z do estilo Pacifista"* (234 linhas) |
| helper do feixe | `src/combat/beam_visual_3d.gd:1` — `BeamVisual3D`, cilindro emissivo `inicio → fim` |
| ligação | `src/combat/FightingStyles.gd:167` — `LaserPX.criar(world, caster, origin, fwd, damage, spec, cast_token)` |
| pedido original | `laser_px.gd:6` — *"um laser que enquanto segurado no Z, ou 3 segundos não se passaram, causa dano constante no alvo"* |

`OBSERVED` — **a duração medida confirma a identificação.** O feixe do vídeo vive
de 1,90 s a 5,00 s = **3,10 s**, contra os **3 s** que o pedido do dono
especifica. Bate.

## O que isso decide

**Prioridade `REUTILIZAR → ESTENDER → CRIAR`:** para um feixe de luz na Pika Pika
Z (*Yasakani no Magatama*), o projeto **já tem a base pronta**. Criar um
`PikaFX` de feixe do zero seria duplicação.

- `BeamVisual3D.criar(pai, inicio, fim, raio, cor, energia, aditivo)` já resolve
  orientação, comprimento e material — inclusive o caso vertical.
- `LaserPX` já resolve feixe **sustentado** com estado (quanto falta, último
  pulso), herança do giro do corpo por ser filho do caster, e pitch convertido
  para espaço LOCAL.

O que muda da Pacifista para a Pika: **cor** (amarelo PX → branco/dourado da luz),
e a **forma** — *Yasakani no Magatama* é rajada de muitos feixes, não um feixe
sustentado. Isso é `ESTENDER`, não `CRIAR`.

## Bloqueio declarado (a trava funcionando)

`laser_px.gd`, `beam_visual_3d.gd`, `px_tri_beam.gd`, `socos_de_ferro.gd`,
`FightingStyles.gd` e `docs/ESTILO_PACIFISTA.md` estão **todos entre os 52
arquivos não commitados do dono** — `laser_px.gd` e `px_tri_beam.gd` foram
tocados em **2026-09-03 18:19/18:20**, ou seja, trabalho de ontem à noite.

A trava do `mm plan` os coloca em `forbidden_changes` automaticamente. Nenhum
agente escreve neles sem `--permitir` explícito. **Isto é comportamento correto,
e é uma decisão do dono, não do pipeline.**

## Números de gameplay

`UNKNOWN` — dano, cooldown, alcance e hitbox da **Pika Z** não estão neste vídeo
e não se leem em vídeo (§12: aparência não decide comportamento). Os números do
`LaserPX` existem em `Balance`/`spec` para o *estilo Pacifista* e **não** são
transferíveis por analogia sem decisão do dono.

## Conexão que vale registrar

O `docs/ESTILO_PACIFISTA.md` documenta uma causa-raiz que é a tese desta skill
inteira: o laser saía **vertical** porque o material usava `BILLBOARD_PARTICLES`
e a GPU girava o cilindro para encarar a câmera *depois* dos cálculos da CPU —
*"testes que verificavam só vetores e transforms podiam passar sem produzir
mudança visível no jogo"*.

Ou seja: o dono já tinha descoberto, sozinho e antes desta skill existir, que
**teste verde não prova tela certa** — e resolveu olhando uma gravação. É
exatamente o buraco que o laço fechado referência × captura existe para fechar.
