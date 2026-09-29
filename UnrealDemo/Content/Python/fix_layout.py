import unreal as u
actors = u.get_editor_subsystem(u.EditorActorSubsystem)
for actor in actors.get_all_level_actors():
    if isinstance(actor,u.StaticMeshActor):
        actor.set_actor_rotation(u.Rotator(pitch=0,yaw=0,roll=90),False)
        u.log('DEMO_FIXED_BOUNDS: '+actor.get_actor_label()+' '+str(actor.get_actor_bounds(False)))
u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(-7500,-9000,1900),u.Rotator(pitch=-9,yaw=47,roll=0))
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
