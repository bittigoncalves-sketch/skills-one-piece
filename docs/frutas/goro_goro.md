# Goro Goro no Mi — trovão

**Id:** `goro_goro` · **Tipo:** Logia · **Passiva declarada:** Sobrecarga
Voltáica — só `speed_mod 1,15` / `jump_mod 1,10` estão implementados (o
*volt meter* de 0 a 100 não existe no código).

É a fruta mais trabalhada em VFX do projeto, e a **primeira a ganhar
charge-up** — a mecânica que o X da Gura Gura reaproveita depois.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/GoroFX.gd` | a **paleta**, a oficina de raios (`bolt_fill`, `volt_material`, `storm_cloud`, `shock_ring`) e os golpes do dia a dia (Z, C) |
| `src/effects/GoroFXGrande.gd` | os dois espetáculos: **X (El Thor)** e **V (Mamaragan)** |
| `src/player/cast_controller.gd:68,159-196` | o gatilho do X no aperto e o charge-up do V |

**Por que dois arquivos.** Os espetáculos são blocos grandes que não participam
do combate normal, e o projeto tem teto de 900 linhas por script
([`../LIMITE_DE_TAMANHO.md`](../LIMITE_DE_TAMANHO.md)). A **oficina fica no
`GoroFX`** e é chamada de lá: duplicá-la criaria duas fontes de verdade para a
paleta do trovão.

### ⚠️ Regra de ouro da paleta

A **nuvem** e a **bola** são azul-escuras; o **raio** é amarelo-branco. O efeito
é o contraste. Por isso as nuvens **não** usam blend aditivo (aditivo sobre
escuro = nada): são alpha opaco, sem emissão. Só o raio é aditivo/emissivo. Se a
nuvem clarear, o raio some dentro dela.

---

## O que cada tecla faz, hoje

| tecla | golpe | o que acontece | hitbox |
|---|---|---|---|
| **Z** | Sango | feixe elétrico à frente | dano 30 · kb 14 · `fwd × 32` · vida 1,1 s · raio 1,0 |
| **X** | El Thor | nuvem de raio 9,5 m, **11 raios** que caem em 4,2 s e a coluna final | raios: `dano × 0,35`, **`paralisa = 1,2 s`**, raio 2,8 · coluna: dano cheio, kb 22, raio 3,5, vida 3,2 s |
| **C** | Shunshin | teleporte-raio curto | dano 20 · kb 10 · `fwd × 25` · vida 0,6 s · raio 1,2 |
| **V** | Mamaragan | **carregável**: a bola cresce enquanto a tecla é segurada e é arremessada na mira do instante da soltura | bola: `dano × 0,6`, kb 26, raio 2,6 · impacto: dano cheio, kb 30, **raio 12**, vida 0,5 s |

### O X tem um gatilho separado do golpe

`CastController.comecar()` chama `GoroFXGrande.gatilho_do_braco()` **no aperto**,
antes de qualquer outra coisa. Pedido do dono: *"a parte inicial do raio indo
para cima é ativada mesmo se o jogador continuar segurando a skill, visto que não
é a parte do ataque e sim uma mecânica para iniciar a reação"*. A origem é o
**`ForeArm_R` do rig**; sem rig na árvore, cai no peito.

### Os raios do X PARALISAM; só a coluna empurra

`zona.paralisa = 1,2` (`GoroFXGrande.gd:295`) troca knockback por `is_frozen` +
`StatusFX.CONGELADO` — o mesmo sinal que o gelo já usa e que o
`_etapa_travamento` do `Player` já respeita.

**Por quê:** empurrar nos raios iniciais espalhava o alvo para fora da área
antes de a coluna chegar. **O golpe se sabotava.** É o único uso do campo
`paralisa` da `DamageZone` no projeto inteiro.

### O charge-up do V

Linha do tempo em `MamaraganController`: `T_CARGA = 2,30 s` para a bola ficar
completa (raio 0,30 → 2,30), `T_LANCA = 3,30`, `TOTAL = 5,40`. Segurando, a
linha do tempo **congela** em `T_LANCA` e a bola espera o dedo.

Três regras que separam o charge-up de todo o resto do jogo:

- a execução 3D começa **no clique**, não na soltura;
- soltar dispara com a carga que houver, na mira **daquele instante**;
- **levar dano dispara** em vez de cancelar (`CastController.liberar_por_dano()`
  roda **antes** do `SkillSystem.interrupt_casting` em `take_damage`).

Soltar cedo **libera o jogador na hora** (`_liberar_jogador()`): antes o
travamento era armado para a duração cheia e quem soltava em 1 s ficava
flutuando até o prazo original vencer.

Coberto por `tools/dev_tests/test_charge_up.gd` (9 checagens).

---

## Pendências

- A recarga real do V é **25 s** (`Player.RECARGA_POR_SLOT`), não os 60 s que a
  tabela do `SkillSystem` ainda declara — item 33 da lista. O motivo do 25:
  com 60 s o ultimate saía uma vez por rodada e testar exigia esperar um minuto
  por tentativa.
- O *volt meter* da passiva não existe. Se for implementado, o lugar é a
  `FruitPassiveSystem` (que hoje só entrega dois multiplicadores).

Histórico completo da repaginação: [`../PEDIDO_2026-08-12.md`](../PEDIDO_2026-08-12.md),
tarefa 5.
