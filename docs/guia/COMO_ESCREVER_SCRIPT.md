# Como escrever um script aqui

Este projeto tem estilo próprio, e ele não é decorativo — cada regra veio de um
problema real. Se você escrever no estilo, o próximo a mexer entende; se não,
ele reescreve.

---

## 1. Comentário explica o PORQUÊ, não o quê

O código já diz o quê. O comentário existe para o **motivo**, a **medição** e a
**armadilha**.

Ruim:

```gdscript
# soma a direção multiplicada pela força
_kb_impulso += direcao * forca
```

Bom (padrão real do projeto):

```gdscript
# ⚠️ POR QUE OS DOIS SOCOS LIAM IGUAL (relato do dono, medido em 2026-08-11).
# Não era clipe errado — o contraste entre os braços é enorme nos dois casos.
# Eram duas outras coisas, ambas de TEMPO:
#  1. VELOCIDADE. A 1,9x, o golpe inteiro do braço direito (0,716 s de clipe)
#     passava em 0,377 s — 23 quadros a 60 fps para 234° de braço.
```

**Padrão-ouro para copiar o tom:** o cabeçalho de `src/combat/Melee.gd` e os
comentários de `src/effects/GoroFXGrande.gd`.

Convenções de marcação já em uso: **⚠️** para armadilha, tabela markdown para
número medido, e a frase **"medido em \<data\>"** quando o número veio de sonda.

## 2. Teto de 900 linhas, e dívida exige gatilho

Nenhum script passa de 900 linhas ([`../LIMITE_DE_TAMANHO.md`](../LIMITE_DE_TAMANHO.md)).

Se você **decidir adiar** uma divisão, declare o **gatilho** que obriga a
revisitar:

```gdscript
# Gatilho para apagar: se daqui a alguns golpes nenhum tiver usado, é dívida.
```

**Dívida com gatilho é decisão. Dívida sem gatilho é esquecimento.** É regra do
dono, e ela vale para qualquer adiamento — não só tamanho de arquivo.

## 3. Fonte única para número que dois lados usam

Se dois lugares precisam do mesmo número, ele mora em **um** lugar.

**Por que isso é levado a sério aqui:** o furo de **munição infinita** (item 14)
nasceu de duas cópias da tabela de recarga escritas à mão. O conserto não foi só
tapar o buraco — foi transformar a tabela em `Player.RECARGA_POR_SLOT` e fazer os
dois lados lerem dela.

**Sintoma de que você está criando o próximo:** você acabou de digitar um número
que já viu noutro arquivo.

## 4. Dano é autoridade do servidor

- A **`DamageZone`** só aplica dano e knockback **no servidor**. Em clientes ela é
  puro enfeite.
- **VFX roda em todo mundo**; dano, não.
- A vida **não** vai num `MultiplayerSynchronizer`: ele replica **da autoridade do
  nó**, que para o corpo de um jogador é o **cliente** — isso deixaria a vida nas
  mãos dele (cliente adulterado ficaria imortal) e sobrescreveria o dano aplicado
  pelo servidor. A vida viaja por **RPC do servidor para os peers** (item 20).
- **RPC resolve por caminho de nó.** Mover um método `@rpc` de arquivo **muda o
  protocolo** — cliente e servidor param de se entender. Se for mover, mova os
  dois lados juntos.

## 5. Cada componente é dono do seu estado

O `Player` é **orquestrador**: ele pergunta aos componentes e combina. Não é ele
que calcula.

Consequência prática: `MovementController` produz `movement_velocity`,
`HealthController` produz `knockback_velocity`, e o `Player` soma. Ninguém
escreve no estado do outro.

⚠️ Ao mover um campo para um componente, leia
[`ARMADILHAS.md#7`](ARMADILHAS.md#7-a-armadilha-das-views--campo-que-vira-propriedade-de-leitura)
**antes de rodar qualquer coisa**. Transformar campo em propriedade só-leitura
quebra quem escrevia nele — **em silêncio**, e já aconteceu 4 vezes.

## 6. Tipos explícitos

`var x := algo_sem_tipo.campo` **não infere** e o script inteiro deixa de
carregar. Declare: `var x: float = algo.campo`.

Vale sempre que o lado direito vier de `get()`, de um `Node` genérico ou de um
retorno sem tipo.

## 7. Complexidade adequada

Regra do dono, e ela corta dos dois lados: nem arquitetura extensível sem
justificativa técnica, nem solução descartável que trava a expansão.

**Toda decisão relevante declara seis coisas:** benefício imediato, impacto
futuro, facilidade de manutenção, facilidade de extensão, custo de implementação,
riscos conhecidos.

Um exemplo real e barato de acertar isso: a flag `"desabilitado"` do Karatê
Tritão. Um `if estilo == "karate_tritao" and slot == "V"` resolveria hoje pelo
mesmo custo — e cobraria código novo no dia em que outro estilo quisesse 3
golpes. A flag mora nos **dados**, onde o resto da definição do golpe já mora.
Genérico pelo mesmo preço; não mais caro.

## 8. Antes de dizer que terminou

1. `./validar.sh rapido` — **25 testes**, tem que fechar 0 falhas.
2. Criou `class_name`? `./checar_cache.sh`.
3. Moveu campo? o `grep` da armadilha 7.
4. **Número, não adjetivo.** "Melhorou" não fecha tarefa. "6/6 acertos, 930 → 930
   nós, delta 0" fecha.
5. Achou bug fora do escopo? **`LISTA_DE_CORRECOES.md`, com como foi detectado.**
   Não conserte de passagem — o dono decide.
