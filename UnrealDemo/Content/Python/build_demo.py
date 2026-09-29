"""Run from Unreal's Tools > Execute Python Script. Builds only /Game/Demo.
Refuses to overwrite an existing level, so subsequent artistic edits are safe.
"""
from pathlib import Path
import unreal as u

ROOT = Path(u.Paths.project_dir()).resolve()
LEVEL = '/Game/Demo/AtlanticDemo'
assets = u.AssetToolsHelpers.get_asset_tools()
actors = u.get_editor_subsystem(u.EditorActorSubsystem)
levels = u.get_editor_subsystem(u.LevelEditorSubsystem)
if (ROOT / 'Saved' / 'demo-built.txt').exists():
    raise RuntimeError('Atlantic already exists: open the saved level instead of rebuilding it.')

def spawn(cls, name, pos=(0,0,0), rot=(0,0,0)):
    actor = actors.spawn_actor_from_class(cls, u.Vector(*pos), u.Rotator(pitch=rot[0],yaw=rot[1],roll=rot[2]))
    actor.set_actor_label(name)
    return actor

def import_mesh(filename, name):
    existing = u.load_asset('/Game/Demo/Meshes/' + name)
    if isinstance(existing, u.StaticMesh):
        return existing
    task = u.AssetImportTask()
    task.filename = str(ROOT / 'Import' / filename)
    task.destination_path = '/Game/Demo/Meshes'
    task.destination_name = name
    task.automated = True
    task.save = True
    options = u.FbxImportUI()
    options.import_mesh = True
    options.import_materials = True
    options.import_textures = True
    options.import_as_skeletal = False
    options.mesh_type_to_import = u.FBXImportType.FBXIT_STATIC_MESH
    options.static_mesh_import_data.combine_meshes = True
    options.static_mesh_import_data.import_uniform_scale = 100.0
    options.static_mesh_import_data.convert_scene = True
    task.options = options
    assets.import_asset_tasks([task])
    meshes = [u.load_asset(p) for p in task.imported_object_paths]
    mesh = next((m for m in meshes if isinstance(m,u.StaticMesh)), None)
    if mesh is None:
        raise RuntimeError('Import failed: '+filename)
    return mesh

submarine = import_mesh('VIIC.obj','VIIC')
coast = import_mesh('Coast.obj','Coast')
if u.EditorAssetLibrary.does_asset_exist(LEVEL):
    if not levels.load_level(LEVEL):
        raise RuntimeError('Cannot load unfinished level')
    if any(a.get_actor_label().startswith('VIIC') for a in actors.get_all_level_actors()):
        raise RuntimeError('Existing scene has content; refusing to duplicate actors')
else:
    if not levels.new_level(LEVEL):
        raise RuntimeError('Cannot create Atlantic level')

boat = spawn(u.StaticMeshActor, 'VIIC — modèle détaillé', (0,0,-190))
boat.static_mesh_component.set_static_mesh(submarine)
boat.set_actor_rotation(u.Rotator(pitch=0,yaw=0,roll=90),False)
land = spawn(u.StaticMeshActor, 'Côte rocheuse', (80000,50000,0))
land.static_mesh_component.set_static_mesh(coast)
land.set_actor_rotation(u.Rotator(pitch=0,yaw=0,roll=90),False)

# World-space rock variation: same scale across the island, with no stretched UVs.
rock = assets.create_asset('Rock', '/Game/Demo/Materials', u.Material, u.MaterialFactoryNew())
mel = u.MaterialEditingLibrary
position = mel.create_material_expression(rock,u.MaterialExpressionWorldPosition,-800,0)
noise = mel.create_material_expression(rock,u.MaterialExpressionNoise,-600,0)
noise.set_editor_property('scale',0.003)
noise.set_editor_property('levels',4)
mel.connect_material_expressions(position,'',noise,'Position')
dark = mel.create_material_expression(rock,u.MaterialExpressionConstant3Vector,-600,200)
dark.set_editor_property('constant',u.LinearColor(0.035,0.042,0.045,1))
light = mel.create_material_expression(rock,u.MaterialExpressionConstant3Vector,-600,350)
light.set_editor_property('constant',u.LinearColor(0.19,0.18,0.15,1))
blend = mel.create_material_expression(rock,u.MaterialExpressionLinearInterpolate,-300,100)
mel.connect_material_expressions(dark,'',blend,'A')
mel.connect_material_expressions(light,'',blend,'B')
mel.connect_material_expressions(noise,'',blend,'Alpha')
mel.connect_material_property(blend,'',u.MaterialProperty.MP_BASE_COLOR)
roughness = mel.create_material_expression(rock,u.MaterialExpressionConstant,-300,350)
roughness.set_editor_property('r',0.88)
mel.connect_material_property(roughness,'',u.MaterialProperty.MP_ROUGHNESS)
mel.recompile_material(rock)
land.static_mesh_component.set_material(0,rock)


# Physically lit sky. Exposure is fixed, avoiding adaptation changes while comparing views.
sun = spawn(u.DirectionalLight,'Soleil', (0,0,50000),(-24,-38,0))
sun.light_component.set_mobility(u.ComponentMobility.MOVABLE)
sun.light_component.set_editor_property('intensity', 45000.0)
sun.light_component.set_editor_property('atmosphere_sun_light',True)
sun.light_component.set_editor_property('light_source_angle',1.0)
spawn(u.SkyAtmosphere,'Atmosphère')
sky = spawn(u.SkyLight,'Lumière du ciel')
sky.light_component.set_mobility(u.ComponentMobility.MOVABLE)
sky.light_component.set_editor_property('real_time_capture',True)
spawn(u.VolumetricCloud,'Nuages')
fog = spawn(u.ExponentialHeightFog,'Brume maritime')
fog.component.set_editor_property('fog_density',0.008)
post = spawn(u.PostProcessVolume,'Exposition')
post.set_editor_property('unbound',True)
settings = post.get_editor_property('settings')
settings.set_editor_property('override_auto_exposure_min_brightness',True)
settings.set_editor_property('override_auto_exposure_max_brightness',True)
settings.set_editor_property('auto_exposure_min_brightness',12.0)
settings.set_editor_property('auto_exposure_max_brightness',12.0)
post.set_editor_property('settings',settings)

zone = spawn(u.WaterZone,'Zone océan', (0,0,0))
zone.set_editor_property('zone_extent',u.Vector2D(500000,500000))
ocean = spawn(u.WaterBodyOcean,'Atlantique', (80000,50000,0))
water = ocean.water_body_component
water.set_editor_property('affects_landscape',False)
water.set_editor_property('ocean_extents',u.Vector2D(500000,500000))
water.set_water_zone_override(zone)
water.set_water_material(u.load_asset('/Water/Materials/WaterSurface/Water_Material_Ocean'))
waves = u.load_asset('/Water/Waves/GerstnerWaves_Ocean').get_editor_property('WaterWaves')
ocean.set_water_waves(waves)
# The ocean spline encloses the island; keep it away from the submarine.
spline = ocean.spline_comp
spline.clear_spline_points(False)
for point in [(-20000,-12000,0),(-20000,12000,0),(20000,12000,0),(20000,-12000,0)]:
    spline.add_spline_point(u.Vector(*point),u.SplineCoordinateSpace.LOCAL,False)
spline.set_closed_loop(True,True)

spawn(u.PlayerStart,'Départ — vue du sous-marin',(-7500,-9000,1900),(-10,47,0))
u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(-7500,-9000,1900),u.Rotator(pitch=-10,yaw=47,roll=0))
levels.save_current_level()
u.EditorAssetLibrary.save_directory('/Game/Demo')
u.log('DEMO_BUILD_COMPLETE: '+LEVEL)

(ROOT / 'Saved' / 'demo-built.txt').write_text(LEVEL)
