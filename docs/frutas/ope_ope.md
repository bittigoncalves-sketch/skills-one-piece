# Ope Ope no Mi

Kit autoral de controle espacial. O jogador cria seu campo de operação, troca
posições, controla rochas e aproxima-se para uma estocada de energia. As técnicas
usam os contratos de dano e rede da arena, com coreografia e efeitos próprios.

## Jogar

```bash
./jogar_ope.sh
```

Abre a arena normal em singleplayer com a Ope equipada e o boneco de treino.
No jogo normal, a fruta nasce na árvore ciano da cirurgia e participa da troca
de frutas pela tecla **T**. **1** seleciona fruta; **2**, estilo; **3**, espada.

| Tecla | Técnica | Comportamento | Recarga |
|---|---|---|---|
| Z | ROOM | Esfera de 18 m de raio por 18 s; uma nova abertura substitui a anterior. | 8 s |
| X | Shambles | Troca de posição com o inimigo mirado; sem alvo, busca chão com espaço livre no campo. | 6 s |
| C | Takt | Suspende cinco rochas e as lança em sequência contra o inimigo mirado no campo. | 10 s |
| V | Gamma Knife | Prepara uma estocada, avança em direção ao alvo e atinge a curta distância. | 22 s |

Pressione a tecla uma vez. X/C/V precisam do próprio ROOM expandido e do usuário
dentro dele. A HUD informa tempo restante e tentativas inválidas. Z e X são
utilitárias, sem dano; C tem até 320 de dano por alvo (cinco acertos de 64);
V tem um acerto de 576. A referência de vida é 2048.

A preparação é vulnerável. A recuperação acompanha a coreografia, sem acrescentar
a trava global de 5 s das demais frutas: Z 0,85 s, X 0,65 s, C 1,65 s, V 0,95 s.
A esfera não acompanha o jogador. Sair dela impede as técnicas; trocar de
fruta/estilo, morrer ou sofrer supressão encerra o campo. Shambles verifica
colisão e apoio no solo. Takt respeita obstáculos e a borda do ROOM. Gamma Knife
respeita cobertura e espaço para avançar.

## Arte, animação e áudio

- Fruta em coração, superfície suave, espirais em relevo, folhas curvas e haste
  enrolada; GLB dedicado, sem usar o corpo cúbico genérico.
- Kikoku separada, presa ao dorso conforme o porte do avatar.
- ROOM com borda ciano translúcida, varredura e marcações cirúrgicas;
  Shambles com marcas espaciais pareadas; Takt com rochas suspensas e rastros;
  Gamma Knife com lâmina verde e impacto cirúrgico.
- Quatro coreografias nos 13 papéis do rig, com apoio das pernas, contrapeso,
  antecipação e recuperação. O rig existente não articula dedos.
- Cinco sons originais sintetizados offline em mono, 48 kHz/16 bits, pico
  de −3,1 dBFS, reprodução posicional. Quatro ícones vetoriais próprios.

## Arquivos

| Parte | Arquivo |
|---|---|
| Estado e técnicas | `src/combat/OpeController.gd` |
| Hitboxes limitadas ao ROOM | `src/combat/OpeDamageZone.gd` |
| Dano e recargas | `src/combat/Balance.gd`, `SkillSystem.gd` |
| Entrada e rede | `src/player/cast_controller.gd`, `Player.gd` |
| Apresentação | `src/effects/OpeVfx.gd`, `OpeRoomField.gd`, `OpeGeometry.gd` |
| Shaders | `src/fx/shaders/ope_room.gdshader`, `ope_floor.gdshader` |
| Poses e arma | `src/anim/OpePoses.gd`, `src/player/OpeWeapon.gd` |
| Indicador e coleta | `src/ui/OpeRoomHud.gd`, `src/world/OpeFruitPickup.gd` |
| Modelos | `assets/models/ope_ope/` |
| Fonte dos modelos | `tools/blender/ope_ope_assets.py` |
| Fonte dos sons | `tools/generate_ope_audio.py` |
| Revisão na arena | `tools/ope_preview.gd` |

Para capturar as fases com renderização real:

```bash
./jogar_ope.sh -- --capture
```

As capturas vão para `multimodal/cache/ope-validation/captures/`. Esse modo usa a cena
da arena e o canal de cast do servidor; muda câmera e disposição do boneco
para tornar cada fase visível. Sem `--capture`, o lançador é jogável.

## Validação executada em 2026-09-08

```bash
python3 tools/validate_ope.py
```

Sete grupos aprovados: integração (26 verificações), combate (33), animação,
arena, qualidade de efeitos, host (5) e cliente (8). Os processos de rede usam
ENet real: confirmam dano de 896 no total, custos somente após aceite,
rejeição de replay e persistência da troca de posições no dono remoto.

A revisão visual usa nove capturas e um vídeo de 8,7 s a 30 fps, sem erros de
script/shader no log. Corrigiu painel ROOM excessivamente alto, perímetro
suspenso, encaixe da Kikoku e sobreposição da barra com controles de treino.
A régua de toque conserva sua altura original para não colocar PULO na área
de câmera; `test_toque` passou com **25 verificações e zero divergências**.
A limpeza de hitboxes usa referência fraca em `FxUtil.autofree`,
evitando callbacks para objetos já destruídos por colisão/cancelamento.

No avatar base, a mão direita percorreu 0,601 m no ROOM, 0,799 m no Shambles,
0,964 m no Takt e 1,187 m no Gamma. A Kikoku manteve folga do chão em todos
os quadros amostrados. **Bluebuddy não foi validado**: o GLB fonte está ausente
nesta cópia do projeto; o teste registra esse caso como pulado.

Os resultados completos e o vídeo `ope_ope_showcase.mp4` ficam em
`multimodal/cache/ope-validation/`. A aprovação destes sete grupos não declara
aprovação da bateria global: ela tem pendências registradas fora da Ope, como
a faixa de dano do Z da Pika e o traço de locomoção (itens 52/53 de
`docs/LISTA_DE_CORRECOES.md`).
