"""Read-only asset contracts and real exported normals. No Godot/editor/network.
Run after generator: python3 tools/audit_bara_assets.py
"""
from pathlib import Path
import json, struct, math, wave, hashlib, xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]; FOLDER=ROOT/'assets/models/bara_bara'
manifest=json.loads((FOLDER/'manifest.json').read_text());report={};checks=0

def check(ok,message):
    global checks
    if not ok:raise AssertionError(message)
    checks+=1

def load_glb(path):
    data=path.read_bytes();magic,version,length=struct.unpack_from('<III',data)
    check(magic==0x46546c67 and version==2 and length==len(data),path.name+' GLB header')
    size=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+size]);offset=20+size
    bsize,btype=struct.unpack_from('<II',data,offset);binary=data[offset+8:offset+8+bsize]
    check(btype==0x004e4942 and len(binary)==bsize,path.name+' BIN chunk')
    return doc,binary,data

def values(doc,binary,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    code={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    fmt='<'+code*count;size=struct.calcsize(fmt);stride=view.get('byteStride',size)
    offset=view.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from(fmt,binary,offset+i*stride) for i in range(a['count'])]

for name in ['bara_bara_fruit','cannon','buggy_ball']:
    path=FOLDER/(name+'.glb');doc,binary,raw=load_glb(path);expected=manifest[name]
    check(len(raw)==expected['bytes'],name+' recorded bytes')
    check(len(doc['meshes'])==expected['meshes'],name+' mesh count')
    check(all(not any(k in node for k in ['translation','rotation','scale','matrix']) for node in doc['nodes']),name+' baked transforms')
    verts=[];triangles=0;outer=[];inner=[]
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            pos=values(doc,binary,p['attributes']['POSITION']);norm=values(doc,binary,p['attributes']['NORMAL']);verts.extend(pos)
            check(all(all(math.isfinite(x) for x in v) for v in pos+norm),name+' finite geometry')
            check(all(abs(sum(x*x for x in n)-1)<.01 for n in norm),name+' normalized normals')
            triangles+=doc['accessors'][p['indices']]['count']//3
            material=doc['materials'][p['material']]['name']
            if name=='cannon':
                for v,n in zip(pos,norm):
                    radius=math.hypot(v[0],v[1]-.69)
                    dot=(v[0]*n[0]+(v[1]-.69)*n[1])/max(radius,.001)
                    if 'blued cast iron' in material and -.16<v[2]<.31 and .19<radius<.26:outer.append(dot)
                    if 'soot inside' in material and -.845<v[2]<-.835 and .14<radius<.18:inner.append(dot)
    check(triangles==expected['triangles'],name+' triangle count')
    actual_min=[min(v[i] for v in verts) for i in range(3)];actual_max=[max(v[i] for v in verts) for i in range(3)]
    check(all(abs(actual_min[i]-expected['godot_min'][i])<1e-5 and abs(actual_max[i]-expected['godot_max'][i])<1e-5 for i in range(3)),name+' recorded bounds')
    check(all('bufferView' in im and 'uri' not in im for im in doc.get('images',[])),name+' embedded texture contract')
    row={'sha256':hashlib.sha256(raw).hexdigest(),'triangles':triangles,'meshes':len(doc['meshes']),'surfaces':sum(len(m['primitives']) for m in doc['meshes']),'images_embedded':len(doc.get('images',[])),'bytes':len(raw),'godot_min':actual_min,'godot_max':actual_max}
    if name=='cannon':
        check({n['name'] for n in doc['nodes']}=={'Barrel','Carriage'},'cannon recoil node contract')
        # A wrong winding reverses these independently measured exported radial normals.
        check(len(outer)>0 and min(outer)>.90,'barrel exterior normals outward')
        check(len(inner)>0 and max(inner)<-.90,'barrel bore normals inward')
        row['outer_radial_normal_min']=min(outer);row['inner_radial_normal_max']=max(inner)
    report[name]=row
for name in ['punch','pincer','cannon','festival']:
    root=ET.parse(ROOT/'assets/ui/bara_bara'/f'{name}.svg').getroot()
    check(root.attrib['viewBox']=='0 0 64 64',name+' icon viewport')
for name in ['split','shot','impact','return','blast']:
    path=ROOT/'assets/audio'/f'bara_{name}.wav'
    with wave.open(str(path),'rb') as f:
        check((f.getnchannels(),f.getsampwidth(),f.getframerate())==(1,2,48000),name+' WAV format')
        samples=struct.unpack('<%dh'%f.getnframes(),f.readframes(f.getnframes()))
    check(samples[0]==0 and abs(samples[-1])<50,name+' click-free edges')
    check(max(abs(s) for s in samples)<32767,name+' no clipping')
report['checks_passed']=checks
report['source_sha256']=hashlib.sha256((ROOT/'tools/blender/bara_bara_assets.py').read_bytes()).hexdigest()
output=ROOT/'art_src/bara_bara/asset_audit.json';output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
