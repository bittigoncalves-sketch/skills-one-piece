# Pet gaivota + comportamentos de pet + inventário N — checkpoint (30/09/2026)

Pedido do dono: gaivota **low poly** para o Modo História que **voa** e tem comportamento
próprio — só segue o jogador quando ele muda o comportamento do pet. Comportamentos para
os pets: **seguir, em guarda, agressividade, livre**, tecla **B**. Cuidado para não colidir
com a sessão que está fazendo a praia e o mar.

## Decisões do dono

- **B abre um menu** com os 4 modos (clique ou 1–4), para o **pet mais próximo**.
- **Em guarda** = fica perto do jogador e ataca inimigo que chegar a ~6 m dele.
  **Agressivo** = procura e ataca inimigo a ~15 m do jogador e volta depois.
- Os 4 modos valem **para os dois pets**; o caranguejo ganha **ataque de pinça**.
- A gaivota NÃO entra pela loja do editor: a loja vira um **vendedor** depois. Agora o pet
  mora no **inventário (tecla N)**, destinado a pets e itens de pesca.
- O personagem **já começa** com a gaivota e o caranguejo no inventário.
- O "Chamar/Recolher" do caranguejo **sai do M e vai para o N**.
- Inventário **salvo no progresso** (pets possuídos e modo de cada um).
- Aba **PESCA** vazia preparada ("nenhum item ainda").

## Decisões minhas (declaradas)

- Modo padrão: gaivota **livre**, caranguejo **seguir** (preserva o que ele fazia).
- Ao reabrir o jogo, os pets começam **guardados** (salva posse e modo, não "fora").
- "Livre": o pet fica em volta do lugar onde ficou livre (onde saiu do inventário ou onde
  estava quando recebeu a ordem).

## Anticolisão (sessão da praia/mar ativa)

Ela edita `ModoHistoria.gd` (bloco do oceano), `src/world/oceano_historia.*`, o mapa vivo e
o catálogo. Aqui: **nada** em oceano/praia/mapa/catálogo; no `ModoHistoria.gd` só o bloco
dos pets (troca curta, com a data do arquivo conferida antes). Pets são achados pelo
grupo `pets_historia`, então B e N moram na `HistoriaHud` sem passar pelo `ModoHistoria`.

## Arquivos

- novo: `tools/blender/gaivota_pet.py` → `assets/models/pets/gaivota.glb`
- novo: `src/historia/pets/gaivota.gd`, `animador_gaivota.gd`, `modo_do_pet.gd`,
  `catalogo_de_pets.gd`
- novo: `src/ui/MenuDeComportamento.gd` (B), `src/ui/InventarioDaHistoria.gd` (N)
- muda: `companhia.gd` (vários pets), `caranguejo.gd` + `animador_caranguejo.gd` (modos,
  pinça), `progressao.gd` (pets e pesca), `HistoriaHud.gd` (B, N), `JanelaDeStatus.gd`
  (tira PETS), `ModoHistoria.gd` (bloco dos pets), testes.

## Estado — CONCLUÍDO (30/09/2026, 21h)

Tudo implementado e validado. Detalhe e números em `docs/PETS.md`.
- Modelo: 326 triângulos; prévias e poses conferidas (pescoço e pontas pretas corrigidos;
  asa dobrada girada no próprio comprimento e varrida a 93° — de cima ficava uma placa).
- `test_pets_comportamento` 32/32 (novo), `test_pet_caranguejo` 24/24 (pelo N), e a
  bateria do Modo História 23/25 (as 2 falhas são as antigas: compila/studio e corte).
- `ModoHistoria.gd`: só o bloco dos pets trocado (3 linhas), com mtime conferido; o bloco
  do oceano da outra sessão ficou intacto. `MODO_HISTORIA.md` e `contexto/INDICE.md` NÃO
  foram tocados enquanto a sessão da praia os editava; o link para `docs/PETS.md` entrou no
  fechamento da praia (21h25), e o índice de contexto foi regenerado pelo gerador.
