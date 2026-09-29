"""Regenerate the optional map's water render meshes in the full editor.

A non-rendering commandlet cannot build WaterInfo meshes (UE CanEverRender guard).
Run after creating the variant, with AtlanticCoast open. Never alters waves or buoyancy.
"""
import unreal as u
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
if not world.get_path_name().startswith('/Game/Demo/AtlanticCoast.'):
    raise RuntimeError('Open AtlanticCoast in the full editor before running this repair')
actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
zone=next(a for a in actors if isinstance(a,u.WaterZone))
ocean=next(a for a in actors if isinstance(a,u.WaterBodyOcean))
water=ocean.water_body_component
# Calling this exposed setter regenerates both WaterInfo meshes. Restore its value.
settings=water.get_editor_property('static_mesh_settings')
was_enabled=settings.get_editor_property('enable_water_body_static_mesh')
water.set_water_body_static_mesh_enabled(not was_enabled)
water.set_water_body_static_mesh_enabled(was_enabled)
info=[c for c in ocean.get_components_by_class(u.StaticMeshComponent)
      if c.get_class().get_name()=='WaterBodyInfoMeshComponent']
if not info or any(c.static_mesh is None for c in info):
    raise RuntimeError('WaterInfo meshes missing: this repair requires a rendering editor')
water.set_water_zone_override(zone)
extent=zone.get_editor_property('zone_extent')
zone.set_editor_property('zone_extent',u.Vector2D(extent.x+1,extent.y+1))
zone.set_editor_property('zone_extent',extent)
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
u.log('COAST_WATER_REPAIRED: render meshes saved')
