from pathlib import Path
import json,unreal as u
root=Path(u.Paths.project_dir())
t=u.AssetImportTask();t.filename=str(root/'Import/CoastalCliff01/coastal_cliff_01_2k.fbx');t.destination_path='/Game/Demo/Scenery/CoastalCliff01/LODSource';t.automated=True;t.save=True
opt=u.FbxImportUI();opt.import_materials=False;opt.import_textures=False;opt.import_as_skeletal=False;opt.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
opt.static_mesh_import_data.combine_meshes=False;opt.static_mesh_import_data.import_mesh_lods=False;opt.static_mesh_import_data.auto_generate_collision=False
t.options=opt
if u.EditorAssetLibrary.does_asset_exist('/Game/Demo/Scenery/CoastalCliff01/LODSource/coastal_cliff_01_LOD0'):
 paths=[f'/Game/Demo/Scenery/CoastalCliff01/LODSource/coastal_cliff_01_LOD{i}' for i in range(4)]
else:
 u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([t])
 paths=t.imported_object_paths
out=[]
for path in paths:
 m=u.load_asset(path)
 if isinstance(m,u.StaticMesh):
  b=m.get_bounding_box();out.append({'path':path,'min':[b.min.x,b.min.y,b.min.z],'max':[b.max.x,b.max.y,b.max.z]})
(root/'Docs/cliff-lod-sources.json').write_text(json.dumps(out,indent=2))
u.log('CLIFF_LOD_SOURCES '+str(out))
