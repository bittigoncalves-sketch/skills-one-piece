"""Clipes aditivos editáveis, radianos por papel do ProceduralAnimator.
Regerar: python3 art_src/alimentacao/gerar_animacoes.py.
"""
from pathlib import Path
OUT=Path(__file__).resolve().parents[2]/'assets/animations/alimentacao'
# Preparação, contato, mordida/goles, recuperação. Pernas seguem a locomoção.
for name,length,times,poses in [
('comer',1.9,[0,.20,.53,.72,.91,1.12,1.42,1.9],{
'UpperArm_R':[(.15,0,.08),(.45,0,.25),(1.08,.56,-.97),(1.10,.56,-.97),(1.04,.56,-.95),(1.08,.56,-.97),(.45,0,.20),(.15,0,.08)],
'ForeArm_R':[(.35,0,0),(.9,0,0),(1.62,0,0),(1.64,0,0),(1.57,0,0),(1.62,0,0),(.9,0,0),(.35,0,0)],
'Head':[(0,0,0),(0,0,0),(-.09,.06,0),(-.14,.06,0),(-.08,.06,0),(-.12,.06,0),(-.03,0,0),(0,0,0)],
'UpperArm_L':[(0,0,0),(.18,0,-.06),(.28,0,-.10),(.28,0,-.10),(.28,0,-.10),(.28,0,-.10),(.15,0,0),(0,0,0)]}),
('beber',2.2,[0,.25,.58,.85,1.12,1.38,1.70,2.2],{
'UpperArm_R':[(.15,0,.08),(.55,0,.23),(1.58,1.18,.20),(1.61,1.18,.20),(1.59,1.18,.20),(1.61,1.18,.20),(.65,0,.25),(.15,0,.08)],
'ForeArm_R':[(.35,0,0),(1.0,0,0),(.81,0,0),(.83,0,0),(.80,0,0),(.83,0,0),(1.2,0,0),(.35,0,0)],
'Head':[(0,0,0),(0,0,0),(.10,.05,0),(.19,.05,0),(.16,.05,0),(.19,.05,0),(.02,0,0),(0,0,0)],
'UpperArm_L':[(0,0,0),(.15,0,-.06),(.22,0,-.10),(.22,0,-.10),(.22,0,-.10),(.22,0,-.10),(.12,0,0),(0,0,0)]})]:
    out=['[gd_resource type="Animation" format=3]','','[resource]',f'resource_name = "{name}"',f'length = {length}']
    for i,(role,values) in enumerate(poses.items()):
        vec=', '.join('Vector3(%s)'%', '.join(map(str,v)) for v in values)
        out.extend([f'tracks/{i}/type = "value"',f'tracks/{i}/path = NodePath("{role}:rotation")',f'tracks/{i}/interp = 2',f'tracks/{i}/keys = {{"times": PackedFloat32Array({", ".join(map(str,times))}), "transitions": PackedFloat32Array({", ".join(["1"]*len(times))}), "update": 0, "values": [{vec}]}}'])
    (OUT/(name+'.tres')).write_text('\n'.join(out)+'\n')
