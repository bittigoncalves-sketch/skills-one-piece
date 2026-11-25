# Checkpoint dos testes de fruta/história — 15/11/2026

Bateria `./validar.sh historia fruta rocket` (24 ok / 7 falhas no início da sessão).

## Corrigido nesta sessão
- **Rocket (código):** `RocketController._dano_em_area` passava o atirador como `corpo_a_corpo_de` em `CombatResolver.aplicar`,
  somando o bônus de Força (+3,0) à fruta DEPOIS da guarda (16,5 em vez de 13,5). Agora vai como `autor`.
- `test_frutas`: Rocket Crash (X) joga o jogador para fora do mapa → a fruta volta à árvore e C/V saíam vazios. A auditoria reequipa.
- `test_kit_do_builder_historia`: abre o inventário pela HUD antes de procurar o Kit (só redesenha aberto). Roda com `SOP_BUILDER=1`.
- `test_fio_espada_historia`, `test_giro_espada_historia`, `test_pegada_giro_espada`: a espada inicial saiu do kit
  (só lâminas do Epic Fight) → o teste concede `equipamentos["espada"]`. Giro: dano esperado inclui a Força (`bonus_fisico_historia`);
  invulnerabilidade Minecraft (`mc_inv_ate`, ms reais) zerada entre quadrantes (flaky no headless).

## Aberto (com gatilho)
- `test_pegada_giro_espada`: mão ESQUERDA 4,2 cm fora do cabo (tolerância 2 cm) e desvio 2,4 cm — calibração do encaixe `Weapon_L`
  no corpo novo (`corpo_historia`). Revisitar ao mexer em `player_rig._attach_item_handle_l` ou na espada de duas mãos.
- ~~`test_contato_historia`~~ **resolvido (decisão do dono, 15/11/2026):** o jogador da história tem ARMADURA NO PREPARO
  (`ExecutorCorpoACorpo.armadura_no_preparo`, ligada em `ModoHistoria`): acerto no preparo não corta a sequência de socos (o dano entra).
  Antes só o ATIVO era protegido (§7.1). RECUPERAÇÃO continua interrompível. O teste agora afirma que os golpes vão até o fim; quem
  "conecta" depende do empurrão e não é afirmado. Os outros erros eram do teste (teto de vida ~24 reaplicado → `_folga_de_vida`, Força, pipeline do mod ×10).
- `test_combate_historia` (preparo ×0,84 vs 0,60) e `test_combate_historia_tela` (precisa de display/mouse): dependem de decisão de design.
