# A regra: estados, ataque, defesa, aparo, riposte e finta

Os números citados aqui são os do boxe (`estilos/boxe.tres`) e servem de exemplo: a
regra é a mesma para qualquer estilo, só os valores mudam.

## Máquina de estados

```
                    ┌──────── clique ────────┐
                    ▼                        │
   NEUTRO ──RMB──► GUARDA ──clique──► PREPARO ──► ATIVO ──► RECUPERAÇÃO ──► NEUTRO
     ▲   ◄─solta── BAIXANDO ◄─solta──┘   │          │            │  ▲
     │                 ▲                 │          │            │  └── guarda pedida
     │                 │            finta│          │contato     │      (≥60% da recuperação)
     │                 └────────── finta p/ guarda  │            │
     │                                              ▼            ▼
     └──── fim ── REAÇÃO ◄── apanhou ── (qualquer estado, menos ATIVO)
     └──── fim ── QUEBRA ◄── postura zerada ao bloquear
     └──── fim ── REBATIDO ◄── seu golpe foi aparado
```

- **ATIVO não é interrompido por acerto**: os dois trocam dano (o choque de golpes,
  V3, fica para depois). Nos outros estados o tranco vence a intenção. Vale igual para
  jogador e boneco: o `take_damage` do Player atordoa em todo dano, e o golpe que levou
  o acerto no ATIVO ignora esse atordoamento até acabar — só trava dura (derrubado,
  congelado, morto) o derruba. Até 21/09 o golpe do jogador caía no quadro seguinte.
- **QUEBRA, REBATIDO e REAÇÃO** não atacam nem erguem guarda enquanto duram.
- A guarda é uma **intenção** (`_guarda_pedida`), não um evento: com o RMB segurado,
  ela volta sozinha assim que o estado deixa (fim do golpe, fim de BAIXANDO, fim da
  reação, 60% da recuperação). Abrir menu segurando o botão derruba a guarda de
  propósito — a UI engoliria o evento de soltar e a guarda ficaria presa.

## Ataque

1. `pedir_ataque(direcao)` aceita em NEUTRO, GUARDA e BAIXANDO. Da guarda se ataca
   direto: o preparo do golpe já é o custo de largá-la.
2. **PREPARO** → **ATIVO** → **RECUPERAÇÃO**, tudo pela ficha. No ATIVO, a cada quadro
   de física, uma varredura liga a posição do punho do quadro anterior à de agora
   (`SwordSweep.contacts`) — a hitbox segue a ANIMAÇÃO, não um timer, e cada alvo só
   é atingido uma vez por ação.
3. O contato resolve ANTES do dano (ver "Defesa"), e o dano sai pelo
   `CombatResolver`.
4. **Buffer**: um clique nos últimos `buffer` segundos (0,30 s no boxe) fica guardado e
   sai quando a ação acaba. Só UM clique é guardado, e só nessa janela: clicar antes é
   descartado — é isso que impede o spam de render golpe. Sofrer (acerto, quebra,
   rebote) descarta o que estava guardado.
5. **A guarda não encurta o golpe.** A guarda pode interromper a recuperação a partir
   de 60% dela — para DEFENDER mais cedo, não para atacar mais cedo. O que faltava da
   recuperação continua correndo; até acabar, o clique de ataque segue a regra do
   buffer. (Sem isso, atacar com o RMB segurado era sempre melhor: o ciclo do jab caía
   de 0,68 s para 0,567 s — ver `docs/erros.md`, 17/09.)

## Movimento e giro

Cada fase tem seu multiplicador de velocidade e seu teto de giro do corpo (na ficha do
golpe): anda-se devagar no preparo, quase nada no ativo, e o corpo não pode girar o
golpe atrás do alvo — no ATIVO o teto é baixo de propósito. Em guarda anda-se a ×0,55;
na quebra, ×0,3. O `avanco` do golpe é um empurrão para a frente somado à velocidade
entre metade do preparo e o fim do ativo, e ele PARA quando o golpe conecta.

## Defesa

Com a guarda erguida, um golpe que chega resolve nesta ordem
(`ResolucaoDeContato.resolver`):

| condição | resultado |
|---|---|
| sem guarda, ou fora do cone (120° à frente) | **ACERTO** (dano, reação pelo lado) |
| aparando (janela aberta) e golpe `aparavel` | **APARO** |
| postura − `dano_de_postura` ≤ 0 | **QUEBRA_DE_GUARDA** |
| caso contrário | **BLOQUEIO** (sem dano, postura cai, tranco na pose) |

- **Postura** é a resistência da guarda (100 no boxe), sem barra na tela (decisão do
  dono; aparece no painel F10). Regenera 25/s depois de 1 s sem bloquear.
- **Quebra**: sem guarda e sem ataque por `duracao_da_quebra`; sai com
  `postura_apos_quebra`. Não causa dano — o castigo é o próximo golpe entrar.
- **Lado do impacto** sai da GEOMETRIA: o vetor de viagem do golpe no espaço do
  defensor decide frente/esquerda/direita; atacante atrás (cos < −0,35) é COSTAS.
  Golpe pesado usa a reação pesada, venha de onde vier.

## Aparo, rebote e riposte

- A **janela de aparo** (0,20 s) conta de um **aperto novo** do RMB. A guarda que volta
  sozinha com o botão segurado não apara — senão segurar o botão apararia tudo.
- Soltar e reapertar não burla: a guarda passa por BAIXANDO (0,20 s), e quando ela sobe
  a janela já venceu.
- Quem apara não perde vida nem postura. Quem foi aparado vai para **REBATIDO**
  (0,15 s, golpe desfeito).
- Depois do aparo abre a **janela de riposte** (0,6 s): o próximo golpe sai com o
  preparo multiplicado por `fator_de_riposte` (0,6). Riposte não finta e usa a janela
  uma vez.
- **Riposte não é dano garantido**: o rebote (0,15 s) é menor que o preparo do riposte
  mais rápido (0,18 s), e quem foi aparado ainda pode erguer a guarda a tempo — medido.

## Finta

- Um clique novo em OUTRA direção, ou um aperto novo do RMB, nos primeiros 60% do
  preparo, troca o golpe (ou volta para a guarda).
- Custa postura (10) e é **uma por ataque** — inclusive pela guarda: um golpe iniciado
  antes do fim do preparo fintado herda a finta. Sem isso, RMB→LMB reiniciava o golpe
  e a "uma por ataque" virava "uma a cada 10 de postura".
- Nunca se finta com menos de `finta_minimo_restante` (0,12 s) de preparo pela frente:
  a leitura do adversário precisa ter chance de acontecer.

## Invariantes (cobrados nos DADOS, em `EstiloCorpoACorpo.validar()`)

1. **A quebra tem de render um acerto, com qualquer golpe**:
   `duracao_da_quebra > max(ativo + recuperação) + preparo mais rápido + 0,10`.
2. **O rebote não pode garantir o riposte**:
   `duracao_rebatido < preparo mais rápido × fator_de_riposte`.
3. **O hitstun não pode prender o alvo**: por golpe,
   `hitstun < recuperação + preparo mais rápido`.
4. Uma direção, exatamente um golpe; toda ficha precisa de chave no ATIVO, efetor,
   dano de postura, cone, postura, tempos de quebra e de baixar a guarda, e das poses
   de guarda, tranco, quebra, aparo, rebatido e das 5 reações.

Quebrar qualquer uma delas faz `validar()` reprovar a ficha, e os testes reprovam
junto — inclusive com sabotagens que provam que a checagem sabe reprovar.
