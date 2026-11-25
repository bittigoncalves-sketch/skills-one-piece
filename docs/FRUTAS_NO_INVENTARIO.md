# Frutas no inventário normal (decisão do dono, 25/11/2026)

"Passar todas as frutas para o inventário normal, de vez": a aba FRUTAS do `InventarioDaHistoria` acabou.

- **Itens:** Akuma no Mi = `akuma:<id>`, fruta do pomar = `pomar:<id>` (`src/inventario/itens_de_fruta.gd`). Empilham até 64, entram na hotbar primeiro e depois na mochila, como qualquer item.
- **Comer a Akuma:** botão direito com ela na mão (`CliqueDeBlocos`) ou no slot da mochila (`MochilaMinecraft`). Com fruta no corpo, o 1º clique avisa o que se perde e o 2º (em 4 s) confirma. Regra única: `ItensDeFruta.comer`.
- **Fruta do pomar na mão (doma):** slot selecionado da hotbar com `pomar:<id>` → `FrutaNaMao` a segura; trocar de slot a guarda (`_sincronizar_com_a_hotbar`).
- **Posse = inventário.** `frutas_compradas`/`frutas_do_pomar` em `ProgressaoDoPersonagem` guardam só o EXCEDENTE que não coube (e saves antigos até migrarem: `recolher_frutas_para_o_inventario`, chamado ao carregar e ao abrir a mochila). Compra com mochila cheia é recusada sem cobrar. API: `quantas_akuma`, `akumas_guardadas`, `remover_akuma`, `quantas_frutas_do_pomar`.
- **Kit do Builder:** entra como `akuma:kit_builder` (1, não se gasta) enquanto houver skill publicada.
- **Ícones 2D novos:** Codex, 32×32, `art_src/akuma_no_mi/icones/<id>.png` → `python3 -I tools/akuma_no_mi/copiar_icones.py` → `assets/ui/frutas/akuma/` → `--import`. Sem o ícone novo, vale o antigo da loja.
- **Testes:** `tools/dev_tests/test_frutas_no_inventario.gd` (23/23); adaptados `test_nikyu_no_inventario`, `test_pomar_e_doma`, `test_kit_do_builder_historia` (com `SOP_BUILDER=1`) e `test_npcs_e_lojas`.
- **GATILHO:** se o excedente virar rotina (mochila sempre cheia), avisar "mochila cheia" em vez de guardar calado.
