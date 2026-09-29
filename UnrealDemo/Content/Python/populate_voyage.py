from pathlib import Path
import unreal as u
ROOT=Path(u.Paths.project_dir())
DEST='/Game/Voyage/AtlanticVoyage'
level=u.get_editor_subsystem(u.LevelEditorSubsystem)
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert world.get_path_name().startswith(DEST+'.')
assert world.get_world_settings().get_editor_property('default_game_mode') is None
assert len(u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors())==19
sub=u.get_editor_subsystem(u.EditorActorSubsystem)
actors=sub.get_all_level_actors()
boat=next(a for a in actors if a.get_actor_label().startswith('VIIC'))
boat.set_editor_property('tags',list(boat.tags)+[u.Name('VoyageVIIC')])
gm=u.load_class(None,'/Script/NordatlantikDemo.VoyageGameMode')
assert gm
world.get_world_settings().set_editor_property('default_game_mode',gm)
# Queries against actual triangles; no convex island collider may eject the boat.
for a in actors:
 if a.get_actor_label().startswith(('Côte','Rivage rocheux')):
  c=a.static_mesh_component;c.set_collision_enabled(u.CollisionEnabled.QUERY_ONLY)
  c.set_collision_response_to_channel(u.CollisionChannel.ECC_VISIBILITY,u.CollisionResponseType.ECR_BLOCK)
assets=u.AssetToolsHelpers.get_asset_tools();mel=u.MaterialEditingLibrary
folder='/Game/Voyage/Materials'
def material(name,color,rough=0.9):
 path=folder+'/'+name
 if u.EditorAssetLibrary.does_asset_exist(path):return u.load_asset(path)
 m=assets.create_asset(name,folder,u.Material,u.MaterialFactoryNew())
 e=mel.create_material_expression(m,u.MaterialExpressionConstant3Vector,-200,0);e.set_editor_property('constant',u.LinearColor(*color,1));mel.connect_material_property(e,'',u.MaterialProperty.MP_BASE_COLOR)
 e=mel.create_material_expression(m,u.MaterialExpressionConstant,-200,160);e.set_editor_property('r',rough);mel.connect_material_property(e,'',u.MaterialProperty.MP_ROUGHNESS)
 mel.recompile_material(m);u.EditorAssetLibrary.save_loaded_asset(m);return m
sand=material('Seabed',(0.075,0.095,0.09));rust=material('WreckSteel',(0.14,0.048,0.016));orange=material('NavigationOrange',(0.9,0.24,0.015),0.55)
def shape(label,mesh,location,scale,mat,collision=True,rotation=None):
 a=sub.spawn_actor_from_class(u.StaticMeshActor,u.Vector(*location),rotation or u.Rotator())
 a.set_actor_label(label);a.static_mesh_component.set_static_mesh(u.load_asset(mesh));a.set_actor_scale3d(u.Vector(*scale));a.static_mesh_component.set_material(0,mat)
 a.static_mesh_component.set_collision_enabled(u.CollisionEnabled.QUERY_ONLY if collision else u.CollisionEnabled.NO_COLLISION)
 a.static_mesh_component.set_collision_response_to_channel(u.CollisionChannel.ECC_VISIBILITY,u.CollisionResponseType.ECR_BLOCK)
 return a
cube='/Engine/BasicShapes/Cube';cylinder='/Engine/BasicShapes/Cylinder';sphere='/Engine/BasicShapes/Sphere'
shape('Fond marin — 240 m',cube,(0,0,-24500),(5000,5000,10),sand)
shape('Balise orange du large',cylinder,(0,-35000,100),(4,4,8),orange,False)
shape('Balise — couronne',sphere,(0,-35000,550),(4,4,4),orange,False)
# A shallow bank supports a small wreck instead of suspending it in mid-water.
shape('Banc de l epave',sphere,(28000,-62000,-9000),(170,130,80),sand)
shape('Epave — coque',cube,(28000,-62000,-4800),(55,10,3),rust,True,u.Rotator(roll=8,pitch=3,yaw=15))
shape('Epave — passerelle',cube,(28200,-62000,-4520),(10,8,5),rust,True,u.Rotator(roll=8,pitch=3,yaw=15))
shape('Epave — cheminee',cylinder,(27700,-62000,-4250),(2.8,2.8,8),rust,True,u.Rotator(roll=14,pitch=4,yaw=15))
# The added battleship is a stationary rendezvous landmark in this gameplay map.
# Its separate simulation map and buoyancy component are untouched.
bmesh=u.load_asset('/Game/Bismarck/Meshes/Bismarck')
if bmesh:
 b=sub.spawn_actor_from_class(u.StaticMeshActor,u.Vector(6000,34000,0),u.Rotator(yaw=-156,pitch=0,roll=0));b.set_actor_label('Bismarck — rendez-vous au mouillage');b.static_mesh_component.set_static_mesh(bmesh)
 b.static_mesh_component.set_collision_enabled(u.CollisionEnabled.QUERY_ONLY)
 b.static_mesh_component.set_collision_response_to_channel(u.CollisionChannel.ECC_VISIBILITY,u.CollisionResponseType.ECR_BLOCK)
# Rebuild WaterInfo in the rendering editor so the copied ocean survives reopening.
water=next(a for a in actors if isinstance(a,u.WaterBodyOcean)).water_body_component
zone=next(a for a in actors if isinstance(a,u.WaterZone))
water.set_water_body_static_mesh_enabled(True);water.set_water_body_static_mesh_enabled(False)
water.set_water_zone_override(zone)
extent=zone.get_editor_property('zone_extent')
zone.set_editor_property('zone_extent',u.Vector2D(extent.x+1,extent.y+1));zone.set_editor_property('zone_extent',extent)
level.save_current_level()
(ROOT/'Saved/voyage-built.txt').write_text(DEST)
u.log('VOYAGE_MAP_BUILT')
u.SystemLibrary.quit_editor()
