# Formas Zoan do jogador (09/11/2026)

**Sintoma:** a tecla J mudava o atributo `minepiece:form` (0↔1) em todas as 14 frutas da tag `minepiece:can_transform`, mas o corpo
não mudava. **Causa (medida):** nada no jogo ligava a forma a um modelo — o mod desenha a forma no `KleidersRenderEventProcedure`
(evento de render), que o jogo nunca traduziu.

## O que existe
| Peça | Papel |
|---|---|
| `tools/mine_piece/extrair_formas_zoan.py` | lê fruta→(modelo, textura) do `KleidersRenderEventProcedure`, extrai as caixas dos `Model*` (agora com `mirror`) e copia as texturas. Saída: `mapas/east_blue/formas_zoan.json` |
| `src/minecraft/forma_zoan.gd` (`FormaZoan`) | monta as peças e as faz seguir as juntas do corpo (`Neck`, `Chest`, `UpperArm_L/R`, `Thigh_L/R`); escala gigante pelo `escala(&"height")` do mod |
| `src/combat/frutas_do_mod/controlador.gd` | liga/desliga a forma quando `forma_atual()` muda; desfaz ao trocar de fruta |
| `Player.gd` `_atualizar_visibilidade_corpo` | esconde o corpo quando a forma o substitui (`FormaZoan.META_ATIVA`); Batto Batto só acrescenta asas |
| `tools/dev_tests/test_forma_zoan.gd` | 171 verificações: 14 frutas (nó, malha, textura, juntas, altura vs cápsula, pé, frente/direita, braço acompanha, J de novo desfaz) + desequipar transformado |

Regerar: `python3 -I tools/mine_piece/extrair_formas_zoan.py` (precisa do jar e da biblioteca de fontes — ver memória `zoan-formas-render-no-mod`).

## Limites e gatilhos (decididos, não esquecidos)
- **Validação visual parcial.** Buda autoral conferido em 11/11/2026 (ver abaixo). Nas demais formas, frente/direita/altura/pé foram medidos numericamente; textura, UV espelhada e aparência não. *Gatilho:* o dono
  abrir cada fruta no jogo antes de qualquer polimento. Pteranodon e Fênix ficam de fora da checagem de pé (AABB inclui asa/cauda).
- **Só o dono vê:** `minepiece:form` é atributo do servidor e não é replicado. *Gatilho:* multiplayer com Zoan → replicar o inteiro da forma (RPC/synchronizer).
- **Braço/perna rígidos, copiando só a junta de cima, exceto o Buda autoral** (o modelo original do mod também não tem cotovelo). Nas demais formas, animações de soco/chute que dependem do antebraço ficam mais curtas.
- **Fora:** variantes `_fly` (Fênix, asas do Batto em voo), `_slim`, `feather_robe` (manto condicional), forma 2 do Kaidou. *Gatilho:* pedido de voo Zoan.
- **Mochi Mochi** não tem controlador do mod (o teste de zoan imprime "sem controlador") — fora desta entrega e não é Zoan.
- Índices de `hidePlayerModelPiece` pertencem a outro mod (Kleiders) fora do jar: o jogo esconde o corpo inteiro quando o modelo traz caixas de corpo, em vez de replicar o esconde parcial.

## Bug "B/V + dano" (fechado em 09/11/2026)
Causa: `McEntidade.setYRot`/`connection.teleport` giravam o nó raiz do jogador (pai da câmera). Corrigido na tradução (o mod não gira o nó do jogador humano; reorientação real escreve o `_yaw`).
Testes: `test_investida_nao_gira_o_jogador`, `test_varredura_giro_do_jogador` (80 técnicas das 40 frutas). O diagnóstico temporário foi removido do controlador.

## Camadas extras paradas (corrigido em 11/11/2026, "Uo Uo: partes desconectadas")
**Sintoma:** transformada, a Uo Uo Seiryu tinha peças que não acompanhavam o corpo (ficavam na pose de repouso enquanto o resto inclinava/girava no Z).
**Causa (medida):** o modelo do mod tem mais de uma camada (`Modeloverlay`, `…humanbeast2`) e cada camada repete as peças de topo (Head, Body, RightArm…).
`FormaZoan._montar` só registrava em `_topo` a primeira peça de cada nome (`not _topo.has(nome)`), então as peças de topo das camadas seguintes nunca copiavam a junta.
Afetava 9 das 14 frutas (as duas Ryu Ryu, Seiryu, Wolf, os dois felinos, Daibutsu, Girafa, Supa). **Correção:** toda camada registra suas peças; chave da primeira = nome, das seguintes = `nome#N`.
**Teste:** `test_forma_zoan` confere que nenhuma peça de topo fica sem seguir o corpo (185 verificações).
**Aberto:** o lag do Z (Demolition Gust) relatado pelo dono NÃO foi reproduzido — ver o relato da sessão; gatilho: nova medição com o dono (primeira vez ou sempre? qual placa?).
