"""Split exported geometry without dropping/duplicating any face; centre each joint."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]/'Import/Articulated'
joints=json.loads((root/'joints.json').read_text());joints['Hull']={'pivot':[0,0,0]}
vs=[];ts=[];ns=[];groups={};group=None;mat=None
for line in (root/'VIIC.obj').read_text().splitlines():
 p=line.split()
 if not p:continue
 if p[0]=='o':group=p[1].split('_Part_')[0];groups.setdefault(group,[])
 elif p[0]=='v':vs.append(tuple(map(float,p[1:])))
 elif p[0]=='vt':ts.append(p[1:])
 elif p[0]=='vn':ns.append(p[1:])
 elif p[0]=='usemtl':mat=p[1]
 elif p[0]=='f':groups[group].append((mat,[tuple(int(i)-1 for i in v.split('/')) for v in p[1:]]))
assert len(groups)==7 and set(groups)==set(joints)
for name,faces in groups.items():
 pivot=joints[name]['pivot'];out=['mtllib VIIC.mtl','o '+name];remap={};verts=[];uvs=[];norms=[];body=[];last=None
 for material,face in faces:
  if material!=last:body.append('usemtl '+material);last=material
  indices=[]
  for key in face:
   if key not in remap:
    remap[key]=len(remap)+1
    v=vs[key[0]];verts.append('v '+' '.join(str(v[i]-pivot[i]) for i in range(3)))
    uvs.append('vt '+' '.join(ts[key[1]]));norms.append('vn '+' '.join(ns[key[2]]))
   i=remap[key];indices.append(f'{i}/{i}/{i}')
  body.append('f '+' '.join(indices))
 (root/(name+'.obj')).write_text('\n'.join(out+verts+uvs+norms+body)+'\n')
 joints[name]['triangles']=len(faces)
 joints[name]['pivot_cm']=[-pivot[2]*100,pivot[0]*100,pivot[1]*100]
print('Split:',{k:v['triangles'] for k,v in joints.items()})
assert sum(x['triangles'] for x in joints.values())==sum(1 for l in (root/'VIIC.obj').read_text().splitlines() if l.startswith('f '))
(root/'joints.json').write_text(json.dumps(joints,indent=2))
# Runtime table generated from the actual pivots, not from bounding-box centres.
h=Path(__file__).resolve().parents[1]/'Source/NordatlantikDemo/GearPivots.inl'
h.write_text('\n'.join('AddGear(TEXT("%s"),FVector(%s));'%(name,','.join(map(str,joints[name]['pivot_cm']))) for name in ['Hull','propellerPort','propellerStarboard','rudderPort','rudderStarboard','bowPlanes','sternPlanes'])+'\n')
