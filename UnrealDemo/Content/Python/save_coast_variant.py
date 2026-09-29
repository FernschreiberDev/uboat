import unreal as u
if u.EditorAssetLibrary.does_asset_exist('/Game/Demo/AtlanticCoast'):
    raise RuntimeError('Coast variant already exists; refusing to overwrite')
level=u.get_editor_subsystem(u.LevelEditorSubsystem)
level.load_level('/Game/Demo/AtlanticDemo')
actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
land=next(a for a in actors if a.get_actor_label().startswith('Côte'))
land.static_mesh_component.set_static_mesh(u.load_asset('/Game/Demo/Scenery/AtlanticCliffs'))
land.static_mesh_component.set_material(0,u.load_asset('/Game/Demo/Scenery/StratifiedCoast'))
land.set_actor_rotation(u.Rotator(roll=0,pitch=0,yaw=0),False)
# Keep the original rendering/collision flags while saving as a new world.
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
if not u.EditorLoadingAndSavingUtils.save_map(world,'/Game/Demo/AtlanticCoast'):
    raise RuntimeError('Save Map failed')
u.log('COAST_SAVE_AS_COMPLETE')
