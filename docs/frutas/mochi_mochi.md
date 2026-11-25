# Mochi Mochi no Mi (Modo História) — técnicas, rosquinhas e braços esticados

Estado de **15/11/2026**. Fruta do mod Mine Piece (Logia da massa de mochi, usuário clássico: Charlotte Katakuri). Teclas: **Z** Edged Mochi · **X** Punch Mochi ·
**C** "That should be enough, right? For an Elephant Gun" · **V** Burning Mochi · **B** Buzz Cut Mochi · **N** Unstoppable Donuts.

## A mecânica das rosquinhas (verificada)
- **N · Unstoppable Donuts** cria **duas** criaturas `entity_muso_donatsu` ATRÁS do usuário, uma de cada lado (anel quadrado de 4 caixas, modelo do mod, 32×32 de textura cinza-clara).
- **Espelhamento:** as rosquinhas não atacam sozinhas (a `AIMusoDonatsuProcedure` as põe em modo de ataque quando o dono usa técnica 1 ou 21–24 e elas executam a técnica a partir da própria posição).
  Medido com o alvo a 5 m: Punch Mochi sozinho = 80 de dano; com as rosquinhas ativas = 184 (**2,3×**).
- **Visual (15/11/2026):** as rosquinhas renderizavam AZUIS sob a luz do céu; agora têm tom **creme de mochi** com brilho leve (`McAliadoDoMod._tingir_de_mochi`).
- **Braços esticados:** em **X** e **C** (números 22 e 23) sai um braço de massa (cilindro cremoso + punho) **da mão do usuário e de cada rosquinha viva** até o inimigo mais perto da mira
  (≤ 25 m; sem inimigo, 9 m à frente); estica em 0,12 s, segura 0,1 s e recolhe em 0,16 s (`VfxFrutaMinePiece.braco_esticado`, `PoderDaFruta._bracos_de_mochi`).
- **Teste:** `tools/dev_tests/test_mochi_bracos.gd` 7/0 (2 rosquinhas, ambas atrás, tom creme, 3 braços no pico, recolhem sozinhos).
- **Limites:** o braço é só desenho (o dano continua o do procedure do mod); a pose do jogador não estica de verdade; as rosquinhas ficam fixas atrás (não giram em volta).

## Descrição técnica a técnica (gerada do código do mod)

### mochi_mochi · Edged Mochi (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `GomuGomunoPistolProcedure` (344 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Edged Mochi — invoca/lança entidades (ENTITY_GOMU_ARM); aplica efeitos do mod (COOLDOWN_TIME, COOLDOWN_TIME_COMBAT, GEAR).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_GOMU_ARM.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, COOLDOWN_TIME_COMBAT, GEAR.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** AttackStrong, GearThirdPistol, PlayAnimation, PlayAnimationEntity2, ReturnDevilFruitEaten, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=0, dano no alvo a 4 m=9.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.9% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.


### mochi_mochi · Punch Mochi (`X`, nº 22)
- **Tecla e custo:** `X` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `GomuGomuGatlingProcedure` (432 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Punch Mochi — invoca/lança entidades (ENTITY_GOMU_ARM); causa dano; aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME, GEAR).
- **Dano no Java:** 4.0.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_GOMU_ARM.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, GEAR.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** até o tick 50 (≈ 2.5 s).
- **Chama outros procedures:** AttackWeakPunch, DamageFix, GearThirdGatling, GetDistance, GetDistanceNearestEnemy, LogicAttack, PlayAnimation, PlayAnimationEntity2.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 34.8% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.


### mochi_mochi · That should be enough, right? For an "Elephant Gun" (`C`, nº 23)
- **Tecla e custo:** `C` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `GomuGomunoPistolProcedure` (344 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** That should be enough, right? For an "Elephant Gun" — invoca/lança entidades (ENTITY_GOMU_ARM); aplica efeitos do mod (COOLDOWN_TIME, COOLDOWN_TIME_COMBAT, GEAR).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_GOMU_ARM.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, COOLDOWN_TIME_COMBAT, GEAR.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** AttackStrong, GearThirdPistol, PlayAnimation, PlayAnimationEntity2, ReturnDevilFruitEaten, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=0, nós criados=0, dano no alvo a 4 m=7.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.0% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.


### mochi_mochi · Burning Mochi (`V`, nº 24)
- **Tecla e custo:** `V` · custo 120 de energia · recarga global 3.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `YakiMochiProcedure` (337 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Burning Mochi — invoca/lança entidades (FIST); aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** FIST.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, entity.wither.shoot.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 19.3% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.


### mochi_mochi · Buzz Cut Mochi (`B`, nº 25)
- **Tecla e custo:** `B` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `SkillMochiMochiProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (38 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Buzz Cut Mochi — aplica efeitos do mod (SKILL).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** SKILL.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** GomuGomuGatling, GomuGomunoPistol, SkillMusoDonatsu, YakiMochi, ZanGiriMochi.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.


### mochi_mochi · Unstoppable Donuts (`N`, nº 29)
- **Tecla e custo:** `N` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 29 → `SkillMusoDonatsuProcedure` (179 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Unstoppable Donuts — invoca/lança entidades (ENTITY_MUSO_DONATSU).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** ENTITY_MUSO_DONATSU.
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.shoot.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** GetEntityByUUID, PlayAnimation, ReturnEntitySize, SetSummonedEntity.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 0.0% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Mori Mori

Despacho do mod: `SkillMoriMoriProcedure.java` — números mapeados: 21, 22, 23, 24.

