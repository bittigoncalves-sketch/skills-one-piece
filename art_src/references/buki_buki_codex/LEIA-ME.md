# Buki Buki (modo história) — briefing de imagens para o Codex (21/11/2026)

Pedido do dono: refazer a Buki Buki no modo história com **estilo artístico de FPS** nos ataques (clarão de cano, traçantes, estojos, recuo, marcador de acerto, HUD de munição),
animações da fruta combinadas com walk/run. Produção do Codex: **Buki Buki completa primeiro**; as demais frutas entram depois, em lotes, pelo mesmo fluxo.

Fluxo (igual à customização): Codex gera PNG aqui, avisa por mensagem; Claude implementa no Godot. Cada um edita só a sua parte.
Estilo: boneco/mundo voxel estilo Minecraft (como o resto do jogo), fundo cinza liso neutro, sem texto, luz de estúdio. Sem sangue.

## Armas (folha de modelo: 3 vistas — frente, lado, 3/4 — cada)
| arquivo | conteúdo |
|---|---|
| `arma_z_pistola.png` | pistola de mão, cano curto, empunhada pelo antebraço direito (a arma "cresce" do braço) |
| `arma_x_canhao.png` | o corpo inteiro vira canhão (jogador encolhido dentro do cano/obus), 3 vistas |
| `arma_c_sniper.png` | fuzil de precisão + luneta, braço direito vira o fuzil |
| `arma_v_minigun.png` | minigun de 6 canos giratórios + tambor de munição |

## Poses do personagem (corpo voxel cinza, 4 vistas: frente, lado, costas, 3/4; mesma arma de cima)
Para CADA arma (Z, X, C, V): `pose_<arma>_empunhar` (saque), `pose_<arma>_mira` (parado mirando), `pose_<arma>_andar` (andando mirando, torso estável, pernas em passo),
`pose_<arma>_correr` (correndo com a arma baixa/ao lado, inclinação à frente), `pose_<arma>_atirar` (frame de disparo com recuo), `pose_<arma>_recarga` (arma some/recarga do slot).
Total 4 armas × 6 poses = 24 imagens. Prioridade: mira, andar, correr, atirar.

## Efeitos (estilo FPS — folha por efeito, vários quadros em sequência)
`vfx_clarao_cano_<z|x|c|v>.png` (4–6 quadros), `vfx_tracante_<z|c|v>.png`, `vfx_estojo_ejetado.png`, `vfx_impacto_<concreto|terra|madeira|inimigo>.png`,
`vfx_marcador_de_acerto.png` (X no retículo: normal, crítico, abate), `vfx_fumaca_cano.png`, `vfx_obus_explosao_x.png`, `vfx_luneta_sniper.png` (retículo).

## HUD
`hud_municao_<z|x|c|v>.png` (contador + ícone da arma, 4 estados: cheio/baixo/vazio/recarga), `hud_reticulo.png` (espalhamento por arma), `icone_fruta_buki_buki.png` (128×128).

## Entrega
PNGs em `art_src/references/buki_buki_codex/`; nomes exatos acima. Avise por mensagem a cada lote (prioridade: armas → poses de mira/andar/correr/atirar → vfx → hud).
Claude lê, modela as armas no Blender headless (`tools/blender/`), implementa poses/VFX no Godot e valida com testes.
