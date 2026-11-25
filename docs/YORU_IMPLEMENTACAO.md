# Yoru — implementação de 09/09/2026

Escopo escolhido pelo dono: **combate completo, M1 + Z/X/C/V**. O modo 3 agora
possui um controlador próprio. Para jogar: `./jogar_yoru.sh`; no jogo normal,
aperte **3**. Botão esquerdo encadeia dois cortes. Os botões de toque chamam o
mesmo `Player.begin_charge` das teclas.

| Entrada | Ação | Preparação / ativo / recuperação | Dano | Recarga |
|---|---|---|---:|---:|
| M1 #1 | Corte horizontal | 0,32 / 0,14 / 0,30 s | 64 | — |
| M1 #2 | Corte vertical | 0,40 / 0,16 / 0,44 s | 96 | — |
| Z | Corte do Horizonte | 0,42 / 0,10 / 0,38 s | 110 | 5 s |
| X | Passo do Predador | 0,20 / 0,20 / 0,40 s | 88 | 6 s |
| C | Guarda da Cruz | 0,06 / 0,54 / 0,28 s | — | 7 s |
| V | Ruptura da Noite | 0,90 / 0,10 / 0,65 s | 180 | 14 s |

Os números são finais, sem escala de dano adicional. Fonte: `YoruMoves.gd`.
M1 conserva 64 + 96 e os tempos anteriores. O buffer guarda uma intenção por
180 ms; não há fila de ataques. Dash fica bloqueado durante a ação. Cancelar
conserva recargas e aplica até 350 ms de recuperação restante. Respawn zera
as recargas, seguindo a regra das frutas e estilos.

Z viaja até 16 m a 22 m/s, sem perseguir e sem exigir piso. X avança até 2,8 m
com `move_and_collide`; o dano só liga depois da passada. C apara espadas na
frente entre 60 e 240 ms, reduz dano frontal para 35% até 600 ms e deixa as
costas abertas. Aparo confirmado abre M1 vertical por 1 s, mediante novo
comando. C não bloqueia ondas ou frutas. V requer piso físico sob o jogador;
a frente viaja até 18 m a 14 m/s e verifica chão no centro e nos lados a cada
20 cm, parando em buracos, paredes ou degraus maiores que 35 cm.

## Corpo, arma e autoria

- `assets/models/weapons/yoru_v2.glb`: sete meshes, 13 superfícies, 28.814
  triângulos; materiais PBR próprios, sem imagens externas. Lâmina negra
  curva, fio, cruz dourada, filigrana, gemas verdes e cabo trançado.
- Marcadores em metros: `handle=(0,0,0)`, `grip_l=(0,-0.17,0)`,
  `guarda=(0,0.39,0)`, `ponta=(0,1.77,0)` e `edge_direction`.
- A espada compensa a escala herdada do avatar: lâmina efetiva de 1,38 m.
  O cabo continua no `Weapon_R`, coincidente com `Grip_R` do personagem novo.
- `YoruRig.gd`: curvas em coordenadas do rig, coluna e braços independentes,
  IK de dois segmentos sem alongamento, punhos e falanges, joelhos com pés
  apoiados durante o golpe. Sete poses/ações, 121 amostras cada, mediram erro
  de pega abaixo de 0,00001 m no rig base normalizado a 1,5 m.
- `art_src/blender/yoru_master.blend` e `tools/blender/yoru_master.py`: fonte
  editável/reprodução do asset. `yoru_combate.blend` contém seis pares de
  ações de corpo/arma, com 126 juntas amostradas a 30 Hz.

A autoria de gameplay está em `YoruRig.gd`. Os clipes Blender são um bake das
curvas/IK medidas no jogo, não um caminho de importação de clipes alterados
à mão. Para regenerar: executar `tools/export_yoru_poses.gd` no Godot e
`tools/blender/yoru_combate.py` no Blender. O personagem fonte permanece em
`personagem_base_v2.blend`.

## Contato, apresentação e rede

`YoruController.gd` usa um relógio físico para pose, janela de dano, rastro,
lançamento e encerramento. Não há timer de startup solto. Sequências antigas
não reiniciam ações. O controlador atualiza antes do `SwordBlade`, inclusive
em servidor headless. Os rigs antigos usam poses legadas como adaptação.

`SwordSweep.gd` varre sete esferas entre ticks. Choques são resolvidos antes
do dano daquele tick; cada alvo recebe no máximo um acerto por ação. Paredes
bloqueiam a varredura e o caminho entre portador/contato. A aproximação entre
amostras é linear e as consultas têm limite de 256 resultados.

`YoruWave.gd` possui orçamento de dano e vida próprios. Ondas já liberadas
continuam até seu limite; cancelar antes da liberação remove o aviso e não
produz a onda. Rastro segue guarda/ponta reais e limpa ao cancelar. Fagulhas,
sons sintetizados/cached e feedback de contato são próprios da Yoru.

`YoruNetwork.gd` pertence ao servidor, mesmo no Player de outro cliente.
Valida dono, serial, direção finita/normalizada, equipamento, estado e recarga.
O servidor escolhe o passo do M1 e publica equipamento, ação, fase, recargas,
recuperação e resposta de aparo. Contatos visuais também são replicados.
A posição corporal mantém a autoridade de movimento já existente no projeto;
X move o corpo do dono por colisão e o servidor recebe essa posição.

O HUD mostra quatro nomes/recargas e o aviso de resposta do aparo. No desktop,
a barra foi elevada para não ficar atrás do painel de treino.

## Evidência e validação

- Vídeo do input real na arena: `art_src/previews/yoru_combate.mp4` (9,1 s).
- Capturas com HUD/efeitos: `art_src/previews/yoru_arena/`.
- Poses sem VFX: `art_src/previews/yoru_combat/`.
- Bateria reproduzível: `python3 tools/validate_yoru.py`; precisa de sockets
  ENet locais liberados. Logs em `/tmp/yoru-validation` e
  `/tmp/yoru-network-proof`.
- `test_yoru_combat`: 20 verificações de dano, deduplicação, cancelamento,
  replay, aparo, recuperação e comportamento das ondas em parede/buraco.
- `test_yoru_sweep`: 17 verificações físicas, incluindo salto entre ticks,
  clash atômico, parede, sobreposição inicial, defesa e ausência de dano cliente.
- `test_yoru_network`: 20 verificações com host/cliente reais, incluindo entrada
  tardia, estado/RPC forjado, replay, recargas, troca de modo, V remoto no piso e recargas após respawn.
- `test_yoru_rig`, `test_espada_yoru`, `test_player_rig` e `test_arena` completam
  a integração e regressão básica.

Na gravação Forward+ em RTX 3050 Laptop, 273 frames: tempo médio de render CPU
0,86 ms e GPU 4,31 ms. São tempos de render desta cena, não FPS total nem
validação de oito jogadores. Balanceamento competitivo, latência artificial,
carga de oito espadachins e IK detalhada em outros avatares não estão certificados.
Entrada tardia retoma ações, mas não reconstrói ondas já lançadas antes do spawn.

A regressão `test_ope_animacoes` acusa quatro falhas de âncora de VFX no novo
rig base e pula bluebuddy por asset ausente. As mesmas quatro falhas foram
reproduzidas na worktree com o animador anterior à integração Yoru: são
preexistentes e não foram ocultadas como aprovação da bateria completa Ope.
