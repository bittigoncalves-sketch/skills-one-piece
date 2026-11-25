# Rocket — a primeira fruta do Modo História

Referência: **Blox Fruits** (vídeo de showcase do dono, 22/09/2026). Estado lido no código em
22/09/2026. O que vale para todas as frutas está em [`README.md`](README.md) — aqui só o que é
desta.

> **A Rocket tem DOIS kits**, porque tem dois modos. O corpo é o mesmo
> (`src/combat/rocket_controller.gd`); o que muda é a ficha de cada modo.
>
> | | arena | Modo História |
> |---|---|---|
> | de onde vêm os números | `src/combat/Balance.gd` | `src/historia/frutas/rocket.tres` |
> | custo de energia | `Player.ENERGY_SKILL` (180 de 4.096) | da ficha (2 de 10) |
> | **Z** | soco propulsionado (2,8 m) | **Missile Fist** — míssil que explode em área |
> | **X** | investida do corpo (11 m) | **Air Strike** — bombardeio em linha |
> | **C** | barragem de 8 pulsos (15 m) | **Rocket Crash** — salto e queda |
> | **V** | sobrecarga + mergulho | **não existe** (a fruta da referência não tem V) |
> | **F** | — | **Blast Off** — voo curto |

## O kit do Modo História (o do vídeo)

| tecla | golpe | o que faz | dano | custo | recarga |
|---|---|---|---:|---:|---:|
| **Z** | Missile Fist | foguete sai do braço a ~90 m/s (alcance 40 m) e explode num raio de 2 m | 30 | 2 | 6 s |
| **X** | Air Strike | 3 explosões **encostadas** logo à frente, a distância **fixa** (centros a 2,5 / 5,7 / 8,9 m): retículo avisa 0,2 s antes, cadeia do perto ao longe, **lança o alvo para cima** | 3 × 15 | 3 | 10 s |
| **C** | Rocket Crash | agacha, cruza pelo alto até o ponto mirado (até 18 m) em ~0,4 s e explode num raio de 3,5 m, com **close curto de câmera** | 45 | 3 | 12 s |
| **F** | Blast Off | o jogador **vira um foguete**: sobe em arco, plana 3 s **pilotado pelo mouse em 3D** e pousa de pé no retrofoguete | — | 2 | 8 s |

Escala: o inimigo do mapa tem 250 de vida e o jab do boxe tira 20. A energia do Civil é 10 e
regenera **1/s neste modo** (a regra da arena, 0,5%/s, daria 0,05/s).

## As regras que valem só aqui

- **A guarda do combate direcional segura a fruta.** A explosão consulta
  `ResolucaoDeContato.resolver_tecnica` ANTES do dano: bloqueado passa **30%** e gasta postura
  (25 no Z); com a postura no fim, a guarda **quebra** e o dano entra inteiro. **Aparo não vale
  contra técnica** (decisão do dono, 21/09).
- **Sem `DamageZone` no Z**: a explosão faz a própria consulta de área. A `DamageZone` grava
  derrubada e emite `hit_landed` antes de qualquer defesa (achado M1 do `PLANO_COMBATE_HISTORIA.md`).
- **O clique continua sendo o boxe direcional**: a fruta mora só em Z/X/C e F, sem troca de modo.
- **O V não sai**: com ficha da história, `rocket_controller.slot_permitido` recusa tecla fora dela.
- **O voo não mata de queda**: qualquer fim (tempo, dano, perder a fruta) passa pelo pouso suave.

## Onde mora cada parte

| parte | arquivo |
|---|---|
| estado, rede e comportamentos (míssil, soco, investida, barragem, mergulho) | `src/combat/rocket_controller.gd` |
| hitbox cancelável (usada pelos golpes da arena) | `src/combat/rocket_hitbox.gd` |
| voo curto (componente de locomoção) | `src/player/voo_foguete.gd` |
| **forma de foguete** do F (malha, chama, fumaça, puff) | `src/effects/forma_de_foguete.gd` |
| números do Modo História | `src/historia/frutas/rocket.tres` (fichas: `tecnica_de_fruta.gd`, `perfil_de_frutas.gd`) |
| números da arena | `src/combat/Balance.gd` |
| efeitos | `src/effects/rocket_vfx.gd` |
| poses | `src/anim/rocket_poses.gd` (+ `ProceduralAnimator`) |
| **onde o golpe cai** (conta única) | `src/combat/mira_de_rocket.gd` |
| **indicador de mira** (segurar mostra) | `src/player/mira_de_fruta.gd` |
| como se come e como se equipa | `src/historia/progressao.gd`, `ModoHistoria.equipar_fruta` |
| HUD das técnicas | `src/ui/TecnicasHud.gd` |
| testes | `tools/dev_tests/test_rocket.gd` (arena), `tools/dev_tests/test_fruta_rocket_historia.gd` (história) |

## Apresentação (23/09/2026)

Comparação com o vídeo feita com julgamento tipado (`jev`): funcionalidade **igual ou
superior** (o Z é mais rápido — 0,22 s de voo a 20 m contra 0,2–0,3 s da referência, com
preparo de 0,35 s contra ~0,8 s — e ganha defesa, ficha calibrável e validação de
servidor), **design abaixo** em 9 de 13 aspectos. O que foi fechado desde então:

- **Pose própria por golpe.** `_pose()` pede `rocket_` + comportamento da ficha; as chaves
  `rocket_missil`, `rocket_bombardeio` e `rocket_mergulho` **não existiam** e os três
  golpes saíam com a sequência genérica de soco. Agora: Z de lado com o braço erguido e
  coice no disparo; X de perfil com as mãos no peito (detonador) e o aperto na cadeia; C
  em quatro tempos (agacha, sobe, mergulha de cabeça, aterrissa) com a aterrissagem caindo
  **exatamente** no instante do impacto (t 0,37 de 1,40 s).
- **Paleta medida.** As oito cores do vídeo viraram constantes em `rocket_vfx.gd`; `FOGO`
  e `NUCLEO` passaram a apontar para os tons medidos mais próximos (a arena muda de tom
  por alguns pontos, não de linguagem).
- **Camadas que faltavam:** estilhaços pretos serrilhados em toda explosão, **mancha preta
  que fica no chão** (7 s, só quando a explosão foi no chão), **retículo de verdade** no
  aviso do X (círculo com ponto, do tamanho do estrago, 0,20 s antes), **pilar vertical de
  chamas** com anel claro no C, e o **foguete com malha própria** — ogiva, corpo, três
  aletas — que fica na mão durante o preparo e depois cruza o cenário.
- **Áudio em camadas:** canhão no disparo e no pilar, sopro no voo do foguete, estalo no
  retículo, impacto na explosão (tudo procedural, `AudioFX`).
- **Indicador de mira:** segurar Z mostra a linha do tiro, X os três pontos do bombardeio,
  C o ponto de queda; soltar apaga. O F não desenha nada (não tem alvo no chão).

## Segurar mira, soltar dispara (23/09/2026)

Decisão do dono, fechada depois da análise. **Só no Modo História**: o que separa os dois
modos é o `PerfilDeFrutas`, nulo na arena — lá o toque continua disparando na hora, e
`test_rocket` prova (41/41).

- **`CastController.comecar`**: chegar ao bloco da Rocket já significa que recarga,
  supressão, bloqueio por dano e trava pós-fruta passaram. Com ficha do modo e energia
  suficiente, em vez de chamar `pedir` ele **arma a mira** (`_mira_fruta = slot`).
- **`CastController.soltar`**: é aqui que o golpe sai. Soltar **outra** tecla não mexe na
  mira em curso (com Z segurado, apertar X troca para o X; largar o Z depois não cancela).
  Soltar com o **menu aberto cancela** — a HUD manda o KEY-UP mesmo com menu aberto, de
  propósito, para a técnica não ficar presa.
- **A mira cai sozinha** quando o corpo perde a condição (morrer, levar dano, ser
  silenciado, trocar de modo, perder a fruta). A checagem mora no getter `mirando()`, e
  não num tick: assim não existe caminho em que o estado fique preso porque ninguém
  chamou o tick (item 23 — morrer segurando a tecla).
- **O indicador é espelho**, não fonte: acende só depois que `comecar` armou
  (`_cast.mirando() == slot`) e se esconde sozinho quando a mira cai.
- **O F não passa por aqui.** O voo é locomoção e entra direto por `pedir_voo_de_fruta`;
  no toque, como sempre.

Custo declarado: do **soltar** ao impacto o tempo é o mesmo de antes (0,47 s a 12 m); o
que se soma é o tempo em que o dedo fica na tecla, que agora é escolha do jogador. Era a
vantagem de responsividade medida contra a referência, trocada de propósito pela mira.

## Pedidos do dono depois de jogar (30/09/2026)

"Funcionais, porém do ponto de vista visual e de controle do jogador estão ruins." Quatro
queixas, medidas antes de mexer, e as decisões dele:

| queixa | causa medida | decisão | o que mudou |
|---|---|---|---|
| "escapamento com fogo acima da cabeça em qualquer ataque" | `rocket_vfx.gd` montava dois bocais metálicos com fogo, fumaça e luz a +0,8 m e os acendia sempre que a fruta estava `ocupado()` — em todo golpe | remover **nos dois modos** | bocais, partículas e luz saíram; ficou uma âncora invisível no antebraço para o foguete do Z. De quebra, o foguete do Z na mão está com a **chama apagada** (acendia na altura da cabeça no preparo) e acende no disparo |
| "espaçamento muito grande entre as áreas do X" | os 3 pontos se espalhavam pelos 25 m da ficha (8,3 / 16,7 / 25 m) com raio 2 → 4,3 m de chão sem dano entre eles; e o ponto mirado era ignorado | **encostadas, distância fixa** | `mira_de_rocket.distancias_do_bombardeio(raio, n)`: passo = 2·raio·(1 − 0,2), primeira borda a 0,5 m. Deriva do **raio** — mexer no raio mantém encostadas. O `alcance` do X saiu da ficha |
| "o F não muda de direção" | o WASD desviava só no plano; girar a câmera (o gesto natural) desviava **0°** | **mouse pilota em 3D** | o rumo persegue o yaw/pitch da câmera a 3,2 rad/s (curva em arco), nariz limitado a ±60°. O **pitch de descanso** da câmera (−0,25, ela olha 14° para baixo) vale como voo nivelado — senão o foguete mergulhava sozinho. WASD não mexe mais. Mergulhar até o chão encerra o voo |
| "transformação do jogador em um literal foguete" | — | **foguete até o chão**; Z/X/C no ar desfazem a forma | `forma_de_foguete.gd`: casco vermelho, ogiva creme, faixas e aletas pretas, escotilha, bocal, chama em camadas, fumaça em disco macio, brasas e luz; inclina nas curvas; puff ao entrar e sair. O corpo some por `_atualizar_visibilidade_corpo` (3º caso, junto da 1ª pessoa e da Buki) |

**Decisões minhas, declaradas:** dano, morte e perder a fruta desfazem a forma como o golpe
(o corpo desce pelo pouso suave); o clique (boxe) também desfaz; em 1ª pessoa a malha do
foguete não se desenha (a câmera ficaria dentro do casco).

**Mudanças de sensação que vieram junto:**
- **Arco na virada** (`VooFoguete.ARCO` = 0,30 s): a velocidade passava de ~77° para cima a
  horizontal num quadro e o nariz ficava 78° fora da direção. Agora faz curva — e sobe
  mais: 6,4 m em vez de 4,2 m.
- **Pouso por retrofoguete:** a descida é proporcional à altura (1,5 m/s por metro, entre
  1,8 e 10 m/s). Com o voo livre em 3D a altura deixou de ser fixa, e os 4 m/s constantes
  de antes levariam mais que o limite de 6 s vindo de 20 m. Toca o chão a 1,8 m/s —
  abaixo dos 2 m/s em que o `FallImpactController` racha o chão.
- O voo inteiro passou de ~4,4 s para ~5,1 s.

**Limites conhecidos:** o colisor continua a cápsula de pé do personagem (o nariz do
foguete, deitado, passa ~1 m à frente dela e pode entrar um pouco em parede); a velocidade
de planagem continua 9 m/s, abaixo da corrida embalada (12,6 m/s); a forma não é replicada
em rede (o Modo História é local).

Evidência: `test_fruta_rocket_historia` 115/115 (era 88), `test_rocket` 41/41, log limpo;
capturas na câmera do jogo em `art_src/validation/rocket_historia/`.

## Uma conta só para onde o golpe cai

`src/combat/mira_de_rocket.gd` é estático e puro: `ponto_mirado`, `pontos_do_bombardeio`
(+ `distancias_do_bombardeio`), `fim_do_missil`, mais `raio`/`solo` (corpo que toma dano
**não** é chão). O controlador e
o indicador chamam os mesmos métodos — duas contas separadas virariam duas verdades, com o
anel mostrando um ponto e a explosão saindo em outro. O teste prova isso comparando o anel
mostrado ANTES do pedido com o lugar onde o corpo aterrissou; com a origem errada (a de
`mira_do_cast`, 1,5 m à frente do corpo) ele reprova com 0,90 m de diferença.

## Como provar jogando

`./jogar_historia.sh` → **F8** (ferramentas de teste) → **Comer Rocket** (dá Fruta 1) → invoque um
**boneco de duelo** e teste o Z. Com o boneco em "Só guarda" dá para ver o bloqueio e a quebra.

## Exceção declarada

O **close de câmera no impacto do C** é a única exceção à regra de não forçar câmera nem usar
soco de FOV: o dono aprovou em 22/09 depois de ver o close no vídeo. Vale só na câmera de quem
deu o golpe (`CameraRig.aproximar`), dura 0,2 s e volta sozinho.

## O que falta

- **Fase 5:** a fruta como peça do mapa (modelo no Blender, categoria "frutas", volta em 300 s).
  Os VFX fiéis ao vídeo saíram em 23/09 (seção acima); falta a **captura aprovada pelo dono** —
  teste headless prova que a camada existe, não que está bonita.
- **Fase 6:** balanço com o `critico-de-combate` e captura visual aprovada pelo dono.
- Não rodado ainda: traço de locomoção (teste com tela) depois do voo.
