"""Read-only checks of saved scenery, boat settings and water rendering data."""
from pathlib import Path
import json,unreal as u
actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
boat=next(a for a in actors if a.get_actor_label().startswith('VIIC'))
land=next(a for a in actors if a.get_actor_label().startswith('Côte'))
rocks=[a for a in actors if a.get_actor_label().startswith('Rivage rocheux ')]
water=next(a for a in actors if isinstance(a,u.WaterBodyOcean))
info=[c for c in water.get_components_by_class(u.StaticMeshComponent) if c.get_class().get_name()=='WaterBodyInfoMeshComponent']
b=boat.static_mesh_component.get_editor_property('body_instance')
pos=boat.get_actor_location();rot=boat.get_actor_rotation()
assert len(rocks)==8
assert all(c.static_mesh is not None for c in info) and len(info)==2
assert b.simulate_physics and abs(b.mass_in_kg_override-769000)<1
assert abs(pos.z+190)<0.01 and abs(rot.yaw+90)<0.01
assert all(a.static_mesh_component.static_mesh.get_num_lods()==4 for a in rocks)
report={'map':u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world().get_path_name(),'rock_sections':len(rocks),'rock_lods':4,'coast_material':land.static_mesh_component.get_material(0).get_path_name(),'water_render_meshes':len(info),'boat_mass_kg':b.mass_in_kg_override,'boat_location_cm':[pos.x,pos.y,pos.z],'boat_yaw':rot.yaw,'buoyancy_class':[c.get_class().get_path_name() for c in boat.get_components_by_class(u.BuoyancyComponent)]}
(Path(u.Paths.project_dir())/'Docs/coast-detail-validation.json').write_text(json.dumps(report,indent=2))
u.log('COAST_DETAIL_VALIDATED')
