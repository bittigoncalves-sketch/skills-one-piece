# Fila de tarefas

O que está **pedido e ainda não feito**, na ordem em que o dono pediu. Uma
tarefa sai daqui quando entra num plano próprio (`PLANO_*.md`) ou quando é
concluída.

> Isto não é a [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md). Lá ficam
> **defeitos encontrados e não corrigidos**; aqui ficam **trabalhos pedidos**.

---

## 1. Pesquisa dos golpes do Luffy → skills da Gomu Gomu

**Pedido em 2026-08-25.** Levantar os golpes do Luffy em One Piece — **nome, como
o golpe acontece, e que efeito produz** — para virar skill no jogo.

### Por que não é só "escolher quatro nomes"

A Gomu Gomu já existe e tem os quatro slots ocupados
(`SkillSystem.get_fruit_skills()`):

| slot | hoje |
|---|---|
| Z | Gomu Gomu no Pistol |
| X | Gomu Gomu no Bazooka |
| C | Gomu Gomu no Gatling |
| V | Gear 2 / Red Hawk |

Então a pesquisa não parte do zero: ela decide **o que fica, o que troca e o que
entra**, e precisa render decisão, não uma lista.

### O que a pesquisa precisa devolver, por golpe

Sem estes cinco campos ela não fecha tarefa, porque é deles que sai a
implementação:

1. **Nome** (japonês e a tradução em uso na obra);
2. **Como acontece** — o gesto: estica, gira, comprime, infla, salta. É isto que
   vira ANIMAÇÃO, e o rig tem 13 papéis e **não tem mão nem pulso** (ver
   [`ESQUELETO.md`](ESQUELETO.md)), então gesto que dependa de punho não é
   implementável como está;
3. **Efeito** — dano único, múltiplos golpes, área, deslocamento, agarrar,
   projétil. Isto mapeia direto em `DamageSpec.tipo` (`UNICO`/`MULTI`/`CARREGADO`)
   e em `Balance.novo()`;
4. **Alcance e escala** — soco de perto, esticado a dezenas de metros, ou de
   área. Decide se é hitbox no braço, projétil, ou `AreaAttackZone`;
5. **Gear** — se é base, Gear 2, 3, 4 ou 5. Muda cor, custo e provavelmente
   é o que separa V dos outros slots.

### Restrições que a pesquisa já tem que respeitar

- **Regra do dono:** não criar fruta nova enquanto as atuais não estiverem
  prontas ([`PLANO_FRUTAS.md`](PLANO_FRUTAS.md)). Isto é melhoria da Gomu Gomu,
  não fruta nova.
- **Quatro slots.** Z/X/C/V, com recargas 5/7/10/25 s e teto de dano por
  conjuração 200/256/384/768 (`Balance.gd`). Uma lista de vinte golpes tem que
  virar uma escolha de quatro, com o resto anotado como reserva.
- **O rig manda na animação.** Sem mão, sem pulso, sem ombro.
- Um golpe só conta como pronto se criar `DamageZone` — os seis critérios do
  `PLANO_FRUTAS.md` valem.

### Onde o resultado deve morar

`docs/frutas/gomu_gomu.md` (o arquivo já existe) e, se a pesquisa virar
trabalho grande, um `PLANO_GOMU.md` próprio.

---

## Concluídas

| tarefa | onde |
|---|---|
| Frame data + FSM do combate | [`PLANO_COMBATE_BATTLEGROUNDS.md`](PLANO_COMBATE_BATTLEGROUNDS.md) |
| Refazer os 4 golpes M1 | `tools/autorar_combo_m1.py` |
| Personagem e animações no Blender | `tools/blender/montar_personagem.py` |
| Árvore do Meshy no lugar das de caixa | `tools/blender/preparar_arvore.py` |
| Plano visual — Fase 1 (ar e luz) | [`PLANO_VISUAL.md`](PLANO_VISUAL.md) |
