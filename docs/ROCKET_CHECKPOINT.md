# Rocket Fruit — plano e checkpoint (22/09/2026)

Pedido: quatro técnicas Z/X/C/V integradas, autorais, com propulsão corporal,
colisão, apresentação, rede e testes reais. Não copiar assets Blox Fruits.

## Arquitetura estudada e decisão

Input: Player.begin_charge → CastController → pedir_cast_no_servidor →
_do_server_cast → _net_play_cast. Balance → DamageSpec → DamageZone →
CombatResolver é o funil de dano, inclusive orçamento por alvo. Cooldowns
moram em SkillSystem e Player; Ope/Bara já têm validação transacional própria.
Corpos comuns são autoridade do cliente: Rocket precisa guardar a posição
canônica de suas ações no servidor, sem confiar no deslocamento recebido.

Reutilizar: DamageZone (varredura, cobertura, deduplicação, knockback),
CombatResolver, DamageSpec, CastController, RPC estável Player, FxUtil,
AudioFX, ProceduralAnimator/rig de 13 papéis, HUD e ciclo de frutas existentes.

Modificar: Player.gd (pontes pequenas), SkillSystem.gd (registro/recargas),
FruitPassiveSystem.gd, TreeAndFruitGenerator.gd (disponibilidade no mapa),
src/player/cast_controller.gd (entrada/cancelamento), src/combat/Balance.gd,
src/anim/ProceduralAnimator.gd (pose autoral).

Criar: src/combat/rocket_controller.gd (estado/rede),
src/combat/rocket_hitbox.gd (subclasse DamageZone com vida controlada/cancelável),
src/effects/rocket_vfx.gd (apresentação limitada), src/anim/rocket_poses.gd,
tools/dev_tests/test_rocket.gd, ferramentas de rede/prévia, docs/frutas/rocket.md.

Benefício: regras próprias contidas, reaproveitamento dos contratos de combate.
Manutenção/extensão: números e tempos centralizados, apresentação separada.
Custo: quatro componentes pequenos e pontes nos sistemas existentes.
Risco: sincronização de corpo controlado pelo cliente durante ação do servidor;
testar com dois processos. Não migrar a movimentação das outras frutas.

## Habilidades e estados

- Z: preparação 0,12 s, soco propulsionado 0,10 s, recuperação 0,22 s.
  Alcance 2,8 m, raio 0,65 m, dano 88, knockback 5, recarga 5 s.
  Antebraço continua corporal; traço de chama atrás do punho, giro interpolado.
- X: preparação 0,18 s, aceleração até 32 m/s, percurso 11 m (15 no V),
  recuperação 0,22 s. Dano 160, knockback 12, recarga 7 s.
  Corpo inteiro varrido com move_and_collide; chão/ar/parede/declive.
- C: preparação 0,18 s, 8 pulsos espaçados por 0,12 s, recuperação 0,22 s.
  Alcance 15 m, raio 1,4 m, 40 por impacto/teto 320, stagger 0,08 s,
  knockback 1,5, recarga 10 s. Um relógio, impactos raycast + DamageZone
  breves, pool visual fixo; sem gerenciador global ou dezenas de projéteis.
- V: carga 0,4 s → sobrecarga 6 s → subida 0,45 s → mira aérea 0,18 s →
  mergulho até solo → recuperação. Velocidade ×1,3, aceleração da corrida
  aumentada; Z ×1,35 no ritmo; X +4 m. Dano das outras skills não aumenta.
  Final: raio 6 m, dano 576, knockback 20, recarga 35 s.
  Raycast antecipado de solo e varredura do corpo; sem teleporte através do chão.
  Sem solo seguro: encerrar mergulho limitado, sem explosão fictícia no vazio.

VFX: bocais metálicos, chama branca/laranja, fumaça, faíscas, trilhas e anéis.
GPUParticles3D limitadas, meshes/material emissivo e pool local de impactos;
efeitos todos filhos de um contêiner descartável. Áudio procedural existente.
Animações: pose completa com antecipação/ação/recuperação e interpolação suave.
Estados canceláveis por dano, morte, troca, supressão, remoção e mudança de modo.
Servidor decide custos, tokens, hits e fases; clientes só apresentam snapshots.

## Jev

22/09: jev_decide arquitetura, jev_decide Barrage e jev_classify balanceamento
chamados com alternativas e evidência do código. Todos retornaram isError:
“No TYPESAFE_API_KEY, OPENROUTER_API_KEY ... found”. Sem probabilidades ou
decisões. Usuário avisado para configurar o MCP; não pedir chave no chat.
Decisões acima são análise técnica local, não parecer do Jev.

## Validação prevista

Baseline ./validar.sh rapido em /tmp/rocket_baseline.log; arquivos antes da
integração em /tmp/rocket-before. Não reverter alterações locais anteriores.
Godot real confirmado: 4.6.3.stable.official.7d41c59c4.
Testar Z chão/ar/alvo/parede/vazio; X chão/ar/parede/alvo/declive; C
zero/um/vários/cobertura; V carga/buff/duração/final/solo/declive; custos,
repetição, falsificação, cancelamento, cleanup, duas instâncias de rede.
Executar compilação, suíte rápida e capturas em display virtual quando disponível.
Não afirmar avaliação visual, multiplayer ou performance sem executar.

Próximo: implementar componentes e integrar após registrar baseline relevante.

---

## Camada do Modo História (Claude, 22/09/2026)

O kit acima (arena) ficou como está. Por cima dele entrou a camada da história, decidida com o
dono e medida no vídeo de showcase dele:

- **Fase 1 — fundação.** `can_use_fruit`/`can_fly` separados de `can_use_skills` (que abriria
  modos 1/2/3, T, E e Corpo de Ferro); `PerfilDeFrutas` + `rocket.tres` com custo, recarga, dano e
  regeneração de energia do modo; `progressao.fruta` + `comer_fruta` salvos no progresso; teclas
  Z/X/C/V encaminhadas pela `HistoriaHud` (antes não chegavam ao corpo); `TecnicasHud`; botões
  "Comer Rocket"/"Tirar fruta" no TESTE.
- **Fase 2 — Z Missile Fist.** Comportamento `missil` no controlador, escolhido pela FICHA do modo
  (`_comportamento`): na arena o Z continua o soco do Codex. Explosão resolve a GUARDA do combate
  direcional antes do dano (30% + postura; quebra com postura no fim). Soco de FOV removido
  (decisão do dono: o jogo não tem).
- **Fase 3 — F Blast Off.** `src/player/voo_foguete.gd` no padrão do `DashController` (devolve
  velocidade, não escreve): impulso, 3 s planando pela mira com WASD desviando, técnicas no ar e
  **pouso suave**. Medido: +5,9 m de altura, 4,4 s no total, chega vivo ao chão.

Medido contra o vídeo: Z do pedido ao impacto 0,47 s a 12 m (gabarito ≤ 0,3 s de voo após 0,35 s
de preparo). Testes: `test_fruta_rocket_historia.gd` (50 checagens) e `test_rocket.gd` (41) verdes.
Falta: X e C da história, fruta como peça do mapa, VFX fiéis e o traço de locomoção (teste com tela).
- **Fase 4 — X e C.** `bombardeio` (3 pontos na LINHA até a mira, retículo 0,2 s antes, cadeia do
  perto ao longe, empurrão para cima — o `BonecoDeDuelo` ganhou impulso vertical) e `mergulho`
  (agacha, arco até o ponto mirado em 0,4 s, explosão de 3,5 m e close curto de câmera via
  `CameraRig.aproximar`, exceção aprovada pelo dono). Medido: bombardeio 15 por ponto e alvo subindo
  1,07 m; mergulho cruzando 8,4 m com 6 m de arco e 45 de dano. Testes: 56 checagens na história,
  41 na arena, `test_camera` 10/10.
- **Fase 5a — apresentação (23/09).** Antes: comparação com a referência por julgamento tipado
  (`jev`): funcionalidade igual/superior (2 aspectos superiores, 1 igual), **design inferior em 9
  de 13 aspectos**, todos de apresentação. Entregue:
  - **pose própria por golpe.** `_pose()` pede `rocket_` + comportamento da ficha, e
    `rocket_missil`/`rocket_bombardeio`/`rocket_mergulho` **não existiam** no `match` de
    `rocket_poses.gd` — caíam calados no soco genérico. Novas: APONTAR/DISPARO (Z), DETONADOR/
    DETONA (X), AGACHO/ARCO/MERGULHO/ATERRISSA (C), com a aterrissagem caindo em t 0,37, o
    instante exato do impacto (o primeiro teste reprovou porque ela chegava depois);
  - **paleta de 8 cores medida** no lugar de duas inventadas; estilhaços pretos, mancha de chão de
    7 s (só quando a explosão foi no chão), retículo de verdade no aviso do X, pilar de chamas no C
    e o foguete com malha própria (mão → voo), com áudio em camadas (`AudioFX`);
  - **indicador de mira** (`src/player/mira_de_fruta.gd`): segurar mostra, soltar apaga;
  - **conta única de onde o golpe cai** (`src/combat/mira_de_rocket.gd`), dividida entre
    controlador e indicador. Sabotando a origem, o teste reprova com 0,90 m de diferença.

  ⚠️ **Divergência declarada:** a decisão do dono dizia "soltar dispara"; hoje o golpe sai no
  toque, e é daí que vem a responsividade medida. O indicador foi feito sem mudar isso.

  Testes: 88 checagens na história (era 56), 41 na arena, mesmas 6 falhas de compilação conhecidas
  em `tools/anim_editor/studio/` (`preload("res://view.gd")`, anteriores e fora deste trabalho).
  Falta: captura visual aprovada pelo dono, fruta como peça do mapa e o traço de locomoção.
- **Fase 5b — segurar mira, soltar dispara (23/09).** Pedido do dono depois da análise.
  `CastController` ganhou `_mira_fruta`: `comecar` arma (depois de todas as travas que ele já
  rodava) e `soltar` dispara; `mirando()` deixa a mira cair sozinha quando o corpo perde a
  condição, e o indicador virou espelho disso. Soltar outra tecla não cancela a mira em curso;
  soltar com o menu aberto cancela. A arena não mudou uma linha de comportamento — o que separa
  os modos é o `PerfilDeFrutas` ser nulo lá (`test_rocket` 41/41 e `test_modos_de_combate` 18/18).
  Três checagens da suíte da história apertavam a tecla sem soltar e foram atualizadas; a suíte
  voltou a 88/88. **Testes do comportamento novo** (mirar sem disparar, cancelar no menu, mira
  caindo na morte, o caso Z+X) ficaram para depois, a pedido do dono.
  Custo declarado: do soltar ao impacto continua 0,47 s a 12 m; some-se o tempo de dedo na tecla.
- **Fase 5c — pedidos depois de jogar (30/09).** Quatro queixas do dono, medidas antes
  (sonda headless): bocais com fogo acesos em QUALQUER golpe; X espalhado por 25 m (4,3 m
  sem dano entre pontos); F sem virar pela câmera (0° com a câmera a 90°); falta da forma
  de foguete. Decisões dele: bocais fora nos dois modos; X encostado a distância fixa;
  mouse pilota em 3D (WASD não); foguete até o chão, Z/X/C no ar desfazem. Entregue:
  `forma_de_foguete.gd` (novo), `voo_foguete.gd` (mira 3D, curva a 3,2 rad/s, arco de
  0,30 s na virada, retrofoguete), `mira_de_rocket.distancias_do_bombardeio`, bocais fora
  do `rocket_vfx.gd`, chama do foguete do Z só no disparo, `Player._mira_do_voo` +
  `_sincronizar_forma_de_foguete` + `PITCH_DE_DESCANSO`. Testes: história 115/115 (era 88),
  arena 41/41, log limpo; `test_compila` com as mesmas 6 falhas do `anim_editor/studio`.
  Capturas: `art_src/validation/rocket_historia/` (14). Detalhe em `docs/frutas/rocket.md`.
  ⚠️ Duas sessões do Claude editaram este trabalho ao mesmo tempo (uma cópia continuou
  depois que a sessão caiu); os testes 11/11b/12b/14b foram escritos pela outra e
  conferidos/ajustados por esta. Falta: aprovação visual do dono.

