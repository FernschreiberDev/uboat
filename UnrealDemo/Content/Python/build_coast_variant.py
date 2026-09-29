"""Create a scenery variant in the full rendering editor. Source boat/waves preserved."""
from pathlib import Path
import json
import unreal as u
ROOT=Path(u.Paths.project_dir()).resolve()
SOURCE='/Game/Demo/AtlanticDemo'
DEST='/Game/Demo/AtlanticCoast'
assets=u.AssetToolsHelpers.get_asset_tools()
mel=u.MaterialEditingLibrary
if (ROOT/'Docs'/'coast-variant-validation.json').exists():
    raise RuntimeError('Variant completed; refusing to overwrite it')
if not u.EditorAssetLibrary.does_asset_exist(DEST):
    if not u.EditorAssetLibrary.duplicate_asset(SOURCE,DEST):
        raise RuntimeError('Cannot duplicate source level')
level=u.get_editor_subsystem(u.LevelEditorSubsystem)
if not level.load_level(DEST): raise RuntimeError('Cannot open copied level')
actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
boat=next(a for a in actors if a.get_actor_label().startswith('VIIC'))
def boat_state():
    comp=boat.static_mesh_component
    body=comp.get_editor_property('body_instance')
    loc=boat.get_actor_location();rot=boat.get_actor_rotation()
    return dict(mesh=comp.static_mesh.get_path_name(),position=[loc.x,loc.y,loc.z],
                rotation=[rot.roll,rot.pitch,rot.yaw],mass=body.mass_in_kg_override,
                physics=body.simulate_physics,
                buoyancy=[c.get_class().get_path_name() for c in boat.get_components_by_class(u.BuoyancyComponent)])
before=boat_state()
task=u.AssetImportTask()
task.filename=str(ROOT/'Import'/'AtlanticCliffs.obj')
task.destination_path='/Game/Demo/Scenery'
task.destination_name='AtlanticCliffs'
task.automated=True;task.save=True;task.replace_existing=True
options=u.FbxImportUI()
options.import_materials=False; options.import_textures=False
options.import_as_skeletal=False
options.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
options.static_mesh_import_data.combine_meshes=True
options.static_mesh_import_data.import_uniform_scale=100.0
options.static_mesh_import_data.import_rotation=u.Rotator(roll=90,pitch=0,yaw=0)
options.static_mesh_import_data.auto_generate_collision=False
task.options=options
assets.import_asset_tasks([task])
mesh=u.load_asset('/Game/Demo/Scenery/AtlanticCliffs')
if not isinstance(mesh,u.StaticMesh): raise RuntimeError('Cliff import failed')
box=mesh.get_bounding_box()
if box.max.z-box.min.z>30000 or box.max.x-box.min.x<150000:
    raise RuntimeError('Unexpected cliff axes: '+str(box))

mat=assets.create_asset('StratifiedCoast','/Game/Demo/Scenery',u.Material,u.MaterialFactoryNew())
def expr(cls,x,y): return mel.create_material_expression(mat,cls,x,y)
pos=expr(u.MaterialExpressionWorldPosition,-900,0)
normal=expr(u.MaterialExpressionVertexNormalWS,-900,200)
macro=expr(u.MaterialExpressionNoise,-650,300)
macro.set_editor_property('scale',0.0008);macro.set_editor_property('levels',3)
fine=expr(u.MaterialExpressionNoise,-650,500)
fine.set_editor_property('scale',0.025);fine.set_editor_property('levels',2)
mel.connect_material_expressions(pos,'',macro,'Position')
mel.connect_material_expressions(pos,'',fine,'Position')
shade=expr(u.MaterialExpressionCustom,-300,0)
shade.set_editor_property('output_type',u.CustomMaterialOutputType.CMOT_FLOAT3)
shade.set_editor_property('description','Rock strata, damp shoreline, sparse turf by slope')
inputs=[]
for name in ['W','N','Macro','Fine']:
    i=u.CustomInput();i.set_editor_property('input_name',name);inputs.append(i)
shade.set_editor_property('inputs',inputs)
shade.set_editor_property('code', '''
float layer=0.5+0.5*sin(W.z*0.012 + W.x*0.0012 + Macro*4.0);
float grain=saturate(Fine)*0.12;
float3 rock=lerp(float3(0.052,0.058,0.060),float3(0.14,0.135,0.12),saturate(0.55*Macro+0.24*layer+grain));
float turf=saturate((N.z-0.66)*4.3)*saturate((W.z-700.0)/1800.0)*saturate(Macro*1.4-0.12);
float3 moss=lerp(float3(0.035,0.048,0.019),float3(0.09,0.105,0.035),saturate(Macro));
float wet=1.0-saturate((W.z-25.0)/220.0);
return lerp(rock,moss,turf)*(1.0-0.5*wet);
''')
for src,pin in [(pos,'W'),(normal,'N'),(macro,'Macro'),(fine,'Fine')]:
    mel.connect_material_expressions(src,'',shade,pin)
mel.connect_material_property(shade,'',u.MaterialProperty.MP_BASE_COLOR)
rough=expr(u.MaterialExpressionCustom,-300,400)
rough.set_editor_property('output_type',u.CustomMaterialOutputType.CMOT_FLOAT1)
inp=u.CustomInput();inp.set_editor_property('input_name','W');rough.set_editor_property('inputs',[inp])
rough.set_editor_property('code','return lerp(0.36,0.92,saturate((W.z-25.0)/220.0));')
mel.connect_material_expressions(pos,'',rough,'W')
mel.connect_material_property(rough,'',u.MaterialProperty.MP_ROUGHNESS)
mel.recompile_material(mat)
land=next(a for a in actors if a.get_actor_label().startswith('Côte'))
land.static_mesh_component.set_static_mesh(mesh)
land.set_actor_rotation(u.Rotator(roll=0,pitch=0,yaw=0),False)
land.static_mesh_component.set_material(0,mat)
# Visual terrain only, consistent with the user's existing offshore buoyancy setup.
land.static_mesh_component.set_collision_enabled(u.CollisionEnabled.NO_COLLISION)
land.set_actor_label('Côte — falaises et végétation rase')
u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(-5500,-7000,1250),u.Rotator(pitch=-7,yaw=52,roll=0))
# Duplicated worlds need their explicit ocean-to-zone soft reference retargeted.
zone=next(a for a in actors if isinstance(a,u.WaterZone))
ocean=next(a for a in actors if isinstance(a,u.WaterBodyOcean))
ocean.water_body_component.set_water_zone_override(zone)
after=boat_state()
if before!=after: raise RuntimeError('Boat state unexpectedly changed')
level.save_current_level()
u.EditorAssetLibrary.save_directory('/Game/Demo/Scenery')
import runpy
runpy.run_path(str(ROOT/'Content/Python/refine_coast_material.py'))
runpy.run_path(str(ROOT/'Content/Python/repair_coast_water.py'))
(ROOT/'Docs'/'coast-variant-validation.json').write_text(json.dumps(dict(source=SOURCE,variant=DEST,boat_unchanged=True,boat=after),indent=2))
u.log('COAST_VARIANT_COMPLETE')
