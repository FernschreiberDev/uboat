"""Use the artist's four alternative LODs, never merged overlapping geometry."""
from pathlib import Path
import json,unreal as u
folder='/Game/Demo/Scenery/CoastalCliff01'
s=u.get_editor_subsystem(u.StaticMeshEditorSubsystem)
source=u.load_asset(folder+'/LODSource/coastal_cliff_01_LOD0')
path=folder+'/CoastalCliffRuntime'
mesh=u.load_asset(path) if u.EditorAssetLibrary.does_asset_exist(path) else u.EditorAssetLibrary.duplicate_asset(source.get_path_name(),path)
assert isinstance(mesh,u.StaticMesh)
for i in range(1,4):
 lod=u.load_asset(folder+'/LODSource/coastal_cliff_01_LOD'+str(i))
 assert s.set_lod_from_static_mesh(mesh,i,lod,0,True)==i
mesh.set_material(0,u.load_asset(folder+'/CoastalCliffSurface'))
assert s.set_lod_screen_sizes(mesh,[1.0,0.4,0.16,0.055])
u.EditorAssetLibrary.save_loaded_asset(mesh)
result={'mesh':mesh.get_path_name(),'lod_count':mesh.get_num_lods(),'vertices_per_lod':[s.get_number_verts(mesh,i) for i in range(mesh.get_num_lods())]}
(Path(u.Paths.project_dir())/'Docs/coast-outcrop-lods.json').write_text(json.dumps(result,indent=2))
u.log('COAST_OUTCROP_LODS '+str(result))
