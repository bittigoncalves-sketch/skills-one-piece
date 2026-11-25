"""Leitor NBT mínimo (formato de estrutura do Minecraft: gzip + TAGs big-endian).

O `rea` abre e verifica o JAR do mod, mas não interpreta NBT; este leitor cobre só o que as
estruturas usam (TAGs 1–12). Não executa nada do arquivo: é dado puro.
"""
import gzip
import struct


def ler(dados):
    """Bytes (gzip ou cru) → dict/list Python da TAG raiz."""
    if dados[:2] == b"\x1f\x8b":
        dados = gzip.decompress(dados)
    pos = 0

    def u(fmt):
        nonlocal pos
        v = struct.unpack_from(">" + fmt, dados, pos)
        pos += struct.calcsize(">" + fmt)
        return v[0]

    def texto():
        nonlocal pos
        n = u("H")
        v = dados[pos:pos + n].decode("utf-8", "replace")
        pos += n
        return v

    def carga(t):
        nonlocal pos
        if t == 1: return u("b")
        if t == 2: return u("h")
        if t == 3: return u("i")
        if t == 4: return u("q")
        if t == 5: return u("f")
        if t == 6: return u("d")
        if t == 7:
            n = u("i"); v = dados[pos:pos + n]; pos += n; return v
        if t == 8: return texto()
        if t == 9:
            et = u("b"); n = u("i"); return [carga(et) for _ in range(n)]
        if t == 10:
            d = {}
            while True:
                tt = u("b")
                if tt == 0:
                    return d
                k = texto()
                d[k] = carga(tt)
        if t == 11:
            n = u("i"); v = struct.unpack_from(">%di" % n, dados, pos); pos += 4 * n; return list(v)
        if t == 12:
            n = u("i"); v = struct.unpack_from(">%dq" % n, dados, pos); pos += 8 * n; return list(v)
        raise ValueError("TAG NBT desconhecida: %d" % t)

    t = u("b")
    texto()
    return carga(t)


def estrutura(dados):
    """Estrutura → (tamanho [x, y, z], [(x, y, z, nome, {prop: valor})])."""
    raiz = ler(dados)
    paleta = raiz.get("palette") or raiz["palettes"][0]
    estados = [(b["Name"], {k: str(v) for k, v in b.get("Properties", {}).items()}) for b in paleta]
    blocos = []
    for b in raiz["blocks"]:
        nome, props = estados[b["state"]]
        x, y, z = b["pos"]
        blocos.append((x, y, z, nome, props))
    return list(raiz["size"]), blocos
