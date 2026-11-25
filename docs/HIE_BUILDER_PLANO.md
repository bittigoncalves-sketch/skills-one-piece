# Hie Hie no Mi refeita no Skills Builder — plano (07/10/2026)

Pedido do dono: "preparar redesenvolvimento da fruta do gelo que existe atualmente, hie
hie no mi. todos os golpes irão congelar por 0.7 segundos. deixar o novo teste de skill Z
fruta do gelo no lugar do Z antigo e melhorar o teste, no caso o novo Z."

O "teste de skill Z" é o `Z_ice` ("Z espinhos de gelo — um novo movimento para a fruta do
gelo, remake da atual"), feito pelo dono no editor numa fruta de teste do Builder ("fruta
do gelo", `fruta_do_gelo`): recua ~7 m em 1,35 s disparando 3 rajadas de 8 estacas de gelo
para a mira (0,4 / 0,8 / 1,15 s), 15 cada (até 360), pose "recuo" (braços à frente).

## Decisões do dono

| tema | decisão |
|---|---|
| como entra | como a Pika: a `hie_hie` vira fruta **reconstruída**; o **Z vira o `Z_ice`** (melhorado), X/C/V seguem o código |
| congelar | **todos** os golpes da Hie congelam **0,7 s** (Z, X, C e V — o campo do V também); **0,5 s de imunidade** depois de descongelar |
| fruta de teste | a "fruta do gelo" **sai** do catálogo e da loja |
| o novo Z | **manter a ideia e dar acabamento**: estacas saindo das mãos em leque legível, rajada de névoa/cristais nas mãos a cada salva, rastro frio no recuo, som de gelo, cada estaca congela 0,7 s, dano no teto do Z antigo (192), custo e recarga da Hie, pose de disparo, foto de cada momento |

## Medição antes de mexer

- Hie de hoje (`IceFX`, `Balance`): Z Disparo de Gelo 16 × 12 = 192, recarga 5 s, não congela; X Iceberg 168, não congela; C Investida 192, congela 5 s (+2 s de imunidade); V Ice Age, campo de 50 s que congela 5 s (+2 s).
- **Congelar em rede não chega ao cliente**: `IceFX._congelar_alvo` marca `is_frozen` onde o dano acontece (servidor), mas o corpo de um jogador remoto é movido pelo cliente dono — não há RPC de congelamento (a lentidão da Noro precisou de `aplicar_lentidao_em_rede`). O gelo de hoje provavelmente não prende outro jogador em rede (só o host e a IA). Entra no escopo: "todos os golpes congelam".

## Decisões técnicas (com custo e gatilho)

| decisão | por quê | custo | risco / gatilho |
|---|---|---|---|
| Um congelamento só: `IceFX.congelar(alvo, segundos)` (0,7 s; imunidade `IceFX.IMUNIDADE` 0,5 s), usado por Z (Builder), X, C e V | regra única "todos congelam 0,7 / 0,5" | baixo | — |
| Em rede: o servidor manda `Player.congelar_em_rede(s)` a todos (o dono trava o próprio corpo; todos veem o bloco de gelo) | o corpo remoto é do cliente | médio | sonda de dois processos |
| Builder ganha `dano.congelar` (s) e `projeteis.sai_de` (Corpo / Mão direita / Mão esquerda / Entre as mãos) e o som "Gelo: disparo" | tudo que o Z novo usa tem de estar no editor | baixo | — |
| O Z novo é refeito por script que opera o editor (`tools/criar_hie_hie.gd`), partindo do `Z_ice` do dono | reproduzível, como a Pika | baixo | o rascunho original do dono fica guardado como `Z_ice_original` na biblioteca |
| Código antigo do Z (`IceFX._disparo_de_gelo`) fica sem uso | igual à Pika | — | gatilho para apagar: o dono aprovar o Z novo jogando |

## Fatias

| # | fatia | pronto quando | estado |
|---|---|---|---|
| H1 | congelar único 0,7/0,5 + rede | X, C e V congelam 0,7 s com 0,5 s de imunidade; jogador remoto fica preso no cliente; testes | **feito** — `IceFX.congelar` + `Player.congelar_em_rede`; não-jogador tem a física parada; bloco no meio do corpo; temporizadores com referência fraca; `test_hie_builder` (X 0,75 / C 0,74 / V 0,70 e recongela 0,70 s depois); `net_hie_*_probe`: cliente congelado 0,70 s sem andar, o Z do host o congela 0,69 s |
| H2 | Builder: congelar, "sai de", som de gelo | campos no editor, executor e prévia; teste | **feito** — `dano.congelar`, `projeteis.sai_de`, sons "Gelo: disparo/rajada"; prévia: alvo no bloco de gelo; `test_builder_gelo` 3/3 |
| H3 | Z novo + Hie reconstruída + fruta de teste fora | `criar_hie_hie.gd` publica; Z congela, dano ≤ 192, recarga 5 s; fotos; testes (história, arena, auditoria dos NPCs, rede) | **feito** — publicado; `test_hie_builder` 14/14 (recua 6,7 m, 24 estacas a 0,13 m das mãos, congela 0,8 s com a física parada, arena); fotos `capturar_hie_builder.gd` (cristais nas mãos, salva, boneco no bloco de gelo, recuo com anel); biblioteca real do dono atualizada (`Z_ice` + `Z_ice_original`) |
| H4 | bateria completa (rodadas 4 e 5) | sem falha nova | **feito** — headless 162/12 (as 12 conhecidas); cena, LAN, mp, dano, kit e **hie** verdes; traco_locomocao, a conhecida; `net_pika_probe` reprovou por azar (mínimo de dano num golpe sorteado), critério corrigido e verde 2× (erros.md). A bateria abortou uma vez porque outra frente editou o `validar.sh` no meio; o resto rodou pela cópia na memória |

## Gatilhos e convivência (07/10/2026, noite)

- **Tamanho:** a frente de "Transformação" (`docs/TRANSFORMACAO_BUILDER_CHECKPOINT.md`, em andamento desde 14:17) acrescentou blocos ao executor (853 linhas) e à prévia (869), que passaram da marca de 850 deste plano (teto do projeto: 900). A extração de âncora, mãos e clipes para um módulo fica para quando aquela frente terminar, para não refatorar arquivos que ela está editando. Gatilho: o checkpoint dela marcar "feito", ou qualquer um dos dois passar de 880.
- **Convivência:** com as mudanças daquela frente no lugar, os 15 testes do Builder, da Pika e da Hie passam (`test_hie_builder` 14/14, `test_builder_gelo` 3/3, `test_pika_builder` 30/30, os 5 `test_skills_builder_*` etc.).

## 10/10/2026 (Modo História)
- **Z:** campo `projeteis.imunidade_gelo`; só a 3ª salva deixa imunidade, e acerto em quem
  já está congelado estica o gelo (`IceFX.congelar(..., estender)`). `test_hie_z_imunidade`.
- **V:** `EraDoGelo` — o lugar vira gelo num raio fixo de 20 m (decal só no cenário).
  `test_hie_v_gelo`. Arena sem mudança. Ver `docs/PEDIDO_2026-10-10_HISTORIA.md`.
