from pathlib import Path
import unreal as u
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
for actor in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
    u.log('DEMO_ACTOR: '+actor.get_actor_label()+' '+str(actor.get_actor_bounds(False)))
u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(-7500,-9000,1900),u.Rotator(pitch=-10,yaw=47,roll=0))
u.log('DEMO_INSPECT_COMPLETE')

for actor in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
    if isinstance(actor,u.DirectionalLight):
        actor.set_actor_rotation(u.Rotator(pitch=-24,yaw=-38,roll=0),False)
        actor.light_component.set_mobility(u.ComponentMobility.MOVABLE)
    if isinstance(actor,u.SkyLight):
        actor.light_component.set_mobility(u.ComponentMobility.MOVABLE)
    if isinstance(actor,u.PlayerStart):
        actor.set_actor_rotation(u.Rotator(pitch=-10,yaw=47,roll=0),False)
level.save_current_level()
