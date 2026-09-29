import unreal as u
mel=u.MaterialEditingLibrary
for actor in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
    if actor.get_actor_label().startswith('VIIC'):
        # Same surface placement as Sources/Game.swift: y = -1.9 m.
        actor.set_actor_location(u.Vector(0,0,-190),False,False)
    if isinstance(actor,u.PostProcessVolume):
        s=actor.settings
        s.auto_exposure_min_brightness=13.3
        s.auto_exposure_max_brightness=13.3
        actor.settings=s
water=u.load_asset('/Game/Demo/Materials/AtlanticWater')
mel.set_material_instance_scalar_parameter_value(water,'Water Roughness',0.14)
mel.set_material_instance_scalar_parameter_value(water,'Water Fresnel Roughness',0.16)
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
u.EditorAssetLibrary.save_directory('/Game/Demo')
u.log('DEMO_FINAL_SAVED')
