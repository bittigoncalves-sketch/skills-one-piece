"""Mede o que o mod Mine Piece (v14, Forge 1.20.1) pede do MINECRAFT — 23/10/2026.

Pedido do dono: "usar o rea para analisar o mod mine piece e implementar por completo ao jogo,
primeiro medindo o que o skills one piece ainda precisa ou necessita simular do minecraft para que
o mod funcione".

Lê as fontes descompiladas (mesmo SHA-256 do JAR, conferido pelo REA) e conta, para cada SISTEMA
do Minecraft, quantos arquivos do mod dependem dele e em que domínio (fruta, haki, estilo, raid,
navio, NPC...). Não executa nada do mod. Saída: JSON (dados) + tabela no terminal.

    python3 -I tools/mine_piece/medir_dependencias_minecraft.py [--fontes DIR] [--saida ARQ.json]
"""
import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from srg_oficial import mapa, traduzir     # o JAR chama o Minecraft por SRG (m_20256_)

FONTES = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/net/mcreator/minepiece")

# Sistema do Minecraft → padrões no código (Java descompilado do MCreator/Forge).
SISTEMAS = {
    "comandos (execute/summon/particle em texto)": r"performPrefixedCommand|getCommands\(\)\.perform|Commands\.",
    "blocos: ler/trocar/destruir": r"setBlock\(|getBlockState\(|destroyBlock\(|removeBlock\(|BlockPos",
    "entidades: invocar": r"addFreshEntity|\.spawn\(\(ServerLevel|EntityType\.[A-Z_]+\.create|ModEntities\.[A-Z_]+\.get\(\)\.spawn",
    "entidades: busca em área": r"getEntitiesOfClass|getEntities\(|AABB",
    "projéteis": r"AbstractArrow|Projectile|shoot\(|ThrowableItemProjectile",
    "dano e fontes de dano": r"\.hurt\(|damageSources|DamageSource|DamageTypes",
    "efeitos de poção": r"MobEffectInstance|addEffect\(|hasEffect\(|removeEffect\(",
    "atributos (vida, força, velocidade)": r"Attributes\.|getAttribute\(|AttributeModifier",
    "variáveis do jogador (capability)": r"MinepieceModVariables|PlayerVariables",
    "NBT / dados persistentes": r"getPersistentData\(\)|CompoundTag|getOrCreateTag",
    "movimento e teleporte": r"setDeltaMovement|teleportTo|moveTo\(|hurtMarked|push\(",
    "explosões": r"\.explode\(",
    "partículas": r"sendParticles|addParticle|ParticleTypes|ModParticleTypes",
    "sons": r"playSound|playLocalSound|SoundEvent",
    "itens e inventário": r"ItemStack|getInventory\(\)|getMainHandItem|getItemBySlot|addItem\(|shrink\(",
    "recarga de item (cooldown)": r"getCooldowns\(\)",
    "tempo e agendamento (ticks)": r"queueServerWork|MinepieceMod\.queue|getGameTime\(\)|tickCount",
    "raycast / mira": r"\.clip\(|ClipContext|HitResult|pick\(",
    "água e fluidos": r"isInWater|isInWaterOrBubble|FluidState|Fluids\.",
    "montaria / veículo": r"startRiding|getVehicle\(\)|isPassenger|ejectPassengers",
    "conquistas (advancements)": r"Advancement|getAdvancements\(\)|award\(",
    "placar / tags de entidade": r"getScoreboard|addTag\(|getTags\(\)",
    "fome e comida": r"getFoodData|FoodProperties",
    "tempo do mundo / clima": r"getDayTime|setDayTime|isRaining|setWeather",
    "dimensões e mundo gerado": r"ResourceKey<Level>|changeDimension|Level\.OVERWORLD|StructureTemplate|placeInWorld",
    "rede (pacotes cliente/servidor)": r"PacketHandler|SimpleChannel|NetworkEvent|PacketDistributor",
    "teclas (keybinds)": r"KeyMapping|KeyBinding|keyMappings",
    "telas / HUD (GUI)": r"Screen|Overlay|GuiGraphics|RenderGuiEvent|Menu\b",
    "animação GeckoLib": r"software\.bernie\.geckolib|GeoEntity|AnimationController|RawAnimation",
    "animação do jogador (playerAnimator)": r"dev\.kosmx|PlayerAnimation|ModifierLayer|KeyframeAnimation",
    "IA de mob (goals/pathfinding)": r"goalSelector|targetSelector|Goal\b|PathNavigation|MeleeAttackGoal",
    "comércio (villager trades)": r"MerchantOffer|VillagerTrades|ItemListing",
    "dificuldade / gamerules": r"getDifficulty|GameRules",
}

# O QUE exatamente se usa de cada sistema (arquivos por nome).
DETALHES = {
    "efeitos vanilla": r"(?<![A-Za-z])MobEffects\.([A-Z_]+)",
    "efeitos do mod": r"MinepieceModMobEffects\.([A-Z_0-9]+)",
    "atributos": r"Attributes\.([A-Z_]+)",
    "blocos colocados/lidos": r"Blocks\.([A-Z_]+)",
    "partículas vanilla": r"ParticleTypes\.([A-Z_]+)",
    "partículas do mod": r"MinepieceModParticleTypes\.([A-Z_0-9]+)",
    "entidades do mod invocadas": r"MinepieceModEntities\.([A-Z_0-9]+)",
    "tipos de dano": r"DamageTypes\.([A-Z_]+)",
}

DOMINIOS = [  # (rótulo, padrão no NOME do arquivo/pasta), na ordem de prioridade
    ("raid", r"raid"), ("navio", r"ship|boat|sail|cannon"), ("haki", r"haki|haoshoku|kenbunshoku|busoshoku"),
    ("estilo de luta", r"rokushiki|soru|geppo|tekkai|shigan|rankyaku|blackleg|fishman|sword|santoryu|style"),
    ("fruta", r"devil|fruit|gomu|mera|hie|goro|pika|moku|suna|yami|magu|gura|ope|bara|bomu|nikyu|hana|kage|"
              r"doku|horo|mochi|ito|zushi|nikyu|sube|supa|baku|toshi|bari|giro|mero|hito|zou|tori|inu|neko|ushi|"
              r"logia|zoan|paramecia"),
    ("NPC / mob", r"entity|marine|pirate|bandit|villager|npc|boss|kaido|whitebeard|akainu|shanks|luffy"),
    ("item / equipamento", r"item|armor|weapon|gun|katana|blade"),
    ("mundo / estrutura", r"structure|biome|world|island|dimension|feature"),
    ("progressão", r"bounty|level|grade|advancement|exp|fame|quest|mission"),
]


def _variaveis_do_jogador(fontes: str) -> list:
    """Campos da PlayerVariables (o estado do jogador que o mod guarda e sincroniza)."""
    arq = os.path.join(fontes, "network", "MinepieceModVariables.java")
    texto = open(arq, encoding="utf-8", errors="replace").read()
    i = texto.find("class PlayerVariables")
    return sorted(set(re.findall(r"public (?:double|boolean|String|int|ItemStack|float) (\w+)", texto[i:])))


def dominio(caminho: str) -> str:
    nome = os.path.basename(caminho).lower()
    for rotulo, padrao in DOMINIOS:
        if re.search(padrao, nome):
            return rotulo
    return "outro"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fontes", default=FONTES)
    ap.add_argument("--saida", default="")
    args = ap.parse_args()
    regex = {s: re.compile(p) for s, p in SISTEMAS.items()}
    detalhes = {k: collections.Counter() for k in DETALHES}
    detalhes["comandos em texto (1ª palavra)"] = collections.Counter()
    detalhes["variáveis do jogador (capability)"] = collections.Counter()
    variaveis = _variaveis_do_jogador(args.fontes)
    srg = mapa()
    chamadas = collections.Counter()            # método oficial do Minecraft → arquivos que chamam
    por_sistema = {s: collections.Counter() for s in SISTEMAS}
    arquivos_por_pacote = collections.Counter()
    total = 0
    for raiz, _, nomes in os.walk(args.fontes):
        for nome in nomes:
            if not nome.endswith(".java"):
                continue
            caminho = os.path.join(raiz, nome)
            pacote = os.path.relpath(raiz, args.fontes).split(os.sep)[0]
            arquivos_por_pacote[pacote] += 1
            total += 1
            bruto = open(caminho, encoding="utf-8", errors="replace").read()
            for nome_srg in set(re.findall(r"\bm_\d+_\b", bruto)):
                chamadas[srg.get(nome_srg, nome_srg).split("|")[0]] += 1
            texto = traduzir(bruto, srg)
            dom = dominio(caminho)
            cmds = set()
            for m in re.finditer(r"performPrefixedCommand", texto):
                achado = re.search(r'\)\s*,\s*"/?([^"]+)"', texto[m.end():m.end() + 1500])
                if achado:
                    linha = achado.group(1)
                    if linha.startswith("execute") and " run " in linha:
                        linha = linha.split(" run ", 1)[1]
                    cmds.add(linha.split()[0] if linha.split() else linha)
            for c in cmds:
                detalhes["comandos em texto (1ª palavra)"][c] += 1
            if "PlayerVariables" in texto:
                for v in variaveis:
                    if re.search(r"\." + v + r"\b", texto):
                        detalhes["variáveis do jogador (capability)"][v] += 1
            for k, padrao in DETALHES.items():
                for achado in set(re.findall(padrao, texto)):
                    detalhes[k][achado if isinstance(achado, str) else achado[0]] += 1
            for s, r in regex.items():
                if r.search(texto):
                    por_sistema[s][dom] += 1
    resultado = {
        "fontes": args.fontes, "arquivos_java": total, "por_pacote": dict(arquivos_por_pacote),
        "sistemas": {s: {"arquivos": sum(c.values()), "por_dominio": dict(c.most_common())} for s, c in por_sistema.items()},
        "metodos_minecraft": dict(chamadas.most_common()),
        "detalhes": {k: dict(c.most_common()) for k, c in detalhes.items()},
    }
    print(f"{total} arquivos .java  ({', '.join(f'{k} {v}' for k, v in arquivos_por_pacote.most_common())})\n")
    print(f"{'arquivos':>8}  sistema do Minecraft  [domínios principais]")
    for s, dados in sorted(resultado["sistemas"].items(), key=lambda x: -x[1]["arquivos"]):
        doms = ", ".join(f"{k} {v}" for k, v in list(dados["por_dominio"].items())[:4])
        print(f"{dados['arquivos']:8d}  {s}  [{doms}]")
    print("\nmétodos do Minecraft mais chamados (arquivos):")
    print("  " + ", ".join(f"{k} {v}" for k, v in chamadas.most_common(70)))
    for k, c in detalhes.items():
        print(f"\n{k} ({len(c)} distintos):")
        print("  " + ", ".join(f"{n} {v}" for n, v in c.most_common(40)))
    if args.saida:
        json.dump(resultado, open(args.saida, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
