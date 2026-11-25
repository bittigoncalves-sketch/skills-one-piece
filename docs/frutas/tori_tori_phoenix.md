# Tori Tori no Mi · Phoenix

Pedido de 14/10/2026: Z transformação; X/C/V; F voo. Revisão visual pelo usuário:
duas imagens do anime, com fênix azul, crista dourada, asas extensas e caudas de fogo.

| Tecla | Ação | Recarga |
|---|---|---|
| Z | Alterna forma completa de fênix | 1 s |
| X | Chama azul projetada na mira; preparação de 0,22 s | 7 s |
| C | Investida de 0,7 s com contato único por alvo | 10 s |
| V | Explosão de raio 6 m após 0,45 s; cura 25% da vida máxima | 25 s |
| F | Alterna voo na forma de fênix, por até 12 s | 1 s |

No voo: WASD, W acompanha a inclinação da mira, Espaço sobe, Ctrl desce.
Parado, paira. F pousa; Z reverte. Desligar voo/forma não custa energia.
Receber dano interrompe voo/investida; morte, limpeza e troca de fruta removem a forma.
Ataques também funcionam na forma humana. V não cura além da vida máxima.

X/C/V e a duração de voo são escolhas iniciais de implementação, não valores
especificados pelo usuário. Os números de dano têm fonte única em `Balance.gd`;
a história usa a escala e os custos de `PerfilDeFrutas` (Z/F 2, X/C 3, V 5).
Voo não dá imunidade. A cápsula física continua sendo a do personagem.

Disponível na árvore da arena e no vendedor de frutas da história.
`./jogar_phoenix.sh` abre a arena com a fruta equipada, sem modificar a fruta inicial.

Fontes editáveis:
- `src/effects/phoenix/forma_phoenix.gd`: proporções, materiais, penas e animação.
- `src/effects/phoenix/geometria_phoenix.gd`: seções do corpo e fitas Bézier.
- `src/effects/phoenix/chama_phoenix.gdshader`: movimento e cores das labaredas.
- `src/player/phoenix_controller.gd`: transformação, voo e investida.
- `src/effects/phoenix/efeito_phoenix.gd`: disparo e explosão/cura.

As referências do anime foram fornecidas pelo usuário e usadas como orientação
visual; nenhum modelo externo foi importado. Capturas reais da engine em
`art_src/validation/phoenix/`, geradas por `tools/dev_tests/capturar_phoenix.gd`.
Sonda de integração: `tools/dev_tests/test_phoenix.gd`.

## Reconstrução pela nova referência — 14/10/2026

A forma completa passou a usar volumes de labaredas azuis, grandes pontas curvas
nas asas, crista e faixas douradas, cabeça afilada e cinco caudas contínuas.
As asas recolhem junto ao corpo; a pose sentada reposiciona os ombros para
preservar a folga em relação ao chão. A transição de decolagem interpola até
uma base fixa antes da batida, evitando inversão de quaternion no cotovelo.

Fontes adicionais: `src/effects/phoenix/labaredas_phoenix.gd` e
`src/effects/phoenix/plasma_phoenix.gdshader`. Exportar com o Godot do projeto:
`--headless --path . --script tools/exportar_fenix_anime.gd`.
O recurso gerado é `assets/models/phoenix/fenix_anime.scn`, usado na história
e na arena pelo mesmo controlador. Kit, dano, duração de voo e colisão preservados.

Capturas e logs: `art_src/validation/phoenix_referencia_2026-10-14/`.
Detalhes e limites: `docs/PHOENIX_REFERENCIA_CHECKPOINT.md`.
A câmera permanece com zoom manual por scroll; aproximada, pode ficar dentro
da silhueta das asas. Afastamento automático foi perguntado e não foi aplicado
sem resposta, respeitando a preferência de câmera registrada no projeto.
