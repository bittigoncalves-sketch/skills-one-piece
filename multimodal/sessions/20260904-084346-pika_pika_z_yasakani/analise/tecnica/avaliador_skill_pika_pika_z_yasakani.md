# Avaliador Sênior de Qualidade — Pika Pika Z (Yasakani no Magatama)

- modelo: **claude** (a própria sessão, papel de orquestrador)
- evidência: `/tmp/mm_denso/sheet.png` — captura de 0,20 s a 1,30 s a cada 0,10 s;
  `validacao/capturas/pika_pika_Z.mp4`; `src/effects/PikaFX.gd`;
  saída do `test_frutas -- pika_pika` e do `test_pika_yasakani`.
- régua: **Naruto Storm 4** (peso do acerto, hitstop), **Dragon Ball FighterZ**
  (VFX em camadas, leitura de silhueta), **Genshin Impact** (skill estilizada
  com identidade elemental).

---

## Rubrica

### Gráficos

| # | critério | nota | evidência |
|---|---|---|---|
| 1 | Leitura em um quadro | **5** | Em `0.50s`, `0.60s` e `0.70s` a carga é um borrão branco que **cobre a cabeça do personagem** — pausando ali não dá para dizer que golpe é. De `0.90s` em diante o leque lê bem. Metade dos quadros do golpe é ilegível. |
| 2 | Antecipação · impacto · follow-through | **4** | Antecipação existe (carga de 0,22 s, visível em `0.30s`). Impacto existe. **Follow-through não existe: o corpo do personagem não se mexe em quadro nenhum.** Comparar com Storm 4, onde o corpo inteiro vende o golpe. |
| 3 | VFX em camadas | **5** | Cinco camadas (núcleo, halo, cabeça, rastro, clarão), mas **todas são o mesmo blob aditivo branco-âmbar**: sem fagulha, sem anel de choque, sem variação de silhueta. O `GoroFX._sango` desta mesma base tem seis camadas com papéis distintos. FighterZ separa núcleo, casca e detrito. |
| 4 | Coerência de arte | **8** | Usa `FxUtil.mesh_emissive_material` (unshaded, aditivo, `BILLBOARD_DISABLED`) — o caminho cel-shading da casa. Cor branco-dourada separa da Pacifista sem sair da paleta. Sem gradiente especular. **É o critério mais forte.** |
| 5 | Feedback de impacto | **4** | Há clarão e `AudioFX.impact`. **Não há hitstop, não há tremor de câmera, não há speed line.** O Storm 4 segura ~6 quadros no acerto; o FighterZ segura mais no pesado. Aqui o acerto passa sem o jogo parar. |

### Funcionamento

| # | critério | nota | evidência |
|---|---|---|---|
| 6 | Responsividade | **8** | 0,22 s de carga e a salva já está saindo (`0.30s` carga, `0.80s` primeiros raios com o atraso do gravador). Dentro do padrão "nota 10" da casa. |
| 7 | Frame data honesta | **5** | O golpe **não passa pela FSM** (`CombatStateAttackStartup/Active/Recovery`): sai por `_fire_skill` direto, sem recovery declarado. Cooldown 5 s vem de `get_slot_cooldown`. Funciona, mas **não existe janela de contra-jogo definida** — a mesma dívida que o `docs/ESTADO_ATUAL.md` já aponta para o combo M1. |
| 8 | Hitbox condiz com o visual | **8** | Medido: hitbox esférica de raio `0.42`, núcleo visível de raio `0.357` **dentro** dela. O rastro é só visual e não machuca, o que é honesto para projétil. |
| 9 | Estado e interrupção | **5** | Sem i-frames, sem cancelamento, sem participação em `SkillSystem.interrupt_casting`. Levar dano no meio da salva não interrompe nada. |
| 10 | Rede | **não avaliado** | Segue o padrão da casa (`_fire_skill` é presentation em todos os peers; a `DamageZone` decide dano). **Não rodei sonda de dois processos**, então não tenho evidência. Dar nota aqui seria inventar — e a regra da skill proíbe. |
| 11 | Performance | **8** | Medido pelo `test_frutas`: `criou 40 nós`, sem partículas, sem alocação por quadro. Vazou 1 nó, e o mesmo 1 vaza no Z da `hie_hie` — é o contêiner `Skills_<jogador>` do primeiro cast, não deste golpe. |

---

## NOTA FINAL: **4** — o MÍNIMO dos eixos, não a média

A média daria 6,0 e seria uma mentira confortável. O jogador não sente a média:
ele sente que **bateu e o jogo não reagiu** (critério 5) e que **o boneco ficou
parado atirando** (critério 2). É por isso que a regra deste cargo é o mínimo.

## VEREDITO: **REPROVADO**

Dois critérios abaixo de 6. Não passa como está.

---

## Gaps, em ordem de impacto

```
GAP 1 · sem hitstop e sem tremor no acerto                       impacto ALTO
  evidência:  nenhum quadro entre 0.20s e 1.30s mostra pausa ou deslocamento
              de câmera; o código não chama nada disso
  régua:      Storm 4 segura ~6 quadros no acerto; FighterZ mais no pesado
  onde:       src/effects/PikaFX._impacto + o CameraRig (tem tremor pronto)
  custo:      BAIXO — é um Engine.time_scale curto no servidor + shake existente

GAP 2 · o corpo não anima                                        impacto ALTO
  evidência:  o personagem está na MESMA pose em 0.20s e em 1.30s
  régua:      em qualquer um dos três jogos da régua o corpo vende o golpe
  onde:       src/anim/ProceduralAnimator.gd (offsets aditivos por junta)
  custo:      MÉDIO — precisa de pose de braço erguido + recuo

GAP 3 · a carga é um borrão branco ilegível                      impacto MÉDIO
  evidência:  0.50s, 0.60s, 0.70s — o blob cobre a cabeça
  régua:      Genshin dá silhueta e cor elemental à carga
  onde:       PikaFX._carga — reduzir escala, dar forma (anel? estrela?)
  custo:      BAIXO

GAP 4 · sem frame data e sem recovery                            impacto MÉDIO
  evidência:  _fire_skill direto, sem passar pela FSM
  onde:       src/player/hsm/ + src/combat/Melee.gd como molde
  custo:      MÉDIO

GAP 5 · VFX de camada única                                      impacto MÉDIO
  evidência:  as 5 camadas são o mesmo blob aditivo
  régua:      GoroFX._sango, na própria base, tem 6 camadas com papéis distintos
  onde:       PikaFX — fagulhas, anel de choque, núcleo com casca
  custo:      BAIXO
```

## O que já está no nível

Coerência de arte (8), responsividade (8), hitbox honesta (8) e performance (8).
A base está certa; o que falta é **peso** — e peso, nos três jogos da régua, é
quase todo feito de hitstop, câmera e corpo. Os gaps 1 e 2 sozinhos levantariam
a nota mínima de 4 para 7.

---

# REAVALIAÇÃO — 2026-09-04, após os gaps 1, 3 e 5

Evidência nova: `/tmp/mm_v3/sheet.png` (0,20 s a 1,30 s a cada 0,10 s) e
`test_pika_yasakani` com dublês de animador/câmera.

| # | critério | antes | agora | o que mudou |
|---|---|---|---|---|
| 1 | Leitura em um quadro | 5 | **7** | a carga lê como orbe distinta em `0.30s`/`0.40s`; os raios viraram estrias. O borrão que cobria a cabeça era **sete cabeças de 0,71 m empilhadas**, não a carga — diagnóstico só possível olhando a captura |
| 2 | Antecipação · follow-through | 4 | **4** | **não mexido** — o corpo está na mesma pose nos 12 quadros |
| 3 | VFX em camadas | 5 | **7** | anel de choque + fagulhas no impacto, reusando `GoroFX.shock_ring` e `GoroFX.sparks` |
| 5 | Feedback de impacto | 4 | **7** | hitstop 0,09 s + tremor 0,22 + soco de FOV 2,5. **PROVADO por teste**, não por leitura de código: dublês contam 1 hitstop, 1 tremor, 1 FOV por salva — e não sete |
| 8 | Hitbox condiz com visual | 8 | **7** | a hitbox caiu para 0,32 e o núcleo visível para 0,176: a hitbox ficou ~1,8× o que se vê. É o lado generoso (perdoa, não mente), mas é desalinhamento |

Os demais seguem: arte **8**, responsividade **8**, performance **8**,
frame data **5**, estado/interrupção **5**, rede **não avaliado**.

## NOTA FINAL: **4** → continua o MÍNIMO, e continua o critério 2

## VEREDITO: ainda **REPROVADO** — agora por UM critério só

O golpe subiu em quatro eixos e travou num: **o personagem não se mexe**.
Enquanto o corpo estiver parado, a nota mínima é 4 por definição, e nenhum
polimento de VFX muda isso.

### Por que o gap 2 não foi feito

Custa mais do que "médio". A pose não é meta livre: passa por
`net_charge_pose` / `net_charge_progress` (vars exportadas do `Player.gd`, com
replicação de rede) e por nomes de pose fixos no `ProceduralAnimator`
(`mera_z_charge`, `bomu_z_charge`, `hibashira`…). Fazer direito significa:

1. pose nova no `src/anim/ProceduralAnimator.gd` (peso + função de pose) — arquivo **limpo**;
2. o nome dela na cadeia de `Player.gd` — arquivo **do dono, com 280 linhas em voo**.

É decisão do dono, não minha. Reusar `mera_z_charge` seria barato mas entrega
uma pose parada de saque de pistola, que não é o gesto do Yasakani.
