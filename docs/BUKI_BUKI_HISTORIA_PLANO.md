# Buki Buki no modo história — plano (21/11/2026)

Pedido do dono: adaptar ao modo história; animações da fruta junto com o walk/run; refazer com estilo artístico de FPS nos ataques; imagens e planejamento com o Codex.
Decisões (dono, 21/11): estética FPS **na câmera atual** (3ª pessoa); imagens: **Buki Buki completa primeiro**.

## Estado encontrado
Hoje a Buki roda no modo história como "fruta da arena na escala da história" (`PerfilDeFrutas.da_arena`): arsenal Z pistola/X canhão/C sniper/V minigun em `BukiFX.ARSENAL`,
estado em `src/player/buki_controller.gd`, pose de arma em `Player._pose_de_arma`. Não há ficha Mine Piece, poses próprias nem visual FPS.

## Entregas
1. (feito) Anti-lag do V: bala viva 0,8 s e enfeite a cada 3 tiros (`BukiFX.ARSENAL.V.vida/efeito_cada`; `test_buki_minigun_vida`).
2. Adaptação: medir no `ModoHistoria` (dano em inimigos da história, energia, HUD de munição, barra de itens) — teste de integração.
3. Poses com walk/run: braço de arma sobre o torso, pernas seguem a locomoção (camadas), sem congelar o corpo.
4. VFX FPS: clarão, traçante, estojos, impacto por material, marcador de acerto, recuo — em `BukiFX`/`BukiProjeteis`, guiados pelas imagens do Codex.
5. Armas modeladas a partir das folhas do Codex (Blender headless).
Imagens: ver `art_src/references/buki_buki_codex/LEIA-ME.md`.
Gatilho: demais frutas só depois da aprovação visual da Buki.

## Estado 21/11 (noite)
Feito: poses por arma (`ProceduralAnimator._buki_pose`), HUD (munição/luneta/marcador), minigun e canhão X modelados da folha do Codex (`BukiFX._voxel_minigun/_voxel_canhao_codex`), `AJUSTE_NA_MAO`; capturas em `art_src/validation/buki_historia_2026-11-21/`.
Pendente: pistola Z (Codex: filtro de violência recusou; reformular o pedido), poses Z/X, impactos, marcador, luneta, HUD de munição (imagens); aprovação visual em movimento; demais frutas (decisão: só depois da Buki).
