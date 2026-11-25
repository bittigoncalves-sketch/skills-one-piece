# Ushi Ushi no Mi (Girafa) — implementação (21/11/2026)

Plano e referências: `PLANO.md` e `art_src/references/ushi_ushi/*.png` (Codex). Código: `src/combat/ushi/`.

## O que existe
| Peça | Arquivo | Função |
|---|---|---|
| Módulo | `ushi_ushi.gd` | 3 formas (0 humano · 1 humanoide do mod · 2 girafa), Z/X/C por forma, recarga/HUD, corrida do humanoide |
| Corte | `ushi_corte.gd` | lâmina de ar do X e da C: sem física, 1 MeshInstance3D (malha estática de 2 superfícies), teto de 14 vivos, centros dos alvos calculados 1× por quadro |
| Pescoço | `ushi_pescoco.gd` | pescoço+cabeça procedurais (pitch/yaw/extensão); servem às 3 formas |
| Quadrúpede | `forma_girafa.gd` | corpo, 4 patas de 2 juntas, galope pela distância percorrida, cauda |
| Materiais | `ushi_materiais.gd` | pele de Voronoi (cores da textura do mod), brilho do corte — um de cada |

Integração: `ControladorFrutaDoMod` (módulo filho, como Buda/Zushi; Z/X/C interceptados, J cicla as formas via `_passo_do_mod`), `FormaZoan.pos_seguir` (gancho de pose), `Balance` (`ushi_ushi_giraffe` Z/X/C, `ushi_ushi_girafa` Z/X).

## Golpes (valores provisórios de playtest)
| Forma | Z | X | C |
|---|---|---|---|
| 0/1 | Investida do Pescoço (60 en., 0,22+0,26+0,36 s, 5,5 m, 1 acerto/alvo) | Corte no Ar (100 en., lâmina 2,6 m, 30 m/s, 22 m) | Rajada de Cortes (150 en., 9 cortes em 1,26 s, leque, teto 324) |
| 2 | Pescoçada (60 en., 6,5 m) | Martelada (110 en., varre ~100° com o nariz) | não existe |
V (Sky Slicer, do mod) segue nas formas 0 e 1.

## Decisões (confirmadas pelo dono em 21/11/2026)
1. Formas 0 e 1 usam o kit novo (o plano do Codex deixa a 0 em aberto). Para a 0 manter os golpes do mod, restringir `iniciar()` a `forma != 0`.
2. "Corrida refeita" vale para as formas 1 (`_pose_humanoide`) e 2 (galope). O humano comum mantém a corrida do rig.
3. A forma 2 é estado do módulo; o atributo `minepiece:form` do mod fica em 1 (tamanho/resistência da girafa).

## Correções do dono (21/11/2026, depois de testar no jogo)
- **X e C não iam longe e subiam:** os cortes agora voam RETO na direção exata da mira (`_dir_reta`, sem convergir para um ponto nem limitar a elevação), saindo do lado do pé que chuta na altura do quadril. Alcance/velocidade: X 40 m a 45 m/s, C 32 m a 42 m/s (antes 22 m/18 m). Teste: desvio da direção < 0,01 rad e lâmina chegando a alvo a 36 m.
- **Peça flutuando na girafa humanoide (print do jogo):** a 2ª camada do modelo ("Head#1") não recebia a pose da corrida e ficava parada na pose do rig enquanto a cabeça inclinava. Agora toda camada (`nome#N`) recebe a pose da peça-base. Capturas `02_humanoide_corrida_*` mostram a cabeça inteira, sem peça solta.
- **Resistência ×1,5 transformado:** meta `resistencia_de_forma = 1,5` nas formas 1 e 2 (removida no humano), aplicada em `Player.take_damage` (`dano /= resistência`). Teste: duas pancadas de 10 → perda 1,5× menor transformado.

## Feedback do dono (21/11/2026, depois do Z aprovado) — implementado
- **Chute em todas as formas, X e C com boa animação, X = chute aéreo que dispara o corte, "como uma bicuda lateral":** `ushi_chute.gd` (plano do Codex em `PLANO_ANIMACOES.md`). X = bicuda lateral aérea de 0,74 s: arma (perna recolhida com o joelho para fora) → impulso (salto visual de 0,25 m) → **pico em 0,34 s, o corte sai da ponta do pé** → varre o arco à frente → aterrissa na esquerda. C = 9 bicudas alternando D/E (ciclo 0,14 s), um corte no PICO de cada chute (0,084 s depois do início do ciclo), saindo do pé que chuta. A pose vai pela meta `pose_externa` do rig (gancho genérico em `ProceduralAnimator`); a girafa humanoide segue as juntas, então o mesmo movimento serve ao humano (forma 0) e ao humanoide (forma 1, pernas rígidas: sem joelho).
- **Girafa (forma 2):** escolha do dono = **coice visual na preparação do X** (pata traseira direita arma, estica para trás, volta ao apoio; sem dano). Z (Pescoçada) intocado.
- **Sons (um por ataque):** `ushi_audio.gd`, 9 cues procedurais (Z investida, Pescoçada, X "varrida + shing", talho do C em 3 tons, Martelada com BONK, impacto do pescoço e da lâmina). Testados por pico/duração; **não foram ouvidos** (headless) — precisam de ouvido humano para ajuste de volume/timbre.
- **Capturas (79 imagens, luz neutra, tempo congelado, cápsulas escondidas):** `*_X_t015/t030/t034/t040/t055_{frente,3q,lado}`, `*_C_pico{1,2,5}_{direita,esquerda}_{frente,3q,atras}` (prefixos `00_humano_`, `04_humanoide_`/`05_humanoide_`), `16a/16b` coice, `17a–d` martelada. Marcadores: vermelho = pé direito, azul = esquerdo (nos chutes).
- **Achado da revisão do Codex (#148) e correção:** a pose chegava às juntas (sonda `tools/dev_tests/sonda_pose_externa.gd`: coxa D desvia 1,66 rad), mas medindo o EIXO da coxa/canela no pico (t=0,342 s) a perna só tinha subido ~54° para o lado, com o joelho dobrado ~50° (o rig soma a pose ao repouso + guarda) e o pico visível chegava ~60 ms depois da emissão. Corrigido em `ushi_chute.gd`: joelho estendido no pico (+15°), abdução menor no pico (8°) e `ATRASO_DO_RIG = 0,06 s` antecipando a linha do tempo. Depois: coxa e canela alinhadas (eixos ≈ (0,35, −0,47, −0,89) e (0,33, −0,51, −0,88): perna esticada à frente, ~30° abaixo da horizontal) no instante do corte.

## Evidência (21/11/2026)
- **Visual:** 16 capturas com render real (Godot/OpenGL compat em Xephyr, software GL) em `art_src/validation/ushi_ushi/` (`tools/dev_tests/captura_ushi.gd`): humanoide parado e correndo, Z (preparo/pico), X e C (lâmina em voo), girafa parada e galopando, Pescoçada e Martelada. Golpes fotografados **no pico, com o tempo do jogo congelado** (o render por software faz ~5 quadros/s). O `Z` da girafa humanoide mostra o pescoço saindo dos ombros como aríete; a Pescoçada, o pescoço reto como um soco; a Martelada, o pescoço varrendo de lado com o nariz; a lâmina do X lê como crescente claro com halo dourado.
- **Lag (relativo, software GL):** quadro médio 177–201 ms sem golpe contra 181–203 ms durante a rajada de 9 cortes (3 rajadas seguidas) — sem custo mensurável da rajada. Headless: baseline 20–44 ms vs 26–31 ms (ruído da máquina). Não é medição de GPU nem de FPS no hardware do jogador.
- **Custo de CPU do pior caso (headless, monitor de física do motor):** 14 cortes vivos (o teto) contra 60 alvos = +0,62 ms/quadro de física (1,21 → 1,83 ms); o filtro geométrico usa uma lista de centros calculada uma vez por quadro. Um C real (9 cortes, poucos inimigos) custa bem menos. É CPU do script; GPU não foi medida (1 malha de 2 superfícies por corte, sem sombra).
- **Testes:** `test_ushi_ushi` 48/48 (inclui pose de chute, pico = emissão, salto, 9 cortes alternados, 9 sons) (inclui parede: X e Z não ferem através de cenário; baseline medida ANTES da rajada); `test_forma_zoan` ushi OK. Falhas que **não** são do Ushi: `test_forma_zoan` altura de phoenix e supa; `test_balance` agora roda inteiro (adicionei `SLOT["K"]`/`["L"]` do Zushi, que faltavam) e as entradas do Ushi passam; sobra só `pika_pika/Z` (total 98 < 85% do teto 200), que não é do Ushi; `test_transformacao_historia` (X/C do Builder em NPC/objeto).
- **Revisão do Codex (#135) aplicada:** 1 MeshInstance por corte (malha de 2 superfícies); raio de obstáculo cobre o passo inteiro e é feito ANTES do dano; pescoço não fere através de parede; orçamento de dano não é encerrado com cortes ainda em voo; cortes saem com a fruta; cabeça humana e 2ª camada da cabeça somem durante o Z. Danos seguem a régua de slot do `Balance` (Z 96, X 160, C 9×36, girafa 96/192), não os múltiplos de D do plano: ajuste só com playtest.

## Limites conhecidos
- Visual: só o dono vê as formas (a forma é atributo do servidor, não replicada — limite já documentado em `FORMAS_ZOAN.md`). Os cortes nascem no servidor.
- Aprovação artística é do dono: pose do tronco no Z humanoide (inclina bastante), cores (a luz azul do cenário de teste esverdeia o amarelo) e galope precisam do seu olho; usar as 8 referências como régua.
- Gatilho: se o dono aprovar a girafa como forma final, trocar o corpo procedural por modelo modelado (Blender) mantendo a API de `FormaGirafa`.

## Teste
`godot --headless --path . --script tools/dev_tests/test_ushi_ushi.gd` — 48 verificações (formas, HUD, Z/X/C, rajada, limite de cortes, parede, custo de física, girafa Z/X/sem C, volta ao humano).
