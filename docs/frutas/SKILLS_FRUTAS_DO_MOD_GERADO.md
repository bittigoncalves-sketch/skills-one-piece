# Skills das frutas só-do-mod no Modo História — descrição extraída do código

> **GERADO** por `tools/mine_piece/documentar_skills_do_mod.py` em 15/11/2026 a partir do jogo (lista de técnicas) e dos procedures Java do mod.
> Nada aqui é inventado: o que a técnica faz vem do Java; o **objetivo** é inferido do nome e dos efeitos e está marcado como tal.
> Para as 5 frutas nativas (Ope, Hie, Moku, Pika, Nikyu) e a Luta, ver `SKILLS_MINE_PIECE_MODO_HISTORIA.md` (escrito à mão, com o visual medido).

## Aro Aro

Despacho do mod: `SkillAroAroProcedure.java` — números mapeados: 21, 22, 25, 29.

### aro_aro · Arrow (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `AroAroSkillArrowProcedure` (401 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Arrow — invoca/lança entidades (ENTITY_ARROW); causa dano; aplica efeitos do mod (COOLDOWN_TIME, GUARD).
- **Dano no Java:** 15.0 * CNT6; 6.0; Math.max(damage, entity.getPersistentData().m_128459_("Damage")).
- **Alcance/área (Range):** 6.0 * range.
- **Empurrão (knockback):** 0.5.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_ARROW.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, GUARD.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.shoot.
- **Duração aproximada:** até o tick 10 (≈ 0.5 s).
- **Chama outros procedures:** DamageFix, GetDistanceNearestEnemy, GuardEffectStartedapplied, PlayAnimation, PlayAnimationEntity2, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=0, dano no alvo a 4 m=72.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### aro_aro · Two-Hit Combo (`X`, nº 23)
- **Tecla e custo:** `X` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `AroAroSkillComboProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (538 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Two-Hit Combo — invoca/lança entidades (ENTITY_ARROW); causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COLLIDED, COOLDOWN_TIME, HIGH_SPEED).
- **Dano no Java:** 18.0 * CNT6; 20.0 * CNT6.
- **Alcance/área (Range):** 12.0 * range; 4.0 * range.
- **Empurrão (knockback):** 0.25; 2.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_ARROW.
- **Efeitos do mod aplicados:** ATTACKING, COLLIDED, COOLDOWN_TIME, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, entity.wither.shoot, forge:ranged_ammo.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** GetDistanceIterator, InsideSolidCalculate, LogicAttack, ParticleGenerator, PlayAnimation, PlayAnimationEntity2, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=3, dano no alvo a 4 m=20.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 17.8% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Batto Batto

Despacho do mod: `SkillBattoBattoProcedure.java` — números mapeados: 21, 22, 23, 24, 25, 26.

### batto_batto · Finger Pistol (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 60 de energia · recarga global 1.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `ShiganProcedure` (285 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Finger Pistol — invoca/lança entidades (BULLET); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 1.5; 10.0 * CNT6; 3.0.
- **Alcance/área (Range):** 2.0 * range.
- **Empurrão (knockback):** 0.25.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BULLET.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetReach, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=20, nós criados=1, dano no alvo a 4 m=5.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.2% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### batto_batto · Tempest Kick (`X`, nº 23)
- **Tecla e custo:** `X` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `RankyakuProcedure` (384 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tempest Kick — invoca/lança entidades (ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH); aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, PlayAnimation, PlayAnimationEntity2, ReturnCharactorDevilFruti, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=3, dano no alvo a 4 m=1077.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 6.3% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### batto_batto · Flying Finger Pistol (`C`, nº 24)
- **Tecla e custo:** `C` · custo 50 de energia · recarga global 1.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `TobuShiganProcedure` (187 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Flying Finger Pistol — invoca/lança entidades (BULLET); causa dano.
- **Dano no Java:** 2.2.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BULLET.
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:gun_shot1.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** DamageFix, GetDistanceNearestEnemy, ParticleGeneratorCircle, PlayAnimation, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=10, nós criados=-2, dano no alvo a 4 m=11.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 15.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### batto_batto · Paper Art: Afterimage (`V`, nº 25)
- **Tecla e custo:** `V` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `KamieZanshinProcedure` (415 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Paper Art: Afterimage — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT, HIGH_SPEED).
- **Dano no Java:** 999999.0.
- **Alcance/área (Range):** 4.0 * range.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT, HIGH_SPEED, STUN.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, entity.wither.shoot, forge:not_living, forge:ranged_ammo.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** DamageFix, GetDistanceNearestEnemy, LogicAttack, ParticleGeneratorCircle, ReturnEntitySize, RotateEntity, StepBlock.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=1, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### batto_batto · Forgive Me...♡ (`B`, nº 26)
- **Tecla e custo:** `B` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `YurushiteneProcedure` (345 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Forgive Me...♡ — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COLLIDED, COOLDOWN_TIME, DAMAGE_EFFECT).
- **Dano no Java:** 18.0 * CNT6.
- **Alcance/área (Range):** 5.0 * range.
- **Empurrão (knockback):** 0.1.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COLLIDED, COOLDOWN_TIME, DAMAGE_EFFECT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.breath, entity.wither.shoot.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** GetDistanceNearestEnemy, GetPowerFix, OnGround, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity, StepBlock.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=0, dano no alvo a 4 m=47.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 6.7% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Bisu Bisu

Despacho do mod: `SkillBisuBisuProcedure.java` — números mapeados: 21, 22, 23, 24, 25.

### bisu_bisu · Honey Pretzel (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `CrashPretzelProcedure` (501 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Honey Pretzel — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED).
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** 12.0 * range; 4.0 * range.
- **Empurrão (knockback):** 1.5.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED.
- **Partículas do mod:** minecraft:cloud, minecraft:explosion, minecraft:smoke_large.
- **Sons:** entity.generic.explode, forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** AttackStrongPunch, EntityVector, GetDistanceIterator, InsideSolidCalculate, Knockback, LogicAttack, OnGround, ParticleGeneratorCircle.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=0, dano no alvo a 4 m=6.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 14.7% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### bisu_bisu · Crash Pretzel (`X`, nº 22)
- **Tecla e custo:** `X` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `CrashPretzelProcedure` (501 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Crash Pretzel — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED).
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** 12.0 * range; 4.0 * range.
- **Empurrão (knockback):** 1.5.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED.
- **Partículas do mod:** minecraft:cloud, minecraft:explosion, minecraft:smoke_large.
- **Sons:** entity.generic.explode, forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** AttackStrongPunch, EntityVector, GetDistanceIterator, InsideSolidCalculate, Knockback, LogicAttack, OnGround, ParticleGeneratorCircle.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=0, dano no alvo a 4 m=37.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 24.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### bisu_bisu · Biscuit Warrior (`C`, nº 23)
- **Tecla e custo:** `C` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `SkillSummonBiscuitWarriorProcedure` (401 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Biscuit Warrior — invoca/lança entidades (BISCUIT_WARRRIOR); aplica efeitos do mod (ARMAMENT_HAKI, COOLDOWN_TIME, OBSERVATION_HAKI).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BISCUIT_WARRRIOR.
- **Efeitos do mod aplicados:** ARMAMENT_HAKI, COOLDOWN_TIME, OBSERVATION_HAKI.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:clap.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** PlayAnimation, ReturnEntitySize, SetSummonedEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=2, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 13.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### bisu_bisu · Biscuit Warrior: Assault Attack (`V`, nº 24)
- **Tecla e custo:** `V` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `SkillSummonBiscuitWarrior2Procedure` (425 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Biscuit Warrior: Assault Attack — invoca/lança entidades (BISCUIT_WARRRIOR); aplica efeitos do mod (ARMAMENT_HAKI, COOLDOWN_TIME, OBSERVATION_HAKI, SKILL).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BISCUIT_WARRRIOR.
- **Efeitos do mod aplicados:** ARMAMENT_HAKI, COOLDOWN_TIME, OBSERVATION_HAKI, SKILL.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:clap.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** GetDistance, PlayAnimation, ReturnEntitySize, RotateEntity, SetSummonedEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=10, dano no alvo a 4 m=21.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 22.9% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### bisu_bisu · Biscuit (`B`, nº 25)
- **Tecla e custo:** `B` · custo 50 de energia · recarga global 1.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `SkillBiscuitProcedure` (76 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Biscuit — técnica utilitária/de preparo (sem dano direto no procedure principal).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:clap.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=10, nós criados=0, dano no alvo a 4 m=7.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 32.3% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Hito Hito Daibutsu

Despacho do mod: `SkillHitoHitoDaibutsuProcedure.java` — números mapeados: 21, 22, 23, 24, 25.

### hito_hito_daibutsu · Tackle (`Z`, nº 22)
- **Tecla e custo:** `Z` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `BrilliantPunkProcedure` (398 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tackle — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** 4.0 * range; 6.0 * range.
- **Empurrão (knockback):** 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 22 (≈ 1.1 s).
- **Chama outros procedures:** AttackStrongPunch, EntityVector, GetDistanceIterator, InsideSolidCalculate, LogicAttack, OnGround, ParticleGeneratorCircle, PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=0, dano no alvo a 4 m=28.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.2% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### hito_hito_daibutsu · Flor de Buda (`X`, nº 1001)
- **Tecla e custo:** `X` · custo 40 de energia · recarga global 1.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 1001 → `?Procedure` (? linhas de Java).
- **Recarga:** 1.00 s (global do mod).
- **Despacho do mod desta fruta:** números 21, 22, 23, 24, 25.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Flor de Buda.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Leitura da medição:** não começou na varredura (pode exigir forma/pré-condição do mod).
- **Visibilidade medida:** 2.4% da imagem muda.
- **Origem:** extensão autoral do projeto (`flor_de_buda.gd`, número 1001); só vale na forma Buda (Hito Hito Daibutsu transformado) e com o jogador no chão.
- **Tempos:** preparo de 1,2 s, duração total 2,8 s, raio de 10 m, custo 40 e recarga 10 s própria (fora da global do mod).
- **Efeito:** na explosão (fim do preparo) fere todo alvo atacável no raio, com empurrão horizontal de 12 + 3 para cima e atordoamento de 0,4 s; não fere aliados nem tripulação.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

### hito_hito_daibutsu · Wave Motion Gun (`C`, nº 23)
- **Tecla e custo:** `C` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `SkillImpactBallProcedure` (355 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Wave Motion Gun — invoca/lança entidades (ENTITY_ENERGY); causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 15.0.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_ENERGY.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, minepiece:frame_set.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** DamageFix, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=0, nós criados=0, dano no alvo a 4 m=7.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.9% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### hito_hito_daibutsu · Strongest Overhead Attack (`V`, nº 24)
- **Tecla e custo:** `V` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `AttackOverheadSuperProcedure` (531 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Strongest Overhead Attack — causa dano; aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT, SOVEREIGN_HAKI).
- **Dano no Java:** 15.0 * CNT6; 24.0; 25.0 * CNT6.
- **Alcance/área (Range):** 10.0 * range; 3.0 * range; strength * 1.0.
- **Empurrão (knockback):** 0.6; 1.0; 2.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT, SOVEREIGN_HAKI.
- **Partículas do mod:** minecraft:crit, minepiece:particle_thunder_black, particle_thunder_black.
- **Sons:** entity.lightning_bolt.impact, entity.lightning_bolt.thunder, entity.zombie.break_wooden_door.
- **Duração aproximada:** até o tick 30 (≈ 1.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetPowerFix, Knockback, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 13.5% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### hito_hito_daibutsu · Impact Wave (`B`, nº 25)
- **Tecla e custo:** `B` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `ImpactWaveProcedure` (408 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Impact Wave — invoca/lança entidades (ENTITY_IMPACT_WAVE); causa dano; aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME, DAMAGE_EFFECT).
- **Dano no Java:** 28.0 * CNT6.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_IMPACT_WAVE.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, DAMAGE_EFFECT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** block.enchantment_table.use, entity.player.attack.sweep, minepiece:frame_set.
- **Duração aproximada:** até o tick 80 (≈ 4.0 s).
- **Chama outros procedures:** DamageFix, GetDistance, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 11.7% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Horo Horo

Despacho do mod: `SkillHoroHoroProcedure.java` — números mapeados: 24, 26, 27, 28, 29.

### horo_horo · Negative Hollow (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `NegativeHollowTackleProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (133 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Negative Hollow — reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (NEGATIVE).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** NEGATIVE.
- **Partículas do mod:** particle_blue.
- **Sons:** forge:not_living.
- **Duração aproximada:** até o tick 25 (≈ 1.2 s).
- **Chama outros procedures:** LogicAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=5, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 21.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### horo_horo · Mini Hollow: Ghost Rap (`X`, nº 25)
- **Tecla e custo:** `X` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `AIMiniHollowProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (393 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Mini Hollow: Ghost Rap — causa dano; aplica impulso/velocidade.
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** 5.0 * entity_size.
- **Empurrão (knockback):** 0.65 * CNT6.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** minepiece:particle_blue.
- **Sons:** entity.generic.explode, forge:ranged_ammo.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** BlockDestroyAllDirection, GetDistanceIterator, GetEntityByUUID, LogicAttack, LogicOwnerExist, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=7, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 16.6% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### horo_horo · Special Hollow: Kamikaze Rap (`C`, nº 27)
- **Tecla e custo:** `C` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 27 → `SkillTokuHoroProcedure` (237 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Special Hollow: Kamikaze Rap — invoca/lança entidades (ENTITY_MINI_HOLLOW); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME, DAMAGE_EFFECT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_MINI_HOLLOW.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, DAMAGE_EFFECT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.spawn.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** GetDistance, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=-5, dano no alvo a 4 m=79.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 19.0% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### horo_horo · Kumacy (`V`, nº 28)
- **Tecla e custo:** `V` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 28 → `SkillRapProcedure` (151 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Kumacy — técnica utilitária/de preparo (sem dano direto no procedure principal).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** ui.button.click.
- **Duração aproximada:** até o tick 4 (≈ 0.2 s).
- **Chama outros procedures:** GetDistanceIterator, PlayAnimation, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=1, dano no alvo a 4 m=23.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Imu

Despacho do mod: `SkillImuProcedure.java` — números mapeados: 25.

### imu · Devil's Arrow (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `ImuArrowProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (165 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Devil's Arrow — invoca/lança entidades (ENTITY_GOMU_ARM); aplica efeitos do mod (COOLDOWN_TIME, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_GOMU_ARM.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** AttackStrong, PlayAnimationEntity2, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=-3, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Inu Inu Okuchi No Makami

Despacho do mod: `SkillInuInuOkuchinoMakamiProcedure.java` — números mapeados: 21, 22, 23, 24, 25, 26.

### inu_inu_okuchi_no_makami · Thunder Bagua (`Z`, nº 23)
- **Tecla e custo:** `Z` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `RaimeiHakkeProcedure` (396 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Thunder Bagua — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT).
- **Dano no Java:** 18.0 * CNT6; entity.getPersistentData().m_128459_("Damage") * 1.2.
- **Alcance/área (Range):** 4.0 * strength.
- **Empurrão (knockback):** 1.0; entity.getPersistentData().m_128459_("knockback") * 1.2.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT.
- **Partículas do mod:** particle_thunder_blue.
- **Sons:** entity.lightning_bolt.impact, entity.lightning_bolt.thunder.
- **Duração aproximada:** até o tick 120 (≈ 6.0 s).
- **Chama outros procedures:** GetDistanceNearestEnemy, GetPowerFix, LogicIsEntityUsingAttack, OnGround, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=0, dano no alvo a 4 m=39.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.9% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_okuchi_no_makami · Narikabura Arrow (`X`, nº 24)
- **Tecla e custo:** `X` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `NarikaburaProcedure` (318 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Narikabura Arrow — invoca/lança entidades (ENTITY_ENERGY); aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_ENERGY.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.shoot.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, ParticleGeneratorCircle, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=1, dano no alvo a 4 m=17.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.6% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_okuchi_no_makami · Namuji Glacier Fang (`C`, nº 25)
- **Tecla e custo:** `C` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `NamujiHyogaProcedure` (341 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Namuji Glacier Fang — causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** Math.min(Math.max(2.0 * range, 2.0), 10.0).
- **Empurrão (knockback):** 0.75.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** minepiece:particle_ice.
- **Sons:** entity.player.breath, minepiece:ice_generate.
- **Duração aproximada:** até o tick 24 (≈ 1.2 s).
- **Chama outros procedures:** BlockToIce, LogicAttack, ParticleGenerator, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=1, dano no alvo a 4 m=20.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_okuchi_no_makami · Hallowed Glacier Slash (`V`, nº 26)
- **Tecla e custo:** `V` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `HimorogiriProcedure` (528 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Hallowed Glacier Slash — causa dano; aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 15.0 * CNT6; 25.0 * CNT6; 30.0.
- **Alcance/área (Range):** 10.0 * range; 3.0 * range.
- **Empurrão (knockback):** 0.6; 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** minepiece:particle_ice, particle_ice.
- **Sons:** entity.lightning_bolt.impact, entity.player.attack.sweep, entity.zombie.break_wooden_door, minepiece:ice_generate.
- **Duração aproximada:** até o tick 30 (≈ 1.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetPowerFix, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=460, nós criados=7, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 13.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Inu Inu Wolf

Despacho do mod: `SkillInuInuWolfProcedure.java` — números mapeados: 21, 22, 23, 24, 25, 26, 28.

### inu_inu_wolf · Finger Pistol (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 60 de energia · recarga global 1.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `ShiganProcedure` (285 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Finger Pistol — invoca/lança entidades (BULLET); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 1.5; 10.0 * CNT6; 3.0.
- **Alcance/área (Range):** 2.0 * range.
- **Empurrão (knockback):** 0.25.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BULLET.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetReach, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=20, nós criados=0, dano no alvo a 4 m=5.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_wolf · Tempest Kick "Lone Wolf" (`X`, nº 23)
- **Tecla e custo:** `X` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `RankyakuProcedure` (384 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tempest Kick "Lone Wolf" — invoca/lança entidades (ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH); aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, PlayAnimation, PlayAnimationEntity2, ReturnCharactorDevilFruti, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=1, dano no alvo a 4 m=63.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.7% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_wolf · Tempest Kick "Lupus Fall" (`C`, nº 24)
- **Tecla e custo:** `C` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `RankyakuLupusFallProcedure` (309 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tempest Kick "Lupus Fall" — invoca/lança entidades (ENTITY_WOLF_PROJECTILE); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_WOLF_PROJECTILE.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=7, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.7% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_wolf · Kung Fu Wolf Bullet (`V`, nº 25)
- **Tecla e custo:** `V` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `OkamiHajikiProcedure` (366 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Kung Fu Wolf Bullet — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED).
- **Dano no Java:** 12.0 * CNT6.
- **Alcance/área (Range):** 4.0 * range; 6.0 * range.
- **Empurrão (knockback):** 2.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** AttackStrongPunch, EntityVector, GetDistanceIterator, InsideSolidCalculate, Knockback, LogicAttack, OnGround, ParticleGenerator.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=-6, dano no alvo a 4 m=10.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.6% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_wolf · Ten Finger Pistol (`B`, nº 26)
- **Tecla e custo:** `B` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `JushiganProcedure` (364 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Ten Finger Pistol — reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** 4.0 * range.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** AttackStrong, AttackWeak, EntityVector, GetDistanceIterator, InsideSolidCalculate, LogicAttack, OnGround, PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=1, dano no alvo a 4 m=61.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 13.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### inu_inu_wolf · Wolf Hunt Highspeed Scratch (`N`, nº 27)
- **Tecla e custo:** `N` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 27 → `SkillInuInuWolfProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (83 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Wolf Hunt Highspeed Scratch — aplica efeitos do mod (SKILL).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** SKILL.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** AttackSpeed, Jushigan, LocalAreaNetWork, OkamiHajiki, Rankyaku, RankyakuLupusFall, Shigan.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=23, dano no alvo a 4 m=60.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida:** não coberta na captura de 15/11/2026.
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Kage Kage

Despacho do mod: `SkillKageKageProcedure.java` — números mapeados: 21, 23, 24, 25, 26, 29.

### kage_kage · Brick Bat (`Z`, nº 22)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `BrickBatProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (358 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Brick Bat — causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 12.0; 15.0 * CNT6; 9.0.
- **Alcance/área (Range):** 8.0 * range; Math.min(2.0 * (5.0 - entity.getPersistentData().m_128459_("cnt1")), 24.0) * range.
- **Empurrão (knockback):** 0.25; 0.5; 1.5.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** minepiece:particle_bat.
- **Sons:** entity.bat.takeoff.
- **Duração aproximada:** até o tick 25 (≈ 1.2 s).
- **Chama outros procedures:** DamageFix, GetDistance, ParticleGenerator, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=-3, dano no alvo a 4 m=161.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### kage_kage · Spiky Shadow Lizard (`X`, nº 24)
- **Tecla e custo:** `X` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `TsunoTokageProcedure` (407 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Spiky Shadow Lizard — causa dano; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME).
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** 4.0 * range.
- **Empurrão (knockback):** 0.5.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME.
- **Partículas do mod:** minecraft:squid_ink, minepiece:particle_bat.
- **Sons:** entity.bat.takeoff, entity.wither.shoot, forge:ranged_ammo.
- **Duração aproximada:** até o tick 32 (≈ 1.6 s).
- **Chama outros procedures:** LogicAttack, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=-1, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 5.8% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### kage_kage · Doppelman (`C`, nº 25)
- **Tecla e custo:** `C` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `DoppelmanProcedure` (418 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Doppelman — invoca/lança entidades (ENTITY_DOPPELMAN); aplica efeitos do mod (ARMAMENT_HAKI, OBSERVATION_HAKI).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** ENTITY_DOPPELMAN.
- **Efeitos do mod aplicados:** ARMAMENT_HAKI, OBSERVATION_HAKI.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** block.portal.ambient.
- **Duração aproximada:** até o tick 1 (≈ 0.1 s).
- **Chama outros procedures:** GetEntityByUUID, SetSummonedEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=0, nós criados=0, dano no alvo a 4 m=6.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.2% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### kage_kage · Shadow's Asgard (`V`, nº 26)
- **Tecla e custo:** `V` · custo 1000 de energia · recarga global 25.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `IslandShatterPunchProcedure` (460 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Shadow's Asgard — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED).
- **Dano no Java:** 10.0 * CNT6; 24.0 * CNT6; 4.0; 44.0 * CNT6.
- **Alcance/área (Range):** 24.0 * range; 3.0 * range; Math.max(24.0 * range, Math.max(d * 1.0, 1.0)).
- **Empurrão (knockback):** 0.6; 1.0 * CNT6.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, entity.lightning_bolt.thunder.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetPowerFix, Knockback, ParticleGeneratorCircle, PlayAnimation, RangeAttack.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.5% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Kira Kira

Despacho do mod: `SkillKiraKiraProcedure.java` — números mapeados: 21, 23, 24, 25.

### kira_kira · Brilliant Punk (`Z`, nº 22)
- **Tecla e custo:** `Z` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `BrilliantPunkProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (398 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Brilliant Punk — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** 4.0 * range; 6.0 * range.
- **Empurrão (knockback):** 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 22 (≈ 1.1 s).
- **Chama outros procedures:** AttackStrongPunch, EntityVector, GetDistanceIterator, InsideSolidCalculate, LogicAttack, OnGround, ParticleGeneratorCircle, PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=0, dano no alvo a 4 m=28.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.9% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### kira_kira · Stone Throwing (`X`, nº 24)
- **Tecla e custo:** `X` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `StoneThrowingProcedure` (222 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Stone Throwing — invoca/lança entidades (ROCK_FRAGMENT); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME_COMBAT, HIGH_SPEED).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** ROCK_FRAGMENT.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, entity.wither.shoot.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** GetDistance, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=2, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### kira_kira · Giant Rock Throwing (`C`, nº 25)
- **Tecla e custo:** `C` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `StoneThrowingLargeProcedure` (227 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Giant Rock Throwing — invoca/lança entidades (ROCK_FRAGMENT); aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ROCK_FRAGMENT.
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, minepiece:stone_crash.
- **Duração aproximada:** até o tick 50 (≈ 2.5 s).
- **Chama outros procedures:** PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=460, nós criados=5, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 42.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Kiro Kiro

Despacho do mod: `SkillKiroKiroProcedure.java` — números mapeados: 21, 22, 25, 29.

### kiro_kiro · 10,000 Kill-o-Press (`Z`, nº 23)
- **Tecla e custo:** `Z` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `SkillKiroKiroProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (81 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** 10,000 Kill-o-Press — aplica efeitos do mod (SKILL).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** SKILL.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** AttackJump, AttackOverhead, KiroKiroOverhead, WeightManipulation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=-1, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.0% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### kiro_kiro · Weight Manipulation (`X`, nº 26)
- **Tecla e custo:** `X` · custo 0 de energia · recarga global 0.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `WeightManipulationProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (141 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Weight Manipulation — aplica efeitos do mod (COOLDOWN_TIME, EFFECT_WEIGHT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME, EFFECT_WEIGHT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** SetComma.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=0, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.7% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Mero Mero

Despacho do mod: `SkillMeroMeroProcedure.java` — números mapeados: 21, 23, 24, 25.

### mero_mero · Pistol Kiss (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 50 de energia · recarga global 1.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `PistolKissProcedure` (190 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Pistol Kiss — invoca/lança entidades (HEART_BULLET); causa dano.
- **Dano no Java:** 2.2.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** HEART_BULLET.
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:gun_shot1.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** DamageFix, GetDistanceNearestEnemy, ParticleGeneratorCircle, PlayAnimation, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=10, nós criados=0, dano no alvo a 4 m=7.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.1% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### mero_mero · Roundhouse Kick (`X`, nº 22)
- **Tecla e custo:** `X` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `Karate7000BrickRoundhouseKickProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (316 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Roundhouse Kick — aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** particle_thunder_black.
- **Sons:** entity.player.attack.sweep, entity.wither.shoot.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** AttackStrongPunch, CanUseArmamentHakiWear, GetDistanceNearestEnemy, LogicCanUseHaoshokuHakiWear, LogicCanUseRyuo, PlayAnimation, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=0, dano no alvo a 4 m=7.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 4.3% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### mero_mero · Perfume Femur (`C`, nº 24)
- **Tecla e custo:** `C` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `RotateKickProcedure` (497 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Perfume Femur — invoca/lança entidades (ENTITY_SWEEP); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT, DIABLE_JAMBE_EFFECT).
- **Dano no Java:** (entity.getPersistentData().m_128459_("cnt3") > 0.0 ? 18.0 : 12.0 + entity.getPersistentData().m_128459_("cnt2") * 0.01) * CNT6
                  .
- **Alcance/área (Range):** distance * 2.0.
- **Empurrão (knockback):** entity.getPersistentData().m_128459_("cnt3") > 0.0 ? 2.5 : 0.01.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_SWEEP.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT, DIABLE_JAMBE_EFFECT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.blaze.shoot, entity.player.attack.sweep, entity.wither.shoot.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** BlockDestroyAllDirection, GetDistanceNearestEnemy, PlayAnimation, PlayAnimationEntity2, RangeAttack, ReturnEntitySize, RotateEntity, SetSummonedEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=2, dano no alvo a 4 m=28.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 21.8% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### mero_mero · Perfume Femur Magna (`V`, nº 25)
- **Tecla e custo:** `V` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `PerfumeFemurMagnaProcedure` (323 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Perfume Femur Magna — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT, DOUBLE_JUMP_EFFECT, FLY_EFFECT).
- **Dano no Java:** 6.0.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT, DOUBLE_JUMP_EFFECT, FLY_EFFECT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** block.stone.step, entity.wither.shoot.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** AttackSpeed, DamageFix, GetDistance, GetPowerFix, ParticleGeneratorCircle, PlayAnimation, ResetCounter, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.7% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Mochi Mochi

Despacho do mod: `SkillMochiMochiProcedure.java` — números mapeados: 21, 22, 23, 24, 28, 29.

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

### mori_mori · Tree Strike (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `MoriMoriRootProcedure` (15 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tree Strike — causa dano.
- **Dano no Java:** 9.0.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** DamageFix, MoriMoriRoot1.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=8, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 13.6% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### mori_mori · Giant Tree (`X`, nº 22)
- **Tecla e custo:** `X` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `MoriMoriRootGiantProcedure` (550 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Giant Tree — invoca/lança entidades (TREE_ROOT); aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** TREE_ROOT.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** particle_big_smoke.
- **Sons:** block.stone.break, entity.generic.explode, entity.zombie.break_wooden_door, forge:ranged_ammo, jujutsucraft:barrier.
- **Duração aproximada:** até o tick 30 (≈ 1.5 s).
- **Chama outros procedures:** LogicAttack, PlayAnimation, ReturnEntitySize, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=9, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.2% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### mori_mori · Assault Attack (`C`, nº 23)
- **Tecla e custo:** `C` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `MoriMoriAssaultProcedure` (58 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Assault Attack — aplica impulso/velocidade.
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** AttackOverhead, BlockToGrass, MoriMoriRootSurroundings, PlayAnimation, ResetCounter.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=-2, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 59.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### mori_mori · I'll Skewer You (`V`, nº 24)
- **Tecla e custo:** `V` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `MoriMoriRootSurroundingsStrongProcedure` (267 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** I'll Skewer You — invoca/lança entidades (TREE_ROOT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** TREE_ROOT.
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** jujutsucraft:barrier.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** AttackOverhead, BlockToGrass, ResetCounter, ReturnEntitySize, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=13, dano no alvo a 4 m=37.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 36.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Neko Neko Leopard

Despacho do mod: `SkillNekoNekoLeopardProcedure.java` — números mapeados: 21, 22, 23, 24, 25, 26, 29.

### neko_neko_leopard · Finger Pistol (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 60 de energia · recarga global 1.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `ShiganProcedure` (285 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Finger Pistol — invoca/lança entidades (BULLET); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 1.5; 10.0 * CNT6; 3.0.
- **Alcance/área (Range):** 2.0 * range.
- **Empurrão (knockback):** 0.25.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BULLET.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetReach, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=20, nós criados=0, dano no alvo a 4 m=5.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.7% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### neko_neko_leopard · Tempest Kick (`X`, nº 23)
- **Tecla e custo:** `X` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `RankyakuProcedure` (384 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tempest Kick — invoca/lança entidades (ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH); aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, PlayAnimation, PlayAnimationEntity2, ReturnCharactorDevilFruti, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=2, dano no alvo a 4 m=58.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 6.6% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### neko_neko_leopard · Tempest Kick "Victory Bird" (`C`, nº 24)
- **Tecla e custo:** `C` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `RankyakuGaichoProcedure` (366 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tempest Kick "Victory Bird" — invoca/lança entidades (PROJECTILE_SLASH); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** PROJECTILE_SLASH.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, minepiece:sword_sweep.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, GetDistanceNearestEnemy, PlayAnimation, PlayAnimationEntity2, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=3, dano no alvo a 4 m=40.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 15.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### neko_neko_leopard · Hand Pistol (`V`, nº 26)
- **Tecla e custo:** `V` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `ShuganProcedure` (338 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Hand Pistol — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT, HIGH_SPEED).
- **Dano no Java:** 18.0 * CNT6.
- **Alcance/área (Range):** 5.0 * range.
- **Empurrão (knockback):** 0.1.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.shoot.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** GetDistanceNearestEnemy, GetPowerFix, OnGround, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity, StepBlock.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=-3, dano no alvo a 4 m=47.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.0% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### neko_neko_leopard · Six King Gun (`B`, nº 27)
- **Tecla e custo:** `B` · custo 600 de energia · recarga global 15.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 27 → `RokuoganProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (400 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Six King Gun — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ARMAMENT_HAKI, ATTACKING, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 24.0 * CNT6; 35.0 * CNT6; 6.0.
- **Alcance/área (Range):** 12.0 * range; 6.0 * range.
- **Empurrão (knockback):** 1.5.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ARMAMENT_HAKI, ATTACKING, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** block.end_gateway.spawn.
- **Duração aproximada:** até o tick 10 (≈ 0.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistanceNearestEnemy, InsideSolidCalculate, Knockback, ParticleGenerator, ParticleGeneratorCircle, PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=-1, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 17.5% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Neko Neko Sabertiger

Despacho do mod: `SkillNekoNekoSaberTigerProcedure.java` — números mapeados: 21, 22, 24, 25, 26.

### neko_neko_sabertiger · Finger Pistol (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 60 de energia · recarga global 1.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `ShiganProcedure` (285 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Finger Pistol — invoca/lança entidades (BULLET); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 1.5; 10.0 * CNT6; 3.0.
- **Alcance/área (Range):** 2.0 * range.
- **Empurrão (knockback):** 0.25.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BULLET.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetReach, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=20, nós criados=0, dano no alvo a 4 m=5.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 11.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### neko_neko_sabertiger · Finger Pistol Spots (`X`, nº 23)
- **Tecla e custo:** `X` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `?Procedure` (? linhas de Java).
- **Recarga:** 2.50 s (global do mod).
- **Despacho do mod desta fruta:** números 21, 22, 24, 25, 26.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Finger Pistol Spots.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=3, dano no alvo a 4 m=45.
- **Leitura da medição:** a técnica roda e gasta energia como a ficha.
- **Visibilidade medida:** 7.6% da imagem muda.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

### neko_neko_sabertiger · Fang Pistol (`C`, nº 25)
- **Tecla e custo:** `C` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `GaganProcedure` (512 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Fang Pistol — invoca/lança entidades (ENTITY_ENERGY); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_ENERGY.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.shoot.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, GetDistanceNearestEnemy, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=-2, dano no alvo a 4 m=47.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.0% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### neko_neko_sabertiger · Fang Flash (`V`, nº 26)
- **Tecla e custo:** `V` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `KibasenProcedure` (393 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Fang Flash — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COLLIDED, COOLDOWN_TIME, HIGH_SPEED).
- **Dano no Java:** 16.0 * CNT6.
- **Alcance/área (Range):** 4.0 * range; 6.0 * range.
- **Empurrão (knockback):** 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COLLIDED, COOLDOWN_TIME, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 25 (≈ 1.2 s).
- **Chama outros procedures:** AttackStrongPunch, EntityVector, GetDistanceIterator, InsideSolidCalculate, LogicAttack, OnGround, ParticleGenerator, PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=-12, dano no alvo a 4 m=48.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 19.3% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Riki Riki

Despacho do mod: `SkillRikiRikiProcedure.java` — números mapeados: 21, 22, 23, 24, 25.

### riki_riki · Shockwave Elbow (`Z`, nº 22)
- **Tecla e custo:** `Z` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `HadoElbowProcedure` (410 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Shockwave Elbow — causa dano; aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT).
- **Dano no Java:** 18.0 * CNT6; 9.0; entity.getPersistentData().m_128459_("cnt1") <= damage_time ? 15.0 : 18.0 * CNT6.
- **Alcance/área (Range):** (entity.getPersistentData().m_128459_("cnt1") <= damage_time ? 6 : 8) * range; 32.0 * range; dis * range * 4.0.
- **Empurrão (knockback):** 0.5; 1.0; entity.getPersistentData().m_128459_("cnt1") <= damage_time ? 0.01 : 2.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT.
- **Partículas do mod:** particle_shockwave.
- **Sons:** entity.lightning_bolt.impact, entity.lightning_bolt.thunder, minepiece:electric_shock.
- **Duração aproximada:** até o tick 25 (≈ 1.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistanceNearestEnemy, Knockback, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=3, dano no alvo a 4 m=100.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.6% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### riki_riki · Galleon Lariat (`X`, nº 23)
- **Tecla e custo:** `X` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `GalleonLariatProcedure` (412 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Galleon Lariat — invoca/lança entidades (PROJECTILE_SWEEP); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 18.0.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** PROJECTILE_SWEEP.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, entity.wither.shoot.
- **Duração aproximada:** até o tick 30 (≈ 1.5 s).
- **Chama outros procedures:** DamageFix, GetDistanceNearestEnemy, ParticleGeneratorSweepingEffect, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=0, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.8% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### riki_riki · Stone Throwing (`C`, nº 24)
- **Tecla e custo:** `C` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `StoneThrowingProcedure` (222 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Stone Throwing — invoca/lança entidades (ROCK_FRAGMENT); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME_COMBAT, HIGH_SPEED).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** ROCK_FRAGMENT.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, entity.wither.shoot.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** GetDistance, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=-2, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.2% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### riki_riki · Giant Rock Throwing (`V`, nº 25)
- **Tecla e custo:** `V` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `StoneThrowingLargeProcedure` (227 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Giant Rock Throwing — invoca/lança entidades (ROCK_FRAGMENT); aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ROCK_FRAGMENT.
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, minepiece:stone_crash.
- **Duração aproximada:** até o tick 50 (≈ 2.5 s).
- **Chama outros procedures:** PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=460, nós criados=5, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 40.2% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Ryu Ryu Brachiosaurus

Despacho do mod: `SkillRyuRyuBrachiosaurusProcedure.java` — números mapeados: 21, 24, 25, 26, 28.

### ryu_ryu_brachiosaurus · Brachio Bomber (`Z`, nº 22)
- **Tecla e custo:** `Z` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `SkillRyuRyuBrachiosaurusProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (85 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Brachio Bomber — aplica efeitos do mod (SKILL).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** SKILL.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** AttackOverhead, BlackCofee, BrachioBober, BrachioLauncher, SparkingQueen.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=1, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 16.3% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ryu_ryu_brachiosaurus · Black Coffee Beam (`X`, nº 25)
- **Tecla e custo:** `X` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `BlackCofeeProcedure` (426 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Black Coffee Beam — invoca/lança entidades (ENTITY_IMPACT_WAVE); causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 17.0 * CNT6.
- **Alcance/área (Range):** 12.0 * CNT6; 2.0.
- **Empurrão (knockback):** 0.1; 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_IMPACT_WAVE.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** minecraft:end_rod, particle_light_large, particle_light_small.
- **Sons:** block.beacon.activate, minepiece:flame_explode, minepiece:laser_beam.
- **Duração aproximada:** até o tick 28 (≈ 1.4 s).
- **Chama outros procedures:** BlockDestroyAllDirection, LogicAttack, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=5, dano no alvo a 4 m=34.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 13.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ryu_ryu_brachiosaurus · Brachio Launcher (`C`, nº 26)
- **Tecla e custo:** `C` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `BrachioLauncherProcedure` (263 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Brachio Launcher — invoca/lança entidades (MISSILE); causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 2.2.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** MISSILE.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, minepiece:rocket_launcher.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** DamageFix, GetDistanceNearestEnemy, PlayAnimation, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=-5, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ryu_ryu_brachiosaurus · Sparking Queen (`V`, nº 27)
- **Tecla e custo:** `V` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 27 → `SparkingQueenProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (258 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Sparking Queen — invoca/lança entidades (PROJECTILE_LASER_RED); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 0.3; 16.0.
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** PROJECTILE_LASER_RED.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:laser_beam.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** DamageFix, GetReach, GetWeaponSize, PlayAnimation, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=25, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 16.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Ryu Ryu Pachycephalosaurus

Despacho do mod: `SkillRyuRyuPachycephalosaurusProcedure.java` — números mapeados: 21, 22, 26, 27, 28.

### ryu_ryu_pachycephalosaurus · Headbutt (`Z`, nº 23)
- **Tecla e custo:** `Z` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `HeadbuttProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (372 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Headbutt — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 15.0 * CNT6.
- **Alcance/área (Range):** 4.0 * range.
- **Empurrão (knockback):** 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 18 (≈ 0.9 s).
- **Chama outros procedures:** AttackStrongPunch, EntityVector, GetDistanceIterator, InsideSolidCalculate, LogicAttack, OnGround, ParticleGeneratorCircle, PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=-2, dano no alvo a 4 m=12.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.2% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ryu_ryu_pachycephalosaurus · Ulti-Mortar (`X`, nº 27)
- **Tecla e custo:** `X` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 27 → `UlZuganProcedure` (328 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Ulti-Mortar — causa dano; aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 18.0 * CNT6.
- **Alcance/área (Range):** 6.0 * range.
- **Empurrão (knockback):** 1.5.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.shoot, forge:ranged_ammo_no_move.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** EntityVector, GetDistanceIterator, GetDistanceNearestEnemy, LogicAttack, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=5, dano no alvo a 4 m=109.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.0% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ryu_ryu_pachycephalosaurus · Ulti-Meteor (`C`, nº 28)
- **Tecla e custo:** `C` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 28 → `UlMeteorProcedure` (312 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Ulti-Meteor — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT).
- **Dano no Java:** (24.0 + entity.getPersistentData().m_128459_("cnt2") * 0.1) * CNT6.
- **Alcance/área (Range):** 12.0 * range.
- **Empurrão (knockback):** 1.0; entity.getPersistentData().m_128459_("cnt2") < 15.0 ? 0.1 : 1.5 * CNT6.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, entity.wither.shoot.
- **Duração aproximada:** até o tick 10 (≈ 0.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, GetDistanceNearestEnemy, Grab, Knockback, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=460, nós criados=-6, dano no alvo a 4 m=22.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 11.3% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Ryu Ryu Pteranodon

Despacho do mod: `SkillRyuRyuPteranodonProcedure.java` — números mapeados: 22, 25, 27.

### ryu_ryu_pteranodon · Imperial Archer (`Z`, nº 23)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `?Procedure` (? linhas de Java).
- **Recarga:** 3.75 s (global do mod).
- **Despacho do mod desta fruta:** números 22, 25, 27.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Imperial Archer.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=-2, dano no alvo a 4 m=26.
- **Leitura da medição:** a técnica roda e gasta energia como a ficha.
- **Visibilidade medida:** 7.6% da imagem muda.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

### ryu_ryu_pteranodon · Imperial Slings And Arrows (`X`, nº 26)
- **Tecla e custo:** `X` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `?Procedure` (? linhas de Java).
- **Recarga:** 5.00 s (global do mod).
- **Despacho do mod desta fruta:** números 22, 25, 27.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Imperial Slings And Arrows.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=1, dano no alvo a 4 m=660.
- **Leitura da medição:** a técnica roda e gasta energia como a ficha.
- **Visibilidade medida:** 10.6% da imagem muda.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

## Soru Soru

Despacho do mod: `SkillSoruSoruProcedure.java` — números mapeados: 21, 22, 23, 24, 25, 26, 27.

### soru_soru · Thunder Bolt (`Z`, nº 23)
- **Tecla e custo:** `Z` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `RaiteiProcedure` (658 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Thunder Bolt — invoca/lança entidades (ENTITY_ZEUS); causa dano; reposiciona o corpo (deslocamento/teleporte); aplica efeitos do mod (ATTACKING, COOLDOWN_TIME, SKILL).
- **Dano no Java:** 1.0; 12.0 * CNT6; 15.0; 15.0 * CNT6.
- **Alcance/área (Range):** 20.0 * d * 0.2; 6.0 * range.
- **Empurrão (knockback):** 0.0; 0.5; 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_ZEUS.
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME, SKILL.
- **Partículas do mod:** minepiece:particle_thunder_blue, particle_thunder_blue.
- **Sons:** entity.generic.explode, entity.lightning_bolt.thunder, minepiece:thunder_impact.
- **Duração aproximada:** até o tick 40 (≈ 2.0 s).
- **Chama outros procedures:** AttackOverhead, BlockDestroyAllDirection, DamageFix, GetDistance, GetEntityByUUID, Grab, Knockback, PlayAnimation.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=3, dano no alvo a 4 m=425.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 17.2% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### soru_soru · Heavenly Fire (`X`, nº 24)
- **Tecla e custo:** `X` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `HebunriFireProcedure` (355 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Heavenly Fire — invoca/lança entidades (ENTITY_PROMETHEUS); reposiciona o corpo (deslocamento/teleporte); aplica efeitos do mod (COOLDOWN_TIME, SKILL).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_PROMETHEUS.
- **Efeitos do mod aplicados:** COOLDOWN_TIME, SKILL.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:flame_explode.
- **Duração aproximada:** até o tick 25 (≈ 1.2 s).
- **Chama outros procedures:** GetEntityByUUID, ParticleGeneratorCircle, PlayAnimation, ResetCounter, ReturnEntitySize, RotateEntity, SetSummonedEntity, StartTechniqueEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=0, dano no alvo a 4 m=13.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 30.5% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### soru_soru · Fulgora (`C`, nº 25)
- **Tecla e custo:** `C` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `FurugoraProcedure` (436 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Fulgora — causa dano; aplica efeitos do mod (COOLDOWN_TIME, DAMAGE_EFFECT).
- **Dano no Java:** (16.0 + 0.001 * entity.getPersistentData().m_128459_("cnt3")) * CNT6.
- **Alcance/área (Range):** 8.0 * range.
- **Empurrão (knockback):** 0.5 * CNT6.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME, DAMAGE_EFFECT.
- **Partículas do mod:** minecraft:flash, minepiece:particle_thunder_blue, particle_thunder_blue.
- **Sons:** entity.lightning_bolt.thunder, minepiece:thunder_impact.
- **Duração aproximada:** até o tick 30 (≈ 1.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, InsideSolidCalculate, Knockback, LogicAttack, LogicIsEntityUsingAttack, ParticleGenerator, PlayAnimation, RangeAttack.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=1, dano no alvo a 4 m=1.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 14.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### soru_soru · Marma-Raid (`V`, nº 26)
- **Tecla e custo:** `V` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `MamaRaidProcedure` (394 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Marma-Raid — causa dano; aplica impulso/velocidade; aplica efeitos do mod (COLLIDED).
- **Dano no Java:** 25.0 * CNT6; 30.0.
- **Alcance/área (Range):** 12.0 * range; 3.0 * range.
- **Empurrão (knockback):** 0.6; 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, entity.player.attack.sweep, entity.zombie.break_wooden_door.
- **Duração aproximada:** até o tick 120 (≈ 6.0 s).
- **Chama outros procedures:** BlockDestroyAllDirection, GetPowerFix, Knockback, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=260, nós criados=9, dano no alvo a 4 m=25.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 20.0% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### soru_soru · Ikoku Sovereignty (`B`, nº 27)
- **Tecla e custo:** `B` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 27 → `IkokuProcedure` (762 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Ikoku Sovereignty — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT, HIGH_SPEED, SOVEREIGN_HAKI).
- **Dano no Java:** (30.0 + entity.getPersistentData().m_128459_("cnt1") * 0.01) * CNT6; 6.0.
- **Alcance/área (Range):** 20.0 * range.
- **Empurrão (knockback):** 2.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT, HIGH_SPEED, SOVEREIGN_HAKI.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, entity.lightning_bolt.thunder, minepiece:electric_shock, minepiece:sword_sweep.
- **Duração aproximada:** até o tick 45 (≈ 2.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetDistanceIterator, GetEntityByUUID, Knockback, LogicAttack, ParticleGenerator.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=460, nós criados=38, dano no alvo a 4 m=176.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 26.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Supa Supa

Despacho do mod: `SkillSupaSupaProcedure.java` — números mapeados: 21, 22, 23, 24.

### supa_supa · Projectile Slash (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `SkillProjectileSlashProcedure` (309 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Projectile Slash — invoca/lança entidades (PROJECTILE_SLASH); aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** PROJECTILE_SLASH.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:sword_sweep.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongSword, PlayAnimation, PlayAnimationEntity2, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=-1, dano no alvo a 4 m=5.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 7.6% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### supa_supa · Atomic Spurt (`X`, nº 22)
- **Tecla e custo:** `X` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `AtomicSpurtProcedure` (342 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Atomic Spurt — causa dano; aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT, HIGH_SPEED).
- **Dano no Java:** 16.0 * CNT6.
- **Alcance/área (Range):** 5.0 * range.
- **Empurrão (knockback):** 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT, HIGH_SPEED.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:sword_sweep.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** GetDistanceNearestEnemy, GetPowerFix, OnGround, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity, StepBlock.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=-2, dano no alvo a 4 m=35.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.6% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### supa_supa · Sparkling Daisy (`C`, nº 23)
- **Tecla e custo:** `C` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `SparklingDaisyProcedure` (339 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Sparkling Daisy — causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** Math.max(18.0 * Math.pow(0.99, Math.round(Math.floor(dis))), 9.0); entity.getPersistentData().m_128459_("Damage") * Math.max(CNT6, 0.75).
- **Alcance/área (Range):** 2.0.
- **Empurrão (knockback):** 0.25 * Math.min(CNT6, 1.0).
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep, minepiece:sword_sweep.
- **Duração aproximada:** até o tick 10 (≈ 0.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=0, dano no alvo a 4 m=4470.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### supa_supa · Spar Break (`V`, nº 24)
- **Tecla e custo:** `V` · custo 300 de energia · recarga global 7.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `SparBreakProcedure` (299 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Spar Break — causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** Math.max((15.0 + entity.getPersistentData().m_128459_("cnt1") * 0.1) * Math.pow(0.99, Math.round(Math.floor(dis))), 9.0)
                        ; entity.getPersistentData().m_128459_("Damage") * Math.max(CNT6, 0.75).
- **Alcance/área (Range):** 2.0.
- **Empurrão (knockback):** 0.25 * Math.min(CNT6, 1.0).
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:crush, minepiece:sword_sweep.
- **Duração aproximada:** até o tick 25 (≈ 1.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=-1, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 13.0% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Uo Uo Seiryu

Despacho do mod: `SkillUoUoSeiryuProcedure.java` — números mapeados: 21, 22, 23, 24, 25, 26, 27, 29.

### uo_uo_seiryu · Thunder Bagua (`Z`, nº 23)
- **Tecla e custo:** `Z` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `RaimeiHakkeProcedure` (396 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Thunder Bagua — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT).
- **Dano no Java:** 18.0 * CNT6; entity.getPersistentData().m_128459_("Damage") * 1.2.
- **Alcance/área (Range):** 4.0 * strength.
- **Empurrão (knockback):** 1.0; entity.getPersistentData().m_128459_("knockback") * 1.2.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COLLIDED, COOLDOWN_TIME_COMBAT, DAMAGE_EFFECT.
- **Partículas do mod:** particle_thunder_blue.
- **Sons:** entity.lightning_bolt.impact, entity.lightning_bolt.thunder.
- **Duração aproximada:** até o tick 120 (≈ 6.0 s).
- **Chama outros procedures:** GetDistanceNearestEnemy, GetPowerFix, LogicIsEntityUsingAttack, OnGround, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=0, dano no alvo a 4 m=62.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 11.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uo_uo_seiryu · Vajra Arrow (`X`, nº 24)
- **Tecla e custo:** `X` · custo 250 de energia · recarga global 6.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `KongoKaburaProcedure` (336 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Vajra Arrow — invoca/lança entidades (ENTITY_ENERGY); aplica efeitos do mod (COOLDOWN_TIME_COMBAT, SOVEREIGN_HAKI).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_ENERGY.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT, SOVEREIGN_HAKI.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.wither.shoot.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, ParticleGeneratorCircle, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=210, nós criados=2, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uo_uo_seiryu · Demolition Gust (`C`, nº 25)
- **Tecla e custo:** `C` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `KaifuProcedure` (460 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Demolition Gust — invoca/lança entidades (PROJECTILE_SLASH, TORNADO); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** PROJECTILE_SLASH, TORNADO.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.breath, entity.wither.shoot, minepiece:sword_sweep.
- **Duração aproximada:** até o tick 15 (≈ 0.8 s).
- **Chama outros procedures:** ParticleGeneratorCircle, PlayAnimation, PlayAnimationEntity2, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=10, dano no alvo a 4 m=1295.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 14.8% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uo_uo_seiryu · Blast Breath (`V`, nº 26)
- **Tecla e custo:** `V` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `BoroBreathProcedure` (453 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Blast Breath — invoca/lança entidades (ENTITY_IMPACT_WAVE); causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 18.0 * CNT6.
- **Alcance/área (Range):** 4.0 * range.
- **Empurrão (knockback):** 0.75.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_IMPACT_WAVE.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** minepiece:particle_flame.
- **Sons:** entity.player.breath, entity.wither.shoot, minepiece:flame_explode.
- **Duração aproximada:** até o tick 30 (≈ 1.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, LogicAttack, ParticleGenerator, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=-6, dano no alvo a 4 m=65.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 26.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uo_uo_seiryu · Conqueror of Three Worlds Ragnaraku (`B`, nº 27)
- **Tecla e custo:** `B` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 27 → `KosanzeRagnarakuProcedure` (565 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Conqueror of Three Worlds Ragnaraku — causa dano; aplica impulso/velocidade; aplica efeitos do mod (COLLIDED, COOLDOWN_TIME_COMBAT, SOVEREIGN_HAKI).
- **Dano no Java:** 15.0 * CNT6; 25.0 * CNT6; 30.0.
- **Alcance/área (Range):** 10.0 * range; 3.0 * range; strength * 1.0.
- **Empurrão (knockback):** 0.6; 1.0; 2.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COLLIDED, COOLDOWN_TIME_COMBAT, SOVEREIGN_HAKI.
- **Partículas do mod:** minepiece:particle_thunder_black, minepiece:particle_thunder_blue, particle_thunder_blue.
- **Sons:** entity.lightning_bolt.impact, entity.lightning_bolt.thunder, entity.player.attack.sweep, entity.zombie.break_wooden_door.
- **Duração aproximada:** até o tick 30 (≈ 1.5 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetPowerFix, Knockback, PlayAnimation, RangeAttack, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=460, nós criados=2, dano no alvo a 4 m=1.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 22.6% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uo_uo_seiryu · Ikoku Sovereignty (`N`, nº 28)
- **Tecla e custo:** `N` · custo 500 de energia · recarga global 12.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 28 → `IkokuProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (762 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Ikoku Sovereignty — causa dano; aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME_COMBAT, HIGH_SPEED, SOVEREIGN_HAKI).
- **Dano no Java:** (30.0 + entity.getPersistentData().m_128459_("cnt1") * 0.01) * CNT6; 6.0.
- **Alcance/área (Range):** 20.0 * range.
- **Empurrão (knockback):** 2.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME_COMBAT, HIGH_SPEED, SOVEREIGN_HAKI.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.generic.explode, entity.lightning_bolt.thunder, minepiece:electric_shock, minepiece:sword_sweep.
- **Duração aproximada:** até o tick 45 (≈ 2.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetDistanceIterator, GetEntityByUUID, Knockback, LogicAttack, ParticleGenerator.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=460, nós criados=-4, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida:** não coberta na captura de 15/11/2026.
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Ushi Ushi Giraffe

Despacho do mod: `SkillUshiUshiGiraffeProcedure.java` — números mapeados: 21, 22, 23, 24, 26.

### ushi_ushi_giraffe · Finger Pistol (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 60 de energia · recarga global 1.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `ShiganProcedure` (285 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Finger Pistol — invoca/lança entidades (BULLET); causa dano; aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** 1.5; 10.0 * CNT6; 3.0.
- **Alcance/área (Range):** 2.0 * range.
- **Empurrão (knockback):** 0.25.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** BULLET.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** BlockDestroyAllDirection, DamageFix, GetDistance, GetReach, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=20, nós criados=-1, dano no alvo a 4 m=5.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ushi_ushi_giraffe · Tempest Kick (`X`, nº 23)
- **Tecla e custo:** `X` · custo 100 de energia · recarga global 2.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `RankyakuProcedure` (384 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tempest Kick — invoca/lança entidades (ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH); aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_WOLF_PROJECTILE, PROJECTILE_SLASH.
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.player.attack.sweep.
- **Duração aproximada:** até o tick 8 (≈ 0.4 s).
- **Chama outros procedures:** AttackStrongPunch, PlayAnimation, PlayAnimationEntity2, ReturnCharactorDevilFruti, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=60, nós criados=1, dano no alvo a 4 m=1084.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 6.2% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ushi_ushi_giraffe · Tempest Kick "Slaughter" (`C`, nº 24)
- **Tecla e custo:** `C` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `RankyakuRanProcedure` (164 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Tempest Kick "Slaughter" — aplica efeitos do mod (COOLDOWN_TIME_COMBAT).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME_COMBAT.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** até o tick 40 (≈ 2.0 s).
- **Chama outros procedures:** Rankyaku, ReturnEntitySize, RotateEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=3, dano no alvo a 4 m=1663.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 18.3% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### ushi_ushi_giraffe · Tempest Kick "Sky Slicer" (`V`, nº 25)
- **Tecla e custo:** `V` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `?Procedure` (? linhas de Java).
- **Recarga:** 10.00 s (global do mod).
- **Despacho do mod desta fruta:** números 21, 22, 23, 24, 26.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Tempest Kick "Sky Slicer".
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=21, dano no alvo a 4 m=69.
- **Leitura da medição:** a técnica roda e gasta energia como a ficha.
- **Visibilidade medida:** 29.8% da imagem muda.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

## Uta Uta

Despacho do mod: `SkillUtaUtaProcedure.java` — números mapeados: 21, 22, 23, 24, 25, 26, 29.

### uta_uta · Note (`Z`, nº 21)
- **Tecla e custo:** `Z` · custo 50 de energia · recarga global 1.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 21 → `NoteAttackProcedure` (300 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Note — invoca/lança entidades (ENTITY_NOTE); aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_NOTE.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** entity.firework_rocket.launch.
- **Duração aproximada:** até o tick 5 (≈ 0.2 s).
- **Chama outros procedures:** NoteAttack2, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=10, nós criados=-5, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 5.2% da imagem muda em relação à cena sem a técnica (baixa: candidata a reforço visual).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uta_uta · Note Beam (`X`, nº 22)
- **Tecla e custo:** `X` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `NoteLaserProcedure` (372 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Note Beam — invoca/lança entidades (ENTITY_NOTE); aplica impulso/velocidade; aplica efeitos do mod (ATTACKING, COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_NOTE.
- **Efeitos do mod aplicados:** ATTACKING, COOLDOWN_TIME.
- **Partículas do mod:** particle_note.
- **Sons:** entity.wither.shoot.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** ParticleGenerator, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=1, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 12.1% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uta_uta · Note Barrier (`C`, nº 23)
- **Tecla e custo:** `C` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `PosingProcedure` (366 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Note Barrier — invoca/lança entidades (ENTITY_IMPACT_WAVE); causa dano; aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 20.0.
- **Alcance/área (Range):** range * 4.0.
- **Empurrão (knockback):** 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** ENTITY_IMPACT_WAVE.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:electric_shock, minepiece:frame_set.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** DamageFix, GetDistanceNearestEnemy, Knockback, ParticleGeneratorCircle, PlayAnimation, ReturnEntitySize, RotateEntity, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=6, dano no alvo a 4 m=6.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 11.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### uta_uta · Note Warrior (`V`, nº 25)
- **Tecla e custo:** `V` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 25 → `SkillSummonNoteWarriorProcedure` (332 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Note Warrior — invoca/lança entidades (NOTE_WARRIOR_1, NOTE_WARRIOR_2); aplica efeitos do mod (ARMAMENT_HAKI, OBSERVATION_HAKI).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** não declarado aqui.
- **Empurrão (knockback):** não declarado aqui.
- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.
- **Entidades criadas:** NOTE_WARRIOR_1, NOTE_WARRIOR_2.
- **Efeitos do mod aplicados:** ARMAMENT_HAKI, OBSERVATION_HAKI.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** não declarados aqui.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** SetSummonedEntity.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=7, dano no alvo a 4 m=4.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 9.3% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

## Zushi Zushi

Despacho do mod: `SkillZushiZushiProcedure.java` — números mapeados: 21, 22, 23, 25, 27, 28, 29.

### zushi_zushi · Gravity Blade (`Z`, nº 22)
- **Tecla e custo:** `Z` · custo 150 de energia · recarga global 3.75 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 22 → `GravitoProcedure` (374 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Gravity Blade — causa dano; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** 11.0 * CNT6; 15.0 * CNT6.
- **Alcance/área (Range):** 2.0 * range.
- **Empurrão (knockback):** 0.001 * (Math.random() - 0.5); 1.0.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** minepiece:particle_gravity, particle_purple.
- **Sons:** entity.generic.explode, minepiece:gravity.
- **Duração aproximada:** até o tick 20 (≈ 1.0 s).
- **Chama outros procedures:** BlockDestroyAllDirection, GetDistance, InsideSolidCalculate, Knockback, ParticleGeneratorCircle, PlayAnimation, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=110, nós criados=1, dano no alvo a 4 m=85.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 8.8% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### zushi_zushi · Small Meteors (`X`, nº 23)
- **Tecla e custo:** `X` · custo 200 de energia · recarga global 5.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 23 → `FujitoraMeteorSmallProcedure` (160 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Small Meteors — invoca/lança entidades (METEOR); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** 8.0 * range.
- **Empurrão (knockback):** 0.1.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** METEOR.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** minepiece:gravity.
- **Duração aproximada:** não derivável de um contador único (várias fases).
- **Chama outros procedures:** BlockDestroyAllDirection, Knockback, ParticleGeneratorCircle, PlayAnimation, ReturnEntitySize, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=160, nós criados=2, dano no alvo a 4 m=14.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 10.4% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### zushi_zushi · Raging Tiger (`C`, nº 24)
- **Tecla e custo:** `C` · custo 400 de energia · recarga global 10.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 24 → `AITigerProcedure` (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure) (278 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Raging Tiger — causa dano; reposiciona o corpo (deslocamento/teleporte); aplica impulso/velocidade.
- **Dano no Java:** 18.0 * CNT6.
- **Alcance/área (Range):** 3.0 * range_fix.
- **Empurrão (knockback):** 1.0 * CNT6.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** nenhuma (efeito direto no jogador/alvos).
- **Efeitos do mod aplicados:** nenhum efeito próprio do mod neste procedure.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** block.end_gateway.spawn, entity.ender_dragon.growl.
- **Duração aproximada:** até o tick 60 (≈ 3.0 s).
- **Chama outros procedures:** BlockDestroyAllDirection, GetEntityByUUID, RangeAttack, ReturnEntitySize.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=360, nós criados=1, dano no alvo a 4 m=28.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 16.9% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### zushi_zushi · Rubbles (`V`, nº 26)
- **Tecla e custo:** `V` · custo 600 de energia · recarga global 15.00 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 26 → `?Procedure` (? linhas de Java).
- **Recarga:** 15.00 s (global do mod).
- **Despacho do mod desta fruta:** números 21, 22, 23, 25, 27, 28, 29.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Rubbles.
- **Medição (varredura 15/11/2026):** começou=true, energia gasta=560, nós criados=16, dano no alvo a 4 m=5.
- **Leitura da medição:** a técnica roda e gasta energia como a ficha.
- **Visibilidade medida:** 3.7% da imagem muda.
- **Origem:** versão PRÓPRIA do V (`zushi_fujitora.gd`, `RUBBLE = 26`): o Rubble do mod faz as pedras nascerem mas não causam dano aqui (dependem da física da entidade `rubble`).
- **Números:** custo 600, recarga 12 s, duração 1,6 s, uma rocha a cada 0,08 s, alcance 40 m, espalhamento 6 m e raio de impacto 2,6 m por rocha.
- **Efeito:** chuva de rochas sobre o alvo mirado; cada rocha fere em área ao cair.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

### zushi_zushi · Meteor (`B`, nº 28)
- **Tecla e custo:** `B` · custo 1250 de energia · recarga global 31.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número 28 → `FujitoraMeteorProcedure` (191 linhas de Java).
- **Objetivo (inferido do nome e dos efeitos):** Meteor — invoca/lança entidades (METEOR); aplica impulso/velocidade; aplica efeitos do mod (COOLDOWN_TIME).
- **Dano no Java:** sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado).
- **Alcance/área (Range):** 16.0 * range.
- **Empurrão (knockback):** 0.1.
- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).
- **Entidades criadas:** METEOR.
- **Efeitos do mod aplicados:** COOLDOWN_TIME.
- **Partículas do mod:** só as partículas padrão do Minecraft (ou nenhuma).
- **Sons:** block.beacon.activate, minepiece:gravity.
- **Duração aproximada:** até o tick 40 (≈ 2.0 s).
- **Chama outros procedures:** BlockDestroyAllDirection, Knockback, ParticleGeneratorCircle, PlayAnimation, ReturnEntitySize, SetRangedAmmo.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=-12, dano no alvo a 4 m=0.
- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.
- **Visibilidade medida (15/11/2026):** 11.6% da imagem muda em relação à cena sem a técnica (legível).
- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.

### zushi_zushi · Jigoku Tabi (`K`, nº None)
- **Tecla e custo:** `K` · custo 450 de energia · recarga global 11.25 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número None → `?Procedure` (? linhas de Java).
- **Recarga:** 11.25 s (global do mod).
- **Despacho do mod desta fruta:** números 21, 22, 23, 25, 27, 28, 29.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Jigoku Tabi.
- **Medição (varredura 15/11/2026):** começou=false, energia gasta=0, nós criados=-2, dano no alvo a 4 m=0.
- **Leitura da medição:** não começou na varredura (pode exigir forma/pré-condição do mod).
- **Visibilidade medida:** não coberta na captura de 15/11/2026.
- **Origem:** poder autoral do Fujitora (`zushi_fujitora.gd`, número 1002, tecla K): 'Viagem ao Inferno'; a pesquisa está em `docs/PESQUISA_FUJITORA_ZUSHI.md`.
- **Números:** custo 450, recarga 14 s, preparo 0,7 s (embainha a espada e o corpo para), duração 1,4 s e raio de 14 m.
- **Efeito:** uma força gravitacional achata tudo ao redor e abre uma cratera no fim; entrada e dano rodam no servidor.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

### zushi_zushi · Abare Himatsuri (`L`, nº None)
- **Tecla e custo:** `L` · custo 700 de energia · recarga global 17.50 s (`max(custo × 0,5; 5) × 0,05`).
- **Procedure do mod:** número None → `?Procedure` (? linhas de Java).
- **Recarga:** 17.50 s (global do mod).
- **Despacho do mod desta fruta:** números 21, 22, 23, 25, 27, 28, 29.
- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).
- **Objetivo (inferido só do nome):** Abare Himatsuri.
- **Medição:** sem linha na varredura (técnica nativa do projeto; ver o teste dedicado).
- **Visibilidade medida:** não coberta na captura de 15/11/2026.
- **Origem:** poder autoral do Fujitora (`zushi_fujitora.gd`, número 1003, tecla L): 'Festival Furioso'.
- **Números:** custo 700, recarga 24 s, duração 4,0 s, velocidade 13, a pedra sobe 2,2 m do chão e um meteoro cai a cada 0,2 s.
- **Efeito:** levanta a rocha em que pisa, voa por cima do campo e faz chover meteoros atrás de si; o mais caro e demorado da Zushi.
- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.

<!-- 107 técnicas documentadas -->
