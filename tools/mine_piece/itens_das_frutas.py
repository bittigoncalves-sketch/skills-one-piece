"""Levantamento estático (10/11/2026): que ITENS cada fruta do Mine Piece v14 usa ou entrega.
Para cada fruta segue as rotas de `DevilFruitSkill1Procedure` e o fecho transitivo de `XProcedure.execute(`, e anota
MinepieceModItems.*, Items.* (SRG), ItemEntity, shrink, giveItem. Muito ruído é comum a todas (armas citadas por checagens
gerais): filtrar o que aparece em >= 20 frutas. Uso: python3 -I tools/mine_piece/itens_das_frutas.py [saida.json]"""
import sys, re, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import inventariar_frutas as inv
from pathlib import Path
F=inv.FONTE; cat=inv.inventariar(F)
proc=F/inv.JAVA/"procedures"
def fecho(ini):
    vis=set(); pil=list(ini)
    while pil:
        p=pil.pop()
        if p in vis or not (proc/f"{p}.java").exists(): continue
        vis.add(p)
        pil+=inv.CHAMADA.findall((proc/f"{p}.java").read_text())
    return vis
pad={'mod':r"MinepieceModItems\.(\w+)\.get",'vanilla':r"\bItems\.(f_\d+_)",'itementity':r"new ItemEntity",'shrink':r"m_41774_\(",'additem':r"m_36356_\(|m_150109_\(\)\.m_6836_|m_19983_",'tag':r"ItemTags\.(\w+)",'loot':r"LootTable|loot"}
out={}
for f in cat['frutas']:
    ini=set()
    for r in f['rotas']: ini|=set(r['procedimentos'])
    fc=fecho(ini)
    ach={}
    for p in fc:
        t=(proc/f"{p}.java").read_text()
        for k,rx in pad.items():
            m=re.findall(rx,t)
            if m: ach.setdefault(k,{}).setdefault(p,sorted(set(m)) if m and isinstance(m[0],str) and m[0] else len(m))
    out[f['id']]=(len(fc),ach)
for k,(n,a) in out.items():
    print(k,n,{kk:len(v) for kk,v in a.items()})
if len(sys.argv)>1: Path(sys.argv[1]).write_text(json.dumps({k:v[1] for k,v in out.items()},indent=1))
