# Desempenho do mod — X do Batto Batto (09/11/2026)

**Sintoma:** técnicas como o X (Tempest Kick) derrubavam o FPS. **Medido** (`await physics_frame` em headless, 150 quadros após o X; linha de base ~16,7 ms = teto de 60 FPS):

| Cenário | Antes (média / pior quadro) | Depois |
|---|---|---|
| mapa plano, 0 inimigos | 22,3 / 118 ms | 16,4 / 51 ms (= linha de base) |
| **mapa real**, 0 inimigos | 30,2 / 193 ms | 17,3 / 65 ms |
| mapa real, 3 inimigos | 22,4 / 120 ms (plano) | 18,5 / 79 ms |

**Causa:** o X cria uma lâmina por tick (`AIProjectileSlash`); com ~9 vivas, cada tick rodava ~150 `BlockDestroyAllDirection` + ~50 `RangeAttack`, e cada um repetia trabalho caro no GDScript: varrer **todas** as entidades do mapa (`getEntitiesOfClass`, 2,2 ms/consulta no mapa real), `Mc.e` refazendo `_snake` por chamada, `ReturnDevilFruitEaten` varrendo ~100 classes, e as mesmas células de bloco testadas dezenas de vezes.

**O que mudou (todas exatas, sem mudar regra de jogo):**
1. `Mc.e`: classificação por nome de classe memorizada (`_classe_do_tipo`).
2. `McMundo.getEntitiesOfClass`: "foto" das caixas por quadro de física (refeita se a contagem de corpos muda; posição escrita pelo mod atualiza só a caixa de quem se mexeu).
3. `McMundo.getBlockState`: cache por quadro, invalidado por célula no `setBlock` e zerado a cada tick.
4. `src/minecraft/otimizadas/` + `Mc.OTIMIZADAS`: cópias das procedures geradas `BlockDestroyAllDirection` (classifica cada célula uma vez por tick) e `ReturnDevilFruitEaten` (resposta por entidade, validada por `id_personagem`; guarda e devolve CÓPIA; jogador nunca em cache). A terceira entrada (`SelectedArmorEquip`) é um no-op por outro motivo (item 1/9), não de desempenho.

**Testes:** `test_procedures_otimizadas` (mundo idêntico à gerada em 4 cenários de dano; mesma fruta em 6 entidades; jogador sem cache; troca de id invalida). Medidor: ver o final deste arquivo.

**Gatilhos:** (a) regerar as procedures com o tradutor → refazer cada arquivo de `otimizadas/` e rodar o teste; (b) novo golpe com queda de FPS → medir antes (tempo por quadro + `Cronometro` nas fases) e procurar chamadas por tick × custo por chamada; (c) próximo candidato: `RangeAttack` (~0,6 ms/chamada: `DamageFix`, `PassiveDamageGain`, `ReturnCharactorDevilFruti`).

**Medidor reproduzível (cenário):** equipar a fruta, 3 s parado, soltar a técnica por 3 quadros, medir o tempo de 150 quadros com e sem a otimização; no mapa real use o modo história sem `mapa_forcado`.
