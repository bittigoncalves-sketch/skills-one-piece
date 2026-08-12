# Auditoria da Fase 6 — `SkillController`

**Medido em 2026-08-12**, antes de mover qualquer código. É o preparo da fase
mais pesada da partição descrita em [`ARQUITETURA_PLAYER.md`](ARQUITETURA_PLAYER.md):
o relatório original mediu **505 linhas e 24 métodos** neste domínio, o maior de
todos.

**Nada foi alterado.** Este documento existe para que a execução seja uma passada
limpa, e não uma investigação com o arquivo já quebrado no meio.

---

## 1. Duas restrições que já estão decididas

### `current_fruit_id` NÃO pode sair do `Player`

`Main.gd:119` replica por caminho de nó:

```gdscript
for p in ["position", "net_velocity", "net_facing", "net_on_floor", "current_fruit_id"]:
	cfg.add_property(NodePath(".:" + p))
```

O `MultiplayerSynchronizer` **escreve** essa propriedade nos peers que recebem.
Duas consequências:

- uma **vista só-leitura** (o padrão das fases 3 e 5) quebraria a replicação —
  sem setter, o synchronizer não consegue atribuir;
- um `RefCounted` **não pode ser alvo de `NodePath`**.

Portanto `current_fruit_id` continua sendo `var` comum no Player. O alerta do
plano ("se `current_fruit_id` migrar, edite o `Main.gd`") **não se aplica**
enquanto o componente for `RefCounted`.

### Os `@rpc` ficam no `Player` — decidido na Fase 5

O canal de bala (`_net_bullet_req` → `_do_server_bullet` → `_net_bullet_play`)
é **compartilhado por três mecânicas**. Mover qualquer um deles muda o caminho
de rede de todas.

---

## 2. O canal de bala é o coração do risco

```
        rajada Z (Mera/Hie)  ─┐
        pistola da Yami      ─┼─→ _request_bullet ─→ _net_bullet_req
        Buki Buki            ─┘                          ↓
                                                  _do_server_bullet
                                          (aqui mora a autorização da Buki)
                                                          ↓
                                                  _net_bullet_play
```

⚠️ **A autorização de munição da Buki vive dentro de `_do_server_bullet`** —
`_buki.servidor_autoriza_tiro(arma)`. Ela foi consertada em 2026-08-12 (era
munição infinita). Qualquer mexida no canal tem que provar que a Buki continua
de pé.

**A rede de segurança que já existe para isso:** as sondas
`net_buki_host_probe.gd` / `net_buki_client_probe.gd`, de dois processos.
Elas exercitam o canal ponta a ponta e medem quantas `DamageZone` nascem no
servidor. Rodar as duas é obrigatório em qualquer passo da Fase 6 que encoste no
canal de bala.

---

## 3. Mapa de estado, medido

| campo | usos no `Player.gd` | outros arquivos | observação |
|---|---|---|---|
| `combat_mode` | 25 | 3 | `Hud.gd`, `AmmoHud.gd` leem |
| `_charging` | 16 | 5 | o mais espalhado |
| `_rapid_fire` | 15 | 3 | |
| `_yami_pistol_active` | 14 | 0 | **contido**, mas lido em 12 portões |
| `is_suppressed` | 9 | 2 | `FireFXGrande.gd` lê |
| `_charge_slot` | 8 | 2 | |
| `energy` | 7 | 4 | `StatsHud.gd`, `GomuArm.gd` leem |
| `_movement_locked_timer` | 6 | 3 | |
| `_cast_token`, `_rapid_t`, `_yami_shot_cooldown` | 5 cada | 0 | **contidos** |
| `_rapid_count` | 4 | 0 | **contido** |
| `suppression_timer` | 4 | 0 | **contido** |

### O que isso quer dizer

**Contidos (saem fáceis):** `_cast_token`, `_rapid_count`, `_rapid_t`,
`_yami_shot_cooldown`, `suppression_timer`.

**Espalhados (exigem cuidado):** `combat_mode`, `_charging`, `energy`,
`is_suppressed` — todos lidos por HUD ou VFX de fora. Viram **vistas
só-leitura** no Player, como `_char_model` na Fase 3.

**Caso à parte — `energy`:** o relatório original já a marcava como campo de
**três domínios** (regenera no ciclo, é gasta pelas skills, é restaurada no
respawn). Ela é candidata natural da **Fase 8** (`HealthController`), não da 6.
Mover na 6 seria puxar a 8 para dentro.

**Caso à parte — `_yami_pistol_active`:** zero uso fora do `Player.gd`, mas é
lido em **12 portões** internos (`_slot_em_uso`, portões do soco em 389/395,
visibilidade da pistola em 583, bloqueio do dash em 682, portões de cast em
1085/1174, reset do `equip_fruit` em 1547). Extrair é mecânico, mas toca muita
linha — não é o "pedaço fácil" que a contagem sugere.

---

## 4. Ordem sugerida, em passos validáveis um a um

A fase é grande demais para uma tacada só. Cada passo abaixo é **completo,
validável e commitável sozinho** — o repositório nunca fica quebrado entre eles.

| passo | o que sai | por que nesta ordem | como validar |
|---|---|---|---|
| **6a** | ✅ **feito** — a rajada Z e a pistola da Yami viraram `DisparoSustentado` (`src/player/disparo_sustentado.gd`, 154 linhas). Player 1.689 → **1.644** | ver nota abaixo | bateria 16/16 + sondas da Buki (11 zonas, 7 checagens) |
| ~~6b~~ | absorvido pelo 6a — ver nota | | |
| **6c** | ✅ **feito** — `CastController` (`src/player/cast_controller.gd`, 168 linhas). Player 1.644 → **1.592** | ver nota abaixo | bateria 16/16 + sonda de cast **idêntica à linha de base** + sonda da Buki |
| **6d** | ✅ **feito** — a SUPRESSÃO foi para o `CastController`. `combat_mode` **ficou no Player**, e a razão está na nota | ver nota | bateria 16/16 + sonda de cast idêntica |

`energy` **fica para a Fase 8**, com `HealthController`.

---

## 5. Armadilha específica desta fase

O acoplamento escondido já cobrado neste projeto foi exatamente aqui: alguém
removeu um `_request_cast(slot)` achando que "isto só atira", e a linha
carregava **duas outras coisas de carona** — gravar o estado autoritativo da
Buki e mostrar a arma no rig. Resultado medido: sniper cheia, 5 balas, **0
`DamageZone`**.

O gêmeo desse acoplamento **continua vivo e documentado** em `_do_server_cast`,
que também grava `_srv_buki_arma`/`_srv_buki_municao` (hoje via
`_buki.servidor_sacar`). Está morto pelo caminho de input, mas alcançável pelo
RPC `_net_cast` vindo de um cliente. **Não apague sem substituir.**

> Regra que saiu daquele episódio: *remover chamada é tão perigoso quanto
> adicionar, quando ela tem efeito colateral.*

---

## 6. O que esta auditoria NÃO cobre

- ~~Não existe sonda de rede para o canal de cast.~~ ✅ **Feita** em 2026-08-12:
  `net_cast_host_probe.gd` / `net_cast_client_probe.gd`. Linha de base medida
  **antes** de refatorar (é o que a torna útil): o cliente conjura os 4 slots da
  Mera Mera e o processo do host registra **20 `DamageZone` do cliente** e vida
  caindo **2048,0 → 2036,3**.
- Nada aqui foi visto **na tela**.
- Não medi o custo em linhas de cada passo — só a ordem e o risco.

---

## Nota de execução do 6a — o plano estava errado, e por quê

O plano dizia: *"6a = extrair o estado **contido** (`_cast_token`, `_rapid_*`,
`_yami_shot_cooldown`, `suppression_timer`)"*, e o 6b viria depois com as
mecânicas.

**Isso era refatoração de fachada.** Timers soltos não formam componente
coerente: o resultado seria um arquivo sem responsabilidade própria, e as
mecânicas continuariam espalhadas no Player lendo os timers de fora — trocando
um acoplamento por dois.

O corte que se sustenta é **por mecânica**. A rajada Z e a pistola da Yami não
são vizinhas por acaso: dividem o canal de bala, pedem bala pelo mesmo caminho e
usam a mesma pistola do rig. Separá-las criaria dois donos para o mesmo pedido.

Então **6a e 6b viraram um passo só**, e o estado veio junto com quem o usa.
`_cast_token` e `suppression_timer` ficam para o 6c, com o cast.

### Medido antes de mover
`_rapid_fire`, `_rapid_count`, `_rapid_t`, `_yami_pistol_active`,
`_yami_shot_cooldown` e `_bullet_side`: **zero uso fora do `Player.gd`**.

### Pedidos novos no Player
`gastar_energia` (a `energy` é da Fase 8), `pedir_bala_simples` (o canal de rede
fica no Player) e `aplicar_mira`.

O `aplicar_mira` recebe `forca_corpo` como parâmetro **de propósito**: a Yami
vira o corpo em 20 e abre o pitch em ±1,3; a Buki vira em 14 e trava em
−1,2..0,5. Reaproveitar o `mirar_suave_para` da Fase 5 teria mudado os dois
números em silêncio.

### O que a rede de segurança pegou
A bateria acusou **regressão de física** logo na primeira rodada, no quadro
**342** — exatamente onde o traço liga a rajada. Causa: o traço escrevia
`p._rapid_fire = true`, e o campo virou **vista sem setter**. É a mesma
armadilha da Fase 5 (`_buki_scope`), e vale registrar o padrão:

> **Toda vez que um campo vira vista só-leitura, algum teste que escrevia nele
> passa a falhar em silêncio.** O traço não falha em silêncio — por isso ele
> existe.

---

## Nota de execução do 6c

`src/player/cast_controller.gd`, 168 linhas. O `Player.gd` foi de 1.644 para
**1.592**.

### A fronteira: decidir ≠ executar

```
CastController  →  decide, valida, mira
Player          →  fala rede (`_net_cast`), cria a hitbox (`_do_server_cast`)
                   e apresenta (`_fire_skill`)
```

`_do_server_cast`, `_fire_skill` e `_generic_vfx` **ficaram no Player** de
propósito: são o lado servidor e a apresentação, colados nos `@rpc`. O que se
moveu foi a **decisão**.

### Por que `comecar()` continua uma pilha de casos

Parece remendo, e não é: cada caso é uma **regra de jogo** diferente — a Buki
empunha em vez de lançar, o Yami Z é toggle, o Yami C exige solo, a rajada Z não
congela o corpo. Espalhar isso em cinco arquivos esconderia a **ordem** em que as
regras se aplicam, que é justamente o que importa ali.

### Pedidos novos no Player

`mira_do_cast` (depende da câmera e do corpo), `pedir_cast_no_servidor` (a rede
fica no Player), `congelar_para_cast` (a `velocity` é do movimento),
`pausar_animacao` (o animador é do rig), `guardar_pistola_da_yami` (as pistolas
são do `PlayerRig`), `pedir_soco_de_fov` e `estilo_atual`.

### A prova

A sonda de cast foi rodada **antes** da refatoração para virar linha de base, e
depois de novo. Resultado **idêntico**:

| | zonas do cliente | danos | vida do host |
|---|---|---|---|
| antes | 20 | `6.0`×16, `45.0`×2, `65.0`, `104.0` | 2048,0 → 2036,3 |
| depois | 20 | idem | 2048,0 → 2036,3 |

Mais a sonda da Buki (canal de bala compartilhado): 11 zonas, 7 checagens, sem
recarga indevida de pente.

### A armadilha das vistas pegou de novo — em DOIS testes

`_charging` e `_charge_slot` viraram vistas só-leitura, e dois testes escreviam
neles: `test_frutas.gd:83` (que está **na bateria**) e `net_bugs_client.gd`.
Sem correção, o `test_frutas` passaria a falhar em silêncio.

É a **terceira** vez que isso acontece (Fase 5: `_buki_scope`; 6a:
`_rapid_fire`). Já é regra:

> Ao transformar um campo em vista só-leitura, **procure quem escrevia nele**
> antes de rodar qualquer coisa:
> `grep -rn "_campo\s*=" --include=*.gd src/ tools/`

---

## Nota de execução do 6d — `combat_mode` NÃO saiu, e por quê

O plano mandava transformar `combat_mode` em vista sobre o componente de
habilidades. **Medindo antes de mover, isso se mostrou errado.**

`combat_mode` é escrito pelo `toggle_combat_mode()` (tecla R), pela troca de
personagem e pelo `equip_fruit`; e é lido pela **HUD** (`Hud.update_combat_mode`,
`AmmoHud`), pelo **corpo a corpo**, pela **Buki** (`_buki_ativa`) e pelo cast.

Ou seja: é o **seletor de modo que o sistema de combate inteiro consulta**, não
estado de habilidade. Pô-lo dentro do `CastController` faria o componente do
cast ser dono de algo que o estilo, a Buki e a HUD dependem — exatamente o
antipadrão que esta refatoração combate.

**Ele fica no Player**, que é onde estado global de fato mora.

### O que saiu: a supressão

`is_suppressed` + `suppression_timer` + o tique + `suppress_skills_temporarily`.
Esse sim é do domínio: quem liga é um golpe, quem consulta são os portões de
cast. Viraram `_suprimido`/`_suprimido_t` no `CastController`, com
`suprimir()` e `tick_silencio()`.

Os portões internos do componente passaram a ler o **próprio** estado
(`_suprimido`) em vez de voltar ao Player — que era o objetivo.

### Achado no caminho, na lista sem correção

`FireFXGrande.gd:185/234` faz `set_meta("is_suppressed", ...)`, e **ninguém lê
esse metadado**. Não quebra o recurso (a supressão real vem da chamada
`suppress_skills_temporarily` logo abaixo), mas é código morto que confunde.
Item 13 da lista.

### Estado da Fase 6

| passo | estado |
|---|---|
| 6a | ✅ `DisparoSustentado` |
| 6b | absorvido pelo 6a |
| 6c | ✅ `CastController` |
| 6d | ✅ supressão movida; `combat_mode` fica |

`Player.gd`: **1.689 → 1.590**. `energy` segue reservada para a Fase 8.
