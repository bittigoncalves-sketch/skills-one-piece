# Pet caranguejo — 30/09/2026

Pedido: modo história, categoria pets do editor, spawn por M, seguir jogador lateralmente, idle/walk/run/jump e bolhas ocasionais nas garras. Direção confirmada: aparência natural com carapaça detalhada.

Implementado:
- Fonte Blender autoral + GLB (34.904 triângulos, ~4,10 × 1,48 × 3,10 m). Oito patas articuladas, carapaça moteada/relevo, garras curvas, marcadores de emissão.
- `src/historia/pets/`: companhia, física, rig procedural e bolhas. Animação lê medidas de repouso do GLB; marcha usa distância realmente percorrida.
- `ModoHistoria.gd`: liga companhia, menu e peças do mapa.
- `JanelaDeStatus.gd`: M → PETS → Chamar/Recolher; ambos cabem em 1280×720. Sem F8.
- `mapas/modelos/catalogo.json` + GLB: categoria pets, comportamento pet_caranguejo. Todos os outros itens/categorias preservados (comparação JSON exata).
- `tools/importar_caranguejo_na_loja.gd`: registro reproduzível; `tools/blender/caranguejo_pet.py`: fonte canônica de geometria.

Validação final:
- 24 verificações do pet passaram: spawn por M, não duplicar, pivôs, walk/run/idle, marcha lateral (alinhamento mínimo 1,000 em reta), salto (2,61 m), pouso, emissão periódica, limpeza, mudança de eixo, recuperação após respawn, parede, recusa sem chão, conversão da peça, escala, recolher.
- Capturas reais no Godot Forward+ 4.6.3, RTX 3050, compositor Weston isolado: `art_src/pets/menu.png`, `pet.png`. Log visual em `art_src/pets/validacao/`; os avisos de decoração e mouse sem ponteiro são do compositor de teste. Nenhum SCRIPT ERROR na execução final do pet.
- Testes de editor, loja, modo história, progressão e HUD de vida/energia passaram na checagem final da área.
- Compilação: somente os seis scripts do projeto separado `tools/anim_editor/studio/` falham, como já documentado em PROJECT_CONTEXT; nenhum script do pet falha.
- Bateria geral iniciada durante o desenvolvimento: 97 passaram, 10 falharam, 5 pulados. Oito falhas coincidem com a dívida documentada; sala pública falhou por UPnP do roteador (código 27). A décima, Rocket história, encontrou um erro transitório de tipagem do pet já corrigido; rerun final passou em 50 s (log `art_src/pets/validacao/rocket.log`).
- `tools/contexto/indice.py verificar`: ok, com avisos de contextos antigos já existentes.

Limites: invocação por sessão; sem navegação global/navmesh (desvio local e recuperação em chão livre após bloqueio prolongado). Peças no “Testar” do editor continuam estáticas, como os outros comportamentos existentes; ativam ao carregar a história. Exportação não validada. Mapa e progresso pessoais não foram editados.

Estado: implementação e validação concluídas. Sem commit. Fotografias e logs acima permitem revisão; snapshots dos arquivos de integração anteriores estão em `/tmp/sop-caranguejo/antes/`.

Atualização (30/09/2026, noite, sessão da gaivota): a pedido do dono, Chamar/Recolher saiu
do M e foi para o inventário **N** (Tirar/Guardar); o caranguejo ganhou os comportamentos
do menu **B** (livre, seguir, em guarda, agressivo) e o ataque de pinça. Teste atualizado
(24/24 pelo N). Ver `docs/PETS.md`.
