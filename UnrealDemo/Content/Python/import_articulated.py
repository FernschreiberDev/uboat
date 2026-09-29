"""Import new visual-only meshes. Never save a world or a shared original asset."""
from pathlib import Path
import json,unreal as u
root=Path(u.Paths.project_dir());src=root/'Import/Articulated'
joints=json.loads((src/'joints.json').read_text());assets=u.AssetToolsHelpers.get_asset_tools();report={}
for name,info in joints.items():
 task=u.AssetImportTask();task.filename=str(src/(name+'.obj'));task.destination_path='/Game/Voyage/Articulated';task.destination_name=name
 task.automated=True;task.replace_existing=True;task.save=False
 opt=u.FbxImportUI();opt.import_mesh=True;opt.import_materials=False;opt.import_textures=False;opt.import_as_skeletal=False;opt.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
 data=opt.static_mesh_import_data;data.combine_meshes=True;data.import_uniform_scale=100.;data.convert_scene=True;data.import_rotation=u.Rotator(roll=90,pitch=0,yaw=90);data.auto_generate_collision=False
 task.options=opt;assets.import_asset_tasks([task]);mesh=u.load_asset('/Game/Voyage/Articulated/'+name);assert mesh
 for i,entry in enumerate(mesh.static_materials):
  mat=u.load_asset('/Game/Demo/Materials/Naval_'+str(entry.material_slot_name));assert mat, str(entry.material_slot_name)
  mesh.set_material(i,mat)
 assert info['triangles']*.9 <= mesh.get_num_triangles(0) <= info['triangles'], name
 u.EditorAssetLibrary.save_loaded_asset(mesh)
 b=mesh.get_bounding_box()
 verts=[list(map(float,l.split()[1:])) for l in (src/(name+'.obj')).read_text().splitlines() if l.startswith('v ')]
 converted=[[-v[2]*100,v[0]*100,v[1]*100] for v in verts]
 lo=[min(v[i] for v in converted) for i in range(3)];hi=[max(v[i] for v in converted) for i in range(3)]
 assert max(abs(a-b) for a,b in zip(lo+hi,[b.min.x,b.min.y,b.min.z,b.max.x,b.max.y,b.max.z]))<.5, (name,lo,hi,str(b))
 report[name]={'triangles':mesh.get_num_triangles(0),'min':[b.min.x,b.min.y,b.min.z],'max':[b.max.x,b.max.y,b.max.z],'pivot_cm':info['pivot_cm']}
(root/'Docs/articulated-import.json').write_text(json.dumps(report,indent=2));u.log('ARTICULATED_IMPORT_PASS')
