# Como construir um asset visual

Neste projeto **quase todo VFX é procedural em GDScript**. Não há cena de efeito
pronta para instanciar: um golpe novo é código que monta malha e partícula na
hora.

Isso é decisão, não acidente — o visual acompanha o dano (mesmo nó, mesma vida) e
não existe `.tscn` para dessincronizar do código.

---

## Malha ou partícula?

**Partícula** para o que é difuso: fumaça, respingo, faísca, poeira, rastro.

**Malha** para o que precisa de **silhueta**: uma onda, uma parede, uma
rachadura, uma bala.

⚠️ **Partícula não lê como forma em movimento rápido.** A bala d'água do Karatê
Tritão viaja a 46 m/s: em partícula ela vira tracejado. Por isso a cabeça, o
núcleo e o rabo são **geometria**, e só o rastro de gotículas é partícula.

**O caso que ensina mais:** a onda da `WaterFX`. O comentário do autor vale a
leitura —

> o lábio de espuma "é a peça que faz a silhueta ler como *onda quebrando* e não
> como *muro azul* — sem ele o efeito parece um portão".

Um efeito grande não convence por tamanho; convence por **silhueta reconhecível**.

## Ferramentas que já existem — use antes de escrever as suas

`src/effects/FxUtil.gd`:

| função | para quê |
|---|---|
| `particles(qtd, vida, one_shot, proc, mesh, explosiveness)` | o emissor padrão |
| `gradient([cores])` | rampa de cor |
| `curve([pontos])` | curva de escala/velocidade |
| `particle_material(cor, emissão, aditivo)` | material de partícula |
| `grain(tamanho)` | o "grão" voxel — mantém a estética |
| `autofree(nó, t)` | limpeza por tempo |
| `damage_number(mundo, pos, valor, cor)` | número flutuante |

`src/effects/AudioFX.gd`: `whoosh`, `impact`, `hurt`, `gunshot`, `pistol`,
`sniper`, `cannon`, `minigun` — sons **gerados**, não arquivos.

⚠️ **`explosiveness` é 0..1.** Passar 2.5 não dá efeito 2,5× — o Godot grampeia.
Foi um dos bugs do V antigo da Gura.

## Cor

A cor não é escolha livre: ela **identifica** a fruta ou o estilo.

- estilos: `FightingStyles.STYLES[<id>]["cor"]` — o Karatê Tritão é azul, o
  Pacifista vermelho, o Mink amarelo;
- frutas: constantes no arquivo da fruta (`GuraFX.QUAKE`, `GuraFX.DEBRIS`).

**Leia a cor de onde ela já está declarada** em vez de escrever o valor de novo.
O corpo a corpo faz isso: `Melee.cor_do_impacto()` devolve a cor do estilo em
uso, então Pacifista sai vermelho e Mink amarelo **de graça**, sem uma linha por
estilo.

E quando precisar de um segundo tom (emissão), derive: `cor.lightened(0.15)`.
Duas cores escritas à mão podem divergir; uma derivada, não.

## Limpeza — vazamento de nó é critério de teste

Todo efeito tem que **sumir sozinho**. Três jeitos, em ordem de preferência:

1. **filho da `DamageZone`** — morre junto com ela. É o melhor: desenho e hitbox
   não têm como dessincronizar;
2. **filho de um nó dono** que se libera (o `GuraVNode` faz isso: se o golpe
   morre, não sobra hitbox invisível varrendo o mapa);
3. **`FxUtil.autofree(nó, t)`** para o que não tem dono natural.

**O critério é medido:** `test_gomu_leak` conta os nós antes e depois e exige
**delta zero**. O V novo da Gura fechou em 930 → 930.

## Posicionamento — a armadilha nº 1 de VFX

**`add_child` primeiro, `global_position` depois. Sempre.**

Fora da árvore, `global_position` escreve no transform **local**, que depois se
soma ao do pai. Três ocorrências já custaram caro (itens 21, 31, 40) — e a pior
delas fazia o clímax do V da Gura nascer na **origem do mapa** enquanto o jogador
estava noutro lugar.

⚠️ E se a sua função recebe um `parent` e cria filhos, **defina a posição
explicitamente**. `GuraFX._ring/_bubble/_debris` não definem — quem passar
`world` como pai vê o efeito no centro do mapa.

## Projétil

Use `DamageZone` com `vel`. Ela já **varre o caminho com raio** todo quadro
(`_varrer_caminho`), então bala rápida não atravessa mais o alvo — medido 10/10
em 95, 250 e 400 m/s.

⚠️ Mas o knockback dela é radial (`alvo − centro`), e em projétil rápido isso
pode empurrar o alvo **para trás, na direção do atirador** (item 26). Se a sua
zona viaja rápido e o empurrão importa, passe direção explícita.

## Ponto de saída na mão

Vários golpes saem da ponta do antebraço. O padrão está em
`GoroFXGrande._ponto_do_braco()` e `WaterFX._ponto_da_mao()`: procure `ForeArm_R`
dentro de `caster.get("_char_model")`, com plano B em
`global_position + Vector3(0, 1.05, 0)`.

⚠️ **`ForeArm_R` é a mão DIREITA desde 2026-08-14** — antes disso o rig estava
espelhado e esse mesmo código saía na mão esquerda. Se você ler código antigo que
parece trocado, é por isso.

## Verificação: número **e** olho

Número prova função; **imagem prova leitura**. As duas coisas.

Dois erros do V da Gura que **nenhuma métrica pegaria**, e que só apareceram em
captura de tela: a parede de 200 m **sumia** contra o céu claro do mapa (azul
médio demais), e o lábio de espoma inteiro virava um comprimido branco de 180 m
boiando.

Para capturar com tela: `DISPLAY=:1`.
