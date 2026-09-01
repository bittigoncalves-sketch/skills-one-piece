# Hospedar para fora da rede de casa

**Última revisão:** 2026-08-31.
**Para quê:** deixar alguém de outro lugar entrar numa partida em que ESTA
máquina é o servidor.

---

## O que já existia, e o que faltava

O jogo já hospeda (`GameFlow.create_room`) e já é encontrado por quem está na
mesma rede (`network/LanDiscovery.gd`). O ID da sala — sete letras — é o IP do
host codificado em base32 (`GameFlow.encode_room_id`).

O problema é que esse IP é o **local**, `192.168.x.x`. Ele não existe fora da
casa: um amigo de outra cidade recebia um código válido para um endereço
inalcançável.

Faltavam duas coisas, e as duas estão em `network/ExposicaoPublica.gd`:

1. **o roteador precisa deixar passar** — um pedido que chega da internet na
   porta 24565 bate no roteador, não no PC. UPnP pede ao próprio roteador que
   encaminhe a porta para esta máquina;
2. **o ID precisa carregar o IP público** — `query_external_address()` pergunta
   ao roteador qual é o endereço dele visto de fora.

---

## Como usar

```gdscript
GameFlow.create_room_publica()
```

A sala **já está no ar** antes de o roteador responder: ninguém espera o UPnP
para começar a jogar em casa. Quando a resposta chega, o sinal
`sala_publica_pronta(ok, id_publico, motivo)` avisa, e o `room_id` passa a ser o
código do IP público.

Ao encerrar:

```gdscript
GameFlow.fechar_sala_publica()
```

⚠️ **Feche.** O mapeamento é criado como permanente (duração 0) para não cair no
meio de uma partida longa — e permanente que ninguém remove fica no roteador
depois que o jogo sai. A próxima pessoa a usar a rede herda uma porta aberta sem
saber disso.

---

## Antes de tudo: o diagnóstico

```bash
godot --headless --path . -s tools/dev_tests/diag_rede_publica.gd
```

Ele **só pergunta, não mexe** — nenhuma porta é aberta. Responde três coisas: se
o roteador fala UPnP, se ele aceita encaminhar portas, e qual é o endereço
externo.

Nesta máquina, em 2026-08-31, o diagnóstico passou: o roteador respondeu em
~2,1 s, aceitou encaminhar, e o endereço externo é **público de verdade** — não
há CGNAT no caminho. `test_sala_publica.gd` confirmou a abertura ponta a ponta.

### Os três resultados possíveis

| o que aparece | o que significa | a saída |
|---|---|---|
| `discover` falhou | o roteador não tem UPnP, ou está desligado nele | ligar UPnP nas configurações do roteador, **ou** encaminhar a porta 24565 à mão (UDP, e de preferência TCP junto) para o IP local desta máquina |
| gateway inválido | ele fala UPnP mas não encaminha portas | encaminhar à mão |
| endereço externo **privado** (`100.64.x`, `10.x`, `192.168.x`) | **CGNAT**: a operadora está entre você e a internet | abrir a porta no seu roteador **não resolve** — o pedido do amigo nem chega nele. Pedir IP público à operadora, ou usar um túnel/VPN |

---

## Detalhes que custaram medição

**O ID só é trocado se a porta abrir.** Um ID com IP público e porta fechada é
pior que um de LAN: o amigo digita, espera, e o erro não diz nada sobre a porta.
Quando o UPnP falha, a sala continua valendo na LAN e o motivo é dito em voz
alta.

**Apagar antes de criar.** `add_port_mapping` **falha** quando já existe
mapeamento para aquela porta — e existe sempre que a sala foi aberta antes e o
jogo não chegou a fechá-la (fechou pela janela, travou, caiu a luz). Medido: a
primeira abertura deu certo, a segunda voltou `ok=false` com a porta já aberta e
funcionando. Por isso o mapeamento antigo é removido antes.

**Em outra thread.** `UPNP.discover()` é bloqueante e leva de 1 a 4 segundos.
Na thread principal, o jogo congelaria ao criar a sala.

---

## O que isto NÃO faz

- não protege a partida: quem tiver o código entra. Não há senha nem lista de
  permitidos;
- não resolve CGNAT — nenhum código resolve, é assunto da operadora;
- não mexe no firewall do sistema. Verificado em 2026-08-31: `ufw` e
  `firewalld` estão **inativos** nesta máquina, então não há nada a liberar. Se
  algum for ligado depois, a porta 24565/UDP precisa ser aberta nele também.
