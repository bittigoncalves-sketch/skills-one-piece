#!/usr/bin/env python3
"""Compacta um procedimento MCreator descompilado (Mine Piece v14) só para LEITURA.

Tira declarações e boilerplate, junta o som servidor/cliente numa linha e troca os nomes
ofuscados mais comuns (m_20185_ → X…). Não altera a fonte. Uso:
    python3 -I tools/mine_piece/compactar_java.py <Arquivo.java>...
"""
import re
import sys

MAPA = {
    r"entity\.m_20185_\(\)": "X", r"entity\.m_20186_\(\)": "Y", r"entity\.m_20189_\(\)": "Z",
    r"entity\.m_20206_\(\)": "H", r"entity\.m_20205_\(\)": "W",
    r"entity\.m_146908_\(\)": "YAW", r"entity\.m_146909_\(\)": "PITCH",
    r"entity\.m_20154_\(\)": "LOOK", r"entity\.m_20184_\(\)": "VEL",
    r"entity\.m_20252_\(1\.0F\)": "LOOK", r"entity\.m_20299_\(1\.0F\)": "EYE",
    r"\.m_7096_\(\)": ".x", r"\.m_7098_\(\)": ".y", r"\.m_7094_\(\)": ".z",
    r"\.f_82479_": ".x", r"\.f_82480_": ".y", r"\.f_82481_": ".z",
    r"entity\.m_6144_\(\)": "SHIFT", r"entity\.m_20096_\(\)": "ON_GROUND",
    r"entity\.m_5830_\(\)": "IN_WALL", r"entity\.m_6084_\(\)": "ALIVE",
    r"\.m_82549_": ".add", r"\.m_82490_": ".scale", r"\.m_82400_": ".inflate",
    r"\.m_82425_\(\)": ".blockPos", r"\.m_123341_\(\)": ".x", r"\.m_123342_\(\)": ".y", r"\.m_123343_\(\)": ".z",
    r"world\.m_6443_": "ENTITIES_IN", r"entity\.m_20256_": "SET_VEL", r"_ent\.m_6021_": "TP",
    r"MobEffects\.f_19597_": "SLOW", r"MobEffects\.f_19600_": "STRENGTH",
    r"entityiterator": "it",
}
RUIDO = re.compile(r"^\s*(double \w+ = 0\.0;|boolean \w+ = false;|_ent\.m_561[68]_\(.*|_ent\.f_1985[90]_ = .*|"
                   r"_entity\.f_2088[46]_ = .*|\}|if \(_ent instanceof LivingEntity _entity\) \{)$")


def compactar(texto: str) -> str:
    texto = texto[texto.find("public static"):] if "public static" in texto else texto
    texto = re.sub(r'entity\.getPersistentData\(\)\.m_128459_\("(\w+)"\)', r"D.\1", texto)
    texto = re.sub(r'entity\.getPersistentData\(\)\.m_128347_\("(\w+)",', r"D.\1 =(", texto)
    texto = re.sub(r'entity\.getPersistentData\(\)\.m_128471_\("(\w+)"\)', r"D.\1", texto)
    texto = re.sub(r'entity\.getPersistentData\(\)\.m_128379_\("(\w+)",', r"D.\1 =(", texto)
    texto = re.sub(r'entityinstance\.getPersistentData\(\)\.m_128347_\("(\w+)",', r"NEW.\1 =(", texto)
    texto = re.sub(r'entityinstance\.getPersistentData\(\)\.m_128459_\("(\w+)"\)', r"NEW.\1", texto)
    texto = re.sub(
        r'if \(world instanceof Level _level\) \{\s*if \(!_level\.m_5776_\(\)\) \{\s*_level\.m_5594_\(\s*null,\s*BlockPos\.m_274561_\(([^;]*?)\),\s*\(SoundEvent\)ForgeRegistries\.SOUND_EVENTS\.getValue\(new ResourceLocation\("([^"]+)"\)\),\s*SoundSource\.\w+,\s*([^,]+),\s*([^;]+?)\s*\);\s*\} else \{.*?\}\s*\}',
        r"SOUND(\2 @ \1 vol=\3 pitch=\4)", texto, flags=re.S)
    texto = re.sub(
        r'if \(!_ent\.m_9236_\(\)\.m_5776_\(\) && _ent\.m_20194_\(\) != null\) \{.*?"([^"]*)"\s*\);\s*\}',
        r'COMMAND("\1")', texto, flags=re.S)
    for a, b in MAPA.items():
        texto = re.sub(a, b, texto)
    return "\n".join(l.rstrip() for l in texto.splitlines() if l.strip() and not RUIDO.match(l))


if __name__ == "__main__":
    for caminho in sys.argv[1:]:
        print(f"===== {caminho.rsplit('/', 1)[-1]}")
        print(compactar(open(caminho, encoding="utf-8").read()))
