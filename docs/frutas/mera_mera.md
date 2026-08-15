# Mera Mera no Mi — fogo

**Id:** `mera_mera` · **Tipo:** Logia · **Passiva declarada:** Combustão
Progressiva — só `speed_mod 1,15` está implementado (as "cargas de chama" da
descrição não existem no código; ver o README da pasta).

Personagem associado: equipar troca a aparência para **`ace`**, se o id estiver
em `Player.ELENCO_LIBERADO` (hoje não está — o elenco está travado em `base` e
`bluebuddy`, então a troca não acontece).

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/FireFX.gd` | Z, X, C e a bala de fogo compartilhada (`bullet`) |
| `src/effects/FireFXGrande.gd` | o V (Inferno) e a explosão — saiu do `FireFX` pelo teto de 900 linhas |
| `src/player/disparo_sustentado.gd` | a **rajada** do Z (compartilhada com a Hie Hie) |
| `src/effects/BurnStatus.gd` | queimadura contínua |

---

## O que cada tecla faz, hoje

### Z — Higan: RAJADA, não um golpe

O Z da Mera (e da Hie) não passa pelo cast normal: `CastController.comecar()`
liga `DisparoSustentado.iniciar_rajada()` no **pressionar** e a rajada corre
sozinha até a tecla soltar ou o pente acabar.

| | valor |
|---|---|
| cadência | `INTERVALO = 0,09 s` |
| teto | `MAX_BALAS = 16` por rajada |
| bala (`FireFX.bullet`) | dano 8 · kb 9 · `fwd × 55` m/s · vida 0,7 s · raio 0,35 |

**Por que a rajada não congela o corpo:** é a única mecânica de tiro sustentado
da fruta; travar o jogador transformaria o golpe de pressão em golpe de risco.
A pistola da Yami segue a mesma regra e mora no mesmo componente.

O `_higan` do `FireFX` (variante 0 do `cast`) também existe e cria zonas de
`dano × 0,3` a `dir × 35`. Ele é o caminho usado quando o slot Z é conjurado
**sem** passar pela rajada.

### X, C, V

| tecla | golpe | hitbox |
|---|---|---|
| **X** | Hiken — o punho de fogo | dano 45 · kb 35 · `d × 25` · vida 1,2 s · raio 2,5 |
| **C** | Dai Enkai: Entei — o sol | modelo do sol + zonas de `FireFXGrande` |
| **V** | Inferno | zona de entrada `dano × 0,45`, kb 35, **raio 22 m**, vida 0,6 s · depois tiques de `dano × 0,16` a cada 0,15 s no mesmo raio |

O V é o golpe de **área persistente** mais largo do jogo (22 m de raio, contra
15 m dos tsunamis da Gura).

---

## Pendências

- **Item 21 da lista:** `FireFX.gd:200` chama `mmi.look_at(...)` **antes** do
  `add_child`, então o transform global é inválido e o `look_at` falha — 32
  ocorrências por processo durante o Z. A bala de fogo nunca é orientada.
- **Item 13:** `FireFXGrande.gd:185` e `:234` fazem `set_meta("is_suppressed")`
  e **ninguém lê** esse metadado. Código morto; a supressão real é a chamada de
  `suppress_skills_temporarily` na linha seguinte.
- **O comentário do topo do `FireFX.gd` está velho:** ele diz que o C é o
  *Hibashira*. O C é `_entei_sun` desde a repaginação; o `_hibashira_legado`
  segue em `FireFXGrande.gd:18` **sem nenhum chamador**.
  ⚠️ A pose `"hibashira"` ainda concede **imunidade a dano** em
  `Player.gd:1069`, `TrainingDummy.gd:64` e `disabled/enemies/Enemy.gd:129`.
  Hoje nada liga essa pose, então é imunidade adormecida — se o Hibashira
  voltar, ela volta junto sem ninguém decidir isso.
- Vazamento: a auditoria de 2026-08-10 mediu 9 nós sobrando no V e 1 no Z; a
  releitura mostrou que quase tudo era **duração longa de propósito**, não
  vazamento. Ver as ressalvas em [`../AUDITORIA_FRUTAS.md`](../AUDITORIA_FRUTAS.md).
