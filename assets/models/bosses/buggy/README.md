# Buggy — asset de ensaio

Fonte fornecida pelo usuário: `/home/gabriel-bitti/Downloads/buggyBoss.glb`.
Cópia binária integral, sem conversão ou modificação do original, em 2026-09-12.
Gerador declarado no glTF: Tripo. Licença/autoria não estão declaradas no arquivo.

SHA-256 de origem e cópia:
`e05a9aa859a46ee9d89773ff995a1b2be90c74e6d300c3de51a5bd953ce4eabc`.

- 56 nós, 13 malhas, 976.226 vértices, 1.881.078 triângulos.
- Um skin, 41 joints; nomes Tripo (`Waist`, `L_Upperarm`, `L_Calf`, etc.).
- Sem animações embarcadas e sem ossos dos dedos.
- 13 materiais PBR double-sided, metallic 0, roughness 0,9.
- 13 JPEG embutidos: um 2048², onze 1024² e um 512².
- AABB das posições de malha: tamanho (0,7075806; 0,9787592; 0,2882233), base Y aproximadamente zero. A cena está Y-up; o osso Root possui rotação própria, que deve ser preservada.

O recurso `buggy_boss_visual.tres` controla escala uniforme, orientação e mapa
explícito dos 13 papéis do animador existente. `SOP_TEST_CHARACTER_VISUAL`
seleciona esse recurso somente no processo de teste. Sem a variável, Player,
TrainingDummy e AutoDummy continuam com seus modelos normais. Nenhuma
identidade, fruta, colisão ou autoridade de rede muda junto da aparência.

As malhas `tripo_part_*` são segmentos de geração, não um contrato anatômico de
Bara Bara: pernas compartilham a mesma malha de roupa e outras peças recebem
pesos de vários ossos. A separação real precisa de preparação artística de
malhas, tampas e pesos, além de trajetória/colisão no gameplay.

O retarget dos 13 papéis permite ensaiar animações existentes; ele não é uma
aprovação do boxe, da guarda ou da mão fechada. Sem dedos no esqueleto, fechamento
dinâmico do punho depende de asset derivado, morph ou rig adicional. As capturas
confirmam que as mãos já são geometricamente fechadas no arquivo atual. Sockets
seguem L_Hand/R_Hand, mas orientação de equipamentos e contato de cada golpe
precisam de validação específica. A densidade foi preservada; performance em
combate com várias cópias deve ser medida antes de uso como boss de produção.

Orientação validada na engine: Y=180° no recurso de teste alinha a frente com −Z.
Altura de repouso: 1,5 m; escala uniforme 1,532553; base local Y=−0,8 m.
Evidências: `art_src/validation/buggy/` e `docs/BOSS_BUGGY_IMPLEMENTATION_PLAN.md`.
