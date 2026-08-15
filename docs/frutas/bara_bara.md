# Bara Bara no Mi — desmembramento

**Id:** `bara_bara` · **Tipo:** Paramecia · **Passiva declarada:** Esquiva
Desmembrada (35% de chance de esquivar dano cortante/frontal).

⚠️ **A esquiva não existe no código.** Só `speed_mod 1,05` é aplicado; nada lê
uma chance de desvio. Ver o README da pasta.

É a fruta mais simples do projeto — quatro golpes diretos, sem estado próprio,
sem nó gerenciador, sem caso especial no `CastController`. Ela é o **piso** da
qualidade das frutas: funciona, é limpa, e não tem nada além do básico.

---

## Onde mora cada parte

`src/effects/BaraFX.gd` — arquivo único, 4 funções, ~120 linhas. Não há
componente auxiliar.

---

## O que cada tecla faz, hoje

| tecla | golpe | o que acontece | hitbox |
|---|---|---|---|
| **Z** | Bara Bara Ho | punho voxel voador com rastro rosa/azul | dano 22 · kb 12 · `fwd × 26` · vida 1,0 s · raio 1,0 |
| **X** | Bara Bara Senbei | disco de lâminas (torus) girando | dano 38 · kb 16 · `fwd × 24` · vida 1,2 s · raio 1,2 |
| **C** | Bara Bara Car | investida das partes desmembradas | dano 35 · kb 14 · `fwd × 30` · vida 1,4 s · raio 1,5 |
| **V** | Bara Bara Festival | explosão de partes a 3,5 m à frente | dano 75 · kb 24 · **estática** · vida 3,2 s · **raio 6,0** |

Os três primeiros são projéteis; só o V é área.

---

## Pendências

- A passiva de esquiva é texto sem implementação.
- Nenhum golpe usa o rig do personagem (ao contrário da Gomu, que estica os
  membros reais). Se a Bara for aprimorada, o caminho natural é **desmembrar o
  modelo do jogador** em vez de desenhar caixas soltas — o `GomuArm` já mostra
  como pegar nós do rig por nome.
- Personagem associado: `buggy` — fora do `ELENCO_LIBERADO` hoje.
- Nunca teve golpe mudo nem vazamento: passou **4/4** já na primeira auditoria.
