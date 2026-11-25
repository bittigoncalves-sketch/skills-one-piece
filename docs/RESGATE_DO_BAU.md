# Resgate o baú — 3ª missão (21/11/2026)

**Divisão:** Codex = planejamento, imagens, falas, grades de textura (`art_src/references/resgate_bau/`, `data/dialogos/bau.json`). Claude = código e organização.
**Pedido do dono:** missão com o Barba Negra (recompensa extra, 21/11: a **Ushi Ushi no Mi, modelo Girafa** — `ushi_ushi_giraffe`); a bússola aponta o baú; o baú é um MÍMICO; o jogador o pega ACERTANDO UM ATAQUE; o drop é o "Baú misterioso"; ao pegá-lo, fala com o Barba Negra e recebe 20 moedas + 700 XP.

## Fluxo implementado
1. Barba Negra tem o "?" da missão (`NpcDaIlha.FICHAS`, `"missao"`); a janela dele mostra a missão NO TOPO (as lojas — fruta, roleta, Geppo, dash — continuam abaixo). Só abre depois do desafio do Buggy (`depois_de: desafio_dos_copos`; vale para acerto OU erro — decisão atual, ver pendências).
2. Aceitou → `RegrasDoResgateDoBau` entra em `procurando`, o `BauMimico` nasce em `PONTO_DO_MIMICO` (194, 74; ~64 m do Barba, plano e seco — medido por varredura de raios) e a bússola ("Baú") aponta para ele.
3. Perto (5 m) o mímico se revela (tampa, dentes, língua, olhos), encara o jogador por 0,9 s e foge aos saltos (raio de 22 m; não entra na água). Fala `mimico_revela` do Codex.
4. UM golpe (qualquer dano > 0, pela `DamageZone` real ou `take_damage`) o derruba: ele estoura e solta o drop roxo "Baú misterioso" (`solto`); fala `mimico_atingido`. A bússola passa a apontar o drop.
5. Chegar a 2 m do drop o pega: o **Baú misterioso entra na MOCHILA** (item `historia:bau_misterioso`, limite 1, ícone 16×16 do Codex), missão PRONTA (1/1), bússola some. Mochila cheia: o drop fica no chão e avisa. Falar com o Barba e "Entregar": o item é **consumido** e vêm +20 moedas, +700 XP **e a fruta Ushi Ushi (Girafa) nas frutas guardadas (N › FRUTAS)**, uma vez (a tabela `Missoes` tem `"fruta"`; `ProgressaoDoPersonagem.entregar_missao` chama `receber_fruta`); sem o item na mochila a entrega recusa e nada muda.

## Arquivos
`src/historia/resgate_bau/` (`regras_do_resgate_do_bau`, `bau_mimico`, `bau_misterioso_drop`, `resgate_do_bau`), `loja_do_barba_negra.gd` (missão + lojas), `missoes.gd` (entrada `resgate_do_bau`), `bussola_hud.gd`/`HistoriaHud.ligar_bussola_de_missao(…, nome)`.
Texturas: `tools/texturas/aplicar_texturas_bau.py` (grades 16×16 → `assets/textures/resgate_bau/`). Testes: `test_resgate_do_bau` (regras + fluxo no mapa real com golpe real). Prints: `art_src/validation/resgate_bau/`.

## Decisões do dono (21/11/2026) e pendências
- **Abre após o desafio do Buggy em QUALQUER resultado** (confirmado pelo dono).
- **O Baú misterioso é item da mochila e é consumido na entrega** (confirmado pelo dono). Arquivos: `src/inventario/bau_misterioso_item.gd` + ganchos em `regras_de_itens.gd`.
- Correções após a revisão visual do Codex (#121): a tampa do mímico girava para BAIXO (sinal do eixo X) e os dentes de cima estavam no corpo, não na tampa → corrigidos; o drop era roxo liso → agora madeira + brilho discreto + ícone flutuante (`Sprite3D`).
- A "Baú raro caiu" nos prints é o aviso do sistema de baús de chefe, evento concomitante, não desta missão.
- Mímico único e fixo no ponto; `RAIO_DA_FUGA`, `VELOCIDADE`, `T_ENCARAR` em `bau_mimico.gd`. Estado local ao jogador (coop real exigiria host).
- Revisão artística final: do Codex/dono.
- Fruta da girafa: entra em `frutas_compradas` (comer pelo N › FRUTAS; só uma no corpo). Limitação já conhecida do projeto: o visual da forma Zoan ainda não está completo (memória `zoan-formas-render-no-mod`); a lógica da fruta funciona.
