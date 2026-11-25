# Skills Builder no jogo — plano e estado (06/10/2026)

Pedido do dono: "parta para o desenvolvimento do skills builder". Próximo passo escolhido:
**equipar no jogo**. Uma skill criada no Builder passa a ser usável de verdade: o
jogador a equipa numa tecla, e inimigos e chefes a usam, no Modo História e na arena.

## Decisões do dono (06/10/2026)

| tema | decisão |
|---|---|
| como o jogador equipa | **kit como uma fruta**: o "Kit do Builder" (`kit_builder`) põe cada skill publicada na tecla que o Builder define (Z/X/C/V/F) e se equipa como fruta. Na história, pelo inventário (N › FRUTAS) e pelas ferramentas F8; na arena, pelo botão no menu do M (ver abaixo). Reaproveita energia, recarga, menu de técnicas e rede |
| escala do dano | **número da arena** (vida 2048); a história aplica a escala das frutas (× 250/2048) |
| quem usa (06/10) | **a atribuição mora na skill**: Usuário (Jogador, Inimigo, Chefe, Animal) + "Quem usa" = o id do modelo de inimigo da loja, do chefe (Harpia/Buggy) ou da espécie. Jogador = a tecla no kit |
| quem age agora | inimigos do mapa e boneco de duelo; chefe e animal **depois** |
| dano de inimigo no jogador | a mesma **fração da vida**: número do Builder × vida máxima do alvo / 2048 (150 tira 1,46 de um jogador de 20) |
| kit na arena | **botão no menu do M** (correção minha: a arena não tinha "menu de frutas"; frutas vêm das árvores) |
| onde ficam | **no projeto**: "Publicar no jogo" copia a skill validada para `res://mapas/skills/` (no git). A biblioteca `user://skills_builder` continua sendo rascunho. Na arena só o ID trafega |

## Suposições declaradas (reversíveis; o dono pode corrigir)

- **Energia:** o custo do Builder é medido numa barra de 100, como a prévia (ator com 100). No jogo vale como fração da energia máxima: custo 10 = 10 % (410 na arena, 1 na história).
- **Recarga:** os segundos do Builder valem igual nos dois modos (as frutas também têm a mesma recarga nos dois).
- **Teto:** o Builder define dano **por acerto**. O executor segue a prévia: "um acerto por alvo" = uma vez por evento; senão, a cada 0,2 s. Sem teto extra por uso.
- **Kit do jogador:** só skills com Usuário = **Jogador**. Publicar uma skill de Jogador na tecla Z substitui a anterior da tecla Z no kit (`mapas/skills/kit.json`).
- **Movimento:** só o dono do corpo o move (na rede, a autoridade), varrendo a cápsula como o Shunshin: não atravessa chão nem parede.

## Etapas

| # | etapa | resultado observável | validação | estado |
|---|---|---|---|---|
| 1 | Executor no mundo real | uma skill JSON roda num corpo do jogo: hitbox, projétil, movimento, dano (crítico, empurrão, atordoamento, lentidão), VFX, áudio e câmera, com zonas de dano de verdade | `test_skills_builder_executor` 21/21 (hitbox única/repetida, projétil com leque, perfurar, gravidade e morte no chão, movimento contra parede, crítico, atordoamento, empurrão, lentidão, escala da história, direção, **paridade com a prévia**) | **feito 06/10** — `src/skills_builder/executor_de_skill.gd`, `visual_de_skill.gd` (a prévia passou a usar o mesmo visual) |
| 2 | Publicar no jogo | botão no Builder, `mapas/skills/<id>.json` + `kit.json`, conflito de tecla avisado | `test_skills_builder_publicar` 15/15 (tecla, substituição, troca de tecla/dono, inválida, kit corrompido, id fora da pasta, botão real) | **feito 06/10** — `src/skills_builder/skills_publicadas.gd`, botão Publicar no Builder |
| 3 | Kit como fruta (história) | `kit_builder` no inventário e no F8; Z/X/C/V/F disparam as skills com energia e recarga; menu de técnicas | `test_kit_do_builder_historia` 15/15 (equipar, ficha, menu de técnicas, Z/X/F nos três alvos com dano × 250/2048, energia, recarga, movimento, Segurar, condição, inventário, save) + fotos `capturar_kit_do_builder.gd` | **feito 06/10** — `kit_do_builder.gd`, `ativacao_do_kit.gd`, ganchos no Player/CastController/ModoHistoria/HUD/inventário/F8 |
| 4 | Arena em rede | o kit no menu do M; dano só no servidor; cliente vê o golpe | `net_kit_host_probe` + `net_kit_client_probe` (no `validar.sh`): equipa pelo servidor, hitbox nasce no host, vida cai 150 nos dois processos | **feito 06/10** — botão no menu do M (decisão do dono: a arena não tinha menu de frutas), F do kit antes do Corpo de Ferro, barra de técnicas |
| 5 | Inimigos | skills de Usuário Inimigo usadas pelos **inimigos do mapa** e pelo **boneco de duelo** (decisão do dono) | `test_inimigos_com_skills` 10/10 (liga pelo modelo, alcance, vira e lança, dano = fração da vida, recarga, boneco só com corpo a corpo neutro, skill de outro modelo ignorada) + `test_skills_builder_publicar` (campo Quem usa) | **feito 06/10** — `usuario_de_skills.gd`, `quem_usa_skill.gd`, campo `atribuida_a` |
| 6 | Chefes e animais | Harpia, Buggy e espécies usam as skills atribuídas a eles | — | **depois** (decisão do dono: a atribuição já existe no Builder; a IA vem depois). GATILHO: o dono pedir |

**Extensão pedida em 07/10:** o evento **Transformação** troca apenas o visual do usuário, inimigos e/ou modelos próximos por fumaça, luz ou modelo do catálogo, durante o bloco. A prévia e o executor chamam os mesmos componentes `transformacao_de_skill.gd` e `visual_de_transformacao.gd`; seleção, sobreposição e restauração não foram duplicadas. Movimento, IA, colisão e combate permanecem. Uso e limites em [SKILLS_BUILDER.md](SKILLS_BUILDER.md); evidência em [TRANSFORMACAO_BUILDER_CHECKPOINT.md](TRANSFORMACAO_BUILDER_CHECKPOINT.md).

**Fora do pedido original:** catálogo novo de animações/sons e obstáculos na prévia. A extensão de transformação acima foi autorizada posteriormente.

## Dívida declarada

- **Inimigo sem time:** a zona da skill de um inimigo também fere outro inimigo ou um bicho no alcance (a `DamageZone` não sabe de time). GATILHO: o primeiro grupo de inimigos que se fira em jogo, ou o dono pedir.
- **Inimigo não gasta energia:** inimigo não tem barra; o custo do Builder vale só para o jogador.
- **Poses dos clipes:** os 5 clipes do Builder viram poses que o animador já tinha (`KitDoBuilder.POSES`); "Investida" lê parecido com "Ataque" vista de trás. GATILHO: o dono pedir pose própria por clipe.
- **Alvo da prévia × corpo do jogo:** a prévia supõe alvo de 0,55 m de raio; os corpos do jogo são mais finos (cápsula ~0,4). Uma hitbox no limite do alcance acerta na prévia e erra no jogo. O teste de paridade usa a skill-modelo (folga normal). GATILHO: a mesma regra do motor duplo abaixo.

- A **prévia** do Builder é uma simulação analítica (busca reproduzível na régua, alvo único), e o **executor** usa física de verdade. São dois motores para a mesma semântica. Guarda: um teste de paridade compara acertos e dano dos dois para as skills-modelo. GATILHO para unificar: a primeira divergência que o teste de paridade não consiga explicar, ou um tipo de evento novo (que teria de ser escrito duas vezes).
