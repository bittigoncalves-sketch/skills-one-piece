# Pesquisa — golpes do Luffy → skills da Gomu Gomu — 15/11/2026

Cumpre a tarefa 1 de `FILA_DE_TAREFAS.md` (pedida em 25/08/2026). **Fonte:** One Piece Wiki (Fandom, comunitária): `Gomu_Gomu_no_Mi`, `/Techniques`, `/Gear_2_Techniques`, `/Gear_3_Techniques`, `/Gear_4_Techniques`, `/Gear_5_Techniques`
(<https://onepiece.fandom.com/wiki/Gomu_Gomu_no_Mi/Techniques>). Itens que a fonte não cobriu estão marcados ❔.

## Os cinco campos, golpe a golpe (os que importam para o jogo)
| golpe | gesto (vira animação) | efeito | alcance/escala | gear |
|---|---|---|---|---|
| **Gomu Gomu no Pistol** | soco reto com o braço que ESTICA e mantém o impulso | dano único | médio/longo (braço esticado) | base |
| **Gomu Gomu no Bazooka** | os dois braços vão para trás e são lançados juntos, palmas abertas | dano único, mais forte | médio | base |
| **Gomu Gomu no Gatling** | rajada de socos (Pistol repetido) ❔ não definido na fonte consultada | múltiplos golpes | curto/médio | base |
| **Gomu Gomu no Rocket** | estica um ou dois braços, agarra um ponto e RECOLHE, lançando o corpo | deslocamento/gap-closer (até contra um oponente) | grande distância | base |
| **Gomu Gomu no Fusen** | infla o corpo pela boca | defesa contra golpe contundente | próprio corpo | base |
| **Jet Missile / Jet Bazooka / Hawk Gatling** | versões de Rocket/Bazooka/Gatling em velocidade e com Haki | mais velocidade e dano | — | **Gear 2** |
| **Gomu Gomu no Elephant Gun** | braço enegrece (Haki) e o punho GIGANTE é arremessado | dano pesado | grande, área do punho | **Gear 3** |
| **Kong Gun** ❔ | carga e soco de Gear 4 (só citado de passagem) | dano muito alto | grande | Gear 4 |
| **Red Hawk** ❔ | não coberto na fonte consultada | — | — | Gear 2 + Haki |

## Decisão para os quatro slots (Z/X/C/V; recargas 5/7/10/25 s; teto 200/256/384/768)
- **Fica:** Z Pistol, X Bazooka, C Gatling — são os três da fonte e o jogo já os tem com hitbox (`docs/frutas/gomu_gomu.md`).
- **V (ultimate):** hoje "Gear 2 / Red Hawk". Como Red Hawk NÃO tem fonte confiável aqui, a recomendação documentada é: manter o V como está (decisão do dono) e registrar a reserva **Elephant Gun (Gear 3)** — gesto, efeito e escala bem definidos na fonte — como candidato a V alternativo ou a skill do Modo História.
- **Reserva (não entra sem decisão do dono):** Rocket (gap-closer: o jogo já tem o `rocket` como fruta própria), Fusen (defesa; exigiria animação de inflar), Jet Missile.
- **Restrição do rig** (`ESQUELETO.md`): o rig não tem mão nem pulso, então gesto que dependa de punho/dedos só entra como efeito (braço esticado + punho em esfera/cubo), como já se faz na Mochi.

## Próximo passo
Nenhuma mudança de código nesta pesquisa. Gatilho para implementar: o dono escolher se o V vira Elephant Gun; então seguem `Balance.novo` (tipo CARREGADO, teto 768), `GomuFX` e teste `test_gomu`.
